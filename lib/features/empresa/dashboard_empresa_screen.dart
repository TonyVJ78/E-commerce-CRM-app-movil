import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/tienda_service.dart';
import '../shared/kantu_app_bar.dart';
import '../shared/stat_card.dart';
import 'create_tienda_dialog.dart';
import 'tienda_detail_screen.dart';
import '../profile/profile_screen.dart';

class DashboardEmpresaScreen extends StatefulWidget {
  const DashboardEmpresaScreen({super.key});

  @override
  State<DashboardEmpresaScreen> createState() => _DashboardEmpresaScreenState();
}

class _DashboardEmpresaScreenState extends State<DashboardEmpresaScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthService>().currentUser;
      context.read<TiendaService>().loadTiendas(usuario: user);
    });
  }

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return KantuColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final tiendaService = context.watch<TiendaService>();

    return Scaffold(
      backgroundColor: KantuColors.background,
      appBar: KantuAppBar(
        title: 'Panel Empresa',
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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: KantuColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_business),
        label: const Text('Nueva Tienda', style: TextStyle(fontWeight: FontWeight.w700)),
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const CreateTiendaDialog(),
          );
        },
      ),
      body: RefreshIndicator(
        onRefresh: () => tiendaService.loadTiendas(usuario: auth.currentUser),
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
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(20),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '🏢 Módulo Empresa Multitenant',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Bienvenido, ${auth.currentUser?.firstName ?? "Empresario"}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Gestiona tus tiendas online, catálogo de productos y ventas.',
                      style: TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Stats Grid
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      title: 'Mis Tiendas',
                      value: '${tiendaService.tiendas.length}',
                      icon: Icons.storefront,
                      color: KantuColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: StatCard(
                      title: 'Estado SaaS',
                      value: 'Activo',
                      icon: Icons.check_circle_outline,
                      color: KantuColors.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Tiendas Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Mis Tiendas Online',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: KantuColors.textPrimary),
                  ),
                  Text(
                    '${tiendaService.tiendas.length} registradas',
                    style: const TextStyle(fontSize: 12, color: KantuColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (tiendaService.isLoading)
                const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
              else if (tiendaService.tiendas.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: KantuColors.border),
                  ),
                  child: Column(
                    children: [
                      const Text('🏢', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 12),
                      const Text('No tienes ninguna tienda registrada', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      const Text('Crea tu primera tienda con el botón "Nueva Tienda".', style: TextStyle(fontSize: 13, color: KantuColors.textSecondary)),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: tiendaService.tiendas.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 12),
                  itemBuilder: (ctx, idx) {
                    final t = tiendaService.tiendas[idx];
                    final storeColor = _parseColor(t.colorPrimario);
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => TiendaDetailScreen(tienda: t)),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: KantuColors.border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(5),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: storeColor.withAlpha(25),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text('🏢', style: TextStyle(fontSize: 24, color: storeColor)),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t.nombre,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: KantuColors.textPrimary),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'kantu.bo/@${t.slug}',
                                    style: TextStyle(fontSize: 12, color: storeColor, fontWeight: FontWeight.w600),
                                  ),
                                  if (t.descripcion.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      t.descripcion,
                                      style: const TextStyle(fontSize: 12, color: KantuColors.textSecondary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios, size: 16, color: KantuColors.textMuted),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
