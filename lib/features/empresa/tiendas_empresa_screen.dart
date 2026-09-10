import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/models/tienda.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/tienda_service.dart';
import '../shared/kantu_app_bar.dart';
import 'create_tienda_dialog.dart';
import 'tienda_detail_screen.dart';

/// Pestaña "Tiendas" del panel de la empresa: lista las tiendas del propietario
/// y es la puerta de entrada al catálogo de cada una (CU-08 y CU-09).
class TiendasEmpresaScreen extends StatefulWidget {
  const TiendasEmpresaScreen({super.key});

  @override
  State<TiendasEmpresaScreen> createState() => _TiendasEmpresaScreenState();
}

class _TiendasEmpresaScreenState extends State<TiendasEmpresaScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthService>().currentUser;
      context.read<TiendaService>().loadTiendas(usuario: user);
    });
  }

  static Color parseColor(String hex) {
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
      appBar: const KantuAppBar(title: 'Mis Tiendas', showBackButton: false),
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
        color: KantuColors.primary,
        onRefresh: () => tiendaService.loadTiendas(usuario: auth.currentUser),
        child: tiendaService.isLoading && tiendaService.tiendas.isEmpty
            ? const Center(child: CircularProgressIndicator(color: KantuColors.primary))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Tiendas Online',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: KantuColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${tiendaService.tiendas.length} registradas',
                        style: const TextStyle(fontSize: 12, color: KantuColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Toca una tienda para gestionar su catálogo de productos.',
                    style: TextStyle(fontSize: 12, color: KantuColors.textSecondary),
                  ),
                  const SizedBox(height: 16),

                  if (tiendaService.tiendas.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: KantuColors.border),
                      ),
                      // Una lista vacía porque el servidor falló no es lo
                      // mismo que una cuenta sin tiendas, y confundirlas hacía
                      // creer a la empresa que había perdido las suyas.
                      child: Column(
                        children: [
                          Text(
                            tiendaService.errorMessage != null ? '📡' : '🏢',
                            style: const TextStyle(fontSize: 48),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            tiendaService.errorMessage != null
                                ? 'No se pudieron cargar tus tiendas'
                                : 'No tienes ninguna tienda registrada',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tiendaService.errorMessage ??
                                'Crea tu primera tienda con el botón "Nueva Tienda".',
                            style: const TextStyle(
                                fontSize: 13, color: KantuColors.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else
                    for (final tienda in tiendaService.tiendas)
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

/// Tarjeta de tienda reutilizada por la pestaña de tiendas y por el panel.
class TarjetaTienda extends StatelessWidget {
  final Tienda tienda;

  const TarjetaTienda({super.key, required this.tienda});

  @override
  Widget build(BuildContext context) {
    final storeColor = _TiendasEmpresaScreenState.parseColor(tienda.colorPrimario);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TiendaDetailScreen(tienda: tienda)),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: KantuColors.border),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 8, offset: const Offset(0, 2)),
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
              child: Center(child: Text('🏢', style: TextStyle(fontSize: 24, color: storeColor))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tienda.nombre,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: KantuColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'kantu.bo/@${tienda.slug}',
                    style: TextStyle(fontSize: 12, color: storeColor, fontWeight: FontWeight.w600),
                  ),
                  if (tienda.descripcion.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      tienda.descripcion,
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
  }
}
