import 'package:flutter/material.dart';

class KantuColors {
  // Paleta Patriótica Boliviana Oficial de Kantu Market
  static const Color primary = Color(0xFFC8102E); // Rojo bandera / principal
  static const Color primaryLight = Color(0xFFFFEBEE);
  static const Color primaryDark = Color(0xFF9E0B22);

  static const Color accent = Color(0xFFF4D03F); // Amarillo acento
  static const Color accentLight = Color(0xFFFEF9E7);
  static const Color accentDark = Color(0xFFD4AC0D);

  static const Color success = Color(0xFF27AE60); // Verde éxito / activo
  static const Color successLight = Color(0xFFE8F8F5);

  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color card = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2E8F0);

  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);

  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // Gradientes
  static const LinearGradient heroGradient = LinearGradient(
    colors: [primary, Color(0xFFE53935)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient boliviaFlagGradient = LinearGradient(
    colors: [primary, accent, success],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}
