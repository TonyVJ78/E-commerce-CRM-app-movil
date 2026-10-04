import 'push_notification_service.dart';
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
  String? _telefono;
  String? _direccionEnvio;

  Usuario? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get telefono => _telefono;
  String? get direccionEnvio => _direccionEnvio;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('km_user');
    if (userJson != null) {
      try {
        final map = jsonDecode(userJson);
        _currentUser = Usuario.fromMap(map);
      } catch (_) {}
    }
    _telefono = prefs.getString('km_user_telefono');
    _direccionEnvio = prefs.getString('km_user_direccion');
    notifyListeners();
  }

  void _saveUserToStorage(Usuario user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('km_user', jsonEncode(user.toMap()));
  }

  Future<void> _clearUserFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('km_user');
  }

  // --- PREFERENCIAS DE CONTACTO Y ENVÍO (CU-05 & CU-19) ---
  Future<bool> guardarPreferenciasEntrega({
    required String telefono,
    required String direccionEnvio,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('km_user_telefono', telefono.trim());
      await prefs.setString('km_user_direccion', direccionEnvio.trim());
      _telefono = telefono.trim();
      _direccionEnvio = direccionEnvio.trim();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'No se pudieron guardar las preferencias: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
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
            PushNotificationService.instance.sincronizarTokenConBackend();
            _isLoading = false;
            notifyListeners();
            return true;
          } else if (res.statusCode >= 500) {
            _errorMessage = 'El servidor tuvo un problema (código ${res.statusCode}). Vuelve a intentarlo en un momento.';
            _isLoading = false;
            notifyListeners();
            return false;
          } else {
            final data = _parseResponse(res.body);
            _errorMessage = data['error'] ?? data['detail'] ?? 'Credenciales incorrectas.';
            _isLoading = false;
            notifyListeners();
            return false;
          }
        } catch (_) {
          _errorMessage = 'No se pudo contactar al servidor. Revisa tu conexión a internet y vuelve a intentarlo.';
          _isLoading = false;
          notifyListeners();
          return false;
        }
      }

      // Modo autónomo SQLite
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
            final data = _parseResponse(res.body);
            _errorMessage = data['error'] ?? data['detail'] ?? data.toString();
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

  // --- UPDATE PROFILE (CU04: Datos Personales) ---
  Future<bool> updatePerfil(String firstName, String lastName) async {
    if (_currentUser == null) return false;
    _isLoading = true;
    _errorMessage = null;
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

  // --- RECUPERACIÓN DE CONTRASEÑA (CU-05: Solicitar Email) ---
  Future<bool> solicitarRecuperacionPassword(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty || !trimmed.contains('@')) {
      _errorMessage = 'Ingresa un correo electrónico válido.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (ApiService.instance.useOnlineBackend) {
        try {
          final res = await ApiService.instance.post(ApiConstants.passwordReset, {
            'email': trimmed,
          });

          if (res.statusCode == 200) {
            _isLoading = false;
            notifyListeners();
            return true;
          } else {
            final data = _parseResponse(res.body);
            _errorMessage = data['error'] ?? data['detail'] ?? 'No se pudo procesar la solicitud.';
            _isLoading = false;
            notifyListeners();
            return false;
          }
        } catch (_) {
          _errorMessage = 'No se pudo contactar al servidor para la recuperación.';
          _isLoading = false;
          notifyListeners();
          return false;
        }
      }

      // Modo local / offline
      final exists = await DatabaseHelper.instance.userExists(trimmed);
      if (!exists) {
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error al solicitar recuperación: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // --- CONFIRMAR RESET DE CONTRASEÑA (CU-05: Con Token y Nueva Clave) ---
  Future<bool> confirmarResetPassword({
    required String tokenOEnlace,
    required String nuevaPassword,
    String? uid,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    if (!isPasswordValid(nuevaPassword)) {
      _errorMessage = 'La nueva contraseña debe tener al menos 8 caracteres, incluyendo letras, números y símbolos.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    String parsedUid = uid?.trim() ?? '';
    String parsedToken = tokenOEnlace.trim();

    if (parsedToken.contains('/recuperar-password/')) {
      final parts = parsedToken.split('/recuperar-password/').last.split('/');
      if (parts.length >= 2) {
        parsedUid = parts[0];
        parsedToken = parts[1];
      }
    } else if (parsedToken.contains('/')) {
      final parts = parsedToken.split('/');
      if (parts.length >= 2) {
        parsedUid = parts[0];
        parsedToken = parts[1];
      }
    } else if (parsedToken.contains(':')) {
      final parts = parsedToken.split(':');
      if (parts.length >= 2) {
        parsedUid = parts[0];
        parsedToken = parts[1];
      }
    }

    try {
      if (ApiService.instance.useOnlineBackend) {
        try {
          final res = await ApiService.instance.post(ApiConstants.passwordResetConfirm, {
            'uid': parsedUid,
            'token': parsedToken,
            'new_password': nuevaPassword,
            'new_password_confirm': nuevaPassword,
          });

          if (res.statusCode == 200) {
            _isLoading = false;
            notifyListeners();
            return true;
          } else {
            final data = _parseResponse(res.body);
            String errorMsg = 'El token es inválido o ha expirado.';
            if (data['error'] != null) {
              errorMsg = data['error'].toString();
            } else if (data['new_password'] != null) {
              final val = data['new_password'];
              errorMsg = val is List ? val.join(' ') : val.toString();
            } else if (data['token'] != null) {
              final val = data['token'];
              errorMsg = val is List ? val.join(' ') : val.toString();
            } else if (data['detail'] != null) {
              errorMsg = data['detail'].toString();
            }
            _errorMessage = errorMsg;
            _isLoading = false;
            notifyListeners();
            return false;
          }
        } catch (_) {
          _errorMessage = 'Error de conexión al confirmar restablecimiento de contraseña.';
          _isLoading = false;
          notifyListeners();
          return false;
        }
      }

      // Modo local / offline
      if (_currentUser != null) {
        await DatabaseHelper.instance.resetPassword(_currentUser!.email, nuevaPassword);
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error al confirmar contraseña: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // --- CAMBIO DE CONTRASEÑA AUTENTICADO (CU-05: Seguridad de Perfil) ---
  Future<bool> cambiarPassword(String actual, String nueva) async {
    if (_currentUser == null) {
      _errorMessage = 'Debes iniciar sesión para cambiar tu contraseña.';
      notifyListeners();
      return false;
    }

    if (!isPasswordValid(nueva)) {
      _errorMessage = 'La nueva contraseña debe tener al menos 8 caracteres, incluyendo letras, números y símbolos.';
      notifyListeners();
      return false;
    }

    if (actual == nueva) {
      _errorMessage = 'La nueva contraseña debe ser diferente a la actual.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (ApiService.instance.useOnlineBackend) {
        final checkRes = await ApiService.instance.post(ApiConstants.login, {
          'email': _currentUser!.email,
          'password': actual,
        });

        if (checkRes.statusCode != 200) {
          _errorMessage = 'La contraseña actual ingresada es incorrecta.';
          _isLoading = false;
          notifyListeners();
          return false;
        }

        await DatabaseHelper.instance.resetPassword(_currentUser!.email, nueva);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        final checkUser = await DatabaseHelper.instance.loginUser(_currentUser!.email, actual);
        if (checkUser == null) {
          _errorMessage = 'La contraseña actual ingresada es incorrecta.';
          _isLoading = false;
          notifyListeners();
          return false;
        }

        await DatabaseHelper.instance.resetPassword(_currentUser!.email, nueva);
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _errorMessage = 'Error al actualizar la contraseña: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Compatibilidad hacia atrás
  Future<bool> requestPasswordReset(String email, String newPassword) async {
    return confirmarResetPassword(tokenOEnlace: 'legacy', nuevaPassword: newPassword);
  }

  static Map<String, dynamic> _parseResponse(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {'detail': body};
    } catch (_) {
      return {'detail': body};
    }
  }
}
