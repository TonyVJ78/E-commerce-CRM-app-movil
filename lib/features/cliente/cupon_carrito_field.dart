import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/services/cart_service.dart';

class CuponCarritoField extends StatefulWidget {
  final int tiendaId;
  const CuponCarritoField({super.key, required this.tiendaId});
  @override
  State<CuponCarritoField> createState() => _CuponCarritoFieldState();
}

class _CuponCarritoFieldState extends State<CuponCarritoField> {
  final _codigo = TextEditingController();
  bool _enviando = false;
  String? _error;
  @override
  void dispose() {
    _codigo.dispose();
    super.dispose();
  }

  Future<void> _aplicar() async {
    if (_enviando) return;
    setState(() {
      _enviando = true;
      _error = null;
    });
    final cart = context.read<CartService>();
    final ok = await cart.aplicarCupon(widget.tiendaId, _codigo.text);
    if (!mounted) return;
    setState(() {
      _enviando = false;
      _error = ok ? null : cart.errorMessage;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartService>();
    final aplicado = cart.codigoCupon(widget.tiendaId);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (aplicado == null)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codigo,
                    enabled: !_enviando,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Código de cupón',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _enviando ? null : _aplicar,
                  child: Text(_enviando ? 'Validando…' : 'Aplicar'),
                ),
              ],
            )
          else ...[
            Text(
              '$aplicado · descuento Bs ${cart.descuentoTienda(widget.tiendaId).toStringAsFixed(2)}',
              style: const TextStyle(color: KantuColors.success),
            ),
            TextButton(
              onPressed: () {
                cart.quitarCupon(widget.tiendaId);
                setState(() => _error = null);
              },
              child: const Text('Quitar cupón'),
            ),
          ],
          if (_error != null)
            Text(_error!, style: const TextStyle(color: KantuColors.error)),
        ],
      ),
    );
  }
}
