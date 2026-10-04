import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../core/models/tienda.dart';
import '../../core/utils/color_parser.dart';

/// Encabezado visual de identidad de marca para el catálogo multitenant (CU-13).
///
/// Muestra de forma destacada el logo de la tienda desde Cloudinary (con soporte de
/// caché y placeholder shimmer suave durante la descarga), el nombre oficial de la marca,
/// descripción comercial y un fondo dinámico con degradado que responde al `color_primario`.
class TiendaHeaderWidget extends StatelessWidget {
  final Tienda tienda;
  final VoidCallback? onCerrarFiltro;

  const TiendaHeaderWidget({
    super.key,
    required this.tienda,
    this.onCerrarFiltro,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = ColorParser.parse(tienda.colorPrimario, fallback: KantuColors.primary);
    final contrastText = ColorParser.getContrastTextColor(primaryColor);
    final isWhiteText = contrastText == Colors.white;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: ColorParser.createHeaderGradient(primaryColor),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withAlpha(50),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Círculos ornamentales de fondo
          Positioned(
            right: -24,
            top: -24,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(25),
              ),
            ),
          ),
          Positioned(
            right: 40,
            bottom: -30,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(15),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Logo con Shimmer Placeholder y Caché
                _TiendaLogoAvatar(
                  logoUrl: tienda.logoUrl,
                  tiendaNombre: tienda.nombre,
                  primaryColor: primaryColor,
                ),
                const SizedBox(width: 14),

                // Información textual de la tienda
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              tienda.nombre,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: contrastText,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Icon(
                            Icons.verified_rounded,
                            size: 16,
                            color: isWhiteText ? KantuColors.accent : primaryColor,
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tienda.descripcion.isNotEmpty
                            ? tienda.descripcion
                            : 'Tienda Oficial Kantu Market • @${tienda.slug}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.3,
                          color: isWhiteText
                              ? Colors.white.withAlpha(220)
                              : KantuColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Badge indicativo de Tienda Activa
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(isWhiteText ? 40 : 180),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withAlpha(isWhiteText ? 60 : 220),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: KantuColors.success,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Catálogo de la Tienda',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: contrastText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Botón opcional para salir del filtro de la tienda
                if (onCerrarFiltro != null) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: onCerrarFiltro,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(isWhiteText ? 45 : 190),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: contrastText,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Avatar con imagen remota en caché (Cloudinary) y fallback a Shimmer / Icono.
class _TiendaLogoAvatar extends StatelessWidget {
  final String logoUrl;
  final String tiendaNombre;
  final Color primaryColor;

  const _TiendaLogoAvatar({
    required this.logoUrl,
    required this.tiendaNombre,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    const double size = 62.0;
    final hasUrl = logoUrl.trim().isNotEmpty &&
        (logoUrl.startsWith('http://') || logoUrl.startsWith('https://'));

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: hasUrl
            ? Image.network(
                logoUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const _ShimmerPlaceholder(size: size);
                },
                errorBuilder: (_, _, _) => _FallbackInitial(
                  nombre: tiendaNombre,
                  primaryColor: primaryColor,
                  size: size,
                ),
              )
            : _FallbackInitial(
                nombre: tiendaNombre,
                primaryColor: primaryColor,
                size: size,
              ),
      ),
    );
  }
}

/// Placeholder suave con animación Shimmer nativa durante la descarga de Cloudinary.
class _ShimmerPlaceholder extends StatefulWidget {
  final double size;

  const _ShimmerPlaceholder({required this.size});

  @override
  State<_ShimmerPlaceholder> createState() => _ShimmerPlaceholderState();
}

class _ShimmerPlaceholderState extends State<_ShimmerPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          color: Colors.grey.withAlpha((_animation.value * 255).round()),
          child: const Center(
            child: Icon(
              Icons.storefront_rounded,
              size: 26,
              color: Colors.white70,
            ),
          ),
        );
      },
    );
  }
}

/// Fallback elegante cuando la tienda no tiene logo o falla la red.
class _FallbackInitial extends StatelessWidget {
  final String nombre;
  final Color primaryColor;
  final double size;

  const _FallbackInitial({
    required this.nombre,
    required this.primaryColor,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final inicial = nombre.trim().isNotEmpty ? nombre.trim()[0].toUpperCase() : 'K';

    return Container(
      width: size,
      height: size,
      color: primaryColor.withAlpha(25),
      child: Center(
        child: Text(
          inicial,
          style: TextStyle(
            fontSize: size * 0.42,
            fontWeight: FontWeight.w900,
            color: primaryColor,
          ),
        ),
      ),
    );
  }
}
