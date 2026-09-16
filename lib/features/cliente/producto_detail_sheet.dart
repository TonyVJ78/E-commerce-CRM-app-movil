import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/models/producto.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/cart_service.dart';
import '../../core/services/recommendation_service.dart';
import '../shared/custom_button.dart';
import '../shared/producto_imagen.dart';

/// Detalle del producto con selección de variante y cantidad (CU-11).
///
/// El precio y el stock dependen de la variante elegida, así que la hoja
/// obliga a escoger una antes de poder agregar al carrito.
class ProductoDetailSheet extends StatefulWidget {
  final Producto producto;

  const ProductoDetailSheet({super.key, required this.producto});

  @override
  State<ProductoDetailSheet> createState() => _ProductoDetailSheetState();
}

class _ProductoDetailSheetState extends State<ProductoDetailSheet> {
  late Variante? _variante;
  int _cantidad = 1;
  bool _agregando = false;

  @override
  void initState() {
    super.initState();
    _variante = widget.producto.variantePrincipal;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<RecommendationService>().registerInteraction(
        tiendaId: widget.producto.tiendaId,
        productoId: widget.producto.id,
        type: 'VIEW',
      );
    });
  }

  int get _stockDisponible => _variante?.stock ?? 0;
  bool get _sinStock => _variante == null || _stockDisponible <= 0;

  double get _totalLinea => (_variante?.precioEfectivo ?? 0) * _cantidad;

  void _seleccionar(Variante variante) {
    setState(() {
      _variante = variante;
      // Al cambiar de variante la cantidad puede pasarse del stock nuevo.
      if (variante.stock > 0 && _cantidad > variante.stock) {
        _cantidad = variante.stock;
      }
    });
  }

  Future<void> _agregarAlCarrito() async {
    final variante = _variante;
    if (variante == null) return;

    setState(() => _agregando = true);
    final cart = context.read<CartService>();
    final cliente = context.read<AuthService>().currentUser;

    final ok = await cart.agregar(
      producto: widget.producto,
      variante: variante,
      cantidad: _cantidad,
      cliente: cliente,
    );

    if (!mounted) return;
    setState(() => _agregando = false);

    final mensaje = ok
        ? '¡${widget.producto.nombre} agregado al carrito!'
        : (cart.errorMessage ?? 'No se pudo agregar al carrito.');

    if (ok) Navigator.pop(context);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: ok ? KantuColors.success : KantuColors.error,
          duration: const Duration(seconds: 2),
        ),
      );
    cart.limpiarError();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.producto;
    final variantes = p.variantesActivas;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: KantuColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              children: [
                ProductoImagen(
                  origen: p.imagenPrincipal,
                  height: 180,
                  width: double.infinity,
                  radio: 16,
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: KantuColors.primaryLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '🏢 ${p.tiendaNombre.isNotEmpty ? p.tiendaNombre : "Kantu Market"}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: KantuColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _sinStock
                            ? KantuColors.error.withAlpha(25)
                            : KantuColors.successLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _sinStock ? 'Agotado' : 'Stock: $_stockDisponible',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _sinStock
                              ? KantuColors.error
                              : KantuColors.success,
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

                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Bs. ${(_variante?.precioEfectivo ?? p.precioBase).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: KantuColors.primary,
                      ),
                    ),
                    if (_variante?.enOferta == true) ...[
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          'Bs. ${_variante!.precio.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: KantuColors.textMuted,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),

                Text(
                  p.descripcion.isNotEmpty
                      ? p.descripcion
                      : 'Producto artesanal de alta calidad garantizada.',
                  style: const TextStyle(
                    fontSize: 14,
                    color: KantuColors.textSecondary,
                    height: 1.4,
                  ),
                ),

                if (p.etiquetas.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final etiqueta in p.etiquetas)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: KantuColors.accentLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '#$etiqueta',
                            style: const TextStyle(
                              fontSize: 11,
                              color: KantuColors.accentDark,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],

                if (variantes.length > 1) ...[
                  const SizedBox(height: 20),
                  const Text(
                    'Elige una presentación',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: KantuColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final variante in variantes)
                        _ChipVariante(
                          variante: variante,
                          seleccionada: _variante?.id == variante.id,
                          onTap: () => _seleccionar(variante),
                        ),
                    ],
                  ),
                ],

                const SizedBox(height: 20),
                Row(
                  children: [
                    const Text(
                      'Cantidad',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: KantuColors.textPrimary,
                      ),
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
                            onPressed: _cantidad > 1
                                ? () => setState(() => _cantidad--)
                                : null,
                          ),
                          Text(
                            '$_cantidad',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add, size: 18),
                            onPressed: _cantidad < _stockDisponible
                                ? () => setState(() => _cantidad++)
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              8,
              24,
              MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: CustomButton(
              text: _sinStock
                  ? 'Sin stock disponible'
                  : 'Agregar al Carrito • Bs. ${_totalLinea.toStringAsFixed(2)}',
              icon: _sinStock ? null : Icons.shopping_bag_outlined,
              isLoading: _agregando,
              onPressed: _sinStock ? null : _agregarAlCarrito,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipVariante extends StatelessWidget {
  final Variante variante;
  final bool seleccionada;
  final VoidCallback onTap;

  const _ChipVariante({
    required this.variante,
    required this.seleccionada,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final agotada = variante.agotada;

    return GestureDetector(
      onTap: agotada ? null : onTap,
      child: Opacity(
        opacity: agotada ? 0.45 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: seleccionada ? KantuColors.primaryLight : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: seleccionada ? KantuColors.primary : KantuColors.border,
              width: seleccionada ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                variante.nombre,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: seleccionada
                      ? KantuColors.primary
                      : KantuColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                agotada
                    ? 'Agotada'
                    : 'Bs. ${variante.precioEfectivo.toStringAsFixed(2)} · ${variante.stock} u.',
                style: const TextStyle(
                  fontSize: 11,
                  color: KantuColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
