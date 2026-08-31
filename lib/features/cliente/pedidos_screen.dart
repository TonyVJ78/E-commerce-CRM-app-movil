import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/services/cart_service.dart';
import '../../core/services/auth_service.dart';
import '../shared/kantu_app_bar.dart';

class PedidosScreen extends StatefulWidget {
  const PedidosScreen({super.key});

  @override
  State<PedidosScreen> createState() => _PedidosScreenState();
}

class _PedidosScreenState extends State<PedidosScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthService>();
      context.read<CartService>().loadPedidos(clienteId: auth.currentUser?.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cartService = context.watch<CartService>();

    return Scaffold(
      backgroundColor: KantuColors.background,
      appBar: const KantuAppBar(title: 'Mis Pedidos'),
      body: cartService.isLoading
          ? const Center(child: CircularProgressIndicator(color: KantuColors.primary))
          : cartService.pedidos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('📦', style: TextStyle(fontSize: 64)),
                      const SizedBox(height: 16),
                      const Text(
                        'Aún no tienes pedidos',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: KantuColors.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Tus compras realizadas aparecerán listadas aquí.',
                        style: TextStyle(fontSize: 13, color: KantuColors.textSecondary),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: cartService.pedidos.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 12),
                  itemBuilder: (ctx, idx) {
                    final pedido = cartService.pedidos[idx];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: KantuColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Pedido #${pedido.id}',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: KantuColors.textPrimary),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: KantuColors.successLight,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  pedido.estadoActual.toUpperCase(),
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: KantuColors.success),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '🏢 Tienda: ${pedido.tiendaNombre}',
                            style: const TextStyle(fontSize: 13, color: KantuColors.textSecondary),
                          ),
                          Text(
                            '💳 Método: ${pedido.metodoPago}',
                            style: const TextStyle(fontSize: 13, color: KantuColors.textSecondary),
                          ),
                          const Divider(height: 20),
                          ...pedido.items.map(
                            (it) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('${it.cantidad}x ${it.productoNombre}', style: const TextStyle(fontSize: 13)),
                                  Text('Bs. ${it.subtotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                              Text(
                                'Bs. ${pedido.total.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: KantuColors.primary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
