import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';

/// Imagen de producto para las tarjetas del catálogo y el formulario de CU-08.
///
/// Muestra la imagen sin que quien la usa tenga que saber de
/// dónde viene: una URL (Cloudinary o el seed de Unsplash) o un archivo del
/// teléfono elegido con el selector de imágenes.
///
/// Cualquier fallo de carga cae en el mismo marcador de posición, para que la
/// tarjeta nunca quede con un hueco roto.
class ProductoImagen extends StatelessWidget {
  final String origen;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double radio;
  final String emojiPlaceholder;

  const ProductoImagen({
    super.key,
    required this.origen,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.radio = 12,
    this.emojiPlaceholder = '📦',
  });

  bool get _esRemota => origen.startsWith('http://') || origen.startsWith('https://');

  @override
  Widget build(BuildContext context) {
    Widget contenido;

    if (origen.trim().isEmpty) {
      contenido = _placeholder();
    } else if (_esRemota) {
      contenido = Image.network(
        origen,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, _, _) => _placeholder(),
        loadingBuilder: (context, child, progreso) {
          if (progreso == null) return child;
          return _cargando();
        },
      );
    } else {
      contenido = Image.file(
        File(origen),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, _, _) => _placeholder(),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radio),
      child: SizedBox(width: width, height: height, child: contenido),
    );
  }

  Widget _placeholder() {
    return Container(
      width: width,
      height: height,
      color: KantuColors.primaryLight,
      child: Center(
        child: Text(
          emojiPlaceholder,
          style: TextStyle(fontSize: (height ?? 48) * 0.4),
        ),
      ),
    );
  }

  Widget _cargando() {
    return Container(
      width: width,
      height: height,
      color: KantuColors.background,
      child: const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: KantuColors.primary),
        ),
      ),
    );
  }
}
