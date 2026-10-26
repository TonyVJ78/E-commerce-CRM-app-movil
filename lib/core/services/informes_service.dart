import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../constants/api_constants.dart';
import '../models/informe.dart';
import 'api_service.dart';

/// Resultado de una operación que puede fallar con un mensaje para el usuario.
class ResultadoInforme<T> {
  final T? valor;
  final String? error;

  const ResultadoInforme.ok(this.valor) : error = null;
  const ResultadoInforme.falla(this.error) : valor = null;

  bool get ok => error == null;
}

/// Informes de tienda con IA (CU-34): `POST /api/ia/informes/generar/`.
///
/// Como el chatbot, el backend no guarda la conversación: aquí se lleva el
/// historial y se manda completo en cada turno. Los informes generados sí
/// quedan en el servidor (historial) y se exportan desde ahí a PDF o Excel.
class InformesService extends ChangeNotifier {
  /// El modelo puede consultar la base varias veces antes de responder.
  static const Duration _timeout = Duration(seconds: 90);

  static const MensajeInforme _saludo = MensajeInforme(
    esUsuario: false,
    contenido: 'Hola, soy el **analista de Kantu**. Dime qué informe necesitas —escrito o '
        'por voz— y consulto los datos de tu tienda. Te devuelvo una tabla, un análisis y '
        'puedes exportarlo a **PDF** o **Excel**.',
  );

  List<MensajeInforme> _mensajes = [_saludo];
  bool _enviando = false;
  int? _usuarioId;

  ContextoInformes? _contexto;
  bool _cargandoContexto = false;
  String? _errorContexto;
  bool _sinPermiso = false;
  int? _tiendaId;

  List<MensajeInforme> get mensajes => List.unmodifiable(_mensajes);
  bool get enviando => _enviando;
  ContextoInformes? get contexto => _contexto;
  bool get cargandoContexto => _cargandoContexto;
  String? get errorContexto => _errorContexto;
  bool get sinPermiso => _sinPermiso;
  int? get tiendaId => _tiendaId;

  /// Llamar al abrir la pantalla: otra cuenta no debe ver la charla anterior.
  void prepararPara(int? usuarioId) {
    if (_usuarioId == usuarioId) return;
    _usuarioId = usuarioId;
    _mensajes = [_saludo];
    _enviando = false;
    _contexto = null;
    _sinPermiso = false;
    _errorContexto = null;
    _tiendaId = null;
  }

  void elegirTienda(int? tiendaId) {
    _tiendaId = tiendaId;
    notifyListeners();
  }

  void reiniciar() {
    if (_enviando) return;
    _mensajes = [_saludo];
    notifyListeners();
  }

  Future<void> cargarContexto() async {
    if (_cargandoContexto) return;
    if (!ApiService.instance.useOnlineBackend) {
      _errorContexto = 'Los informes necesitan conexión con el servidor. Activa el modo servidor en Ajustes.';
      notifyListeners();
      return;
    }
    _cargandoContexto = true;
    _errorContexto = null;
    _sinPermiso = false;
    notifyListeners();
    try {
      final res = await ApiService.instance.get(
        ApiConstants.informesContexto,
        auth: true,
      );
      if (res.statusCode == 200) {
        _contexto = ContextoInformes.fromJson(
          _json(res.bodyBytes) as Map<String, dynamic>,
        );
        _sinPermiso = false;
        final tiendas = _contexto!.tiendas;
        if (tiendas.length == 1) {
          _tiendaId = tiendas.first.id;
        } else if (_tiendaId != null &&
            !tiendas.any((t) => t.id == _tiendaId)) {
          _tiendaId = null;
        }
      } else {
        _contexto = null;
        _tiendaId = null;
        if (res.statusCode == 403) {
          _sinPermiso = true;
        } else if (res.statusCode == 404) {
          _errorContexto =
              'Los informes aún no están disponibles en el servidor. '
              'El equipo debe actualizarlo para habilitar esta función.';
        } else if (res.statusCode == 401) {
          _errorContexto =
              'Tu sesión venció. Cierra sesión e ingresa nuevamente.';
        } else if (res.statusCode == 429) {
          _errorContexto = 'Se alcanzó el límite de consultas. Espera un momento y vuelve a intentar.';
        } else {
          _errorContexto = 'El servicio de informes no está disponible temporalmente. Intenta más tarde.';
        }
      }
    } catch (_) {
      _contexto = null;
      _tiendaId = null;
      _errorContexto =
          'No pude conectarme con el servidor. Revisa tu conexión.';
    }
    _cargandoContexto = false;
    notifyListeners();
  }

