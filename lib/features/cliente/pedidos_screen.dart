import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/models/pedido.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/cart_service.dart';
import '../shared/kantu_app_bar.dart';

/// Pedidos confirmados, el paso siguiente al carrito de CU-11.
///
/// La misma pantalla sirve al cliente (sus compras) y a la empresa (las
/// ventas de todas sus tiendas), cambiando sólo el filtro.
class PedidosScreen extends StatefulWidget {
  final bool modoEmpresa;

  const PedidosScreen({super.key, this.modoEmpresa = false});

  @override
  State<PedidosScreen> createState() => _PedidosScreenState();
}

class _PedidosScreenState extends State<PedidosScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  Future<void> _cargar() {
    final auth = context.read<AuthService>();
    final usuarioId = auth.currentUser?.id;
    return context.read<CartService>().loadPedidos(
          clienteId: widget.modoEmpresa ? null : usuarioId,
          propietarioId: widget.modoEmpresa ? usuarioId : null,
        );
  }

  @override
  Widget build(BuildContext context) {
    final cartService = context.watch<CartService>();

    return Scaffold(
      backgroundColor: KantuColors.background,
      appBar: KantuAppBar(
        title: widget.modoEmpresa ? 'Ventas de mis Tiendas' : 'Mis Pedidos',
        showBackButton: false,
      ),
      body: RefreshIndicator(
        color: KantuColors.primary,
        onRefresh: _cargar,
        child: cartService.isLoading && cartService.pedidos.isEmpty
            ? const Center(child: CircularProgressIndicator(color: KantuColors.primary))
            : cartService.pedidos.isEmpty
                ? ListView(
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                      const Center(child: Text('📦', style: TextStyle(fontSize: 64))),
                      const SizedBox(height: 16),
                      Text(
                        widget.modoEmpresa ? 'Aún no tienes ventas' : 'Aún no tienes pedidos',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: KantuColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.modoEmpresa
                            ? 'Los pedidos que reciban tus tiendas aparecerán aquí.'
                            : 'Tus compras realizadas aparecerán listadas aquí.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, color: KantuColors.textSecondary),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: cartService.pedidos.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 12),
                    itemBuilder: (ctx, idx) => _TarjetaPedido(
                      pedido: cartService.pedidos[idx],
                      modoEmpresa: widget.modoEmpresa,
                    ),
                  ),
      ),
    );
  }
}

class _TarjetaPedido extends StatelessWidget {
  final Pedido pedido;
  final bool modoEmpresa;

  const _TarjetaPedido({required this.pedido, required this.modoEmpresa});

  Color get _colorEstado {
    switch (pedido.estadoActual) {
      case 'cancelado':
        return KantuColors.error;
      case 'pendiente':
        return KantuColors.warning;
      default:
        return KantuColors.success;
    }
  }

  String get _fechaCorta {
    final fecha = DateTime.tryParse(pedido.fecha);
    if (fecha == null) return '';
    final dd = fecha.day.toString().padLeft(2, '0');
    final mm = fecha.month.toString().padLeft(2, '0');
    return '$dd/$mm/${fecha.year}';
  }

  @override
  Widget build(BuildContext context) {
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
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: KantuColors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _colorEstado.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  pedido.estadoActual.toUpperCase(),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _colorEstado),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            modoEmpresa
                ? '👤 Cliente: ${pedido.clienteEmail}'
                : '🏢 Tienda: ${pedido.tiendaNombre}',
            style: const TextStyle(fontSize: 13, color: KantuColors.textSecondary),
          ),
          Text(
            '💳 ${pedido.metodoPago}${_fechaCorta.isNotEmpty ? "  ·  📅 $_fechaCorta" : ""}',
            style: const TextStyle(fontSize: 13, color: KantuColors.textSecondary),
          ),
          const Divider(height: 20),
          ...pedido.items.map(
            (it) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${it.cantidad}x ${it.descripcion}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  Text(
                    'Bs. ${it.subtotal.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
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
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: KantuColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
