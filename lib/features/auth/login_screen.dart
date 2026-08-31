import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/services/auth_service.dart';
import '../shared/custom_button.dart';
import '../shared/custom_text_field.dart';
import 'register_screen.dart';
import 'password_recovery_screen.dart';
import '../profile/profile_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _navigateToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    final authService = context.read<AuthService>();
    final success = await authService.login(
      _emailController.text,
      _passwordController.text,
    );

    if (success && mounted) {
      _navigateToHome();
    }
  }

  Future<void> _quickLogin(String role) async {
    final authService = context.read<AuthService>();
    await authService.loginQuickDemo(role);
    if (mounted && authService.isAuthenticated) {
      _navigateToHome();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    return Scaffold(
      backgroundColor: KantuColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo & Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: KantuColors.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Text('🛍️', style: TextStyle(fontSize: 42)),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Kantu Market',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: KantuColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Mercado Digital Multitenant de Bolivia 🇧🇴',
                  style: TextStyle(fontSize: 14, color: KantuColors.textSecondary),
                ),
                const SizedBox(height: 28),

                // Form Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: KantuColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(8),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Iniciar Sesión',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: KantuColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),

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

                        CustomTextField(
                          label: 'Correo Electrónico',
                          hint: 'ejemplo@kantu.bo',
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: const Icon(Icons.email_outlined, size: 20, color: KantuColors.textMuted),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'El correo es obligatorio';
                            if (!val.contains('@')) return 'Ingresa un correo válido';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        CustomTextField(
                          label: 'Contraseña',
                          hint: '••••••••',
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
                          validator: (val) {
                            if (val == null || val.isEmpty) return 'La contraseña es obligatoria';
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),

                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const PasswordRecoveryScreen()),
                              );
                            },
                            child: const Text(
                              '¿Olvidaste tu contraseña?',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: KantuColors.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        CustomButton(
                          text: 'Ingresar',
                          isLoading: authService.isLoading,
                          onPressed: _handleLogin,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Quick Demo Accounts Box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: KantuColors.accentLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: KantuColors.accent.withAlpha(100)),
                  ),
                  child: Column(
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bolt, size: 18, color: KantuColors.accentDark),
                          SizedBox(width: 6),
                          Text(
                            'Acceso Rápido Demo (1 toque)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: KantuColors.accentDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: KantuColors.textPrimary,
                                elevation: 0,
                                side: const BorderSide(color: KantuColors.border),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              onPressed: () => _quickLogin('admin'),
                              child: const Text('🛡️ Admin', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: KantuColors.textPrimary,
                                elevation: 0,
                                side: const BorderSide(color: KantuColors.border),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              onPressed: () => _quickLogin('empresa'),
                              child: const Text('🏢 Empresa', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: KantuColors.textPrimary,
                                elevation: 0,
                                side: const BorderSide(color: KantuColors.border),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              onPressed: () => _quickLogin('cliente'),
                              child: const Text('👤 Cliente', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Link to Register
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '¿No tienes una cuenta? ',
                      style: TextStyle(fontSize: 14, color: KantuColors.textSecondary),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const RegisterScreen()),
                        );
                      },
                      child: const Text(
                        'Regístrate aquí',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: KantuColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
