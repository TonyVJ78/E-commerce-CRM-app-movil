import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/dashboard_service.dart';
import '../../core/services/tienda_service.dart';
import '../shared/home_shell.dart';
import '../shared/kantu_app_bar.dart';
import '../shared/stat_card.dart';
import '../shared/ventas_bar_chart.dart';
import 'tiendas_empresa_screen.dart';

/// CU-10 — Dashboard de gestión de tienda.
///
/// Consume `GET /api/tiendas/dashboard/` cuando hay servidor y cae al cálculo
/// equivalente sobre SQLite cuando no lo hay; la pantalla es la misma en ambos
/// casos y sólo cambia el sello de origen de los datos.
class DashboardEmpresaScreen extends StatefulWidget {
  const DashboardEmpresaScreen({super.key});

  @override
  State<DashboardEmpresaScreen> createState() => _DashboardEmpresaScreenState();
}

class _DashboardEmpresaScreenState extends State<DashboardEmpresaScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  Future<void> _cargar() async {
    final user = context.read<AuthService>().currentUser;
    await Future.wait([
      context.read<DashboardService>().loadDashboard(user),
      context.read<TiendaService>().loadTiendas(usuario: user),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final dashboard = context.watch<DashboardService>();
    final tiendaService = context.watch<TiendaService>();
    final resumen = dashboard.resumen;

    return Scaffold(
      backgroundColor: KantuColors.background,
      appBar: const KantuAppBar(title: 'Panel de Gestión', showBackButton: false),
      body: RefreshIndicator(
        color: KantuColors.primary,
        onRefresh: _cargar,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _Banner(
              nombre: auth.currentUser?.firstName ?? 'Empresario',
              tiendas: tiendaService.tiendas.length,
              desdeServidor: dashboard.desdeServidor,
            ),
            const SizedBox(height: 20),

            if (dashboard.isLoading && resumen.totalProductos == 0)
              const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
            else ...[
              if (resumen.productosBajoStock > 0) ...[
                _AlertaBajoStock(cantidad: resumen.productosBajoStock),
                const SizedBox(height: 16),
              ],

              const _TituloSeccion('Resumen de tu negocio'),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      title: 'Productos',
                      value: '${resumen.totalProductos}',
                      subtitle: '${resumen.productosActivos} activos',
                      icon: Icons.inventory_2_outlined,
                      color: KantuColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      title: 'Pedidos',
                      value: '${resumen.totalPedidos}',
                      subtitle: '${resumen.pedidosPendientes} pendientes',
                      icon: Icons.receipt_long_outlined,
                      color: KantuColors.info,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      title: 'Ingresos',
                      value: 'Bs. ${resumen.ingresosTotales.toStringAsFixed(0)}',
                      subtitle: 'Pedidos no cancelados',
                      icon: Icons.payments_outlined,
                      color: KantuColors.success,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      title: 'Bajo stock',
                      value: '${resumen.productosBajoStock}',
                      subtitle: 'Variantes a reponer',
                      icon: Icons.warning_amber_outlined,
                      color: resumen.productosBajoStock > 0
                          ? KantuColors.warning
                          : KantuColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      title: 'Mis tiendas',
                      value: '${tiendaService.tiendas.length}',
                      subtitle: 'Multitenant',
                      icon: Icons.storefront_outlined,
                      color: KantuColors.accentDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      title: 'Vendido (7 d)',
                      value: '${resumen.unidadesVendidasSemana}',
                      subtitle: 'Unidades despachadas',
                      icon: Icons.trending_up,
                      color: KantuColors.primaryDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              VentasBarChart(ventas: resumen.graficoVentas),
              const SizedBox(height: 20),
            ],

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const _TituloSeccion('Mis tiendas'),
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: KantuColors.primary),
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: const Text('Ver todas'),
                  onPressed: () => HomeShellScope.of(context)?.irATab(1),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (tiendaService.tiendas.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: KantuColors.border),
                ),
                child: Column(
                  children: [
                    const Text('🏢', style: TextStyle(fontSize: 40)),
                    const SizedBox(height: 10),
                    Text(
                      tiendaService.errorMessage != null
                          ? 'No se pudieron cargar tus tiendas'
                          : 'Aún no tienes tiendas',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tiendaService.errorMessage ??
                          'Crea una desde la pestaña Tiendas para empezar a cargar tu catálogo.',
                      style: const TextStyle(fontSize: 12, color: KantuColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: KantuColors.primary,
                        side: const BorderSide(color: KantuColors.primary),
                      ),
                      icon: const Icon(Icons.add_business, size: 18),
                      label: const Text('Ir a Tiendas'),
                      onPressed: () => HomeShellScope.of(context)?.irATab(1),
                    ),
                  ],
                ),
              )
            else
              // Sólo un adelanto: la pestaña Tiendas lleva a la lista completa
              // y desde ahí al catálogo de CU-08 y CU-09.
              for (final tienda in tiendaService.tiendas.take(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TarjetaTienda(tienda: tienda),
                ),
          ],
        ),
      ),
    );
  }
}

class _TituloSeccion extends StatelessWidget {
  final String texto;

  const _TituloSeccion(this.texto);

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: KantuColors.textPrimary,
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final String nombre;
  final int tiendas;
  final bool desdeServidor;

  const _Banner({
    required this.nombre,
    required this.tiendas,
    required this.desdeServidor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Row(
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
              const Spacer(),
              // Deja claro si los números vienen del servidor o de este teléfono.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (desdeServidor ? KantuColors.success : KantuColors.accent).withAlpha(40),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  desdeServidor ? 'API' : 'LOCAL',
                  style: TextStyle(
                    color: desdeServidor ? KantuColors.success : KantuColors.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Bienvenido, $nombre',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            tiendas == 0
                ? 'Crea tu primera tienda para empezar a vender.'
                : 'Gestiona tu catálogo, tu inventario y tus ventas.',
            style: const TextStyle(fontSize: 13, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _AlertaBajoStock extends StatelessWidget {
  final int cantidad;

  const _AlertaBajoStock({required this.cantidad});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: KantuColors.warning.withAlpha(25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KantuColors.warning.withAlpha(80)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: KantuColors.warning.withAlpha(40),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.inventory_outlined, size: 20, color: KantuColors.warning),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cantidad == 1
                      ? '1 variante llegó a su stock mínimo'
                      : '$cantidad variantes llegaron a su stock mínimo',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Revisa el catálogo de tus tiendas y repone inventario.',
                  style: TextStyle(fontSize: 11, color: KantuColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
