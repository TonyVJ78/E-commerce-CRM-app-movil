import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/database/db_helper.dart';
import '../../core/models/bitacora.dart';
import '../shared/kantu_app_bar.dart';

class AuditoriaScreen extends StatefulWidget {
  const AuditoriaScreen({super.key});

  @override
  State<AuditoriaScreen> createState() => _AuditoriaScreenState();
}

class _AuditoriaScreenState extends State<AuditoriaScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<BitacoraAcceso> _bitacora = [];
  List<LogAuditoria> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final bit = await DatabaseHelper.instance.getBitacora();
    final log = await DatabaseHelper.instance.getLogsAuditoria();
    setState(() {
      _bitacora = bit;
      _logs = log;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KantuColors.background,
      appBar: KantuAppBar(
        title: 'Auditoría & Bitácora',
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: KantuColors.primary,
              unselectedLabelColor: KantuColors.textSecondary,
              indicatorColor: KantuColors.primary,
              tabs: const [
                Tab(icon: Icon(Icons.history, size: 18), text: 'Bitácora de Acceso'),
                Tab(icon: Icon(Icons.security, size: 18), text: 'Logs de Auditoría'),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: KantuColors.primary))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // Tab 1: Bitácora
                      _bitacora.isEmpty
                          ? const Center(child: Text('No hay registros en bitácora'))
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: _bitacora.length,
                              separatorBuilder: (_, index) => const SizedBox(height: 10),
                              itemBuilder: (ctx, idx) {
                                final b = _bitacora[idx];
                                return Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: KantuColors.border),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: KantuColors.successLight,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(Icons.login, size: 20, color: KantuColors.success),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(b.usuarioEmail, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                                            const SizedBox(height: 2),
                                            Text('IP: ${b.ip} • Dispositivo: ${b.dispositivo}', style: const TextStyle(fontSize: 11, color: KantuColors.textMuted)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),

                      // Tab 2: Logs de Auditoría
                      _logs.isEmpty
                          ? const Center(child: Text('No hay logs de auditoría'))
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: _logs.length,
                              separatorBuilder: (_, index) => const SizedBox(height: 10),
                              itemBuilder: (ctx, idx) {
                                final l = _logs[idx];
                                return Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: KantuColors.border),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: KantuColors.primaryLight,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(Icons.edit_document, size: 20, color: KantuColors.primary),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('${l.accion} en ${l.tablaAfectada} (#${l.registroId})', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                                            const SizedBox(height: 2),
                                            Text('Por: ${l.usuarioEmail}', style: const TextStyle(fontSize: 11, color: KantuColors.textMuted)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
