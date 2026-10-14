import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../constants/api_constants.dart';
import 'api_service.dart';

/// Excepción especializada para pedidos no encontrados o sin permisos de acceso.
class PedidoNotFoundException implements Exception {
  final int pedidoId;
  final String message;

  const PedidoNotFoundException(this.pedidoId, [this.message = 'Pedido no encontrado']);

  @override
  String toString() => message;
}

/// Servicio para trazabilidad de pedidos y registro de reseñas (CU-20 y CU-21).
class PedidosService {
  /// Obtiene el detalle completo y trazabilidad de un pedido del cliente:
  /// `GET /api/pedidos/mis-pedidos/{pedidoId}/`
  Future<Map<String, dynamic>> obtenerDetalle(int pedidoId) async {
    try {
      final response = await ApiService.instance.get(
        ApiConstants.pedidoCliente(pedidoId),
        auth: true,
      );

      if (response.statusCode == 404) {
        throw PedidoNotFoundException(
          pedidoId,
          'El pedido #$pedidoId no fue encontrado o no pertenece a tu cuenta.',
        );
      }

      return _decodificar(response.statusCode, response.body);
    } on SocketException catch (_) {
      throw const SocketException(
        'No se pudo conectar con el servidor. Revisa tu conexión a internet.',
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Registra una reseña para un producto o la tienda asociada al pedido:
  /// `POST /api/pedidos/mis-pedidos/{pedidoId}/resenas/`
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
    if (tipo == 'producto') {
      body['producto_id'] = productoId;
    }

    try {
      final response = await ApiService.instance.post(
        ApiConstants.resenasPedido(pedidoId),
        body,
        auth: true,
      );

      if (response.statusCode == 404) {
        throw PedidoNotFoundException(
          pedidoId,
          'No se puede calificar: el pedido #$pedidoId no fue encontrado.',
        );
      }

      return _decodificar(response.statusCode, response.body);
    } on SocketException catch (_) {
      throw const SocketException(
        'No se pudo conectar con el servidor. Revisa tu conexión a internet.',
      );
    } catch (e) {
      rethrow;
    }
  }

  /// CU-33: descarga la factura en PDF del pedido
  /// (`GET /api/pedidos/mis-pedidos/{pedidoId}/recibo/`) a la carpeta temporal
  /// y devuelve la ruta local, lista para abrir o compartir.
  Future<String> descargarRecibo(int pedidoId) async {
    try {
      final response = await ApiService.instance.get(
        ApiConstants.reciboPedido(pedidoId),
        auth: true,
      );
      if (response.statusCode == 404) {
        throw PedidoNotFoundException(pedidoId, 'La factura del pedido #$pedidoId no está disponible.');
      }
      if (response.statusCode != 200) {
        throw Exception('No se pudo descargar la factura (HTTP ${response.statusCode}).');
      }
      final carpeta = await getTemporaryDirectory();
      final archivo = File('${carpeta.path}/factura-kantu-${pedidoId.toString().padLeft(8, '0')}.pdf');
      await archivo.writeAsBytes(response.bodyBytes, flush: true);
      return archivo.path;
    } on SocketException catch (_) {
      throw const SocketException(
        'No se pudo conectar con el servidor. Revisa tu conexión a internet.',
      );
    }
  }

  /// CU-33: reenvía la factura al correo de la cuenta
  /// (`POST /api/pedidos/mis-pedidos/{pedidoId}/recibo/enviar/`).
  /// Devuelve el mensaje de confirmación del backend.
  Future<String> reenviarRecibo(int pedidoId) async {
    try {
      final response = await ApiService.instance.post(
        ApiConstants.reenviarReciboPedido(pedidoId),
        {},
        auth: true,
        timeout: const Duration(seconds: 40),
      );
      final data = _decodificar(response.statusCode, response.body);
      return data['mensaje']?.toString() ?? 'Enviamos la factura a tu correo.';
    } on SocketException catch (_) {
      throw const SocketException(
        'No se pudo conectar con el servidor. Revisa tu conexión a internet.',
      );
    }
  }

  Map<String, dynamic> _decodificar(int statusCode, String body) {
    dynamic data;
    try {
      data = body.isEmpty ? <String, dynamic>{} : jsonDecode(body);
    } catch (_) {
      data = <String, dynamic>{'error': body};
    }

    if (statusCode < 200 || statusCode >= 300) {
      String? message;
      if (data is Map) {
        message = data['error']?.toString() ??
            data['detail']?.toString() ??
            (data.values.firstOrNull is List
                ? (data.values.firstOrNull as List).join(' ')
                : data.values.firstOrNull?.toString());
      }
      throw Exception(
        message ?? 'No se pudo completar la operación (HTTP $statusCode).',
      );
    }

    if (data is Map<String, dynamic>) {
      return data;
    }
    return <String, dynamic>{'results': data};
  }
}
