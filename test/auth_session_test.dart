import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kantu_market/core/services/api_service.dart';
import 'package:kantu_market/core/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final usuario = jsonEncode({
    'id': 42,
    'email': 'cliente@example.test',
    'first_name': 'Cliente',
    'last_name': 'Prueba',
    'rol': 'cliente',
  });

  setUp(() {
    ApiService.instance.setOnlineBackend(true);
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'una cuenta local guardada sin credenciales no abre la sesión del servidor',
    () async {
      SharedPreferences.setMockInitialValues({
        'km_user': usuario,
        'km_user_telefono': 'dato-local-de-prueba',
      });
      final auth = AuthService();
      await auth.init();
      expect(auth.isAuthenticated, isFalse);
      expect(auth.currentUser, isNull);
      expect(auth.errorMessage, contains('Inicia sesión nuevamente'));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('km_user'), isFalse);
      expect(prefs.getString('km_user_telefono'), 'dato-local-de-prueba');
    },
  );

  test('restaura el usuario si existe un token de acceso', () async {
    SharedPreferences.setMockInitialValues({
      'km_user': usuario,
      'km_access_token': 'access-simulado',
    });
    final auth = AuthService();
    await auth.init();
    expect(auth.isAuthenticated, isTrue);
    expect(auth.currentUser?.id, 42);
    expect(auth.errorMessage, isNull);
  });

  test(
    'permite restaurar con refresh para que ApiService pueda renovar el acceso',
    () async {
      SharedPreferences.setMockInitialValues({
        'km_user': usuario,
        'km_refresh_token': 'refresh-simulado',
      });
      final auth = AuthService();
      await auth.init();
      expect(auth.isAuthenticated, isTrue);
      expect(auth.currentUser?.id, 42);
    },
  );

  test(
    'el modo autónomo conserva su sesión SQLite sin exigir tokens remotos',
    () async {
      ApiService.instance.setOnlineBackend(false);
      SharedPreferences.setMockInitialValues({'km_user': usuario});
      final auth = AuthService();
      await auth.init();
      expect(auth.isAuthenticated, isTrue);
      expect(auth.currentUser?.id, 42);
    },
  );

  test('valores vacíos o espacios no cuentan como credenciales', () async {
    SharedPreferences.setMockInitialValues({
      'km_user': usuario,
      'km_access_token': ' ',
      'km_refresh_token': '',
    });
    final auth = AuthService();
    await auth.init();
    expect(auth.isAuthenticated, isFalse);
  });

  test('reinicializar no conserva una identidad previa después de perder las credenciales', () async {
    SharedPreferences.setMockInitialValues({
      'km_user': usuario,
      'km_access_token': 'access-simulado',
    });
    final auth = AuthService();
    await auth.init();
    expect(auth.isAuthenticated, isTrue);
    await ApiService.instance.clearTokens();
    await auth.init();
    expect(auth.currentUser, isNull);
    expect(auth.isAuthenticated, isFalse);
  });
}
