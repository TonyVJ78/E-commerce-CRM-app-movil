import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants/colors.dart';
import 'core/services/api_service.dart';
import 'core/services/auth_service.dart';
import 'core/services/cart_service.dart';
import 'core/services/catalogo_service.dart';
import 'core/services/dashboard_service.dart';
import 'core/services/recommendation_service.dart';
import 'core/services/tienda_service.dart';
import 'features/auth/login_screen.dart';
import 'features/shared/home_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.instance.init();

  final authService = AuthService();
  await authService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: authService),
        ChangeNotifierProvider<TiendaService>(create: (_) => TiendaService()),
        ChangeNotifierProvider<CatalogoService>(
          create: (_) => CatalogoService(),
        ),
        ChangeNotifierProvider<CartService>(create: (_) => CartService()),
        ChangeNotifierProvider<DashboardService>(
          create: (_) => DashboardService(),
        ),
        ChangeNotifierProvider<RecommendationService>(
          create: (_) => RecommendationService(),
        ),
      ],
      child: const KantuMarketApp(),
    ),
  );
}

class KantuMarketApp extends StatelessWidget {
  const KantuMarketApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kantu Market',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Inter',
        colorScheme: ColorScheme.fromSeed(
          seedColor: KantuColors.primary,
          primary: KantuColors.primary,
          secondary: KantuColors.accent,
          surface: KantuColors.surface,
        ),
        // Material 3 tiñe las superficies elevadas con el color semilla; sin
        // esto los diálogos y menús salen rosados en vez de blancos.
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: KantuColors.textPrimary,
          elevation: 0.5,
          surfaceTintColor: Colors.transparent,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        popupMenuTheme: PopupMenuThemeData(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          insetPadding: const EdgeInsets.all(16),
          contentTextStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        scaffoldBackgroundColor: KantuColors.background,
      ),
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
