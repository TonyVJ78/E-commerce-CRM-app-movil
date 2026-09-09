import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';

/// Cliente HTTP contra la API de Django, compartido por todos los CU.
///
/// Guarda el modo (autónomo o servidor) y la URL base, adjunta el token JWT
/// y renueva la sesión cuando el backend responde 401.
class ApiService {
  static final ApiService instance = ApiService._init();
  ApiService._init();

  /// Tiempo máximo de espera por petición. Corto a propósito: si el backend
  /// remoto no responde, se cae rápido al modo local en vez de congelar la UI.
  static const Duration _timeout = Duration(seconds: 4);

  String _baseUrl = ApiConstants.defaultEmulatorUrl;
  bool _useOnlineBackend = false;

  String get baseUrl => _baseUrl;
  bool get useOnlineBackend => _useOnlineBackend;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString('api_base_url') ?? ApiConstants.defaultEmulatorUrl;
    _useOnlineBackend = prefs.getBool('use_online_backend') ?? false;
  }

  Future<void> setConfig({required String baseUrl, required bool useOnline}) async {
    _baseUrl = baseUrl;
    _useOnlineBackend = useOnline;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_base_url', baseUrl);
    await prefs.setBool('use_online_backend', useOnline);
  }

  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('km_access_token');
  }

  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('km_refresh_token');
  }

  Future<void> saveTokens({required String access, required String refresh}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('km_access_token', access);
    await prefs.setString('km_refresh_token', refresh);
  }

  Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('km_access_token');
    await prefs.remove('km_refresh_token');
  }

  Uri _uri(String endpoint, [Map<String, String>? query]) {
    final uri = Uri.parse('$_baseUrl$endpoint');
    if (query == null || query.isEmpty) return uri;
    final limpio = Map<String, String>.from(query)
      ..removeWhere((_, value) => value.trim().isEmpty);
    return uri.replace(queryParameters: {...uri.queryParameters, ...limpio});
  }

  Future<Map<String, String>> _headers({required bool auth, bool json = true}) async {
    final headers = <String, String>{};
    if (json) headers['Content-Type'] = 'application/json';
    if (auth) {
      final token = await getAccessToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  /// Renueva el access token con el refresh guardado. Devuelve `true` si lo logró.
  ///
  /// Espeja a `auth.interceptor.ts` del frontend Angular, incluida su limitación
  /// conocida: dos peticiones que reciben 401 a la vez disparan dos refresh y la
  /// segunda puede fallar por la rotación de tokens de SimpleJWT.
  Future<bool> _refreshAccessToken() async {
    final refresh = await getRefreshToken();
    if (refresh == null || refresh.isEmpty) return false;

    try {
      final res = await http
          .post(
            _uri(ApiConstants.tokenRefresh),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refresh': refresh}),
          )
          .timeout(_timeout);

      if (res.statusCode != 200) return false;

      final data = jsonDecode(res.body);
      await saveTokens(
        access: data['access'] ?? '',
        // Con ROTATE_REFRESH_TOKENS el backend devuelve un refresh nuevo.
        refresh: data['refresh'] ?? refresh,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Ejecuta la petición y, si el backend responde 401, renueva el token y
  /// reintenta una única vez.
  Future<http.Response> _enviar(
    Future<http.Response> Function() peticion, {
    required bool auth,
  }) async {
    final res = await peticion();
    if (res.statusCode != 401 || !auth) return res;

    final renovado = await _refreshAccessToken();
    if (!renovado) return res;
    return await peticion();
  }

  Future<http.Response> get(
    String endpoint, {
    bool auth = false,
    Map<String, String>? query,
  }) {
    return _enviar(
      () async => http.get(_uri(endpoint, query), headers: await _headers(auth: auth)).timeout(_timeout),
      auth: auth,
    );
  }

  Future<http.Response> post(String endpoint, Map<String, dynamic> body, {bool auth = false}) {
    return _enviar(
      () async => http
          .post(_uri(endpoint), headers: await _headers(auth: auth), body: jsonEncode(body))
          .timeout(_timeout),
      auth: auth,
    );
  }

  Future<http.Response> patch(String endpoint, Map<String, dynamic> body, {bool auth = false}) {
    return _enviar(
      () async => http
          .patch(_uri(endpoint), headers: await _headers(auth: auth), body: jsonEncode(body))
          .timeout(_timeout),
      auth: auth,
    );
  }

  Future<http.Response> delete(String endpoint, {bool auth = false}) {
    return _enviar(
      () async => http.delete(_uri(endpoint), headers: await _headers(auth: auth)).timeout(_timeout),
      auth: auth,
    );
  }

  /// POST `multipart/form-data`. Lo usa CU-08, porque el backend recibe las
  /// imágenes del producto como archivos y el resto de campos como texto
  /// (`variantes` y `etiquetas` viajan serializados en JSON).
  ///
  /// La subida a Cloudinary puede tardar más que una petición normal, así que
  /// aquí el timeout es más holgado que `_timeout`.
  Future<http.Response> multipart(
    String endpoint, {
    required Map<String, String> campos,
    List<String> archivos = const [],
    String campoArchivo = 'imagenes',
    bool auth = true,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    Future<http.Response> enviar() async {
      final request = http.MultipartRequest('POST', _uri(endpoint))
        ..headers.addAll(await _headers(auth: auth, json: false))
        ..fields.addAll(campos);

      for (final ruta in archivos) {
        request.files.add(await http.MultipartFile.fromPath(campoArchivo, ruta));
      }

      final streamed = await request.send().timeout(timeout);
      return await http.Response.fromStream(streamed);
    }

    return _enviar(enviar, auth: auth);
  }
}
