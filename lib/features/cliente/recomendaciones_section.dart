import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/models/producto.dart';
import '../../core/services/recommendation_service.dart';
import '../shared/producto_imagen.dart';

class RecomendacionesSection extends StatefulWidget {
  final int tiendaId;
  final ValueChanged<Producto> onProductTap;

  const RecomendacionesSection({
    super.key,
    required this.tiendaId,
    required this.onProductTap,
  });

  @override
  State<RecomendacionesSection> createState() => _RecomendacionesSectionState();
}

class _RecomendacionesSectionState extends State<RecomendacionesSection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<RecommendationService>().loadRecommendations(
          widget.tiendaId,
        );
      }
    });
  }

  @override
  void didUpdateWidget(covariant RecomendacionesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tiendaId != widget.tiendaId) {
      context.read<RecommendationService>().loadRecommendations(
        widget.tiendaId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final recommendations = context.watch<RecommendationService>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recomendados para ti',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: KantuColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Productos disponibles de la tienda que estás consultando.',
            style: TextStyle(fontSize: 12, color: KantuColors.textSecondary),
          ),
          const SizedBox(height: 12),
          if (recommendations.isLoading)
            const SizedBox(
              height: 118,
              child: Center(
                child: CircularProgressIndicator(color: KantuColors.primary),
              ),
            )
          else if (recommendations.errorMessage != null)
            _RecommendationMessage(
              icon: Icons.error_outline,
              text: recommendations.errorMessage!,
              action: () =>
                  recommendations.loadRecommendations(widget.tiendaId),
            )
          else if (recommendations.products.isEmpty)
            const _RecommendationMessage(
              icon: Icons.auto_awesome_outlined,
              text: 'Aún no hay productos disponibles para recomendar.',
            )
          else
            SizedBox(
              height: 166,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: recommendations.products.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final product = recommendations.products[index];
                  return _RecommendationCard(
                    key: ValueKey('recommendation-${product.id}'),
                    product: product,
                    onTap: () => widget.onProductTap(product),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  final Producto product;
  final VoidCallback onTap;

  const _RecommendationCard({
    super.key,
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 230,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: KantuColors.border),
        ),
        child: Row(
          children: [
            ProductoImagen(
              origen: product.imagenPrincipal,
              width: 82,
              height: 126,
              radio: 10,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    product.categoriaNombre.isNotEmpty
                        ? product.categoriaNombre
                        : product.tiendaNombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: KantuColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    product.nombre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'Bs. ${product.precioBase.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: KantuColors.primary,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Ver producto',
                    style: TextStyle(
                      fontSize: 11,
                      decoration: TextDecoration.underline,
                      color: KantuColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecommendationMessage extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? action;

  const _RecommendationMessage({
    required this.icon,
    required this.text,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KantuColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: KantuColors.textMuted),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
          if (action != null)
            TextButton(onPressed: action, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}
