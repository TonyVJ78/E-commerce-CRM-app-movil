import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/models/producto.dart';
import '../../core/models/tienda.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/catalogo_service.dart';
import '../shared/kantu_app_bar.dart';
import '../shared/kantu_search_field.dart';
import '../shared/producto_imagen.dart';
import 'producto_form_screen.dart';

/// Catálogo de una tienda desde el panel de la empresa.
///
/// Aquí viven CU-08 (registrar), CU-09 (editar / activar / eliminar) y el
/// resumen de inventario por tienda de CU-10.
class TiendaDetailScreen extends StatefulWidget {
  final Tienda tienda;

  const TiendaDetailScreen({super.key, required this.tienda});

  @override
  State<TiendaDetailScreen> createState() => _TiendaDetailScreenState();
}

class _TiendaDetailScreenState extends State<TiendaDetailScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final catalogo = context.read<CatalogoService>();
      catalogo.limpiarFiltros();
      catalogo.loadCatalogoEmpresa(widget.tienda.id);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color get _storeColor {
    try {
      final clean = widget.tienda.colorPrimario.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return KantuColors.primary;
    }
  }

  void _mostrarMensaje(ResultadoCatalogo resultado) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(resultado.mensaje),
          backgroundColor: !resultado.exito
              ? KantuColors.error
              : (resultado.guardadoLocal ? KantuColors.warning : KantuColors.success),
          duration: Duration(seconds: resultado.guardadoLocal ? 5 : 3),
        ),
      );
  }

  Future<void> _abrirFormulario({Producto? producto}) async {
    final resultado = await Navigator.push<ResultadoCatalogo>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductoFormScreen(tienda: widget.tienda, producto: producto),
      ),
    );

    if (!mounted || resultado == null) return;
    _mostrarMensaje(resultado);
    context.read<CatalogoService>().loadCatalogoEmpresa(widget.tienda.id);
  }

  Future<void> _confirmarEliminacion(Producto producto) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar producto', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
          '¿Seguro que deseas eliminar "${producto.nombre}" del catálogo?\n\n'
          'Se dará de baja sin borrarlo, para no afectar a los pedidos que ya lo incluyen. '
          'Podrás volver a verlo con el filtro "Inactivos".',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: KantuColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: KantuColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmado != true || !mounted) return;

    final catalogo = context.read<CatalogoService>();
    final email = context.read<AuthService>().currentUser?.email;
    _mostrarMensaje(await catalogo.eliminarProducto(producto, usuarioEmail: email));
  }

  Future<void> _alternarEstado(Producto producto) async {
    final catalogo = context.read<CatalogoService>();
    final email = context.read<AuthService>().currentUser?.email;
    _mostrarMensaje(await catalogo.toggleActivo(producto, usuarioEmail: email));
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tienda;
    final catalogo = context.watch<CatalogoService>();

    return Scaffold(
      backgroundColor: KantuColors.background,
      appBar: KantuAppBar(title: t.nombre),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _storeColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Producto', style: TextStyle(fontWeight: FontWeight.w700)),
        onPressed: () => _abrirFormulario(),
      ),
      body: RefreshIndicator(
        color: _storeColor,
        onRefresh: () => catalogo.loadCatalogoEmpresa(t.id),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            _CabeceraTienda(tienda: t, color: _storeColor),
            const SizedBox(height: 16),
            _ResumenInventario(catalogo: catalogo, color: _storeColor),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Catálogo de Productos',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: KantuColors.textPrimary),
                ),
                Text(
                  '${catalogo.productos.length} productos',
                  style: const TextStyle(fontSize: 12, color: KantuColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 12),

            KantuSearchField(
              controller: _searchController,
              onChanged: (valor) => catalogo.setSearch(valor, tiendaId: t.id, empresa: true),
              onLimpiar: () {
                _searchController.clear();
                catalogo.setSearch('', tiendaId: t.id, empresa: true);
              },
            ),
            const SizedBox(height: 12),

            FiltrosCategoria(
              categorias: [
                (id: null, nombre: 'Todas'),
                for (final c in catalogo.categorias) (id: c.id, nombre: c.nombre),
              ],
              seleccionada: catalogo.selectedCategoriaId,
              color: _storeColor,
              onSeleccionar: (id) => catalogo.setCategoria(id, tiendaId: t.id, empresa: true),
              incluirInactivos: catalogo.incluirInactivos,
              onInactivos: (valor) => catalogo.setIncluirInactivos(valor, t.id),
            ),
            const SizedBox(height: 12),

            if (catalogo.isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
            else if (catalogo.productos.isEmpty)
              _EstadoVacio(hayFiltros: catalogo.searchQuery.isNotEmpty || catalogo.selectedCategoriaId != null)
            else
              for (final producto in catalogo.productos)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _TarjetaProducto(
                    producto: producto,
                    color: _storeColor,
                    onEditar: () => _abrirFormulario(producto: producto),
                    onAlternar: () => _alternarEstado(producto),
                    onEliminar: () => _confirmarEliminacion(producto),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _CabeceraTienda extends StatelessWidget {
  final Tienda tienda;
  final Color color;

  const _CabeceraTienda({required this.tienda, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: KantuColors.border),
        boxShadow: [
          BoxShadow(color: color.withAlpha(20), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withAlpha(30),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(child: Text('🏢', style: TextStyle(fontSize: 24, color: color))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tienda.nombre,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: KantuColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'kantu.bo/@${tienda.slug}',
                      style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: KantuColors.successLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'ACTIVA',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: KantuColors.success),
                ),
              ),
            ],
          ),
          if (tienda.descripcion.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              tienda.descripcion,
              style: const TextStyle(fontSize: 13, color: KantuColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

/// Resumen de inventario de esta tienda (CU-10).
///
/// El endpoint `/api/tiendas/dashboard/` agrega por propietario, no por tienda,
/// así que este desglose se calcula sobre los productos ya cargados.
class _ResumenInventario extends StatelessWidget {
  final CatalogoService catalogo;
  final Color color;

  const _ResumenInventario({required this.catalogo, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KantuColors.border),
      ),
      child: Row(
        children: [
          _Metrica(
            valor: '${catalogo.productosActivos}',
            etiqueta: 'Productos',
            color: color,
          ),
          _Separador(),
          _Metrica(
            valor: '${catalogo.stockTotal}',
            etiqueta: 'Unidades',
            color: KantuColors.info,
          ),
          _Separador(),
          _Metrica(
            valor: 'Bs. ${catalogo.valorInventario.toStringAsFixed(0)}',
            etiqueta: 'Inventario',
            color: KantuColors.success,
          ),
          if (catalogo.productosAgotados > 0) ...[
            _Separador(),
            _Metrica(
              valor: '${catalogo.productosAgotados}',
              etiqueta: 'Agotados',
              color: KantuColors.error,
            ),
          ],
        ],
      ),
    );
  }
}

class _Metrica extends StatelessWidget {
  final String valor;
  final String etiqueta;
  final Color color;

  const _Metrica({required this.valor, required this.etiqueta, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            child: Text(
              valor,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            etiqueta,
            style: const TextStyle(fontSize: 11, color: KantuColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _Separador extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 32, color: KantuColors.border);
  }
}

class _TarjetaProducto extends StatelessWidget {
  final Producto producto;
  final Color color;
  final VoidCallback onEditar;
  final VoidCallback onAlternar;
  final VoidCallback onEliminar;

  const _TarjetaProducto({
    required this.producto,
    required this.color,
    required this.onEditar,
    required this.onAlternar,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: producto.activo ? 1 : 0.6,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: producto.activo ? KantuColors.border : KantuColors.textMuted.withAlpha(80),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProductoImagen(origen: producto.imagenPrincipal, width: 56, height: 56, radio: 10),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    producto.nombre,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'SKU: ${producto.sku.isNotEmpty ? producto.sku : "S/N"} · Stock: ${producto.stockTotal}'
                    '${producto.tieneVariasVariantes ? " · ${producto.variantesActivas.length} variantes" : ""}',
                    style: const TextStyle(fontSize: 11, color: KantuColors.textMuted),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '${producto.tieneVariasVariantes ? "Desde " : ""}Bs. ${producto.precioBase.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color),
                      ),
                      if (!producto.activo)
                        const _Etiqueta(texto: 'INACTIVO', color: KantuColors.textSecondary),
                      if (producto.activo && producto.agotado)
                        const _Etiqueta(texto: 'AGOTADO', color: KantuColors.error),
                      if (producto.activo && !producto.agotado && producto.bajoStock)
                        const _Etiqueta(texto: 'BAJO STOCK', color: KantuColors.warning),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20, color: KantuColors.textSecondary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (valor) {
                switch (valor) {
                  case 'editar':
                    onEditar();
                  case 'alternar':
                    onAlternar();
                  case 'eliminar':
                    onEliminar();
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'editar',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.edit_outlined, size: 20),
                    title: Text('Editar', style: TextStyle(fontSize: 14)),
                  ),
                ),
                PopupMenuItem(
                  value: 'alternar',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      producto.activo ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 20,
                    ),
                    title: Text(
                      producto.activo ? 'Desactivar' : 'Activar',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
                const PopupMenuItem(
                  value: 'eliminar',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.delete_outline, size: 20, color: KantuColors.error),
                    title: Text(
                      'Eliminar',
                      style: TextStyle(fontSize: 14, color: KantuColors.error),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  final String texto;
  final Color color;

  const _Etiqueta({required this.texto, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        texto,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }
}

class _EstadoVacio extends StatelessWidget {
  final bool hayFiltros;

  const _EstadoVacio({required this.hayFiltros});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KantuColors.border),
      ),
      child: Column(
        children: [
          Text(hayFiltros ? '🔍' : '📦', style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(
            hayFiltros ? 'Ningún producto coincide' : 'Esta tienda aún no tiene productos',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            hayFiltros
                ? 'Prueba con otra búsqueda o cambia de categoría.'
                : 'Usa el botón "Nuevo Producto" para agregar ítems al catálogo.',
            style: const TextStyle(fontSize: 12, color: KantuColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
