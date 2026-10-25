import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_service.dart';

typedef MarketingGet = Future<http.Response> Function(String path);
typedef MarketingWrite = Future<http.Response> Function(
  String path,
  Map<String, dynamic> body,
);

class MarketingException implements Exception {
  final String mensaje;
  const MarketingException(this.mensaje);
  @override
  String toString() => mensaje;
}

/// Peticiones autenticadas. Los errores nunca se convierten en datos de ejemplo.
class MarketingApi {
  final MarketingGet _get;
  final MarketingWrite _post;
  final MarketingWrite _patch;
  final bool Function() _online;

  MarketingApi({
    MarketingGet? get,
    MarketingWrite? post,
    MarketingWrite? patch,
    bool Function()? online,
  }) : _get = get ?? ((p) => ApiService.instance.get(p, auth: true)),
       _post = post ?? ((p, b) => ApiService.instance.post(p, b, auth: true)),
       _patch =
           patch ?? ((p, b) => ApiService.instance.patch(p, b, auth: true)),
       _online = online ?? (() => ApiService.instance.useOnlineBackend);

  Future<dynamic> get(String path) => _request(() => _get(path));
  Future<dynamic> post(String path, Map<String, dynamic> body) =>
      _request(() => _post(path, body));
  Future<dynamic> patch(String path, Map<String, dynamic> body) =>
      _request(() => _patch(path, body));

  Future<dynamic> _request(Future<http.Response> Function() send) async {
    if (!_online()) {
      throw const MarketingException(
        'Conéctate al servidor para usar esta función.',
      );
    }
    try {
      final r = await send();
      if (r.statusCode == 401) {
        throw const MarketingException(
          'Tu sesión venció. Inicia sesión nuevamente.',
        );
      }
      if (r.statusCode == 403) {
        throw const MarketingException(
          'No tienes permiso para realizar esta acción.',
        );
      }
      if (r.statusCode == 404) {
        throw const MarketingException(
          'La información solicitada no está disponible.',
        );
      }
      if (r.statusCode >= 500) {
        throw const MarketingException(
          'El servicio no está disponible. Intenta más tarde.',
        );
      }
      final data = jsonDecode(utf8.decode(r.bodyBytes));
      if (r.statusCode < 200 || r.statusCode >= 300) {
        if ((r.statusCode == 400 || r.statusCode == 409) && data is Map) {
          throw MarketingException(
            data.values.expand((v) => v is List ? v : [v]).join('\n'),
          );
        }
        throw const MarketingException('No se pudo completar la solicitud.');
      }
      return data;
    } on MarketingException {
      rethrow;
    } on TimeoutException {
      throw const MarketingException(
        'El servidor tardó demasiado. Comprueba la información antes de reenviar.',
      );
    } catch (_) {
      throw const MarketingException(
        'No se pudo conectar con el servidor. Revisa tu conexión.',
      );
    }
  }
}
