import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/models/tienda.dart';
import '../../core/services/catalogo_service.dart';
import '../shared/kantu_app_bar.dart';
import 'create_producto_dialog.dart';

class TiendaDetailScreen extends StatefulWidget {
  final Tienda tienda;

  const TiendaDetailScreen({super.key, required this.tienda});

  @override
  State<TiendaDetailScreen> createState() => _TiendaDetailScreenState();
}

class _TiendaDetailScreenState extends State<TiendaDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CatalogoService>().loadCatalogo(tiendaId: widget.tienda.id);
    });
  }

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return KantuColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tienda;
    final catalogo = context.watch<CatalogoService>();
    final storeColor = _parseColor(t.colorPrimario);

    return Scaffold(
      backgroundColor: KantuColors.background,
      appBar: KantuAppBar(title: t.nombre),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: storeColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Producto', style: TextStyle(fontWeight: FontWeight.w700)),
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => CreateProductoDialog(tienda: t),
          );
        },
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Store Card Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: KantuColors.border),
                boxShadow: [
                  BoxShadow(
                    color: storeColor.withAlpha(20),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
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
                          color: storeColor.withAlpha(30),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(
                            '🏢',
                            style: TextStyle(fontSize: 24, color: storeColor),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.nombre,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: KantuColors.textPrimary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'kantu.bo/@${t.slug}',
                              style: TextStyle(fontSize: 12, color: storeColor, fontWeight: FontWeight.w600),
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
                        child: const Text('ACTIVA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: KantuColors.success)),
                      ),
                    ],
                  ),
                  if (t.descripcion.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(t.descripcion, style: const TextStyle(fontSize: 13, color: KantuColors.textSecondary)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Products Section
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

            if (catalogo.isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
            else if (catalogo.productos.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: KantuColors.border),
                ),
                child: Column(
                  children: [
                    const Text('📦', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 12),
                    const Text('Esta tienda aún no tiene productos', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    const Text('Usa el botón "Nuevo Producto" para agregar ítems al catálogo.', style: TextStyle(fontSize: 12, color: KantuColors.textSecondary)),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: catalogo.productos.length,
                separatorBuilder: (_, index) => const SizedBox(height: 10),
                itemBuilder: (ctx, idx) {
                  final p = catalogo.productos[idx];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: KantuColors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: storeColor.withAlpha(20),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(child: Text('🧣', style: TextStyle(fontSize: 22))),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.nombre, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Text('SKU: ${p.sku.isNotEmpty ? p.sku : "S/N"} • Stock: ${p.stock}', style: const TextStyle(fontSize: 11, color: KantuColors.textMuted)),
                            ],
                          ),
                        ),
                        Text(
                          'Bs. ${p.precioBase.toStringAsFixed(2)}',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: storeColor),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
