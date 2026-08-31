import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/services/auth_service.dart';
import '../shared/custom_button.dart';
import '../shared/custom_text_field.dart';
import '../shared/kantu_app_bar.dart';

class PasswordRecoveryScreen extends StatefulWidget {
  const PasswordRecoveryScreen({super.key});

  @override
  State<PasswordRecoveryScreen> createState() => _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState extends State<PasswordRecoveryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureNewPass = true;
  bool _step2 = false;

  @override
  void dispose() {
    _emailController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleStep1() async {
    if (_emailController.text.trim().isEmpty || !_emailController.text.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un correo electrónico válido'), backgroundColor: KantuColors.error),
      );
      return;
    }
    setState(() => _step2 = true);
  }

  Future<void> _handleReset() async {
    if (!_formKey.currentState!.validate()) return;
    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Las contraseñas no coinciden'), backgroundColor: KantuColors.error),
      );
      return;
    }

    final authService = context.read<AuthService>();
    final success = await authService.requestPasswordReset(
      _emailController.text,
      _newPasswordController.text,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Contraseña restablecida con éxito! Ya puedes iniciar sesión.'),
          backgroundColor: KantuColors.success,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    return Scaffold(
      backgroundColor: KantuColors.background,
      appBar: const KantuAppBar(title: 'Recuperar Contraseña'),
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
                  const Text('🔑', style: TextStyle(fontSize: 36)),
                  const SizedBox(height: 12),
                  const Text(
                    'Restablecer Contraseña',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: KantuColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    !_step2
                        ? 'Ingresa el correo electrónico asociado a tu cuenta para restablecer tu acceso.'
                        : 'Ingresa tu nueva contraseña para ${_emailController.text}',
                    style: const TextStyle(fontSize: 13, color: KantuColors.textSecondary),
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

                  if (!_step2) ...[
                    CustomTextField(
                      label: 'Correo Electrónico',
                      hint: 'ejemplo@kantu.bo',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: const Icon(Icons.email_outlined, size: 20, color: KantuColors.textMuted),
                    ),
                    const SizedBox(height: 24),
                    CustomButton(
                      text: 'Continuar',
                      onPressed: _handleStep1,
                    ),
                  ] else ...[
                    CustomTextField(
                      label: 'Nueva Contraseña',
                      hint: 'Mínimo 8 caracteres',
                      controller: _newPasswordController,
                      obscureText: _obscureNewPass,
                      prefixIcon: const Icon(Icons.lock_outline, size: 20, color: KantuColors.textMuted),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureNewPass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          size: 20,
                          color: KantuColors.textMuted,
                        ),
                        onPressed: () => setState(() => _obscureNewPass = !_obscureNewPass),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'La contraseña es obligatoria';
                        if (!AuthService.isPasswordValid(v)) return 'Debe tener letras, números y símbolos';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      label: 'Confirmar Nueva Contraseña',
                      hint: 'Repite tu nueva contraseña',
                      controller: _confirmPasswordController,
                      obscureText: true,
                      prefixIcon: const Icon(Icons.lock_outline, size: 20, color: KantuColors.textMuted),
                      validator: (v) {
                        if (v != _newPasswordController.text) return 'Las contraseñas no coinciden';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    CustomButton(
                      text: 'Restablecer Contraseña',
                      isLoading: authService.isLoading,
                      onPressed: _handleReset,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
