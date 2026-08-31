import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/database/db_helper.dart';
import '../../core/models/usuario.dart';
import '../shared/kantu_app_bar.dart';

class UsuariosManagementScreen extends StatefulWidget {
  const UsuariosManagementScreen({super.key});

  @override
  State<UsuariosManagementScreen> createState() => _UsuariosManagementScreenState();
}

class _UsuariosManagementScreenState extends State<UsuariosManagementScreen> {
  List<Usuario> _usuarios = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsuarios();
  }

  Future<void> _loadUsuarios() async {
    setState(() => _isLoading = true);
    final users = await DatabaseHelper.instance.getAllUsuarios();
    setState(() {
      _usuarios = users;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KantuColors.background,
      appBar: const KantuAppBar(title: 'Gestión de Usuarios'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: KantuColors.primary))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _usuarios.length,
              separatorBuilder: (_, index) => const SizedBox(height: 12),
              itemBuilder: (ctx, idx) {
                final u = _usuarios[idx];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: KantuColors.border),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: u.rol == 'administrador'
                            ? KantuColors.primaryLight
                            : u.rol == 'empresa'
                                ? KantuColors.accentLight
                                : KantuColors.successLight,
                        child: Text(
                          u.initials,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: u.rol == 'administrador'
                                ? KantuColors.primary
                                : u.rol == 'empresa'
                                    ? KantuColors.accentDark
                                    : KantuColors.success,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              u.fullName.isNotEmpty ? u.fullName : u.email,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(u.email, style: const TextStyle(fontSize: 12, color: KantuColors.textSecondary)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: u.rol == 'administrador'
                              ? KantuColors.primaryLight
                              : u.rol == 'empresa'
                                  ? KantuColors.accentLight
                                  : KantuColors.successLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          u.rol.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: u.rol == 'administrador'
                                ? KantuColors.primary
                                : u.rol == 'empresa'
                                    ? KantuColors.accentDark
                                    : KantuColors.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
