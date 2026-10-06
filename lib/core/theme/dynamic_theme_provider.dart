import 'package:flutter/material.dart';

import '../constants/colors.dart';
import '../models/tienda.dart';
import '../utils/color_parser.dart';

/// Provider de gestión de tema dinámico multitenant en tiempo real (CU-13).
///
/// Permite reconstruir dinámicamente el [ThemeData] completo de la aplicación
/// (AppBar, botones, acentos, chips, indicadores de progreso y sombras)
/// adaptándose a la identidad visual de la tienda activa que el usuario esté consultando.
///
/// Si no hay tienda activa o se resetea el contexto, regresa a la identidad corporativa
/// oficial de Kantu Market (Rojo bandera #C8102E).
class DynamicThemeProvider extends ChangeNotifier {
  Tienda? _activeTienda;
  Color _primaryColor = KantuColors.primary;

  /// Retorna la tienda activa actualmente asociada al tema.
  Tienda? get activeTienda => _activeTienda;

  /// Retorna el color primario de marca activo.
  Color get primaryColor => _primaryColor;

  /// Retorna un tono claro derivado del primario (ideal para fondos y badges).
  Color get primaryLight => ColorParser.lighten(_primaryColor, 0.42);

  /// Retorna un tono oscuro derivado del primario (ideal para bordes y estados pressed).
  Color get primaryDark => ColorParser.darken(_primaryColor, 0.15);

  /// Retorna el gradiente insignia de la tienda para banners y hero cards.
  LinearGradient get heroGradient => ColorParser.createHeaderGradient(_primaryColor);

  /// Indica si actualmente se está aplicando una identidad personalizada de tienda.
  bool get isCustomTheme => _activeTienda != null || _primaryColor != KantuColors.primary;

  /// Aplica la identidad de una tienda activa [tienda].
  ///
  /// Extrae el campo `color_primario` (#RRGGBB) enviado por el backend,
  /// lo valida mediante [ColorParser] y notifica a los widgets suscritos.
  void setStore(Tienda? tienda) {
    if (_activeTienda?.id == tienda?.id && _activeTienda?.colorPrimario == tienda?.colorPrimario) {
      return;
    }

    _activeTienda = tienda;
    if (tienda != null) {
      _primaryColor = ColorParser.parse(tienda.colorPrimario, fallback: KantuColors.primary);
    } else {
      _primaryColor = KantuColors.primary;
    }

    notifyListeners();
  }

  /// Aplica directamente un color primario en formato hexadecimal o fallback.
  void setPrimaryColor(String? colorHex) {
    final parsed = ColorParser.parse(colorHex, fallback: KantuColors.primary);
    if (_primaryColor == parsed && _activeTienda == null) return;

    _primaryColor = parsed;
    notifyListeners();
  }

  /// Restablece el tema a los colores institucionales oficiales de Kantu Market.
  void resetToDefault() {
    if (_activeTienda == null && _primaryColor == KantuColors.primary) return;

    _activeTienda = null;
    _primaryColor = KantuColors.primary;
    notifyListeners();
  }

  /// Construye y retorna el [ThemeData] completo y coherente con la identidad activa.
  ThemeData get currentTheme {
    final contrastOnPrimary = ColorParser.getContrastTextColor(_primaryColor);
    final isDarkPrimary = contrastOnPrimary == Colors.white;

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      colorScheme: ColorScheme.fromSeed(
        seedColor: _primaryColor,
        primary: _primaryColor,
        onPrimary: contrastOnPrimary,
        secondary: KantuColors.accent,
        onSecondary: KantuColors.textPrimary,
        surface: KantuColors.surface,
        onSurface: KantuColors.textPrimary,
      ),

      // AppBar adaptada con iconos y detalles de la tienda
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: KantuColors.textPrimary,
        elevation: 0.5,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: _primaryColor),
        titleTextStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: KantuColors.textPrimary,
        ),
      ),

      // Botones Elevados y Primarios
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: contrastOnPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: contrastOnPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _primaryColor,
          side: BorderSide(color: _primaryColor, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _primaryColor,
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),

      // Botón de Acción Flotante
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _primaryColor,
        foregroundColor: contrastOnPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // Indicadores de Progreso
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: _primaryColor,
      ),

      // Chips y Filtros
      chipTheme: ChipThemeData(
        selectedColor: primaryLight,
        secondarySelectedColor: _primaryColor,
        checkmarkColor: _primaryColor,
        labelStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: KantuColors.textPrimary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: KantuColors.border),
        ),
      ),

      // Selección de Texto y Cursors
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: _primaryColor,
        selectionColor: _primaryColor.withAlpha(50),
        selectionHandleColor: _primaryColor,
      ),

      // Diálogos y Hojas Inferiores (Material 3 Surface Tint Neutral)
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: isDarkPrimary ? _primaryColor : KantuColors.textPrimary,
        contentTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isDarkPrimary ? contrastOnPrimary : Colors.white,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      scaffoldBackgroundColor: KantuColors.background,
    );
  }
}
