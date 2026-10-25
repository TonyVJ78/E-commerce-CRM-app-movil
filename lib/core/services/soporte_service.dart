import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/api_constants.dart';
import '../models/ticket_soporte.dart';
import 'api_service.dart';

typedef SoporteGet = Future<http.Response> Function(String endpoint);
typedef SoportePost = Future<http.Response> Function(
  String endpoint,
  Map<String, dynamic> body,
);

class SoporteException implements Exception {
  final String mensaje;
  const SoporteException(this.mensaje);
  @override
  String toString() => mensaje;
}

/// No crea tickets locales ni simula un envío cuando el servidor falla.
class SoporteService {
  final SoporteGet _get;
  final SoportePost _post;
  final bool Function() _online;

  SoporteService({SoporteGet? get, SoportePost? post, bool Function()? online})
    : _get = get ?? ((path) => ApiService.instance.get(path, auth: true)),
      _post =
          post ??
          ((path, body) => ApiService.instance.post(path, body, auth: true)),
      _online = online ?? (() => ApiService.instance.useOnlineBackend);

  Future<dynamic> _solicitar(Future<http.Response> Function() enviar) async {
    if (!_online()) {
      throw const SoporteException(
        'Conéctate al servidor para consultar o enviar tus reclamos.',
      );
    }
    try {
      final response = await enviar();
      if (response.statusCode == 401) {
        throw const SoporteException(
          'Tu sesión venció. Inicia sesión nuevamente.',
        );
      }
      if (response.statusCode == 403) {
        throw const SoporteException(
          'No tienes permiso para acceder a esta solicitud.',
        );
      }
      if (response.statusCode == 404) {
        throw const SoporteException(
          'La solicitud, tienda o pedido no existe o no está disponible.',
        );
      }
      if (response.statusCode >= 500) {
        throw const SoporteException(
          'El servicio de soporte no está disponible. Intenta más tarde.',
        );
      }
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (response.statusCode == 400 && data is Map) {
          final messages = data.values.expand(
            (value) => value is List ? value : [value],
          );
          throw SoporteException(messages.join('\n'));
        }
        throw const SoporteException(
          'No se pudo completar la solicitud. Vuelve a intentarlo.',
        );
      }
      return data;
    } on SoporteException {
      rethrow;
    } on TimeoutException {
      throw const SoporteException(
        'El servidor tardó demasiado. Comprueba tus solicitudes antes de reenviar.',
      );
    } catch (_) {
      throw const SoporteException(
        'No se pudo conectar con soporte. Revisa tu conexión e inténtalo nuevamente.',
      );
    }
  }

  Future<List<TicketSoporte>> listar() async {
    final data = await _solicitar(() => _get(ApiConstants.misTickets));
    return (data as List)
        .map(
          (item) =>
              TicketSoporte.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(growable: false);
  }

  Future<TicketSoporte> detalle(int id) async {
    final data = await _solicitar(() => _get(ApiConstants.ticketSoporte(id)));
    return TicketSoporte.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<Map<int, String>> tiendas() async {
    final data = await _solicitar(() => _get(ApiConstants.catalogoTiendas));
    final items = data is List ? data : data['results'] as List;
    return {
      for (final item in items)
        (item['id'] as num).toInt(): item['nombre'].toString(),
    };
  }

  Future<TicketSoporte> crear({
    int? tiendaId,
    int? pedidoId,
    required String tipo,
    required String asunto,
    required String descripcion,
    String? adjunto,
  }) async {
    if ((pedidoId ?? 0) <= 0 && (tiendaId ?? 0) <= 0) {
      throw const SoporteException('Selecciona una tienda o un pedido.');
    }
    if (asunto.trim().isEmpty ||
        asunto.trim().length > 200 ||
        descripcion.trim().isEmpty) {
      throw const SoporteException(
        'Completa el asunto (máximo 200 caracteres) y la descripción.',
      );
    }
    if (adjunto != null && adjunto.trim().isNotEmpty) {
      final uri = Uri.tryParse(adjunto.trim());
      if (uri == null ||
          !uri.hasAuthority ||
          !['https', 'http'].contains(uri.scheme) ||
          adjunto.trim().length > 500) {
        throw const SoporteException(
          'El comprobante debe ser un enlace HTTP o HTTPS válido de hasta 500 caracteres.',
        );
      }
    }
    final data = await _solicitar(
      () => _post(ApiConstants.crearTicket, {
        if (pedidoId != null) 'pedido_id': pedidoId else 'tienda_id': tiendaId,
        'tipo': tipo,
        'prioridad': 'media',
        'asunto': asunto.trim(),
        'descripcion': descripcion.trim(),
        if (adjunto != null && adjunto.trim().isNotEmpty)
          'archivo_adjunto': adjunto.trim(),
      }),
    );
    return TicketSoporte.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> responder(int id, String contenido) async {
    if (contenido.trim().isEmpty) {
      throw const SoporteException('Escribe un mensaje.');
    }
    await _solicitar(
      () => _post(ApiConstants.responderTicket(id), {
        'contenido': contenido.trim(),
      }),
    );
  }
}
