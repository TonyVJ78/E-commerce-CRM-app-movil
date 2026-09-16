import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../constants/api_constants.dart';
import '../models/producto.dart';
import 'api_service.dart';

class RecommendationResponse {
  final int statusCode;
  final String body;

  const RecommendationResponse(this.statusCode, this.body);
}

abstract class RecommendationClient {
  Future<RecommendationResponse> getRecommendations(int tiendaId, int limit);
  Future<RecommendationResponse> postInteraction(Map<String, dynamic> body);
}

class ApiRecommendationClient implements RecommendationClient {
  @override
  Future<RecommendationResponse> getRecommendations(
    int tiendaId,
    int limit,
  ) async {
    final response = await ApiService.instance.get(
      ApiConstants.recomendacionesTienda(tiendaId),
      auth: true,
      query: {'limit': '$limit'},
    );
    return RecommendationResponse(response.statusCode, response.body);
  }

  @override
  Future<RecommendationResponse> postInteraction(
    Map<String, dynamic> body,
  ) async {
    final response = await ApiService.instance.post(
      ApiConstants.recomendacionesInteracciones,
      body,
      auth: true,
    );
    return RecommendationResponse(response.statusCode, response.body);
  }
}

class RecommendationService extends ChangeNotifier {
  final RecommendationClient _client;
  final Map<String, DateTime> _recentEvents = {};
  static const Duration _dedupWindow = Duration(seconds: 30);

  RecommendationService({RecommendationClient? client})
    : _client = client ?? ApiRecommendationClient();

  List<Producto> _products = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _requestSerial = 0;

  List<Producto> get products => List.unmodifiable(_products);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadRecommendations(int tiendaId, {int limit = 8}) async {
    final requestId = ++_requestSerial;
    _isLoading = true;
    _errorMessage = null;
    _products = [];
    notifyListeners();

    try {
      final response = await _client.getRecommendations(tiendaId, limit);
      if (response.statusCode != 200) {
        throw StateError('Respuesta ${response.statusCode}');
      }
      final decoded = jsonDecode(response.body);
      final list = decoded is Map && decoded['results'] is List
          ? decoded['results'] as List
          : decoded as List;
      final products = list
          .map(
            (item) => Producto.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .where((product) => product.tiendaId == tiendaId)
          .toList();
      if (requestId != _requestSerial) return;
      _products = products;
    } catch (_) {
      if (requestId != _requestSerial) return;
      _products = [];
      _errorMessage = 'No pudimos cargar tus recomendaciones.';
    }

    if (requestId != _requestSerial) return;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> registerInteraction({
    required int tiendaId,
    required String type,
    int? productoId,
    String? searchTerm,
  }) async {
    final normalizedTerm = searchTerm?.trim().toLowerCase() ?? '';
    final key = '$type:$tiendaId:${productoId ?? ''}:$normalizedTerm';
    final now = DateTime.now();
    final previous = _recentEvents[key];
    if (previous != null && now.difference(previous) < _dedupWindow) return;
    _recentEvents[key] = now;

    try {
      await _client.postInteraction({
        'tienda_id': tiendaId,
        'tipo_interaccion': type,
        'producto_id': ?productoId,
        if (normalizedTerm.isNotEmpty) 'termino_busqueda': normalizedTerm,
      });
    } catch (_) {
      // La telemetría no debe bloquear la navegación del Cliente.
    }
  }
}
