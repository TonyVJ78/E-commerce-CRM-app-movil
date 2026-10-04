import 'dart:convert';

import '../constants/api_constants.dart';
import 'api_service.dart';

class PedidosService {
  Future<Map<String, dynamic>> obtenerDetalle(int pedidoId) async {
    final response = await ApiService.instance.get(
      ApiConstants.pedidoCliente(pedidoId),
      auth: true,
    );
    return _decodificar(response.statusCode, response.body);
  }

  Future<Map<String, dynamic>> guardarResena(
    int pedidoId, {
    required String tipo,
    int? productoId,
    required int calificacion,
    required String comentario,
  }) async {
    final body = <String, dynamic>{
      'tipo': tipo,
      'calificacion': calificacion,
      'comentario': comentario,
    };
    if (tipo == 'producto') body['producto_id'] = productoId;

    final response = await ApiService.instance.post(
      ApiConstants.resenasPedido(pedidoId),
      body,
      auth: true,
    );
    return _decodificar(response.statusCode, response.body);
  }

  Map<String, dynamic> _decodificar(int statusCode, String body) {
    final dynamic data = body.isEmpty ? <String, dynamic>{} : jsonDecode(body);
    if (statusCode < 200 || statusCode >= 300) {
      final message = data is Map
          ? data['error'] ?? data['detail'] ?? data.values.firstOrNull
          : null;
      throw Exception(
        message?.toString() ?? 'No se pudo completar la operación.',
      );
    }
    if (data is Map<String, dynamic>) return data;
    return <String, dynamic>{'results': data};
  }
}
