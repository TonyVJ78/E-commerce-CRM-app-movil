import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/database/db_helper.dart';
import '../../core/services/auth_service.dart';
import '../shared/kantu_app_bar.dart';
import '../shared/stat_card.dart';
import 'usuarios_management_screen.dart';
import 'auditoria_screen.dart';
import '../profile/profile_screen.dart';

class DashboardAdminScreen extends StatefulWidget {
  const DashboardAdminScreen({super.key});

  @override
  State<DashboardAdminScreen> createState() => _DashboardAdminScreenState();
}

class _DashboardAdminScreenState extends State<DashboardAdminScreen> {
  Map<String, int> _stats = {
    'usuarios': 0,
    'tiendas': 0,
    'productos': 0,
    'pedidos': 0,
  };
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    final stats = await DatabaseHelper.instance.getAdminStats();
    setState(() {
      _stats = stats;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return Scaffold(
      backgroundColor: KantuColors.background,
      appBar: KantuAppBar(
        title: 'Panel Administrador',
        showBackButton: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline, color: KantuColors.textPrimary),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: KantuColors.primary))
          : RefreshIndicator(
              onRefresh: _loadStats,
              color: KantuColors.primary,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
              // Greeting Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF881337), Color(0xFFC8102E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: KantuColors.primary.withAlpha(50),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(30),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('🛡️', style: TextStyle(fontSize: 14)),
                          SizedBox(width: 6),
                          Text(
                            'Administración Global del Sistema',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Hola, ${auth.currentUser?.firstName ?? "Admin"}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Monitorea el estado general, usuarios y auditoría de la plataforma.',
                      style: TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Stats Grid
              const Text(
                'Métricas de la Plataforma',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: KantuColors.textPrimary),
              ),
              const SizedBox(height: 12),

              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.3,
                children: [
                  StatCard(
                    title: 'Usuarios',
                    value: '${_stats["usuarios"]}',
                    icon: Icons.people_outline,
                    color: KantuColors.info,
                  ),
                  StatCard(
                    title: 'Tiendas Activas',
                    value: '${_stats["tiendas"]}',
                    icon: Icons.storefront,
                    color: KantuColors.primary,
                  ),
                  StatCard(
                    title: 'Productos Totales',
                    value: '${_stats["productos"]}',
                    icon: Icons.inventory_2_outlined,
                    color: KantuColors.warning,
                  ),
                  StatCard(
                    title: 'Pedidos Registrados',
                    value: '${_stats["pedidos"]}',
                    icon: Icons.receipt_long_outlined,
                    color: KantuColors.success,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Quick Actions
              const Text(
                'Gestión y Auditoría',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: KantuColors.textPrimary),
              ),
              const SizedBox(height: 12),

              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: KantuColors.border),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: KantuColors.info.withAlpha(25), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.people, color: KantuColors.info),
                      ),
                      title: const Text('Gestión de Usuarios', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      subtitle: const Text('Ver lista de cuentas de clientes, empresas y administradores', style: TextStyle(fontSize: 12, color: KantuColors.textSecondary)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: KantuColors.textMuted),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const UsuariosManagementScreen()),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: KantuColors.success.withAlpha(25), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.security, color: KantuColors.success),
                      ),
                      title: const Text('Bitácora y Auditoría', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      subtitle: const Text('Historial de accesos por IP y registro de cambios en base de datos', style: TextStyle(fontSize: 12, color: KantuColors.textSecondary)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: KantuColors.textMuted),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AuditoriaScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
