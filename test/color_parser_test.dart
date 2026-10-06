import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kantu_market/core/constants/colors.dart';
import 'package:kantu_market/core/utils/color_parser.dart';

void main() {
  group('ColorParser', () {
    test('parsea colores hexadecimales estándar #RRGGBB', () {
      expect(ColorParser.parse('#FF0000'), const Color(0xFFFF0000));
      expect(ColorParser.parse('#00FF00'), const Color(0xFF00FF00));
      expect(ColorParser.parse('#0000FF'), const Color(0xFF0000FF));
      expect(ColorParser.parse('#C8102E'), const Color(0xFFC8102E));
    });

    test('parsea colores sin hash y con espacios RRGGBB', () {
      expect(ColorParser.parse('  C8102E  '), const Color(0xFFC8102E));
      expect(ColorParser.parse('27AE60'), const Color(0xFF27AE60));
    });

    test('soporta formato abreviado #RGB', () {
      expect(ColorParser.parse('#F00'), const Color(0xFFFF0000));
      expect(ColorParser.parse('0F0'), const Color(0xFF00FF00));
    });

    test('retorna fallback cuando el string es nulo o vacío', () {
      expect(ColorParser.parse(null), KantuColors.primary);
      expect(ColorParser.parse(''), KantuColors.primary);
      expect(ColorParser.parse('   '), KantuColors.primary);
      expect(
        ColorParser.parse(null, fallback: Colors.blue),
        Colors.blue,
      );
    });

    test('retorna fallback cuando el string contiene caracteres no hexadecimales', () {
      expect(ColorParser.parse('#XYZ123'), KantuColors.primary);
      expect(ColorParser.parse('invalid-color'), KantuColors.primary);
      expect(ColorParser.parse('#12345'), KantuColors.primary); // longitud inválida
    });

    test('valida formatos válidos e inválidos con isValidHex', () {
      expect(ColorParser.isValidHex('#C8102E'), isTrue);
      expect(ColorParser.isValidHex('C8102E'), isTrue);
      expect(ColorParser.isValidHex('#FFF'), isTrue);
      expect(ColorParser.isValidHex('invalid'), isFalse);
      expect(ColorParser.isValidHex(null), isFalse);
    });

    test('calcula contraste accesible blanco/negro', () {
      expect(ColorParser.getContrastTextColor(Colors.black), Colors.white);
      expect(ColorParser.getContrastTextColor(const Color(0xFF101010)), Colors.white);
      expect(ColorParser.getContrastTextColor(Colors.white), KantuColors.textPrimary);
      expect(ColorParser.getContrastTextColor(const Color(0xFFF0F0F0)), KantuColors.textPrimary);
    });
  });
}
