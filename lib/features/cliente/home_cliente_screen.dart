import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/models/producto.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/cart_service.dart';
import '../../core/services/catalogo_service.dart';
import '../../core/services/recommendation_service.dart';
import '../shared/home_shell.dart';
import '../shared/kantu_app_bar.dart';
import '../shared/kantu_search_field.dart';
import '../shared/producto_imagen.dart';
import 'producto_detail_sheet.dart';
import 'recomendaciones_section.dart';

/// Vitrina del cliente (CU-11). En modo servidor lee el catálogo público
/// (`/api/catalogo/productos/`, con búsqueda y filtro del lado del servidor) y
/// en modo autónomo el mismo catálogo desde SQLite.
class HomeClienteScreen extends StatefulWidget {
  const HomeClienteScreen({super.key});

  @override
  State<HomeClienteScreen> createState() => _HomeClienteScreenState();
}

class _HomeClienteScreenState extends State<HomeClienteScreen> {
  final _searchController = TextEditingController();
  final Map<int, String> _stores = {};
  int? _selectedStoreId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final catalogo = context.read<CatalogoService>();
      final cart = context.read<CartService>();
      final currentUser = context.read<AuthService>().currentUser;
      catalogo.limpiarFiltros();
      await catalogo.loadCatalogo();
      if (!mounted) return;
      setState(() {
        for (final product in catalogo.productos) {
          _stores[product.tiendaId] = product.tiendaNombre;
        }
      });
      cart.loadCarrito(currentUser);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _abrirDetalle(Producto producto) async {
    context.read<RecommendationService>().registerInteraction(
      tiendaId: producto.tiendaId,
      productoId: producto.id,
      type: 'CLICK',
    );
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProductoDetailSheet(producto: producto),
    );
  }

  Future<void> _selectStore(int? storeId) async {
    setState(() => _selectedStoreId = storeId);
    final catalog = context.read<CatalogoService>();
    catalog.limpiarFiltros();
    _searchController.clear();
    await catalog.loadCatalogo(tiendaId: storeId);
    if (mounted && storeId == null) {
      setState(() {
        for (final product in catalog.productos) {
          _stores[product.tiendaId] = product.tiendaNombre;
        }
      });
    }
  }

  void _search(String value) {
    final catalog = context.read<CatalogoService>();
    catalog.setSearch(value, tiendaId: _selectedStoreId);
    if (_selectedStoreId != null && value.trim().isNotEmpty) {
      context.read<RecommendationService>().registerInteraction(
        tiendaId: _selectedStoreId!,
        type: 'SEARCH',
        searchTerm: value,
      );
    }
  }

  /// Agregado rápido desde la tarjeta: sólo tiene sentido cuando no hay que
  /// elegir entre varias variantes; si las hay, se abre el detalle.
  Future<void> _agregarRapido(Producto producto) async {
    if (producto.tieneVariasVariantes) {
      await _abrirDetalle(producto);
      return;
    }

    final variante = producto.variantePrincipal;
    if (variante == null) return;

    final cart = context.read<CartService>();
    final ok = await cart.agregar(
      producto: producto,
      variante: variante,
      cliente: context.read<AuthService>().currentUser,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? '¡${producto.nombre} agregado!'
                : (cart.errorMessage ?? 'No se pudo agregar al carrito.'),
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: ok ? KantuColors.success : KantuColors.error,
        ),
      );
    cart.limpiarError();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final catalogo = context.watch<CatalogoService>();
    final cart = context.watch<CartService>();

    return Scaffold(
      backgroundColor: KantuColors.background,
      appBar: KantuAppBar(
        title: 'Kantu Market',
        showBackButton: false,
        actions: [
          // Atajo al carrito con su total. La pestaña de abajo ya lleva el
          // contador, así que aquí basta un botón discreto y no un FAB que
          // tape la última fila de productos.
          if (cart.itemCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: KantuColors.primary,
                  backgroundColor: KantuColors.primaryLight,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.shopping_bag_outlined, size: 16),
                label: Text(
                  'Bs. ${cart.totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                onPressed: () => HomeShellScope.of(context)?.irATab(1),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => catalogo.loadCatalogo(),
        color: KantuColors.primary,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HeroBanner(nombre: auth.currentUser?.firstName ?? 'Cliente'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: KantuSearchField(
                      controller: _searchController,
                      hint: 'Buscar textiles, artesanías, café...',
                      // Sólo al enviar: en modo servidor buscar por tecla sería
                      // una petición por carácter.
                      onSubmitted: _search,
                      onChanged: (valor) {
                        setState(() {});
                        if (valor.isEmpty) {
                          catalogo.setSearch('', tiendaId: _selectedStoreId);
                        }
                      },
                      onLimpiar: () {
                        _searchController.clear();
                        catalogo.setSearch('', tiendaId: _selectedStoreId);
                        setState(() {});
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (_stores.isNotEmpty) ...[
                    SizedBox(
                      height: 38,
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        children: [
                          ChoiceChip(
                            label: const Text('Todas las tiendas'),
                            selected: _selectedStoreId == null,
                            onSelected: (_) => _selectStore(null),
                          ),
                          const SizedBox(width: 8),
                          for (final entry in _stores.entries) ...[
                            ChoiceChip(
                              label: Text(
                                entry.value.isEmpty
                                    ? 'Tienda ${entry.key}'
                                    : entry.value,
                              ),
                              selected: _selectedStoreId == entry.key,
                              onSelected: (_) => _selectStore(entry.key),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (catalogo.categorias.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: FiltrosCategoria(
                        categorias: [
                          (id: null, nombre: 'Todos'),
                          for (final c in catalogo.categorias)
                            (id: c.id, nombre: c.nombre),
                        ],
                        seleccionada: catalogo.selectedCategoriaId,
                        onSeleccionar: catalogo.setCategoria,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Catálogo de Productos',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: KantuColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${catalogo.productos.length} items',
                          style: const TextStyle(
                            fontSize: 12,
                            color: KantuColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_selectedStoreId != null)
                    RecomendacionesSection(
                      key: ValueKey('recommendations-$_selectedStoreId'),
                      tiendaId: _selectedStoreId!,
                      onProductTap: _abrirDetalle,
                    ),
                ],
              ),
            ),

            if (catalogo.isLoading)
              const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(
                      color: KantuColors.primary,
                    ),
                  ),
                ),
              )
            else if (catalogo.productos.isEmpty)
              const SliverToBoxAdapter(child: _SinResultados())
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.66,
                  ),
                  delegate: SliverChildBuilderDelegate((ctx, idx) {
                    final producto = catalogo.productos[idx];
                    return _TarjetaProducto(
                      producto: producto,
                      onTap: () => _abrirDetalle(producto),
                      onAgregar: () => _agregarRapido(producto),
                    );
                  }, childCount: catalogo.productos.length),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  final String nombre;

  const _HeroBanner({required this.nombre});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: KantuColors.heroGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: KantuColors.primary.withAlpha(50),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(40),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🇧🇴', style: TextStyle(fontSize: 14)),
                SizedBox(width: 6),
                Text(
                  'Mercado Digital Boliviano',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '¡Hola, $nombre! 👋',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Descubre productos auténticos de emprendedores bolivianos.',
            style: TextStyle(fontSize: 13, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _TarjetaProducto extends StatelessWidget {
  final Producto producto;
  final VoidCallback onTap;
  final VoidCallback onAgregar;

  const _TarjetaProducto({
    required this.producto,
    required this.onTap,
    required this.onAgregar,
  });

  @override
  Widget build(BuildContext context) {
    final agotado = producto.agotado;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: KantuColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(5),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ProductoImagen(
                  origen: producto.imagenPrincipal,
                  height: 120,
                  width: double.infinity,
                  radio: 15,
                ),
                if (agotado)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: KantuColors.error,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'AGOTADO',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  )
                else if (producto.variantePrincipal?.enOferta == true)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: KantuColors.accent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'OFERTA',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: KantuColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      producto.tiendaNombre.isNotEmpty
                          ? producto.tiendaNombre
                          : 'Kantu Market',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: KantuColors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Expanded(
                      child: Text(
                        producto.nombre,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: KantuColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (producto.tieneVariasVariantes)
                      Text(
                        '${producto.variantesActivas.length} presentaciones',
                        style: const TextStyle(
                          fontSize: 10,
                          color: KantuColors.textMuted,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: FittedBox(
                            child: Text(
                              '${producto.tieneVariasVariantes ? "Desde " : ""}Bs. ${producto.precioBase.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: KantuColors.primary,
                              ),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: agotado ? null : onAgregar,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: agotado
                                  ? KantuColors.border
                                  : KantuColors.primaryLight,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.add_shopping_cart,
                              size: 16,
                              color: agotado
                                  ? KantuColors.textMuted
                                  : KantuColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SinResultados extends StatelessWidget {
  const _SinResultados();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          children: [
            Text('🔍', style: TextStyle(fontSize: 48)),
            SizedBox(height: 12),
            Text(
              'No se encontraron productos',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 4),
            Text(
              'Intenta con otra búsqueda o categoría',
              style: TextStyle(fontSize: 12, color: KantuColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
