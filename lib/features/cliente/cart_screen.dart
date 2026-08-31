import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/services/cart_service.dart';
import '../../core/services/auth_service.dart';
import '../shared/custom_button.dart';
import '../shared/kantu_app_bar.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  String _metodoPago = 'QR Simple (Bolivia)';

  void _showCheckoutDialog() {
    final cartService = context.read<CartService>();
    final authService = context.read<AuthService>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              const Text(
                'Finalizar Pedido',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: KantuColors.textPrimary),
              ),
              const SizedBox(height: 16),

              const Text(
                'Método de Pago',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: KantuColors.textSecondary),
              ),
              const SizedBox(height: 8),

              // Opciones de Pago
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: KantuColors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    InkWell(
                      onTap: () {
                        setModalState(() => _metodoPago = 'QR Simple (Bolivia)');
                        setState(() => _metodoPago = 'QR Simple (Bolivia)');
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            const Text('📱 ', style: TextStyle(fontSize: 20)),
                            const Expanded(
                              child: Text(
                                'QR Simple (Bancos de Bolivia)',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                            Icon(
                              _metodoPago == 'QR Simple (Bolivia)' ? Icons.radio_button_checked : Icons.radio_button_off,
                              color: _metodoPago == 'QR Simple (Bolivia)' ? KantuColors.primary : KantuColors.textMuted,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    InkWell(
                      onTap: () {
                        setModalState(() => _metodoPago = 'Efectivo');
                        setState(() => _metodoPago = 'Efectivo');
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            const Text('💵 ', style: TextStyle(fontSize: 20)),
                            const Expanded(
                              child: Text(
                                'Pago Contra Entrega (Efectivo)',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                            Icon(
                              _metodoPago == 'Efectivo' ? Icons.radio_button_checked : Icons.radio_button_off,
                              color: _metodoPago == 'Efectivo' ? KantuColors.primary : KantuColors.textMuted,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Resumen
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total a pagar:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  Text(
                    'Bs. ${cartService.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: KantuColors.primary),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              CustomButton(
                text: 'Confirmar y Pagar',
                isLoading: cartService.isLoading,
                icon: Icons.check_circle_outline,
                onPressed: () async {
                  if (authService.currentUser == null) return;
                  final nav = Navigator.of(context);
                  final modalNav = Navigator.of(ctx);
                  final pedido = await cartService.checkout(
                    cliente: authService.currentUser!,
                    metodoPago: _metodoPago,
                  );

                  if (pedido != null && mounted) {
                    modalNav.pop();
                    _showSuccessDialog(nav, pedido.id);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSuccessDialog(NavigatorState parentNav, int pedidoId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: KantuColors.successLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, size: 48, color: KantuColors.success),
            ),
            const SizedBox(height: 16),
            const Text(
              '¡Pedido Confirmado!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: KantuColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Tu pedido #$pedidoId ha sido registrado con éxito.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: KantuColors.textSecondary),
            ),
            const SizedBox(height: 20),
            CustomButton(
              text: 'Aceptar',
              onPressed: () {
                Navigator.pop(ctx);
                parentNav.pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartService = context.watch<CartService>();

    return Scaffold(
      backgroundColor: KantuColors.background,
      appBar: const KantuAppBar(title: 'Carrito de Compras'),
      body: cartService.items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🛒', style: TextStyle(fontSize: 64)),
                  const SizedBox(height: 16),
                  const Text(
                    'Tu carrito está vacío',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: KantuColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Explora los productos de Kantu Market y agrégalos aquí.',
                    style: TextStyle(fontSize: 13, color: KantuColors.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: 200,
                    child: CustomButton(
                      text: 'Explorar Catálogo',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: cartService.itemsList.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 12),
                    itemBuilder: (ctx, idx) {
                      final item = cartService.itemsList[idx];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: KantuColors.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: KantuColors.primaryLight,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(child: Text('🛍️', style: TextStyle(fontSize: 24))),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.producto.nombre,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: KantuColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Bs. ${item.producto.precioBase.toStringAsFixed(2)} c/u',
                                    style: const TextStyle(fontSize: 12, color: KantuColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            // Selector de cantidad
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, size: 20, color: KantuColors.primary),
                                  onPressed: () => cartService.removeSingleItem(item.producto.id),
                                ),
                                Text(
                                  '${item.cantidad}',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, size: 20, color: KantuColors.primary),
                                  onPressed: () => cartService.addItem(item.producto, cantidad: 1),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Bottom Checkout Bar
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(10),
                        blurRadius: 16,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Subtotal:', style: TextStyle(fontSize: 14, color: KantuColors.textSecondary)),
                            Text(
                              'Bs. ${cartService.totalAmount.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: KantuColors.primary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        CustomButton(
                          text: 'Continuar con el Pago',
                          onPressed: _showCheckoutDialog,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
