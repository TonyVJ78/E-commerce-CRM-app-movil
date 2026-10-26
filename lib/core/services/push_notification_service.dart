import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/cliente/seguimiento_pedido_sheet.dart';
import '../../features/cliente/cupones_screen.dart';
import '../../features/cliente/producto_detail_sheet.dart';
import '../models/producto.dart';
import '../constants/api_constants.dart';
import 'api_service.dart';
import 'auth_service.dart';
import 'cart_service.dart';
import 'firebase_runtime.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await FirebaseRuntime.initialize();
}

enum EstadoPush { sinConfigurar, desactivado, conectando, activo, error }

class PushNotificationService {
  static final instance = PushNotificationService._();
  PushNotificationService._();
  static final navigatorKey = GlobalKey<NavigatorState>();
  static final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  static final tabChangeNotifier = ValueNotifier<int?>(null);
  final estado = ValueNotifier(EstadoPush.sinConfigurar);
  bool _initialized = false;
  bool get isInitialized => _initialized;
  String? _fcmToken;
  String? get fcmToken => _fcmToken;
  Map<String, dynamic>? _pendiente;

  Future<void> init({GlobalKey<NavigatorState>? navKey}) async {
    if (_initialized) return;
    try {
      final m = FirebaseMessaging.instance;
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      FirebaseMessaging.onMessage.listen((message) {
        final ctx = navigatorKey.currentContext;
        final usuario = ctx?.read<AuthService>().currentUser;
        if (usuario == null ||
            usuario.rol != 'cliente' ||
            (message.data['cliente_id'] != null &&
                positivo(message.data['cliente_id']) != usuario.id)) {
          return;
        }
        final messenger = scaffoldMessengerKey.currentState;
        messenger?.showSnackBar(
          SnackBar(
            content: Text(
              message.notification?.title ??
                  'Nueva notificación de Kantu Market',
            ),
            action: SnackBarAction(
              label: 'VER',
              onPressed: () => abrirDatos(datosMensaje(message)),
            ),
          ),
        );
      });
      FirebaseMessaging.onMessageOpenedApp.listen(
        (m) => abrirDatos(datosMensaje(m)),
      );
      m.onTokenRefresh.listen((token) {
        _fcmToken = token;
        unawaited(sincronizarTokenConBackend());
      });
      final initial = await m.getInitialMessage();
      if (initial != null) _pendiente = datosMensaje(initial);
      _initialized = true;
      final settings = await m.getNotificationSettings();
      estado.value = EstadoPush.desactivado;
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        _fcmToken = await m.getToken();
        await sincronizarTokenConBackend();
      }
    } catch (_) {
      estado.value = EstadoPush.sinConfigurar;
    }
  }

  Future<void> activar() async {
    if (!_initialized) return;
    estado.value = EstadoPush.conectando;
    try {
      final m = FirebaseMessaging.instance;
      final s = await m.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (s.authorizationStatus != AuthorizationStatus.authorized &&
          s.authorizationStatus != AuthorizationStatus.provisional) {
        estado.value = EstadoPush.desactivado;
        return;
      }
      _fcmToken = await m.getToken();
      await sincronizarTokenConBackend();
    } catch (_) {
      estado.value = EstadoPush.error;
    }
  }

  Future<void> sincronizarTokenConBackend() async {
    if (_fcmToken == null) return;
    final tokenSesion = await ApiService.instance.getAccessToken();
    if (tokenSesion == null || tokenSesion.isEmpty) return;
    try {
      final r = await ApiService.instance.post(
        ApiConstants.registrarDispositivo,
        {
          'token': _fcmToken,
          'plataforma': Platform.isIOS ? 'ios' : 'android',
          'activo': true,
        },
        auth: true,
      );
      if (r.statusCode != 200) {
        estado.value = EstadoPush.error;
        return;
      }
      final data = jsonDecode(r.body);
      estado.value =
          data['registrado'] == true && data['push_disponible'] == true
          ? EstadoPush.activo
          : EstadoPush.desactivado;
    } catch (_) {
      estado.value = EstadoPush.error;
    }
  }

  Future<void> cerrarSesion() async {
    _pendiente = null;
    if (_fcmToken != null) {
      try {
        await ApiService.instance.post(ApiConstants.registrarDispositivo, {
          'token': _fcmToken,
          'plataforma': Platform.isIOS ? 'ios' : 'android',
          'activo': false,
        }, auth: true);
      } catch (_) {
        /* Delete the FCM registration even when backend is unavailable. */
      }
      try {
        await FirebaseMessaging.instance.deleteToken();
      } catch (_) {}
      _fcmToken = null;
    }
    if (_initialized) estado.value = EstadoPush.desactivado;
  }

  static Map<String, dynamic> datosMensaje(RemoteMessage message) {
    final data = Map<String, dynamic>.from(message.data);
    if (data['tipo'] == null && extraerPedidoId(data) == null) {
      final pedido =
          extraerPedidoIdDeTexto(message.notification?.title) ??
          extraerPedidoIdDeTexto(message.notification?.body);
      if (pedido != null) data.addAll({'tipo': 'pedido', 'pedido_id': pedido});
    }
    return data;
  }

  static int? positivo(dynamic valor) {
    final n = int.tryParse(valor?.toString() ?? '');
    return n != null && n > 0 ? n : null;
  }

  static bool esRecuperacionCarrito(Map<String, dynamic>? data) => const {
    'carrito_abandonado',
    'recuperacion_carrito',
    'carrito',
  }.contains(data?['tipo']?.toString().toLowerCase());
  static int? extraerPedidoId(Map<String, dynamic>? data) {
    if (data == null || esRecuperacionCarrito(data)) return null;
    final tipo = data['tipo']?.toString();
    if (tipo != null &&
        !const {
          'pedido',
          'estado_pedido',
          'actualizacion_pedido',
        }.contains(tipo)) {
      return null;
    }
    return positivo(
      data['pedido_id'] ?? data['pedidoId'] ?? data['order_id'] ?? data['id'],
    );
  }

  static int? extraerPedidoIdDeTexto(String? texto) =>
      positivo(RegExp(r'#(\d+)').firstMatch(texto ?? '')?.group(1));

  /// Keep only known destinations; obtain product, stock and cart from the API.
  static bool destinoValido(Map<String, dynamic> data) =>
      esRecuperacionCarrito(data) ||
      extraerPedidoId(data) != null ||
      (data['tipo'] == 'cupon' && positivo(data['tienda_id']) != null) ||
      (data['tipo'] == 'recompra' &&
          positivo(data['tienda_id']) != null &&
          positivo(data['producto_id']) != null);

  Future<void> abrirDatos(Map<String, dynamic> datos) async {
    if (!destinoValido(datos)) return;
    _pendiente = Map<String, dynamic>.from(datos);
    await _procesarPendiente();
  }

  Future<void> navegarAPedido(int pedidoId) =>
      abrirDatos({'tipo': 'pedido', 'pedido_id': pedidoId});
  Future<void> navegarAlCarrito() => abrirDatos({'tipo': 'carrito_abandonado'});
  void procesarCarritoPendiente() {
    unawaited(_procesarPendiente());
    if (_initialized) unawaited(_renovarSesionPush());
  }

  Future<void> _renovarSesionPush() async {
    try {
      final m = FirebaseMessaging.instance;
      final s = await m.getNotificationSettings();
      if (s.authorizationStatus == AuthorizationStatus.authorized ||
          s.authorizationStatus == AuthorizationStatus.provisional) {
        _fcmToken = await m.getToken();
        await sincronizarTokenConBackend();
      }
    } catch (_) {
      estado.value = EstadoPush.error;
    }
  }

  Future<void> _procesarPendiente() async {
    final nav = navigatorKey.currentState;
    final ctx = navigatorKey.currentContext;
    final datos = _pendiente;
    if (nav == null || ctx == null || datos == null) return;
    final usuario = ctx.read<AuthService>().currentUser;
    if (usuario == null || usuario.rol != 'cliente') return;
    _pendiente = null;
    if (datos['cliente_id'] != null &&
        positivo(datos['cliente_id']) != usuario.id) {
      return;
    }
    if (esRecuperacionCarrito(datos)) {
      nav.popUntil((r) => r.isFirst);
      tabChangeNotifier.value = 1;
      await ctx.read<CartService>().loadCarrito(usuario);
      return;
    }
    if (datos['tipo'] == 'cupon') {
      await nav.push(MaterialPageRoute(builder: (_) => const CuponesScreen()));
      return;
    }
    if (datos['tipo'] == 'recompra') {
      try {
        final r = await ApiService.instance.get(
          '${ApiConstants.catalogoProductos}${datos['producto_id']}/',
          auth: true,
        );
        if (r.statusCode != 200) throw Exception();
        final producto = Producto.fromJson(
          jsonDecode(utf8.decode(r.bodyBytes)),
        );
        if (producto.tiendaId != positivo(datos['tienda_id'])) {
          throw Exception();
        }
        // A session may change while fetching the product.
        if (!ctx.mounted ||
            ctx.read<AuthService>().currentUser?.id != usuario.id) {
          return;
        }
        await showModalBottomSheet<void>(
          context: ctx,
          isScrollControlled: true,
          builder: (_) => ProductoDetailSheet(producto: producto),
        );
      } catch (_) {
        scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Este producto ya no está disponible.')),
        );
      }
      return;
    }
    final id = extraerPedidoId(datos);
    if (id != null) {
      nav.popUntil((r) => r.isFirst);
      tabChangeNotifier.value = 2;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ctx.mounted &&
            ctx.read<AuthService>().currentUser?.id == usuario.id) {
          showModalBottomSheet<void>(
            context: ctx,
            isScrollControlled: true,
            builder: (_) => SeguimientoPedidoSheet.porId(pedidoId: id),
          );
        }
      });
    }
  }
}
