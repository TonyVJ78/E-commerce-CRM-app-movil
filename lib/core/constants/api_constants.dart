class ApiConstants {
  // URLs por defecto: el puerto 8000 de `python manage.py runserver`.
  // Es sólo el valor inicial; cada quien ajusta la suya en Perfil → Ajustes y
  // queda guardada en el dispositivo.
  static const String defaultEmulatorUrl = 'http://10.0.2.2:8000/api';
  static const String defaultLocalhostUrl = 'http://127.0.0.1:8000/api';

  // --- Autenticación (CU-01 a CU-05) ---
  static const String login = '/auth/login/';
  static const String registro = '/auth/registro/';
  static const String logout = '/auth/logout/';
  static const String tokenRefresh = '/auth/token/refresh/';
  static const String perfil = '/auth/perfil/';
  static const String passwordReset = '/auth/password-reset/';
  static const String passwordResetConfirm = '/auth/password-reset-confirm/';

  // --- Tiendas (CU-06) y panel del vendedor (CU-10) ---
  static const String tiendas = '/tiendas/';
  static const String dashboardVendedor = '/tiendas/dashboard/';

  // --- Catálogo de la empresa (CU-08 y CU-09) ---
  static String categoriasTienda(int tiendaId) => '/tiendas/$tiendaId/categorias/';
  static String productosTienda(int tiendaId) => '/tiendas/$tiendaId/productos/';
  static String productoDetalle(int tiendaId, int productoId) =>
      '/tiendas/$tiendaId/productos/$productoId/';

  // --- Catálogo público del cliente (CU-11) ---
  static const String catalogoProductos = '/catalogo/productos/';
  static const String catalogoCategorias = '/catalogo/categorias/';

  // --- Carrito (CU-11) ---
  static const String carrito = '/pedidos/carrito/';
  static const String carritoItems = '/pedidos/carrito/items/';
  static String carritoItemDetalle(int itemId) => '/pedidos/carrito/items/$itemId/';
}
