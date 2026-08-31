class ApiConstants {
  // URLs por defecto
  static const String defaultEmulatorUrl = 'http://10.0.2.2:8000/api';
  static const String defaultLocalhostUrl = 'http://127.0.0.1:8000/api';

  // Endpoints
  static const String login = '/auth/login/';
  static const String registro = '/auth/registro/';
  static const String logout = '/auth/logout/';
  static const String tokenRefresh = '/auth/token/refresh/';
  static const String perfil = '/auth/perfil/';
  static const String passwordReset = '/auth/password-reset/';
  static const String passwordResetConfirm = '/auth/password-reset-confirm/';
  static const String tiendas = '/tiendas/';
}
