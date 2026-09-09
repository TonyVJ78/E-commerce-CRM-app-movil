import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/models/pedido.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/cart_service.dart';
import '../shared/custom_button.dart';
import '../shared/home_shell.dart';
import '../shared/kantu_app_bar.dart';
import '../shared/producto_imagen.dart';

/// Carrito del cliente (CU-11).
///
/// Los ítems se agrupan por tienda porque así los guarda el backend: un
/// `Carrito` por cliente y tienda, y el pedido se confirma por tienda.
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  String _metodoPago = 'QR Simple (Bolivia)';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CartService>().loadCarrito(context.read<AuthService>().currentUser);
    });
  }

  void _mostrarCheckout() {
    final cartService = context.read<CartService>();
    final authService = context.read<AuthService>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
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
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: KantuColors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _OpcionPago(
                      emoji: '📱',
                      texto: 'QR Simple (Bancos de Bolivia)',
                      valor: 'QR Simple (Bolivia)',
                      seleccionado: _metodoPago,
                      onTap: (valor) {
                        setModalState(() => _metodoPago = valor);
                        setState(() => _metodoPago = valor);
                      },
                    ),
                    const Divider(height: 1),
                    _OpcionPago(
                      emoji: '💵',
                      texto: 'Pago Contra Entrega (Efectivo)',
                      valor: 'Efectivo',
                      seleccionado: _metodoPago,
                      onTap: (valor) {
                        setModalState(() => _metodoPago = valor);
                        setState(() => _metodoPago = valor);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total a pagar:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  Text(
                    'Bs. ${cartService.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: KantuColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              CustomButton(
                text: 'Confirmar y Pagar',
                isLoading: cartService.isLoading,
                icon: Icons.check_circle_outline,
                onPressed: () async {
                  final cliente = authService.currentUser;
                  if (cliente == null) return;

                  final modalNav = Navigator.of(ctx);
                  final pedido = await cartService.checkout(
                    cliente: cliente,
                    metodoPago: _metodoPago,
                  );

                  if (!mounted) return;
                  modalNav.pop();
                  if (pedido != null) _mostrarExito(pedido.id);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _mostrarExito(int pedidoId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
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
              text: 'Ver mis pedidos',
              onPressed: () {
                Navigator.pop(ctx);
                HomeShellScope.of(context)?.irATab(2);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmarVaciado() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vaciar carrito', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('Se quitarán todos los productos del carrito.'),
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
            child: const Text('Vaciar'),
          ),
        ],
      ),
    );

    if (confirmado == true && mounted) {
      await context.read<CartService>().vaciar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartService = context.watch<CartService>();
    final grupos = cartService.porTienda;

    return Scaffold(
      backgroundColor: KantuColors.background,
      appBar: KantuAppBar(
        title: 'Carrito de Compras',
        showBackButton: false,
        actions: [
          if (!cartService.isEmpty)
            IconButton(
              tooltip: 'Vaciar carrito',
              icon: const Icon(Icons.delete_sweep_outlined, color: KantuColors.error),
              onPressed: _confirmarVaciado,
            ),
        ],
      ),
      body: cartService.isEmpty
          ? _CarritoVacio(onExplorar: () => HomeShellScope.of(context)?.irATab(0))
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      for (final entrada in grupos.entries) ...[
                        _CabeceraTienda(
                          nombre: cartService.nombreTienda(entrada.key),
                          items: entrada.value.length,
                        ),
                        const SizedBox(height: 8),
                        for (final item in entrada.value)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _LineaCarrito(
                              item: item,
                              onIncrementar: () => cartService.incrementar(item),
                              onDecrementar: () => cartService.decrementar(item),
                              onEliminar: () => cartService.eliminar(item),
                            ),
                          ),
                        const SizedBox(height: 8),
                      ],
                      if (grupos.length > 1)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: KantuColors.accentLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline, size: 18, color: KantuColors.accentDark),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Cada tienda genera su propio pedido. Al confirmar se procesará '
                                  'primero la tienda de arriba.',
                                  style: TextStyle(fontSize: 11, color: KantuColors.textSecondary),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                _BarraTotal(
                  total: cartService.totalAmount,
                  unidades: cartService.itemCount,
                  onPagar: _mostrarCheckout,
                ),
              ],
            ),
    );
  }
}

class _CabeceraTienda extends StatelessWidget {
  final String nombre;
  final int items;

  const _CabeceraTienda({required this.nombre, required this.items});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('🏢', style: TextStyle(fontSize: 14)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            nombre,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: KantuColors.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          items == 1 ? '1 producto' : '$items productos',
          style: const TextStyle(fontSize: 11, color: KantuColors.textMuted),
        ),
      ],
    );
  }
}

class _LineaCarrito extends StatelessWidget {
  final ItemCarrito item;
  final VoidCallback onIncrementar;
  final VoidCallback onDecrementar;
  final VoidCallback onEliminar;

  const _LineaCarrito({
    required this.item,
    required this.onIncrementar,
    required this.onDecrementar,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final etiqueta = item.etiquetaVariante;

    return Dismissible(
      key: ValueKey('item-carrito-${item.id}-${item.variante.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onEliminar(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: KantuColors.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: KantuColors.border),
        ),
        child: Row(
          children: [
            ProductoImagen(origen: item.producto.imagenPrincipal, width: 54, height: 54, radio: 10),
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (etiqueta.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: KantuColors.background,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: KantuColors.border),
                      ),
                      child: Text(
                        etiqueta,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    'Bs. ${item.precioUnitario.toStringAsFixed(2)} c/u  ·  Bs. ${item.total.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 12, color: KantuColors.textSecondary),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: KantuColors.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: onDecrementar,
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.remove, size: 16, color: KantuColors.primary),
                        ),
                      ),
                      Text(
                        '${item.cantidad}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      InkWell(
                        onTap: onIncrementar,
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.add, size: 16, color: KantuColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Stock: ${item.variante.stock}',
                  style: const TextStyle(fontSize: 9, color: KantuColors.textMuted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BarraTotal extends StatelessWidget {
  final double total;
  final int unidades;
  final VoidCallback onPagar;

  const _BarraTotal({required this.total, required this.unidades, required this.onPagar});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 16, offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Subtotal ($unidades ${unidades == 1 ? "unidad" : "unidades"}):',
                  style: const TextStyle(fontSize: 14, color: KantuColors.textSecondary),
                ),
                Text(
                  'Bs. ${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: KantuColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            CustomButton(text: 'Continuar con el Pago', onPressed: onPagar),
          ],
        ),
      ),
    );
  }
}

class _OpcionPago extends StatelessWidget {
  final String emoji;
  final String texto;
  final String valor;
  final String seleccionado;
  final ValueChanged<String> onTap;

  const _OpcionPago({
    required this.emoji,
    required this.texto,
    required this.valor,
    required this.seleccionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activo = seleccionado == valor;

    return InkWell(
      onTap: () => onTap(valor),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Text('$emoji ', style: const TextStyle(fontSize: 20)),
            Expanded(
              child: Text(texto, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
            Icon(
              activo ? Icons.radio_button_checked : Icons.radio_button_off,
              color: activo ? KantuColors.primary : KantuColors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _CarritoVacio extends StatelessWidget {
  final VoidCallback onExplorar;

  const _CarritoVacio({required this.onExplorar});

  @override
  Widget build(BuildContext context) {
    return Center(
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
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 200,
            child: CustomButton(text: 'Explorar Catálogo', onPressed: onExplorar),
          ),
        ],
      ),
    );
  }
}
