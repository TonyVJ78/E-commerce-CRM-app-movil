import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/db_helper.dart';
import '../models/usuario.dart';
import 'api_service.dart';
import '../constants/api_constants.dart';

class AuthService extends ChangeNotifier {
  Usuario? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  Usuario? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('km_user');
    if (userJson != null) {
      try {
        final map = jsonDecode(userJson);
        _currentUser = Usuario.fromMap(map);
        notifyListeners();
      } catch (_) {}
    }
  }

  void _saveUserToStorage(Usuario user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('km_user', jsonEncode(user.toMap()));
  }

  Future<void> _clearUserFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('km_user');
  }

  // --- PASSWORD COMPLEXITY VALIDATION ---
  static Map<String, bool> checkPasswordComplexity(String password) {
    return {
      'minLength': password.length >= 8,
      'hasLetter': RegExp(r'[a-zA-Z]').hasMatch(password),
      'hasNumber': RegExp(r'[0-9]').hasMatch(password),
      'hasSpecial': RegExp(r'[^a-zA-Z0-9]').hasMatch(password),
    };
  }

  static bool isPasswordValid(String password) {
    final c = checkPasswordComplexity(password);
    return c['minLength']! && c['hasLetter']! && c['hasNumber']! && c['hasSpecial']!;
  }

  // --- LOGIN ---
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (ApiService.instance.useOnlineBackend) {
        // Intento Online
        try {
          final res = await ApiService.instance.post(ApiConstants.login, {
            'email': email.trim(),
            'password': password,
          });

          if (res.statusCode == 200) {
            final data = jsonDecode(res.body);
            await ApiService.instance.saveTokens(
              access: data['access'] ?? '',
              refresh: data['refresh'] ?? '',
            );
            _currentUser = Usuario.fromJson(data['usuario']);
            _saveUserToStorage(_currentUser!);
            _isLoading = false;
            notifyListeners();
            return true;
          } else {
            final data = jsonDecode(res.body);
            _errorMessage = data['error'] ?? data['detail'] ?? 'Credenciales incorrectas en el servidor.';
            _isLoading = false;
            notifyListeners();
            return false;
          }
        } catch (_) {
          // Fallback a Local Database
        }
      }

      // Modo Local Database
      final userMap = await DatabaseHelper.instance.loginUser(email, password);
      if (userMap != null) {
        _currentUser = Usuario.fromMap(userMap);
        _saveUserToStorage(_currentUser!);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Correo o contraseña incorrectos. Verifica tus credenciales.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Ocurrió un error al procesar el inicio de sesión: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // --- REGISTRO ---
  Future<bool> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String rol,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (!isPasswordValid(password)) {
        _errorMessage = 'La contraseña no cumple con los requisitos mínimos de seguridad.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (ApiService.instance.useOnlineBackend) {
        try {
          final res = await ApiService.instance.post(ApiConstants.registro, {
            'email': email.trim(),
            'password': password,
            'password_confirm': password,
            'first_name': firstName.trim(),
            'last_name': lastName.trim(),
            'rol_id': rol == 'empresa' ? 2 : (rol == 'administrador' ? 1 : 3),
          });

          if (res.statusCode == 201 || res.statusCode == 200) {
            _isLoading = false;
            notifyListeners();
            return true;
          } else {
            final data = jsonDecode(res.body);
            _errorMessage = data.toString();
            _isLoading = false;
            notifyListeners();
            return false;
          }
        } catch (_) {}
      }

      // Registro en Base de Datos Local
      final exists = await DatabaseHelper.instance.userExists(email);
      if (exists) {
        _errorMessage = 'Ya existe una cuenta registrada con este correo electrónico.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      await DatabaseHelper.instance.registerUser({
        'email': email.trim(),
        'password': password,
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'rol': rol,
      });

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error al registrar usuario: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // --- LOGOUT (CU03: Cerrar sesión) ---
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    // Intento de invalidar el refresh token en el backend (blacklist).
    // Si falla o no hay conexión, igual se cierra la sesión localmente.
    if (ApiService.instance.useOnlineBackend) {
      try {
        final refreshToken = await ApiService.instance.getRefreshToken();
        if (refreshToken != null && refreshToken.isNotEmpty) {
          await ApiService.instance.post(
            ApiConstants.logout,
            {'refresh': refreshToken},
            auth: true,
          );
        }
      } catch (_) {}
    }

    await ApiService.instance.clearTokens();
    _currentUser = null;
    _errorMessage = null;
    await _clearUserFromStorage();
    _isLoading = false;
    notifyListeners();
  }

  // --- UPDATE PROFILE ---
  Future<bool> updatePerfil(String firstName, String lastName) async {
    if (_currentUser == null) return false;
    _isLoading = true;
    notifyListeners();

    try {
      if (ApiService.instance.useOnlineBackend) {
        try {
          await ApiService.instance.patch(ApiConstants.perfil, {
            'first_name': firstName,
            'last_name': lastName,
          }, auth: true);
        } catch (_) {}
      }

      await DatabaseHelper.instance.updatePerfil(_currentUser!.id, firstName, lastName);
      _currentUser = _currentUser!.copyWith(firstName: firstName, lastName: lastName);
      _saveUserToStorage(_currentUser!);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error al actualizar perfil: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // --- RECUPERAR CONTRASEÑA ---
  Future<bool> requestPasswordReset(String email, String newPassword) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final exists = await DatabaseHelper.instance.userExists(email);
      if (!exists) {
        _errorMessage = 'No se encontró ninguna cuenta asociada a este correo.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      await DatabaseHelper.instance.resetPassword(email, newPassword);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error al restablecer contraseña: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Acceso Rápido Demo para pruebas con 1 toque
  Future<void> loginQuickDemo(String role) async {
    if (role == 'admin') {
      await login('admin@kantu.bo', 'Password123!');
    } else if (role == 'empresa') {
      await login('empresa@kantu.bo', 'Password123!');
    } else {
      await login('cliente@kantu.bo', 'Password123!');
    }
  }
}
