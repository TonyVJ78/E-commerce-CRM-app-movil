import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/models/producto.dart';
import '../../core/services/cart_service.dart';
import '../shared/custom_button.dart';

class ProductoDetailSheet extends StatefulWidget {
  final Producto producto;

  const ProductoDetailSheet({super.key, required this.producto});

  @override
  State<ProductoDetailSheet> createState() => _ProductoDetailSheetState();
}

class _ProductoDetailSheetState extends State<ProductoDetailSheet> {
  int _cantidad = 1;

  @override
  Widget build(BuildContext context) {
    final p = widget.producto;
    final cartService = context.read<CartService>();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: KantuColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header with Store Tag
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: KantuColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '🏢 ${p.tiendaNombre.isNotEmpty ? p.tiendaNombre : "Kantu Market"}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: KantuColors.primary,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: KantuColors.successLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Stock: ${p.stock}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: KantuColors.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Text(
            p.nombre,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: KantuColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),

          Text(
            'Bs. ${p.precioBase.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: KantuColors.primary,
            ),
          ),
          const SizedBox(height: 12),

          Text(
            p.descripcion.isNotEmpty ? p.descripcion : 'Producto artesanal de alta calidad garantizada.',
            style: const TextStyle(fontSize: 14, color: KantuColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 20),

          // Selector de Cantidad
          Row(
            children: [
              const Text(
                'Cantidad:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: KantuColors.textPrimary),
              ),
              const Spacer(),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: KantuColors.border),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, size: 18),
                      onPressed: _cantidad > 1 ? () => setState(() => _cantidad--) : null,
                    ),
                    Text(
                      '$_cantidad',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, size: 18),
                      onPressed: _cantidad < p.stock ? () => setState(() => _cantidad++) : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Total & Add Button
          CustomButton(
            text: 'Agregar al Carrito • Bs. ${(p.precioBase * _cantidad).toStringAsFixed(2)}',
            icon: Icons.shopping_bag_outlined,
            onPressed: () {
              cartService.addItem(p, cantidad: _cantidad);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('¡${p.nombre} agregado al carrito!'),
                  backgroundColor: KantuColors.success,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
