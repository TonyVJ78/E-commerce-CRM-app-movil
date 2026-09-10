import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/models/producto.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/cart_service.dart';
import '../../core/services/catalogo_service.dart';
import '../shared/filtro_tiendas.dart';
import '../shared/home_shell.dart';
import '../shared/kantu_app_bar.dart';
import '../shared/kantu_search_field.dart';
import '../shared/producto_imagen.dart';
import 'producto_detail_sheet.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final catalogo = context.read<CatalogoService>();
      catalogo.limpiarFiltros();
      catalogo.loadCatalogo();
      context.read<CartService>().loadCarrito(context.read<AuthService>().currentUser);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _abrirDetalle(Producto producto) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProductoDetailSheet(producto: producto),
    );
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
          content: Text(ok
              ? '¡${producto.nombre} agregado!'
              : (cart.errorMessage ?? 'No se pudo agregar al carrito.')),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.shopping_bag_outlined, size: 16),
                label: Text(
                  'Bs. ${cart.totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
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
                      onSubmitted: catalogo.setSearch,
                      onChanged: (valor) {
                        setState(() {});
                        if (valor.isEmpty) catalogo.setSearch('');
                      },
                      onLimpiar: () {
                        _searchController.clear();
                        catalogo.setSearch('');
                        setState(() {});
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (catalogo.tiendas.isNotEmpty) ...[
                    const _TituloFiltro(texto: 'Tiendas'),
                    const SizedBox(height: 8),
                    FiltroTiendas(
                      tiendas: catalogo.tiendas,
                      seleccionada: catalogo.selectedTiendaId,
                      onSeleccionar: catalogo.setTienda,
                    ),
                    const SizedBox(height: 14),
                  ],

                  if (catalogo.categorias.isNotEmpty) ...[
                    const _TituloFiltro(texto: 'Categorías'),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: FiltrosCategoria(
                        categorias: [
                          (id: null, nombre: 'Todas'),
                          for (final c in catalogo.categorias) (id: c.id, nombre: c.nombre),
                        ],
                        seleccionada: catalogo.selectedCategoriaId,
                        onSeleccionar: catalogo.setCategoria,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (catalogo.errorMessage != null)
                    _AvisoConexion(mensaje: catalogo.errorMessage!),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                catalogo.selectedTiendaNombre ?? 'Catálogo de Productos',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: KantuColors.textPrimary,
                                ),
                              ),
                              Text(
                                // Mientras carga, el conteo todavía es el del
                                // filtro anterior: decirlo es peor que callarlo.
                                catalogo.isLoading
                                    ? 'Buscando productos...'
                                    : '${catalogo.productos.length} '
                                        '${catalogo.productos.length == 1 ? "producto" : "productos"}'
                                        '${catalogo.selectedTiendaNombre != null ? " en esta tienda" : ""}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: KantuColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (catalogo.hayFiltrosActivos)
                          TextButton.icon(
                            onPressed: () {
                              _searchController.clear();
                              catalogo.limpiarFiltrosVitrina();
                              setState(() {});
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: KantuColors.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
                            label: const Text(
                              'Limpiar',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),

            if (catalogo.isLoading)
              const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(color: KantuColors.primary),
                  ),
                ),
              )
            else if (catalogo.productos.isEmpty)
              SliverToBoxAdapter(
                child: _SinResultados(
                  hayFiltros: catalogo.hayFiltrosActivos,
                  onLimpiar: () {
                    _searchController.clear();
                    catalogo.limpiarFiltrosVitrina();
                    setState(() {});
                  },
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.64,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (ctx, idx) {
                      final producto = catalogo.productos[idx];
                      return _TarjetaProducto(
                        producto: producto,
                        onTap: () => _abrirDetalle(producto),
                        onAgregar: () => _agregarRapido(producto),
                      );
                    },
                    childCount: catalogo.productos.length,
                  ),
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
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '¡Hola, $nombre! 👋',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
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
            BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 8, offset: const Offset(0, 2)),
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
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: KantuColors.error,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'AGOTADO',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                  )
                else if (producto.variantePrincipal?.enOferta == true)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
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

                // La categoría se ve sobre la imagen, igual que en la web: dice
                // de qué es el producto sin depender del nombre.
                if (producto.categoriaNombre.isNotEmpty)
                  Positioned(
                    left: 8,
                    bottom: 8,
                    right: 8,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(235),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          producto.categoriaNombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: KantuColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.storefront_outlined,
                            size: 11, color: KantuColors.textMuted),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
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
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Expanded(
                      child: Text(
                        producto.nombre,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.25,
                          fontWeight: FontWeight.w700,
                          color: KantuColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // Disponibilidad: la web la muestra y en el móvil sólo se
                    // sabía al abrir el detalle.
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: agotado ? KantuColors.error : KantuColors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            agotado
                                ? 'Sin stock'
                                : producto.tieneVariasVariantes
                                    ? '${producto.variantesActivas.length} presentaciones'
                                    : '${producto.stockTotal} disponibles',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: agotado
                                  ? KantuColors.error
                                  : KantuColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${producto.tieneVariasVariantes ? "Desde " : ""}'
                        'Bs. ${producto.precioBase.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: KantuColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Botón con texto, como en la web: un icono suelto no dejaba
                    // claro que la tarjeta añade al carrito sin abrir el detalle.
                    SizedBox(
                      width: double.infinity,
                      height: 30,
                      child: FilledButton.icon(
                        onPressed: agotado ? null : onAgregar,
                        style: FilledButton.styleFrom(
                          backgroundColor: KantuColors.primary,
                          disabledBackgroundColor: KantuColors.border,
                          disabledForegroundColor: KantuColors.textMuted,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: Icon(
                          agotado ? Icons.remove_shopping_cart_outlined : Icons.add_shopping_cart,
                          size: 14,
                        ),
                        label: Text(
                          agotado
                              ? 'Agotado'
                              : producto.tieneVariasVariantes
                                  ? 'Elegir'
                                  : 'Agregar',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                        ),
                      ),
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

class _TituloFiltro extends StatelessWidget {
  final String texto;

  const _TituloFiltro({required this.texto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        texto.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: KantuColors.textMuted,
        ),
      ),
    );
  }
}

/// Avisa cuando lo que se ve no viene del servidor. Sin esto, un teléfono que
/// no alcanza el backend muestra el catálogo local como si fuera el real.
class _AvisoConexion extends StatelessWidget {
  final String mensaje;

  const _AvisoConexion({required this.mensaje});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: KantuColors.accentLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KantuColors.accent),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 18, color: KantuColors.accentDark),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              mensaje,
              style: const TextStyle(
                fontSize: 12,
                height: 1.35,
                color: KantuColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SinResultados extends StatelessWidget {
  final bool hayFiltros;
  final VoidCallback onLimpiar;

  const _SinResultados({required this.hayFiltros, required this.onLimpiar});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Text('🔍', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            const Text(
              'No se encontraron productos',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              hayFiltros
                  ? 'Ninguno coincide con la tienda, la categoría o la búsqueda activas.'
                  : 'Todavía no hay productos publicados en el catálogo.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: KantuColors.textSecondary),
            ),
            if (hayFiltros) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onLimpiar,
                style: OutlinedButton.styleFrom(
                  foregroundColor: KantuColors.primary,
                  side: const BorderSide(color: KantuColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
                label: const Text(
                  'Quitar filtros',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
