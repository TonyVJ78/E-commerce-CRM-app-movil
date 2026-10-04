import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kantu_market/core/models/producto.dart';
import 'package:kantu_market/core/services/recommendation_service.dart';
import 'package:kantu_market/features/cliente/recomendaciones_section.dart';
import 'package:provider/provider.dart';

class SectionClient implements RecommendationClient {
  RecommendationResponse response;
  Completer<RecommendationResponse>? completer;

  SectionClient(this.response);

  @override
  Future<RecommendationResponse> getRecommendations(int tiendaId, int limit) =>
      completer?.future ?? Future.value(response);

  @override
  Future<RecommendationResponse> postInteraction(
    Map<String, dynamic> body,
  ) async => const RecommendationResponse(201, '{}');
}

Map<String, dynamic> sectionProduct() => {
  'id': 4,
  'tienda_id': 9,
  'tienda_nombre': 'Tienda Móvil',
  'nombre': 'Producto recomendado',
  'slug': 'producto-recomendado',
  'descripcion': 'Detalle',
  'imagenes': [],
  'categoria_nombre': 'Calzado',
  'variantes': [
    {
      'id': 5,
      'nombre': 'Única',
      'sku': 'REC-5',
      'precio': '30.00',
      'stock': 3,
      'activa': true,
    },
  ],
};

Widget buildSubject(
  RecommendationService service,
  ValueChanged<Producto> onTap,
) {
  return ChangeNotifierProvider.value(
    value: service,
    child: MaterialApp(
      home: Scaffold(
        body: RecomendacionesSection(tiendaId: 9, onProductTap: onTap),
      ),
    ),
  );
}

void main() {
  testWidgets('muestra loading mientras espera respuesta', (tester) async {
    final client = SectionClient(const RecommendationResponse(200, '[]'))
      ..completer = Completer<RecommendationResponse>();
    final service = RecommendationService(client: client);
    await tester.pumpWidget(buildSubject(service, (_) {}));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    client.completer!.complete(const RecommendationResponse(200, '[]'));
    await tester.pumpAndSettle();
  });

  testWidgets('muestra resultados y tap abre el producto real', (tester) async {
    final client = SectionClient(
      RecommendationResponse(200, jsonEncode([sectionProduct()])),
    );
    final service = RecommendationService(client: client);
    Producto? selected;
    await tester.pumpWidget(
      buildSubject(service, (product) => selected = product),
    );
    await tester.pumpAndSettle();
    expect(find.text('Recomendados para ti'), findsOneWidget);
    expect(find.text('Producto recomendado'), findsOneWidget);
    await tester.tap(find.text('Producto recomendado'));
    expect(selected?.id, 4);
  });

  testWidgets('aplica fallback silencioso ante error de red o servidor', (tester) async {
    final service = RecommendationService(
      client: SectionClient(const RecommendationResponse(500, '{}')),
    );
    await tester.pumpWidget(buildSubject(service, (_) {}));
    await tester.pumpAndSettle();
    // En cumplimiento de antigravity.md Sec. 4.6 & Dir. 8:
    // No debe mostrar ningún mensaje de error al usuario y debe ocultar la sección.
    expect(find.text('Recomendados para ti'), findsNothing);
    expect(find.text('No pudimos cargar tus recomendaciones.'), findsNothing);
    expect(find.byIcon(Icons.error_outline), findsNothing);
  });

  testWidgets('aplica fallback silencioso si la tienda no tiene recomendaciones', (tester) async {
    final service = RecommendationService(
      client: SectionClient(const RecommendationResponse(200, '[]')),
    );
    await tester.pumpWidget(buildSubject(service, (_) {}));
    await tester.pumpAndSettle();
    expect(find.text('Recomendados para ti'), findsNothing);
    expect(find.text('Aún no hay productos disponibles para recomendar.'), findsNothing);
  });
}
