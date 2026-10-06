import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kantu_market/core/services/auth_service.dart';
import 'package:kantu_market/features/auth/forgot_password_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('ForgotPasswordScreen muestra título y campos de correo', (tester) async {
    final authService = AuthService();

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthService>.value(
        value: authService,
        child: const MaterialApp(
          home: ForgotPasswordScreen(initialEmail: 'test@kantu.bo'),
        ),
      ),
    );

    expect(find.text('¿Olvidaste tu contraseña?'), findsOneWidget);
    expect(find.text('Enviar Código de Recuperación'), findsOneWidget);
    expect(find.text('test@kantu.bo'), findsOneWidget);
  });
}
