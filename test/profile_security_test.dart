import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kantu_market/core/models/usuario.dart';
import 'package:kantu_market/core/services/auth_service.dart';
import 'package:kantu_market/features/profile/profile_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'km_user_telefono': '+591 71234567',
      'km_user_direccion': 'Av. Ballivián #500, Calacoto',
    });
  });

  testWidgets('ProfileScreen muestra secciones de Envío y Seguridad de Contraseña (CU-05)', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final authService = AuthService();
    await authService.init();

    // Simular usuario autenticado
    final testUser = Usuario(
      id: 99,
      email: 'juan.perez@kantu.bo',
      firstName: 'Juan',
      lastName: 'Pérez',
      rol: 'cliente',
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthService>.value(
        value: authService,
        child: const MaterialApp(
          home: ProfileScreen(),
        ),
      ),
    );

    // Inyectar usuario en el authService e iniciar pump
    authService.setCurrentUserForTesting(testUser);
    await tester.pumpAndSettle();

    // Verificar datos de encabezado y formulario
    expect(find.text('Juan Pérez'), findsOneWidget);
    expect(find.text('juan.perez@kantu.bo'), findsNWidgets(2));

    // Verificar sección Envío & Contacto
    expect(find.text('Envío & Contacto'), findsOneWidget);
    expect(find.text('+591 71234567'), findsOneWidget);
    expect(find.text('Av. Ballivián #500, Calacoto'), findsOneWidget);

    // Verificar sección Seguridad & Contraseña
    expect(find.text('Seguridad & Contraseña'), findsOneWidget);
    expect(find.text('Cambiar'), findsOneWidget);

    // Asegurar visibilidad del botón y abrir formulario de cambio de clave
    await tester.ensureVisible(find.text('Cambiar'));
    await tester.tap(find.text('Cambiar'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Actualizar Contraseña'));
    expect(find.text('Contraseña Actual'), findsOneWidget);
    expect(find.text('Nueva Contraseña'), findsOneWidget);
    expect(find.text('Confirmar Nueva Contraseña'), findsOneWidget);
    expect(find.text('Actualizar Contraseña'), findsOneWidget);
  });
}
