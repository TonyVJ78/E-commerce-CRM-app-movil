import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../core/services/dashboard_service.dart';

/// Gráfico de barras de las unidades vendidas en los últimos 7 días (CU-10).
///
/// Se dibuja con widgets simples en vez de con una librería de charts: son
/// siete barras y añadir una dependencia para eso no se justifica.
class VentasBarChart extends StatelessWidget {
  final List<VentaDia> ventas;
  final Color color;

  const VentasBarChart({
    super.key,
    required this.ventas,
    this.color = KantuColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    if (ventas.isEmpty) {
      return const SizedBox.shrink();
    }

    final maximo = ventas.map((v) => v.cantidad).reduce((a, b) => a > b ? a : b);
    final sinDatos = maximo == 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KantuColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Ventas de los últimos 7 días',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: KantuColors.textPrimary,
                ),
              ),
              Text(
                sinDatos ? 'Sin ventas' : '$maximo máx.',
                style: const TextStyle(fontSize: 11, color: KantuColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Unidades despachadas por día',
            style: TextStyle(fontSize: 11, color: KantuColors.textSecondary),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 130,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final venta in ventas)
                  Expanded(child: _Barra(venta: venta, maximo: maximo, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Barra extends StatelessWidget {
  final VentaDia venta;
  final int maximo;
  final Color color;

  const _Barra({required this.venta, required this.maximo, required this.color});

  @override
  Widget build(BuildContext context) {
    // Altura disponible: 130 menos la etiqueta del día y el valor.
    const alturaMaxima = 78.0;
    final proporcion = maximo == 0 ? 0.0 : venta.cantidad / maximo;
    final altura = venta.cantidad == 0 ? 4.0 : (proporcion * alturaMaxima).clamp(8.0, alturaMaxima);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            '${venta.cantidad}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: venta.cantidad == 0 ? KantuColors.textMuted : KantuColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            height: altura,
            decoration: BoxDecoration(
              gradient: venta.cantidad == 0
                  ? null
                  : LinearGradient(
                      colors: [color, color.withAlpha(150)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
              color: venta.cantidad == 0 ? KantuColors.border : null,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            venta.fecha,
            style: const TextStyle(fontSize: 10, color: KantuColors.textMuted),
          ),
        ],
      ),
    );
  }
}
