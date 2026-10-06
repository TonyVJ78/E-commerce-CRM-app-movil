import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kantu_market/core/services/recommendation_service.dart';

class FakeRecommendationClient implements RecommendationClient {
  RecommendationResponse response;
  RecommendationResponse interactionResponse = const RecommendationResponse(201, '{}');
  final interactions = <Map<String, dynamic>>[];
  Completer<RecommendationResponse>? completer;

  FakeRecommendationClient(this.response);

  @override
  Future<RecommendationResponse> getRecommendations(int tiendaId, int limit) {
    return completer?.future ?? Future.value(response);
  }

  @override
  Future<RecommendationResponse> postInteraction(
    Map<String, dynamic> body,
  ) async {
    interactions.add(body);
    return interactionResponse;
  }
}

Map<String, dynamic> productJson({int id = 1, int storeId = 7}) => {
  'id': id,
  'tienda_id': storeId,
  'tienda_nombre': 'Tienda $storeId',
  'nombre': 'Producto $id',
  'slug': 'producto-$id',
  'descripcion': 'Detalle',
  'imagenes': [],
  'categoria_nombre': 'Categoría',
  'variantes': [
    {
      'id': id,
      'nombre': 'Única',
      'sku': 'SKU-$id',
      'precio': '25.00',
      'stock': 4,
      'activa': true,
    },
  ],
};

void main() {
  test('parsea recomendaciones y conserva el tenant solicitado', () async {
    final client = FakeRecommendationClient(
      RecommendationResponse(200, jsonEncode([productJson()])),
    );
    final service = RecommendationService(client: client);

    await service.loadRecommendations(7);

    expect(service.errorMessage, isNull);
    expect(service.products.single.nombre, 'Producto 1');
    expect(service.products.single.tiendaId, 7);
  });

  test('expone estado de error controlado', () async {
    final client = FakeRecommendationClient(
      const RecommendationResponse(500, '{}'),
    );
    final service = RecommendationService(client: client);

    await service.loadRecommendations(7);

    expect(service.products, isEmpty);
    expect(service.errorMessage, isNotNull);
    expect(service.isLoading, isFalse);
  });

  test('registra interacción y deduplica repetición inmediata', () async {
    final client = FakeRecommendationClient(
      const RecommendationResponse(200, '[]'),
    );
    final service = RecommendationService(client: client);

    await service.registerInteraction(
      tiendaId: 7,
      productoId: 2,
      type: 'CLICK',
    );
    await service.registerInteraction(
      tiendaId: 7,
      productoId: 2,
      type: 'CLICK',
    );

    expect(client.interactions, hasLength(1));
    expect(client.interactions.single['producto_id'], 2);
  });

  test('VIEW y SEARCH usan el contrato de interacciones de CU-14', () async {
    final client = FakeRecommendationClient(
      const RecommendationResponse(200, '[]'),
    );
    final service = RecommendationService(client: client);

    await service.registerInteraction(tiendaId: 7, productoId: 2, type: 'VIEW');
    await service.registerInteraction(
      tiendaId: 7,
      type: 'SEARCH',
      searchTerm: '  Calzado  ',
    );

    expect(client.interactions[0], {
      'tienda_id': 7,
      'tipo_interaccion': 'VIEW',
      'producto_id': 2,
    });
    expect(client.interactions[1], {
      'tienda_id': 7,
      'tipo_interaccion': 'SEARCH',
      'termino_busqueda': 'calzado',
    });
  });

  test('una interacción rechazada puede reintentarse', () async {
    final client = FakeRecommendationClient(
      const RecommendationResponse(200, '[]'),
    )..interactionResponse = const RecommendationResponse(429, '{}');
    final service = RecommendationService(client: client);

    await service.registerInteraction(tiendaId: 7, productoId: 2, type: 'CLICK');
    client.interactionResponse = const RecommendationResponse(201, '{}');
    await service.registerInteraction(tiendaId: 7, productoId: 2, type: 'CLICK');

    expect(client.interactions, hasLength(2));
  });
}
