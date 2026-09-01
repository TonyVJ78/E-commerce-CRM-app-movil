import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';

class ApiService {
  static final ApiService instance = ApiService._init();
  ApiService._init();

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

  Future<http.Response> post(String endpoint, Map<String, dynamic> body, {bool auth = false}) async {
    final url = Uri.parse('$_baseUrl$endpoint');
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (auth) {
      final token = await getAccessToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return await http.post(url, headers: headers, body: jsonEncode(body)).timeout(
      const Duration(seconds: 8),
    );
  }

  Future<http.Response> get(String endpoint, {bool auth = false}) async {
    final url = Uri.parse('$_baseUrl$endpoint');
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (auth) {
      final token = await getAccessToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return await http.get(url, headers: headers).timeout(
      const Duration(seconds: 8),
    );
  }

  Future<http.Response> patch(String endpoint, Map<String, dynamic> body, {bool auth = false}) async {
    final url = Uri.parse('$_baseUrl$endpoint');
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (auth) {
      final token = await getAccessToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return await http.patch(url, headers: headers, body: jsonEncode(body)).timeout(
      const Duration(seconds: 8),
    );
  }
}
