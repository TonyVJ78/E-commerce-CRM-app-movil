import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/services/auth_service.dart';
import '../auth/login_screen.dart';
import '../shared/custom_button.dart';
import '../shared/custom_text_field.dart';
import '../shared/kantu_app_bar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Datos personales (CU-04)
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  bool _isEditingPersonal = false;

  // Preferencias de envío y contacto (CU-05 / CU-19)
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isEditingDelivery = false;

  // Seguridad y contraseña (CU-05)
  final _securityFormKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isChangingPassword = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthService>();
    final user = auth.currentUser;
    if (user != null) {
      _firstNameController.text = user.firstName;
      _lastNameController.text = user.lastName;
    }
    _phoneController.text = auth.telefono ?? '';
    _addressController.text = auth.direccionEnvio ?? '';
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSavePersonal() async {
    final authService = context.read<AuthService>();
    final success = await authService.updatePerfil(
      _firstNameController.text.trim(),
      _lastNameController.text.trim(),
    );

    if (success && mounted) {
      setState(() => _isEditingPersonal = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Perfil actualizado exitosamente.'),
          backgroundColor: KantuColors.success,
        ),
      );
    }
  }

  Future<void> _handleSaveDelivery() async {
    final authService = context.read<AuthService>();
    final success = await authService.guardarPreferenciasEntrega(
      telefono: _phoneController.text.trim(),
      direccionEnvio: _addressController.text.trim(),
    );

    if (success && mounted) {
      setState(() => _isEditingDelivery = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preferencias de envío guardadas exitosamente.'),
          backgroundColor: KantuColors.success,
        ),
      );
    }
  }

  Future<void> _handleChangePassword() async {
    if (!_securityFormKey.currentState!.validate()) return;

    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Las contraseñas nuevas no coinciden.'),
          backgroundColor: KantuColors.error,
        ),
      );
      return;
    }

    final authService = context.read<AuthService>();
    final success = await authService.cambiarPassword(
      _currentPasswordController.text,
      _newPasswordController.text,
    );

    if (!mounted) return;

    if (success) {
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      setState(() => _isChangingPassword = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contraseña actualizada con éxito.'),
          backgroundColor: KantuColors.success,
        ),
      );
    } else {
      final error = authService.errorMessage ?? 'No se pudo actualizar la contraseña.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: KantuColors.error,
        ),
      );
    }
  }

  void _showLogoutDialog(BuildContext context, AuthService authService) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
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

            // Card 1: Datos Personales (CU-04)
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
                      const Row(
                        children: [
                          Icon(Icons.badge_outlined, size: 20, color: KantuColors.primary),
                          SizedBox(width: 8),
                          Text(
                            'Datos Personales',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: KantuColors.textPrimary),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        icon: Icon(_isEditingPersonal ? Icons.close : Icons.edit, size: 16),
                        label: Text(_isEditingPersonal ? 'Cancelar' : 'Editar'),
                        style: TextButton.styleFrom(foregroundColor: KantuColors.primary),
                        onPressed: () {
                          setState(() {
                            _isEditingPersonal = !_isEditingPersonal;
                            if (!_isEditingPersonal) {
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
                    readOnly: !_isEditingPersonal,
                  ),
                  const SizedBox(height: 12),

                  CustomTextField(
                    label: 'Apellido',
                    controller: _lastNameController,
                    readOnly: !_isEditingPersonal,
                  ),
                  const SizedBox(height: 12),

                  CustomTextField(
                    label: 'Correo Electrónico',
                    hint: user.email,
                    readOnly: true,
                  ),

                  if (_isEditingPersonal) ...[
                    const SizedBox(height: 20),
                    CustomButton(
                      text: 'Guardar Datos Personales',
                      isLoading: authService.isLoading,
                      onPressed: _handleSavePersonal,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Card 2: Preferencias de Contacto y Envío (CU-05 & CU-19)
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
                      const Row(
                        children: [
                          Icon(Icons.local_shipping_outlined, size: 20, color: KantuColors.primary),
                          SizedBox(width: 8),
                          Text(
                            'Envío & Contacto',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: KantuColors.textPrimary),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        icon: Icon(_isEditingDelivery ? Icons.close : Icons.edit, size: 16),
                        label: Text(_isEditingDelivery ? 'Cancelar' : 'Modificar'),
                        style: TextButton.styleFrom(foregroundColor: KantuColors.primary),
                        onPressed: () {
                          setState(() {
                            _isEditingDelivery = !_isEditingDelivery;
                            if (!_isEditingDelivery) {
                              _phoneController.text = authService.telefono ?? '';
                              _addressController.text = authService.direccionEnvio ?? '';
                            }
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Configura tu teléfono y dirección para agilizar tus compras en el carrito.',
                    style: TextStyle(fontSize: 12, color: KantuColors.textSecondary),
                  ),
                  const SizedBox(height: 14),

                  CustomTextField(
                    label: 'Teléfono o WhatsApp',
                    hint: '+591 70000000',
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    readOnly: !_isEditingDelivery,
                    prefixIcon: const Icon(Icons.phone_outlined, size: 20, color: KantuColors.textMuted),
                  ),
                  const SizedBox(height: 12),

                  CustomTextField(
                    label: 'Dirección de Envío Predeterminada',
                    hint: 'Zona, Calle, Nro. o Referencia de entrega',
                    controller: _addressController,
                    readOnly: !_isEditingDelivery,
                    prefixIcon: const Icon(Icons.location_on_outlined, size: 20, color: KantuColors.textMuted),
                  ),

                  if (_isEditingDelivery) ...[
                    const SizedBox(height: 20),
                    CustomButton(
                      text: 'Guardar Preferencias de Envío',
                      isLoading: authService.isLoading,
                      onPressed: _handleSaveDelivery,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Card 3: Seguridad y Contraseña (CU-05)
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
              child: Form(
                key: _securityFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.shield_outlined, size: 20, color: KantuColors.primary),
                            SizedBox(width: 8),
                            Text(
                              'Seguridad & Contraseña',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: KantuColors.textPrimary),
                            ),
                          ],
                        ),
                        TextButton.icon(
                          icon: Icon(_isChangingPassword ? Icons.close : Icons.lock_outline, size: 16),
                          label: Text(_isChangingPassword ? 'Cancelar' : 'Cambiar'),
                          style: TextButton.styleFrom(foregroundColor: KantuColors.primary),
                          onPressed: () {
                            setState(() {
                              _isChangingPassword = !_isChangingPassword;
                              if (!_isChangingPassword) {
                                _currentPasswordController.clear();
                                _newPasswordController.clear();
                                _confirmPasswordController.clear();
                              }
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Mantén tu cuenta protegida renovando tu contraseña periódicamente.',
                      style: TextStyle(fontSize: 12, color: KantuColors.textSecondary),
                    ),

                    if (_isChangingPassword) ...[
                      const SizedBox(height: 16),
                      CustomTextField(
                        label: 'Contraseña Actual',
                        hint: '••••••••',
                        controller: _currentPasswordController,
                        obscureText: _obscureCurrent,
                        prefixIcon: const Icon(Icons.lock_clock_outlined, size: 20, color: KantuColors.textMuted),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureCurrent ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            size: 20,
                            color: KantuColors.textMuted,
                          ),
                          onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Ingresa tu contraseña actual';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      CustomTextField(
                        label: 'Nueva Contraseña',
                        hint: '••••••••',
                        controller: _newPasswordController,
                        obscureText: _obscureNew,
                        prefixIcon: const Icon(Icons.lock_outline, size: 20, color: KantuColors.textMuted),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            size: 20,
                            color: KantuColors.textMuted,
                          ),
                          onPressed: () => setState(() => _obscureNew = !_obscureNew),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Ingresa la nueva contraseña';
                          if (!AuthService.isPasswordValid(val)) {
                            return 'Debe tener al menos 8 caracteres, números y símbolos';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      CustomTextField(
                        label: 'Confirmar Nueva Contraseña',
                        hint: '••••••••',
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirm,
                        prefixIcon: const Icon(Icons.lock_outline, size: 20, color: KantuColors.textMuted),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            size: 20,
                            color: KantuColors.textMuted,
                          ),
                          onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Confirma tu contraseña';
                          if (val != _newPasswordController.text) {
                            return 'Las contraseñas no coinciden';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      CustomButton(
                        text: 'Actualizar Contraseña',
                        icon: Icons.check_circle_outline,
                        isLoading: authService.isLoading,
                        onPressed: _handleChangePassword,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Card 4: Botón de Cerrar Sesión (CU-03)
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
