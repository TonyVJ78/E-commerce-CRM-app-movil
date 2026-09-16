class ApiConstants {
  /// URL del backend fijada **al compilar**, para repartir un APK que ya sabe
  /// a qué servidor hablar sin que nadie toque Ajustes:
  ///
  ///   flutter build apk --release --dart-define=API_BASE_URL=https://tu-servidor/api
  ///
  /// Por defecto apunta a la API en producción en Vercel.
  static const String buildBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://kantumarket.vercel.app/api',
  );

  /// El despliegue del proyecto: la misma base de datos que ve la web.
  /// Es el único servidor al que apunta la app mientras no se compile con otro.
  static const String apiProduccion = 'https://kantumarket.vercel.app/api';

  /// URL con la que arranca una instalación nueva.
  static String get urlInicial =>
      buildBaseUrl.isNotEmpty ? buildBaseUrl : apiProduccion;

  /// Un APK compilado con `API_BASE_URL` arranca ya en modo servidor: es la
  /// diferencia entre "abre y muestra los datos reales" y "abre con la base
  /// local y las cuentas del equipo no entran".
  static bool get onlinePorDefecto => buildBaseUrl.isNotEmpty;

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

  /// Tiendas activas para el filtro de la vitrina. Es `AllowAny`, así que
  /// también sirve de sonda para comprobar si el servidor está vivo.
  static const String catalogoTiendas = '/catalogo/tiendas/';

  // --- Carrito (CU-11) y checkout con pasarela de pagos (CU-19) ---
  static const String carrito = '/pedidos/carrito/';
  static const String carritoItems = '/pedidos/carrito/items/';
  static String carritoItemDetalle(int itemId) => '/pedidos/carrito/items/$itemId/';
  static const String carritoCheckout = '/pedidos/carrito/checkout/';
  static const String carritoPagoIntento = '/pedidos/carrito/pago-intento/';
}
