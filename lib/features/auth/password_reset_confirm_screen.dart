import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/services/auth_service.dart';
import '../shared/custom_button.dart';
import '../shared/custom_text_field.dart';
import '../shared/kantu_app_bar.dart';
import 'login_screen.dart';

class PasswordResetConfirmScreen extends StatefulWidget {
  final String? initialEmail;
  final String? initialToken;
  final String? initialUid;

  const PasswordResetConfirmScreen({
    super.key,
    this.initialEmail,
    this.initialToken,
    this.initialUid,
  });

  @override
  State<PasswordResetConfirmScreen> createState() => _PasswordResetConfirmScreenState();
}

class _PasswordResetConfirmScreenState extends State<PasswordResetConfirmScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _tokenController;
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureNewPass = true;
  bool _obscureConfirmPass = true;

  @override
  void initState() {
    super.initState();
    _tokenController = TextEditingController(text: widget.initialToken ?? '');
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleConfirm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Las contraseñas no coinciden.'),
          backgroundColor: KantuColors.error,
        ),
      );
      return;
    }

    final authService = context.read<AuthService>();
    final ok = await authService.confirmarResetPassword(
      tokenOEnlace: _tokenController.text.trim(),
      nuevaPassword: _newPasswordController.text,
      uid: widget.initialUid,
    );

    if (!mounted) return;

    if (ok) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: KantuColors.success, size: 28),
              SizedBox(width: 10),
              Text('¡Contraseña Actualizada!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ],
          ),
          content: const Text(
            'Tu contraseña ha sido restablecida exitosamente. Ya puedes iniciar sesión con tus nuevas credenciales.',
            style: TextStyle(fontSize: 13, color: KantuColors.textSecondary, height: 1.4),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: KantuColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
              child: const Text('Iniciar Sesión', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    } else {
      final error = authService.errorMessage ?? 'No se pudo restablecer la contraseña.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: KantuColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final pass = _newPasswordController.text;
    final complexity = AuthService.checkPasswordComplexity(pass);

    return Scaffold(
      backgroundColor: KantuColors.background,
      appBar: const KantuAppBar(
        title: 'Nueva Contraseña',
        showBackButton: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                const Text(
                  'Define tu nueva contraseña',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: KantuColors.textPrimary,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Pega el código de verificación o el enlace completo recibido en tu correo electrónico.',
                  style: TextStyle(
                    fontSize: 13,
                    color: KantuColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: KantuColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(5),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomTextField(
                        label: 'Código o Enlace de Verificación',
                        hint: 'Pega aquí el código o enlace recibido',
                        controller: _tokenController,
                        prefixIcon: const Icon(Icons.key_rounded, size: 20, color: KantuColors.textMuted),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Debes ingresar el código o token';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      CustomTextField(
                        label: 'Nueva Contraseña',
                        hint: '••••••••',
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
                        onChanged: (_) => setState(() {}),
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'La contraseña es obligatoria';
                          if (!AuthService.isPasswordValid(val)) {
                            return 'La contraseña no cumple con los requisitos';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      CustomTextField(
                        label: 'Confirmar Nueva Contraseña',
                        hint: '••••••••',
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPass,
                        prefixIcon: const Icon(Icons.lock_outline, size: 20, color: KantuColors.textMuted),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            size: 20,
                            color: KantuColors.textMuted,
                          ),
                          onPressed: () => setState(() => _obscureConfirmPass = !_obscureConfirmPass),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Confirma tu contraseña';
                          if (val != _newPasswordController.text) {
                            return 'Las contraseñas no coinciden';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),

                      // Requisitos de seguridad interactivos
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: KantuColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: KantuColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Requisitos de seguridad:',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            _ReglaPassword(cumplida: complexity['minLength']!, texto: 'Mínimo 8 caracteres'),
                            _ReglaPassword(cumplida: complexity['hasLetter']!, texto: 'Al menos una letra'),
                            _ReglaPassword(cumplida: complexity['hasNumber']!, texto: 'Al menos un número'),
                            _ReglaPassword(cumplida: complexity['hasSpecial']!, texto: 'Al menos un carácter especial (@, #, \$, etc.)'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),

                      CustomButton(
                        text: 'Restablecer Contraseña',
                        icon: Icons.check_circle_outline,
                        isLoading: authService.isLoading,
                        onPressed: _handleConfirm,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReglaPassword extends StatelessWidget {
  final bool cumplida;
  final String texto;

  const _ReglaPassword({required this.cumplida, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            cumplida ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 14,
            color: cumplida ? KantuColors.success : KantuColors.textMuted,
          ),
          const SizedBox(width: 6),
          Text(
            texto,
            style: TextStyle(
              fontSize: 11.5,
              color: cumplida ? KantuColors.textPrimary : KantuColors.textSecondary,
              fontWeight: cumplida ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
