import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kantu_market/core/services/auth_service.dart';
import 'package:kantu_market/features/auth/password_reset_confirm_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('PasswordResetConfirmScreen renderiza campos y lista de requisitos', (tester) async {
    final authService = AuthService();

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthService>.value(
        value: authService,
        child: const MaterialApp(
          home: PasswordResetConfirmScreen(initialToken: 'ABC123XYZ'),
        ),
      ),
    );

    expect(find.text('Define tu nueva contraseña'), findsOneWidget);
    expect(find.text('ABC123XYZ'), findsOneWidget);
    expect(find.text('Requisitos de seguridad:'), findsOneWidget);
    expect(find.text('Mínimo 8 caracteres'), findsOneWidget);
    expect(find.text('Restablecer Contraseña'), findsOneWidget);
  });
}
