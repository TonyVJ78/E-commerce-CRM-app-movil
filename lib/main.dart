import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/services/api_service.dart';
import 'core/services/auth_service.dart';
import 'core/services/cart_service.dart';
import 'core/services/catalogo_service.dart';
import 'core/services/dashboard_service.dart';
import 'core/services/push_notification_service.dart';
import 'core/services/recommendation_service.dart';
import 'core/services/tienda_service.dart';
import 'core/theme/dynamic_theme_provider.dart';
import 'features/auth/login_screen.dart';
import 'features/shared/home_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.instance.init();

  final authService = AuthService();
  await authService.init();

  // Inicialización de Firebase y Push Notification Service (CU-18)
  // Regla Estricta: Manejo silencioso. Si la inicialización falla (p. ej. por falta de
  // google-services.json local), se imprime el error en consola y la app arranca SIN crash.
  try {
    await Firebase.initializeApp();
    await PushNotificationService.instance.init();
  } catch (e) {
    debugPrint(
      '[FCM] Inicialización de Firebase omitida o fallida (modo offline/resiliente): $e',
    );
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: authService),
        ChangeNotifierProvider<TiendaService>(create: (_) => TiendaService()),
        ChangeNotifierProvider<CatalogoService>(create: (_) => CatalogoService()),
        ChangeNotifierProvider<CartService>(create: (_) => CartService()),
        ChangeNotifierProvider<DashboardService>(create: (_) => DashboardService()),
        ChangeNotifierProvider<RecommendationService>(create: (_) => RecommendationService()),
        ChangeNotifierProvider<DynamicThemeProvider>(create: (_) => DynamicThemeProvider()),
      ],
      child: const KantuMarketApp(),
    ),
  );
}

class KantuMarketApp extends StatelessWidget {
  const KantuMarketApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<DynamicThemeProvider?>(context);
    final theme = themeProvider?.currentTheme ?? DynamicThemeProvider().currentTheme;

    return MaterialApp(
      navigatorKey: PushNotificationService.navigatorKey,
      scaffoldMessengerKey: PushNotificationService.scaffoldMessengerKey,
      title: 'Kantu Market',
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: const AppInitializer(),
    );
  }
}

class AppInitializer extends StatelessWidget {
  const AppInitializer({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    if (auth.isAuthenticated) {
      return const HomeShell();
    }

    return const LoginScreen();
  }
}
