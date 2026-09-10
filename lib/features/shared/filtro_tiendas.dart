import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../core/models/tienda.dart';

/// Filtro por tienda de la vitrina del cliente (CU-11).
///
/// Va aparte del de categorías porque son dos ejes distintos y se combinan:
/// primero se elige de quién se compra y después qué. Cada tienda se pinta con
/// su `color_primario`, que es el que la empresa configuró en CU-06.
class FiltroTiendas extends StatelessWidget {
  final List<Tienda> tiendas;
  final int? seleccionada;
  final ValueChanged<int?> onSeleccionar;

  const FiltroTiendas({
    super.key,
    required this.tiendas,
    required this.seleccionada,
    required this.onSeleccionar,
  });

  /// `color_primario` llega como `#RRGGBB`; si viniera mal formado se usa el
  /// rojo de la marca en vez de reventar el render.
  static Color _color(String hex) {
    final limpio = hex.replaceFirst('#', '').trim();
    if (limpio.length != 6) return KantuColors.primary;
    final valor = int.tryParse(limpio, radix: 16);
    return valor == null ? KantuColors.primary : Color(0xFF000000 | valor);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: tiendas.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (ctx, idx) {
          if (idx == 0) {
            return _Chip(
              etiqueta: 'Todas las tiendas',
              icono: Icons.storefront_outlined,
              color: KantuColors.primary,
              seleccionado: seleccionada == null,
              onTap: () => onSeleccionar(null),
            );
          }

          final tienda = tiendas[idx - 1];
          return _Chip(
            etiqueta: tienda.nombre,
            inicial: tienda.nombre.isNotEmpty ? tienda.nombre[0].toUpperCase() : '?',
            color: _color(tienda.colorPrimario),
            seleccionado: seleccionada == tienda.id,
            onTap: () => onSeleccionar(tienda.id),
          );
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String etiqueta;
  final String? inicial;
  final IconData? icono;
  final Color color;
  final bool seleccionado;
  final VoidCallback onTap;

  const _Chip({
    required this.etiqueta,
    required this.color,
    required this.seleccionado,
    required this.onTap,
    this.inicial,
    this.icono,
  });

  @override
  Widget build(BuildContext context) {
    final contenido = seleccionado ? Colors.white : KantuColors.textPrimary;

    return Material(
      color: seleccionado ? color : Colors.white,
      borderRadius: BorderRadius.circular(21),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(21),
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 5, 14, 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(21),
            border: Border.all(color: seleccionado ? color : KantuColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: seleccionado ? Colors.white.withAlpha(56) : color.withAlpha(28),
                  shape: BoxShape.circle,
                ),
                child: icono != null
                    ? Icon(icono, size: 15, color: seleccionado ? Colors.white : color)
                    : Text(
                        inicial ?? '?',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: seleccionado ? Colors.white : color,
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Text(
                  etiqueta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: contenido,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
