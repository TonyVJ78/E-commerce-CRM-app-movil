import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/services/auth_service.dart';
import '../shared/custom_button.dart';
import '../shared/custom_text_field.dart';
import '../shared/kantu_app_bar.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _selectedRole = 'cliente';
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Las contraseñas no coinciden'), backgroundColor: KantuColors.error),
      );
      return;
    }

    final authService = context.read<AuthService>();
    final success = await authService.register(
      email: _emailController.text,
      password: _passwordController.text,
      firstName: _firstNameController.text,
      lastName: _lastNameController.text,
      rol: _selectedRole,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Cuenta creada exitosamente! Ya puedes iniciar sesión.'),
          backgroundColor: KantuColors.success,
        ),
      );
      Navigator.pop(context);
    }
  }

  Widget _buildRequirementItem(String label, bool met) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 14,
            color: met ? KantuColors.success : KantuColors.textMuted,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: met ? KantuColors.success : KantuColors.textSecondary,
              fontWeight: met ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final passComplexity = AuthService.checkPasswordComplexity(_passwordController.text);

    return Scaffold(
      backgroundColor: KantuColors.background,
      appBar: const KantuAppBar(title: 'Registro de Usuario'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: KantuColors.border),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Crear Nueva Cuenta',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: KantuColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Únete a la plataforma de comercio digital de Bolivia',
                    style: TextStyle(fontSize: 13, color: KantuColors.textSecondary),
                  ),
                  const SizedBox(height: 20),

                  if (authService.errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, size: 18, color: KantuColors.error),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              authService.errorMessage!,
                              style: const TextStyle(fontSize: 12, color: KantuColors.error),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Role Selector
                  const Text(
                    'Tipo de Cuenta',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: KantuColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedRole = 'cliente'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _selectedRole == 'cliente' ? KantuColors.primaryLight : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _selectedRole == 'cliente' ? KantuColors.primary : KantuColors.border,
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              children: [
                                const Text('👤', style: TextStyle(fontSize: 20)),
                                const SizedBox(height: 4),
                                Text(
                                  'Cliente',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _selectedRole == 'cliente' ? KantuColors.primary : KantuColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedRole = 'empresa'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _selectedRole == 'empresa' ? KantuColors.primaryLight : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _selectedRole == 'empresa' ? KantuColors.primary : KantuColors.border,
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              children: [
                                const Text('🏢', style: TextStyle(fontSize: 20)),
                                const SizedBox(height: 4),
                                Text(
                                  'Empresa',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _selectedRole == 'empresa' ? KantuColors.primary : KantuColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: CustomTextField(
                          label: 'Nombre',
                          hint: 'Juan',
                          controller: _firstNameController,
                          validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: CustomTextField(
                          label: 'Apellido',
                          hint: 'Pérez',
                          controller: _lastNameController,
                          validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  CustomTextField(
                    label: 'Correo Electrónico',
                    hint: 'usuario@kantu.bo',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: const Icon(Icons.email_outlined, size: 20, color: KantuColors.textMuted),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'El correo es obligatorio';
                      if (!v.contains('@')) return 'Ingresa un correo válido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  CustomTextField(
                    label: 'Contraseña',
                    hint: 'Mínimo 8 caracteres',
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    prefixIcon: const Icon(Icons.lock_outline, size: 20, color: KantuColors.textMuted),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        size: 20,
                        color: KantuColors.textMuted,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'La contraseña es obligatoria';
                      if (!AuthService.isPasswordValid(v)) return 'Cumple todos los requisitos de seguridad';
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),

                  // Checklist de Complejidad en Tiempo Real
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: KantuColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: KantuColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Requisitos de contraseña:',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: KantuColors.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        _buildRequirementItem('Mínimo 8 caracteres', passComplexity['minLength']!),
                        _buildRequirementItem('Al menos una letra', passComplexity['hasLetter']!),
                        _buildRequirementItem('Al menos un número', passComplexity['hasNumber']!),
                        _buildRequirementItem('Al menos un símbolo especial (!@#\$%)', passComplexity['hasSpecial']!),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  CustomTextField(
                    label: 'Confirmar Contraseña',
                    hint: 'Repite tu contraseña',
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    prefixIcon: const Icon(Icons.lock_outline, size: 20, color: KantuColors.textMuted),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        size: 20,
                        color: KantuColors.textMuted,
                      ),
                      onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Confirma tu contraseña';
                      if (v != _passwordController.text) return 'Las contraseñas no coinciden';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  CustomButton(
                    text: 'Crear Cuenta',
                    isLoading: authService.isLoading,
                    onPressed: _handleRegister,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
