import '../../core/services/push_notification_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/cart_service.dart';
import '../admin/auditoria_screen.dart';
import '../admin/dashboard_admin_screen.dart';
import '../admin/usuarios_management_screen.dart';
import '../cliente/cart_screen.dart';
import '../cliente/home_cliente_screen.dart';
import '../cliente/pedidos_screen.dart';
import '../empresa/dashboard_empresa_screen.dart';
import '../empresa/tiendas_empresa_screen.dart';
import '../profile/profile_screen.dart';

/// Da acceso al shell desde cualquier pantalla de una pestaÃ±a, para poder
/// saltar a otra (p. ej. el carrito vacÃ­o que invita a volver al catÃ¡logo).
class HomeShellScope extends InheritedWidget {
  final int indice;
  final void Function(int) irATab;

  const HomeShellScope({
    super.key,
    required this.indice,
    required this.irATab,
    required super.child,
  });

  static HomeShellScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HomeShellScope>();

  @override
  bool updateShouldNotify(HomeShellScope oldWidget) => oldWidget.indice != indice;
}

class _Pestania {
  final String etiqueta;
  final IconData icono;
  final IconData iconoActivo;
  final Widget pantalla;

  const _Pestania({
    required this.etiqueta,
    required this.icono,
    required this.iconoActivo,
    required this.pantalla,
  });
}

/// Contenedor principal tras el login. Las pestaÃ±as dependen del rol, igual que
/// el routing por rol del frontend Angular (`cliente` â†’ inicio, `empresa` â†’
/// tiendas, `administrador` â†’ dashboard).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _indice = 0;

  @override
  void initState() {
    super.initState();
    PushNotificationService.tabChangeNotifier.addListener(_onTabChangeRequested);
  }

  @override
  void dispose() {
    PushNotificationService.tabChangeNotifier.removeListener(_onTabChangeRequested);
    super.dispose();
  }

  void _onTabChangeRequested() {
    final nuevoIndice = PushNotificationService.tabChangeNotifier.value;
    if (nuevoIndice != null && mounted) {
      setState(() => _indice = nuevoIndice);
    }
  }

  /// PestaÃ±as por rol:
  /// - empresa â†’ panel (CU-10), tiendas y su catÃ¡logo (CU-08 y CU-09), ventas
  /// - cliente â†’ vitrina y carrito (CU-11), pedidos
  /// - administrador â†’ mÃ©tricas, usuarios y auditorÃ­a (CU-07)
  List<_Pestania> _pestanias(String rol) {
    switch (rol) {
      case 'empresa':
        return const [
          _Pestania(
            etiqueta: 'Panel',
            icono: Icons.insights_outlined,
            iconoActivo: Icons.insights,
            pantalla: DashboardEmpresaScreen(),
          ),
          _Pestania(
            etiqueta: 'Tiendas',
            icono: Icons.storefront_outlined,
            iconoActivo: Icons.storefront,
            pantalla: TiendasEmpresaScreen(),
          ),
          _Pestania(
            etiqueta: 'Pedidos',
            icono: Icons.receipt_long_outlined,
            iconoActivo: Icons.receipt_long,
            pantalla: PedidosScreen(modoEmpresa: true),
          ),
          _Pestania(
            etiqueta: 'Perfil',
            icono: Icons.person_outline,
            iconoActivo: Icons.person,
            pantalla: ProfileScreen(),
          ),
        ];

      case 'administrador':
        return const [
          _Pestania(
            etiqueta: 'Panel',
            icono: Icons.dashboard_outlined,
            iconoActivo: Icons.dashboard,
            pantalla: DashboardAdminScreen(),
          ),
          _Pestania(
            etiqueta: 'Usuarios',
            icono: Icons.group_outlined,
            iconoActivo: Icons.group,
            pantalla: UsuariosManagementScreen(),
          ),
          _Pestania(
            etiqueta: 'AuditorÃ­a',
            icono: Icons.fact_check_outlined,
            iconoActivo: Icons.fact_check,
            pantalla: AuditoriaScreen(),
          ),
          _Pestania(
            etiqueta: 'Perfil',
            icono: Icons.person_outline,
            iconoActivo: Icons.person,
            pantalla: ProfileScreen(),
          ),
        ];

      default:
        return const [
          _Pestania(
            etiqueta: 'Inicio',
            icono: Icons.home_outlined,
            iconoActivo: Icons.home,
            pantalla: HomeClienteScreen(),
          ),
          _Pestania(
            etiqueta: 'Carrito',
            icono: Icons.shopping_bag_outlined,
            iconoActivo: Icons.shopping_bag,
            pantalla: CartScreen(),
          ),
          _Pestania(
            etiqueta: 'Pedidos',
            icono: Icons.receipt_long_outlined,
            iconoActivo: Icons.receipt_long,
            pantalla: PedidosScreen(),
          ),
          _Pestania(
            etiqueta: 'Perfil',
            icono: Icons.person_outline,
            iconoActivo: Icons.person,
            pantalla: ProfileScreen(),
          ),
        ];
    }
  }

  void _irATab(int indice) {
    if (indice == _indice) return;
    setState(() => _indice = indice);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final rol = auth.currentUser?.rol ?? 'cliente';
    final pestanias = _pestanias(rol);

    // Cambiar de rol (cerrar sesiÃ³n y entrar con otra cuenta) puede dejar el
    // Ã­ndice fuera de rango si el rol nuevo tiene menos pestaÃ±as.
    final indiceValido = _indice.clamp(0, pestanias.length - 1);

    return HomeShellScope(
      indice: indiceValido,
      irATab: _irATab,
      child: Scaffold(
        backgroundColor: KantuColors.background,
        body: IndexedStack(
          index: indiceValido,
          children: [for (final p in pestanias) p.pantalla],
        ),
        bottomNavigationBar: _BarraInferior(
          indice: indiceValido,
          pestanias: pestanias,
          esCliente: rol != 'empresa' && rol != 'administrador',
          onTap: _irATab,
        ),
      ),
    );
  }
}