  Future<void> enviar(String texto) async {
    final contenido = texto.trim();
    if (contenido.isEmpty || _enviando) return;

    // Los errores no se reenvían: confundirían al modelo.
    _mensajes = [
      ..._mensajes.where((m) => !m.error),
      MensajeInforme(esUsuario: true, contenido: contenido),
    ];
    _enviando = true;
    notifyListeners();

    MensajeInforme respuesta;
    try {
      final res = await ApiService.instance.post(
        ApiConstants.informesGenerar,
        {
          'mensajes': _mensajes.map((m) => m.toApiJson()).toList(),
          'tienda_id': _tiendaId,
        },
        auth: true,
        timeout: _timeout,
      );
      respuesta = res.statusCode == 200 ? _desdeRespuesta(res.bodyBytes) : _error(res.statusCode, res.bodyBytes);
    } on TimeoutException {
      respuesta = const MensajeInforme(
        esUsuario: false,
        contenido: 'El informe tardó demasiado. Intenta con un pedido más acotado.',
        error: true,
      );
    } catch (_) {
      respuesta = const MensajeInforme(
        esUsuario: false,
        contenido: 'No pude conectarme con el servidor. Revisa tu conexión e intenta de nuevo.',
        error: true,
      );
    }

    _mensajes = [..._mensajes, respuesta];
    _enviando = false;
    notifyListeners();
  }

  Future<ResultadoInforme<List<InformeResumen>>> historial() async {
    try {
      final res = await ApiService.instance.get(ApiConstants.informes, auth: true);
      if (res.statusCode != 200) return const ResultadoInforme.falla('No se pudo cargar el historial.');
      final lista = (_json(res.bodyBytes) as List)
          .map((i) => InformeResumen.fromJson(Map<String, dynamic>.from(i as Map)))
          .toList();
      return ResultadoInforme.ok(lista);
    } catch (_) {
      return const ResultadoInforme.falla('No pude conectarme con el servidor.');
    }
  }

  Future<ResultadoInforme<Informe>> obtener(int id) async {
    try {
      final res = await ApiService.instance.get(ApiConstants.informeDetalle(id), auth: true);
      if (res.statusCode != 200) return const ResultadoInforme.falla('Ese informe ya no está disponible.');
      return ResultadoInforme.ok(Informe.fromJson(_json(res.bodyBytes) as Map<String, dynamic>));
    } catch (_) {
      return const ResultadoInforme.falla('No pude conectarme con el servidor.');
    }
  }

  Future<bool> eliminar(int id) async {
    try {
      final res = await ApiService.instance.delete(ApiConstants.informeDetalle(id), auth: true);
      return res.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  /// Descarga el informe en `formato` (`pdf` o `xlsx`) y devuelve la ruta local.
  Future<ResultadoInforme<String>> exportar(Informe informe, String formato) async {
    try {
      final res = await ApiService.instance.get(
        ApiConstants.informeExportar(informe.id),
        auth: true,
        query: {'formato': formato},
      );
      if (res.statusCode != 200) {
        return const ResultadoInforme.falla('No se pudo exportar el informe.');
      }
      final carpeta = await getTemporaryDirectory();
      final archivo = File('${carpeta.path}/${_nombreArchivo(informe.titulo)}.$formato');
      await archivo.writeAsBytes(res.bodyBytes, flush: true);
      return ResultadoInforme.ok(archivo.path);
    } catch (_) {
      return const ResultadoInforme.falla('No se pudo guardar el archivo en el teléfono.');
    }
  }

  static String _nombreArchivo(String titulo) {
    const conTilde = 'áéíóúüñÁÉÍÓÚÜÑ';
    const sinTilde = 'aeiouunAEIOUUN';
    var base = titulo;
    for (var i = 0; i < conTilde.length; i++) {
      base = base.replaceAll(conTilde[i], sinTilde[i]);
    }
    base = base.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '');
    if (base.length > 60) base = base.substring(0, 60);
    return 'informe-${base.isEmpty ? 'kantu' : base}';
  }

  /// Se decodifica desde los bytes: sin `charset` en la cabecera, `body`
  /// podría leer las tildes como latin1.
  static dynamic _json(List<int> bytes) => jsonDecode(utf8.decode(bytes, allowMalformed: true));

  static MensajeInforme _desdeRespuesta(List<int> bytes) {
    final data = _json(bytes) as Map<String, dynamic>;
    final informe = data['informe'] is Map
        ? Informe.fromJson(Map<String, dynamic>.from(data['informe'] as Map))
        : null;
    return MensajeInforme(
      esUsuario: false,
      contenido: (data['mensaje'] ?? '').toString(),
      sugerencias: (data['sugerencias'] as List? ?? []).map((s) => s.toString()).toList(),
      informe: informe,
    );
  }

  static MensajeInforme _error(int status, List<int> bytes) {
    String mensaje;
    if (status == 429) {
      mensaje = 'Vas muy rápido. Espera un momento y vuelve a intentarlo.';
    } else {
      mensaje = status == 403
          ? 'No tienes permiso para generar informes.'
          : 'No pude generar el informe ahora. Intenta de nuevo en unos segundos.';
      try {
        final detalle = (_json(bytes) as Map)['detail'];
        if (detalle != null) mensaje = detalle.toString();
      } catch (_) {}
    }
    return MensajeInforme(esUsuario: false, contenido: mensaje, error: true);
  }
}
