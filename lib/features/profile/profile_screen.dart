import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/services/auth_service.dart';
import '../shared/custom_button.dart';
import '../shared/custom_text_field.dart';
import '../shared/kantu_app_bar.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthService>().currentUser;
    if (user != null) {
      _firstNameController.text = user.firstName;
      _lastNameController.text = user.lastName;
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final authService = context.read<AuthService>();
    final success = await authService.updatePerfil(
      _firstNameController.text.trim(),
      _lastNameController.text.trim(),
    );

    if (success && mounted) {
      setState(() => _isEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Perfil actualizado exitosamente'),
          backgroundColor: KantuColors.success,
        ),
      );
    }
  }

  void _showLogoutDialog(BuildContext context, AuthService authService) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cerrar Sesión', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('¿Estás seguro de que deseas salir de tu cuenta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: KantuColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: KantuColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final nav = Navigator.of(context);
              await authService.logout();
              nav.pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('Salir', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final user = authService.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('No has iniciado sesión')));
    }

    return Scaffold(
      backgroundColor: KantuColors.background,
      appBar: KantuAppBar(
        title: 'Mi Cuenta & Perfil',
        showBackButton: false,
        actions: [
          IconButton(
            tooltip: 'Cerrar Sesión',
            icon: const Icon(Icons.logout, color: KantuColors.error),
            onPressed: () => _showLogoutDialog(context, authService),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // User Avatar Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: KantuColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(5),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: KantuColors.primaryLight,
                    child: Text(
                      user.initials,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: KantuColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.fullName.isNotEmpty ? user.fullName : 'Usuario Kantu',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: KantuColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.email,
                          style: const TextStyle(fontSize: 13, color: KantuColors.textSecondary),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: user.rol == 'administrador'
                                ? KantuColors.primaryLight
                                : user.rol == 'empresa'
                                    ? KantuColors.accentLight
                                    : KantuColors.successLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Rol: ${user.rol.toUpperCase()}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: user.rol == 'administrador'
                                  ? KantuColors.primary
                                  : user.rol == 'empresa'
                                      ? KantuColors.accentDark
                                      : KantuColors.success,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Form de Edición (CU04)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: KantuColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(5),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Datos Personales',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: KantuColors.textPrimary),
                      ),
                      TextButton.icon(
                        icon: Icon(_isEditing ? Icons.close : Icons.edit, size: 16),
                        label: Text(_isEditing ? 'Cancelar' : 'Editar'),
                        style: TextButton.styleFrom(foregroundColor: KantuColors.primary),
                        onPressed: () {
                          setState(() {
                            _isEditing = !_isEditing;
                            if (!_isEditing) {
                              _firstNameController.text = user.firstName;
                              _lastNameController.text = user.lastName;
                            }
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  CustomTextField(
                    label: 'Nombre',
                    controller: _firstNameController,
                    readOnly: !_isEditing,
                  ),
                  const SizedBox(height: 12),

                  CustomTextField(
                    label: 'Apellido',
                    controller: _lastNameController,
                    readOnly: !_isEditing,
                  ),
                  const SizedBox(height: 12),

                  CustomTextField(
                    label: 'Correo Electrónico',
                    hint: user.email,
                    readOnly: true,
                  ),

                  if (_isEditing) ...[
                    const SizedBox(height: 20),
                    CustomButton(
                      text: 'Guardar Cambios',
                      isLoading: authService.isLoading,
                      onPressed: _handleSave,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Botón de Cerrar Sesión (CU03)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: KantuColors.border),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: KantuColors.error.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.logout, color: KantuColors.error, size: 20),
                ),
                title: const Text('Cerrar Sesión', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: KantuColors.error)),
                subtitle: const Text('Salir de la cuenta en este dispositivo', style: TextStyle(fontSize: 12, color: KantuColors.textSecondary)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: KantuColors.textMuted),
                onTap: () => _showLogoutDialog(context, authService),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
