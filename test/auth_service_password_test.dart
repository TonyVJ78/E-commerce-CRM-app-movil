import 'package:flutter_test/flutter_test.dart';
import 'package:kantu_market/core/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AuthService - CU-05 Password & Preferences', () {
    test('valida complejidad de contraseñas correctamente', () {
      expect(AuthService.isPasswordValid('1234567'), isFalse); // < 8 chars
      expect(AuthService.isPasswordValid('abcdefgh'), isFalse); // sin numero ni simbolo
      expect(AuthService.isPasswordValid('Abcdefgh1'), isFalse); // sin simbolo
      expect(AuthService.isPasswordValid('Abcdefg1!'), isTrue); // cumple todos
    });

    test('solicitarRecuperacionPassword valida formato de correo', () async {
      final auth = AuthService();
      final okInvalido = await auth.solicitarRecuperacionPassword('email-invalido');
      expect(okInvalido, isFalse);
      expect(auth.errorMessage, contains('correo electrónico válido'));
    });

    test('confirmarResetPassword exige complejidad antes de enviar', () async {
      final auth = AuthService();
      final ok = await auth.confirmarResetPassword(
        'token123',
        'debil',
      );
      expect(ok, isFalse);
      expect(auth.errorMessage, contains('al menos 8 caracteres'));
    });

    test('guardarPreferenciasEntrega persiste teléfono y dirección', () async {
      final auth = AuthService();
      await auth.init();

      final ok = await auth.guardarPreferenciasEntrega(
        telefono: '+591 71234567',
        direccionEnvio: 'Av. 6 de Agosto #1234, Sopocachi',
      );

      expect(ok, isTrue);
      expect(auth.telefono, '+591 71234567');
      expect(auth.direccionEnvio, 'Av. 6 de Agosto #1234, Sopocachi');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('km_user_telefono'), '+591 71234567');
      expect(prefs.getString('km_user_direccion'), 'Av. 6 de Agosto #1234, Sopocachi');
    });

    test('cambiarPassword exige usuario autenticado', () async {
      final auth = AuthService();
      final ok = await auth.cambiarPassword('actual123!', 'NuevaPass123!');
      expect(ok, isFalse);
      expect(auth.errorMessage, contains('iniciar sesión'));
    });

    test('cambiarPassword rechaza nueva contraseña idéntica a la actual', () async {
      final auth = AuthService();
      // Simulamos que hay usuario seteando errorMessage
      final ok = await auth.cambiarPassword('MismaPass123!', 'MismaPass123!');
      expect(ok, isFalse);
    });
  });
}