class _BarraInferior extends StatelessWidget {
  final int indice;
  final List<_Pestania> pestanias;
  final bool esCliente;
  final void Function(int) onTap;

  const _BarraInferior({
    required this.indice,
    required this.pestanias,
    required this.esCliente,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // SÃ³lo el cliente tiene pestaÃ±a de carrito, y es la Ãºnica con contador.
    final cantidadCarrito = esCliente ? context.watch<CartService>().itemCount : 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: Colors.white,
            indicatorColor: KantuColors.primaryLight,
            labelTextStyle: WidgetStateProperty.resolveWith(
              (estados) => TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: estados.contains(WidgetState.selected)
                    ? KantuColors.primary
                    : KantuColors.textSecondary,
              ),
            ),
          ),
          child: NavigationBar(
            height: 64,
            selectedIndex: indice,
            onDestinationSelected: onTap,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              for (var i = 0; i < pestanias.length; i++)
                NavigationDestination(
                  icon: _ConBadge(
                    cantidad: esCliente && pestanias[i].etiqueta == 'Carrito' ? cantidadCarrito : 0,
                    child: Icon(pestanias[i].icono, color: KantuColors.textSecondary),
                  ),
                  selectedIcon: _ConBadge(
                    cantidad: esCliente && pestanias[i].etiqueta == 'Carrito' ? cantidadCarrito : 0,
                    child: Icon(pestanias[i].iconoActivo, color: KantuColors.primary),
                  ),
                  label: pestanias[i].etiqueta,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConBadge extends StatelessWidget {
  final int cantidad;
  final Widget child;

  const _ConBadge({required this.cantidad, required this.child});

  @override
  Widget build(BuildContext context) {
    if (cantidad <= 0) return child;

    return Badge.count(
      count: cantidad,
      backgroundColor: KantuColors.primary,
      textColor: Colors.white,
      child: child,
    );
  }
}
