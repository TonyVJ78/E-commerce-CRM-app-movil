import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kantu_market/core/models/tienda.dart';
import 'package:kantu_market/features/tienda/tienda_header_widget.dart';

void main() {
  group('TiendaHeaderWidget', () {
    final tiendaTest = Tienda(
      id: 5,
      propietarioId: 2,
      nombre: 'Textiles & Alpaca Andina',
      slug: 'alpaca-andina',
      colorPrimario: '#2980B9',
      descripcion: 'Prendas exclusivas de fibra de alpaca boliviana.',
    );

    testWidgets('renderiza nombre, descripción e inicial de la tienda', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TiendaHeaderWidget(tienda: tiendaTest),
          ),
        ),
      );

      expect(find.text('Textiles & Alpaca Andina'), findsOneWidget);
      expect(
        find.text('Prendas exclusivas de fibra de alpaca boliviana.'),
        findsOneWidget,
      );
      // Inicial 'T' en el avatar fallback
      expect(find.text('T'), findsOneWidget);
      expect(find.text('Catálogo de la Tienda'), findsOneWidget);
      expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
    });

    testWidgets('ejecuta onCerrarFiltro al tocar el botón de cierre', (tester) async {
      var cerrado = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TiendaHeaderWidget(
              tienda: tiendaTest,
              onCerrarFiltro: () => cerrado = true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close_rounded));
      expect(cerrado, isTrue);
    });
  });
}
