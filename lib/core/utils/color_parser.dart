import 'package:flutter/material.dart';

import '../constants/colors.dart';

/// Helper de utilidad para el parseo y manipulación de colores de marca multitenant (CU-13).
///
/// Convierte códigos hexadecimales en formato `#RRGGBB` o `RRGGBB` provenientes
/// del backend Django a instancias [Color] de Flutter de forma tolerante a fallos,
/// proveyendo un color neutro o el color institucional de Kantu Market ante datos nulos o inválidos.
class ColorParser {
  /// Color de respaldo por defecto si el backend no envía un color o el string es inválido.
  static const Color defaultFallback = KantuColors.primary;

  /// Parsea un string hexadecimal [hexString] (#RRGGBB, RRGGBB, #AARRGGBB o #RGB)
  /// a un objeto [Color] de Flutter.
  ///
  /// Si [hexString] es nulo, está vacío o contiene caracteres inválidos, retorna [fallback].
  static Color parse(
    String? hexString, {
    Color fallback = defaultFallback,
  }) {
    if (hexString == null) return fallback;

    var cleaned = hexString.trim().replaceAll('#', '').toUpperCase();
    if (cleaned.isEmpty) return fallback;

    // Soporte para formato abreviado #RGB -> #RRGGBB
    if (cleaned.length == 3) {
      cleaned = '${cleaned[0]}${cleaned[0]}${cleaned[1]}${cleaned[1]}${cleaned[2]}${cleaned[2]}';
    }

    // Si tiene 6 caracteres (RRGGBB), agregamos FF para canal alfa opaco (AARRGGBB)
    if (cleaned.length == 6) {
      cleaned = 'FF$cleaned';
    }

    // Debe tener exactamente 8 caracteres (AARRGGBB)
    if (cleaned.length != 8) {
      return fallback;
    }

    final val = int.tryParse(cleaned, radix: 16);
    if (val == null) {
      return fallback;
    }

    return Color(val);
  }

  /// Valida si un string cumple con el formato hexadecimal válido (#RRGGBB o RRGGBB).
  static bool isValidHex(String? hexString) {
    if (hexString == null) return false;
    final cleaned = hexString.trim().replaceAll('#', '');
    if (cleaned.length != 6 && cleaned.length != 8 && cleaned.length != 3) {
      return false;
    }
    return int.tryParse(cleaned, radix: 16) != null;
  }

  /// Convierte un objeto [Color] a su representación hexadecimal `#RRGGBB`.
  static String toHex(
    Color color, {
    bool leadingHashSign = true,
    bool includeAlpha = false,
  }) {
    final a = (color.a * 255).round().toRadixString(16).padLeft(2, '0').toUpperCase();
    final r = (color.r * 255).round().toRadixString(16).padLeft(2, '0').toUpperCase();
    final g = (color.g * 255).round().toRadixString(16).padLeft(2, '0').toUpperCase();
    final b = (color.b * 255).round().toRadixString(16).padLeft(2, '0').toUpperCase();

    final prefix = leadingHashSign ? '#' : '';
    if (includeAlpha) {
      return '$prefix$a$r$g$b';
    }
    return '$prefix$r$g$b';
  }

  /// Retorna un color con mayor luminosidad (útil para fondos sutiles, chips y estados hover).
  static Color lighten(Color color, [double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(color);
    final hslLight = hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));
    return hslLight.toColor();
  }

  /// Retorna un color oscurecido (útil para bordes, sombras y estados pressed).
  static Color darken(Color color, [double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(color);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }

  /// Determina si un texto sobre este color de fondo debe ser blanco o negro
  /// para garantizar un ratio de contraste accesible (WCAG 2.1).
  static Color getContrastTextColor(Color background) {
    return background.computeLuminance() > 0.5 ? KantuColors.textPrimary : Colors.white;
  }

  /// Crea un gradiente elegante para banners de tienda basado en el color primario de marca.
  static LinearGradient createHeaderGradient(Color primary) {
    return LinearGradient(
      colors: [
        primary,
        darken(primary, 0.12),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
}
