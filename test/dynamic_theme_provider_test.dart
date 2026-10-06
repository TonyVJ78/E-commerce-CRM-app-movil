import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kantu_market/core/constants/colors.dart';
import 'package:kantu_market/core/models/tienda.dart';
import 'package:kantu_market/core/theme/dynamic_theme_provider.dart';

void main() {
  group('DynamicThemeProvider', () {
    test('inicia con la paleta oficial de Kantu Market', () {
      final provider = DynamicThemeProvider();
      expect(provider.primaryColor, KantuColors.primary);
      expect(provider.activeTienda, isNull);
      expect(provider.isCustomTheme, isFalse);
      expect(provider.currentTheme.colorScheme.primary, KantuColors.primary);
    });

    test('aplica la identidad de marca de la tienda activa', () {
      final provider = DynamicThemeProvider();
      var notifications = 0;
      provider.addListener(() => notifications++);

      final tiendaVerde = Tienda(
        id: 3,
        propietarioId: 1,
        nombre: 'Sabores de Bolivia Gourmet',
        slug: 'sabores-gourmet',
        colorPrimario: '#27AE60',
      );

      provider.setStore(tiendaVerde);

      expect(notifications, 1);
      expect(provider.activeTienda?.id, 3);
      expect(provider.primaryColor, const Color(0xFF27AE60));
      expect(provider.isCustomTheme, isTrue);
      expect(provider.currentTheme.colorScheme.primary, const Color(0xFF27AE60));
    });

    test('ignora actualizaciones idénticas sin emitir notificaciones redundantes', () {
      final provider = DynamicThemeProvider();
      final tienda = Tienda(
        id: 1,
        propietarioId: 1,
        nombre: 'Textiles Andinos',
        slug: 'textiles-andinos',
        colorPrimario: '#3B82F6',
      );

      provider.setStore(tienda);
      var notifications = 0;
      provider.addListener(() => notifications++);

      // Misma tienda y color
      provider.setStore(tienda);
      expect(notifications, 0);
    });

    test('restablece a la identidad corporativa con resetToDefault', () {
      final provider = DynamicThemeProvider();
      final tienda = Tienda(
        id: 2,
        propietarioId: 1,
        nombre: 'Joyería Plata',
        slug: 'joyeria-plata',
        colorPrimario: '#8E44AD',
      );

      provider.setStore(tienda);
      expect(provider.isCustomTheme, isTrue);

      provider.resetToDefault();
      expect(provider.activeTienda, isNull);
      expect(provider.primaryColor, KantuColors.primary);
      expect(provider.isCustomTheme, isFalse);
    });

    test('reacciona ante colores hexadecimales inválidos aplicando fallback', () {
      final provider = DynamicThemeProvider();
      final tiendaInvalida = Tienda(
        id: 99,
        propietarioId: 1,
        nombre: 'Tienda Test',
        slug: 'test',
        colorPrimario: 'color-invalido',
      );

      provider.setStore(tiendaInvalida);
      expect(provider.primaryColor, KantuColors.primary);
    });
  });
}
