import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/services/auth_service.dart';
import '../shared/custom_button.dart';
import '../shared/custom_text_field.dart';
import '../shared/kantu_app_bar.dart';
import 'password_reset_confirm_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String? initialEmail;

  const ForgotPasswordScreen({super.key, this.initialEmail});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  bool _enviado = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final authService = context.read<AuthService>();
    final ok = await authService.solicitarRecuperacionPassword(_emailController.text.trim());

    if (!mounted) return;

    if (ok) {
      setState(() => _enviado = true);
    } else {
      final error = authService.errorMessage ?? 'No se pudo enviar la solicitud.';
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

    return Scaffold(
      backgroundColor: KantuColors.background,
      appBar: const KantuAppBar(
        title: 'Recuperar Contraseña',
        showBackButton: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _enviado ? _buildEnviadoView() : _buildFormView(authService),
        ),
      ),
    );
  }

  Widget _buildFormView(AuthService authService) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: KantuColors.primaryLight,
                shape: BoxShape.circle,
                border: Border.all(color: KantuColors.primary.withAlpha(30)),
              ),
              child: const Icon(
                Icons.lock_reset_rounded,
                size: 38,
                color: KantuColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '¿Olvidaste tu contraseña?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: KantuColors.textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ingresa el correo electrónico asociado a tu cuenta de Kantu Market. '
            'Te enviaremos un enlace seguro y un código de verificación para que puedas definir una nueva contraseña.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: KantuColors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 28),

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
                  label: 'Correo Electrónico',
                  hint: 'ejemplo@correo.com',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: const Icon(Icons.email_outlined, size: 20, color: KantuColors.textMuted),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'El correo es obligatorio';
                    }
                    if (!val.contains('@') || !val.contains('.')) {
                      return 'Ingresa un correo electrónico válido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                CustomButton(
                  text: 'Enviar Código de Recuperación',
                  icon: Icons.send_rounded,
                  isLoading: authService.isLoading,
                  onPressed: _handleSubmit,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PasswordResetConfirmScreen(
                    initialEmail: _emailController.text.trim(),
                  ),
                ),
              );
            },
            child: const Text(
              '¿Ya recibiste un código o enlace? Ingresa aquí',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: KantuColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnviadoView() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: KantuColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: KantuColors.successLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mark_email_read_outlined,
              size: 34,
              color: KantuColors.success,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '¡Solicitud Enviada!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: KantuColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Si ${_emailController.text.trim()} está registrado en Kantu Market, recibirás un correo con las instrucciones y el código de verificación.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: KantuColors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),

          CustomButton(
            text: 'Ingresar Código de Verificación',
            icon: Icons.arrow_forward_rounded,
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => PasswordResetConfirmScreen(
                    initialEmail: _emailController.text.trim(),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),

          TextButton(
            onPressed: () => setState(() => _enviado = false),
            child: const Text(
              'Intentar con otro correo',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: KantuColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
