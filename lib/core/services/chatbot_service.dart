import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../constants/api_constants.dart';
import '../models/producto.dart';
import 'api_service.dart';

/// Un mensaje de la conversación con el asistente.
class MensajeChat {
  final bool esUsuario;

  /// Markdown en los del asistente; los productos van como `[Nombre](producto:ID)`.
  final String contenido;
  final List<Producto> productos;
  final List<String> sugerencias;
  final bool error;

  const MensajeChat({
    required this.esUsuario,
    required this.contenido,
    this.productos = const [],
    this.sugerencias = const [],
    this.error = false,
  });

  Map<String, String> toApiJson() => {
        'rol': esUsuario ? 'usuario' : 'asistente',
        'contenido': contenido,
      };
}

/// Chatbot de recomendaciones (`POST /api/ia/chatbot/`).
///
/// El backend no guarda la conversación, así que aquí se lleva el historial y
/// se manda completo en cada mensaje. Vive como provider para que la charla
/// siga ahí al cerrar la pantalla y volver; se reinicia al cambiar de cuenta.
class ChatbotService extends ChangeNotifier {
  /// El modelo puede consultar el catálogo varias veces antes de contestar.
  static const Duration _timeout = Duration(seconds: 60);

  static const MensajeChat _saludo = MensajeChat(
    esUsuario: false,
    contenido: '¡Hola! Soy **Kantu**, tu asistente de compras. Cuéntame qué buscas '
        '—aunque sea una idea general— y te ayudo a encontrarlo en las tiendas.',
    sugerencias: ['Busco un regalo', 'Algo de alpaca', 'Café boliviano', 'Ofertas de hoy'],
  );

  List<MensajeChat> _mensajes = [_saludo];
  bool _enviando = false;
  int? _usuarioId;

  List<MensajeChat> get mensajes => List.unmodifiable(_mensajes);
  bool get enviando => _enviando;

  /// Productos citados en cualquier respuesta, para abrir su ficha al tocar un
  /// enlace del texto sin volver a pedirlos al servidor.
  Producto? productoCitado(int id) {
    for (final mensaje in _mensajes.reversed) {
      for (final producto in mensaje.productos) {
        if (producto.id == id) return producto;
      }
    }
    return null;
  }

  /// Llamar al abrir la pantalla: otra cuenta no debe ver la charla anterior.
  void prepararPara(int? usuarioId) {
    if (_usuarioId == usuarioId) return;
    _usuarioId = usuarioId;
    _mensajes = [_saludo];
    _enviando = false;
  }

  void reiniciar() {
    if (_enviando) return;
    _mensajes = [_saludo];
    notifyListeners();
  }

  Future<void> enviar(String texto) async {
    final contenido = texto.trim();
    if (contenido.isEmpty || _enviando) return;

    // Los errores no se reenvían: confundirían al modelo.
    _mensajes = [
      ..._mensajes.where((m) => !m.error),
      MensajeChat(esUsuario: true, contenido: contenido),
    ];
    _enviando = true;
    notifyListeners();

    final historial = _mensajes.map((m) => m.toApiJson()).toList();
    MensajeChat respuesta;

    if (!ApiService.instance.useOnlineBackend) {
      respuesta = const MensajeChat(
        esUsuario: false,
        contenido: 'El asistente necesita conexión con el servidor. Activa el modo servidor '
            'en Ajustes para usarlo.',
        error: true,
      );
    } else {
      try {
        final res = await ApiService.instance.post(
          ApiConstants.chatbot,
          {'mensajes': historial},
          auth: true,
          timeout: _timeout,
        );
        respuesta = res.statusCode == 200
            ? _desdeJson(res.bodyBytes)
            : _error(res.statusCode, utf8.decode(res.bodyBytes, allowMalformed: true));
      } on TimeoutException {
        respuesta = const MensajeChat(
          esUsuario: false,
          contenido: 'El asistente tardó demasiado en responder. Intenta de nuevo.',
          error: true,
        );
      } catch (_) {
        respuesta = const MensajeChat(
          esUsuario: false,
          contenido: 'No pude conectarme con el servidor. Revisa tu conexión e intenta de nuevo.',
          error: true,
        );
      }
    }

    _mensajes = [..._mensajes, respuesta];
    _enviando = false;
    notifyListeners();
  }

  /// Se decodifica desde los bytes: sin `charset` en la cabecera, `body`
  /// podría leer las tildes como latin1.
  static MensajeChat _desdeJson(List<int> bytes) {
    final data = jsonDecode(utf8.decode(bytes, allowMalformed: true)) as Map<String, dynamic>;
    final productos = (data['productos'] as List? ?? [])
        .map((p) => Producto.fromJson(Map<String, dynamic>.from(p as Map)))
        .toList();
    final sugerencias = (data['sugerencias'] as List? ?? []).map((s) => s.toString()).toList();
    return MensajeChat(
      esUsuario: false,
      contenido: (data['mensaje'] ?? '').toString(),
      productos: productos,
      sugerencias: sugerencias,
    );
  }

  static MensajeChat _error(int status, String body) {
    String mensaje;
    if (status == 429) {
      mensaje = 'Vas muy rápido 😅. Espera un momento y vuelve a intentarlo.';
    } else {
      mensaje = 'No pude responder ahora. Intenta de nuevo en unos segundos.';
      try {
        final detalle = (jsonDecode(body) as Map)['detail'];
        if (detalle != null) mensaje = detalle.toString();
      } catch (_) {}
    }
    return MensajeChat(esUsuario: false, contenido: mensaje, error: true);
  }
}
