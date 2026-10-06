import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/models/pedido.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/cart_service.dart';
import '../shared/kantu_app_bar.dart';
import 'seguimiento_pedido_sheet.dart';

/// Pedidos confirmados, el paso siguiente al carrito de CU-11.
///
/// La misma pantalla sirve al cliente (sus compras) y a la empresa (las
/// ventas de todas sus tiendas), cambiando sólo el filtro.
/// Implementa reactividad en tiempo real con Provider (CU-20 y CU-21).
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

  Future<void> _cargar() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final cart = Provider.of<CartService>(context, listen: false);
    final user = auth.currentUser;
    if (user == null) return;

    if (widget.modoEmpresa) {
      await cart.loadPedidos(propietarioId: user.id);
    } else {
      await cart.loadPedidos(clienteId: user.id);
    }
  }

  Future<void> _abrirSeguimiento(Pedido pedido) async {
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => SeguimientoPedidoSheet(pedido: pedido),
      );
      if (!mounted) return;
      await _cargar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo abrir el detalle del pedido: $e'),
          backgroundColor: KantuColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartService = context.watch<CartService>();

    return Scaffold(
      backgroundColor: KantuColors.background,
      appBar: KantuAppBar(
        title: widget.modoEmpresa ? 'Ventas Recibidas' : 'Mis Pedidos',
        showBackButton: false,
      ),
      body: RefreshIndicator(
        color: KantuColors.primary,
        onRefresh: _cargar,
        child: cartService.isLoading && cartService.pedidos.isEmpty
            ? const Center(
                child: CircularProgressIndicator(color: KantuColors.primary),
              )
            : cartService.pedidos.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      if (cartService.errorMessage != null) ...[
                        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                        const Center(
                          child: Icon(
                            Icons.cloud_off_outlined,
                            size: 56,
                            color: KantuColors.error,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            cartService.errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: KantuColors.error),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: TextButton.icon(
                            onPressed: _cargar,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reintentar'),
                          ),
                        ),
                      ] else ...[
                        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                        const Center(
                          child: Text('📦', style: TextStyle(fontSize: 64)),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.modoEmpresa
                              ? 'Aún no tienes ventas'
                              : 'Aún no tienes pedidos',
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
                          style: const TextStyle(
                            fontSize: 13,
                            color: KantuColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: cartService.pedidos.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 12),
                    itemBuilder: (ctx, idx) {
                      final pedido = cartService.pedidos[idx];
                      return _TarjetaPedido(
                        pedido: pedido,
                        modoEmpresa: widget.modoEmpresa,
                        onTap: widget.modoEmpresa
                            ? null
                            : () => _abrirSeguimiento(pedido),
                      );
                    },
                  ),
      ),
    );
  }
}

class _TarjetaPedido extends StatelessWidget {
  final Pedido pedido;
  final bool modoEmpresa;
  final VoidCallback? onTap;

  const _TarjetaPedido({
    required this.pedido,
    required this.modoEmpresa,
    this.onTap,
  });

  Color get _colorEstado {
    switch (pedido.estadoActual.toLowerCase()) {
      case 'cancelado':
        return KantuColors.error;
      case 'pendiente':
        return KantuColors.warning;
      case 'en_camino':
      case 'enviado':
      case 'en_proceso':
        return KantuColors.info;
      case 'completado':
      case 'completada':
      case 'entregado':
      case 'finalizado':
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _colorEstado.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    (pedido.estadoEtiqueta.isNotEmpty
                            ? pedido.estadoEtiqueta
                            : pedido.estadoActual.replaceAll('_', ' '))
                        .toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _colorEstado,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              modoEmpresa
                  ? '👤 Cliente: ${pedido.clienteEmail}'
                  : '🏢 Tienda: ${pedido.tiendaNombre}',
              style: const TextStyle(
                fontSize: 13,
                color: KantuColors.textSecondary,
              ),
            ),
            Text(
              '💳 ${pedido.metodoPago}${_fechaCorta.isNotEmpty ? "  ·  📅 $_fechaCorta" : ""}',
              style: const TextStyle(
                fontSize: 13,
                color: KantuColors.textSecondary,
              ),
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
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
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
            if (!modoEmpresa) ...[
              const SizedBox(height: 12),
              const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Ver seguimiento y reseñas →',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: KantuColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
