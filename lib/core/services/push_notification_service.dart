import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../../features/cliente/seguimiento_pedido_sheet.dart';
import '../constants/api_constants.dart';
import '../constants/colors.dart';
import 'api_service.dart';


/// Manejador de notificaciones FCM en segundo plano o estado terminado.
/// Debe ser una función de nivel superior con la anotación `@pragma('vm:entry-point')`.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint(
    '[FCM Background] Notificación recibida ID: ${message.messageId}, datos: ${message.data}',
  );
}

/// Servicio centralizado de Firebase Cloud Messaging (FCM) para Kantu Market (CU-18).
///
/// Gestiona:
/// - Solicitud de permisos al usuario y captura del token único del dispositivo.
/// - Sincronización asíncrona "fire-and-forget" del token con el backend Django (`/api/usuarios/dispositivos/`).
/// - Captura de notificaciones en primer plano con SnackBar no intrusivo.
/// - Enrutamiento reactivo hacia "Mis Pedidos" y despliegue automático del `SeguimientoPedidoSheet`.
class PushNotificationService {
  static final PushNotificationService instance = PushNotificationService._();
  PushNotificationService._();

  /// Llave global de navegación para enrutar sin acoplamiento a BuildContext locales.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// Llave global para desplegar SnackBars y alertas no intrusivas en cualquier vista.
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  /// Notificador para cambiar de pestaña en `HomeShell` (índice 2 = 'Mis Pedidos').
  static final ValueNotifier<int?> tabChangeNotifier =
      ValueNotifier<int?>(null);

  bool _initialized = false;
  bool get isInitialized => _initialized;

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  /// Inicializa FCM, solicita permisos y suscribe los listeners en segundo y primer plano.
  /// Aplica manejo silencioso de excepciones para prevenir cualquier crash en entornos sin Google Play Services.
  Future<void> init({GlobalKey<NavigatorState>? navKey}) async {
    if (_initialized) return;

    try {
      final messaging = FirebaseMessaging.instance;

      // 1. Solicitar permisos de notificación (iOS y Android 13+)
      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint(
        '[FCM] Estado de autorización de notificaciones: ${settings.authorizationStatus}',
      );

      // 2. Obtener y sincronizar Token FCM
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        _fcmToken = await messaging.getToken();
        if (_fcmToken != null) {
          debugPrint('[FCM] Token obtenido: $_fcmToken');
          unawaited(_enviarTokenAlBackend(_fcmToken!));
        }
      }

      // 3. Listener para renovación de token FCM
      messaging.onTokenRefresh.listen((nuevoToken) {
        _fcmToken = nuevoToken;
        debugPrint('[FCM] Token renovado: $nuevoToken');
        unawaited(_enviarTokenAlBackend(nuevoToken));
      });

      // 4. Registrar manejador en segundo plano
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 5. Configurar listener en primer plano (Foreground) -> SnackBar no intrusivo
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _mostrarSnackBarPrimerPlano(message);
      });

      // 6. Configurar listener al tocar notificación desde segundo plano
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _manejarNotificacionTap(message);
      });

      // 7. Manejar notificación que abrió la app desde estado terminado (Terminated)
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        _manejarNotificacionTap(initialMessage);
      }

      _initialized = true;
      debugPrint('[FCM] PushNotificationService inicializado correctamente.');
    } catch (e) {
      debugPrint('[FCM] Error silencioso al inicializar FCM: $e');
    }
  }

  /// Envía el token de dispositivo al backend de forma asíncrona ("fire-and-forget").
  /// No bloquea la UI ni interrumpe la navegación en caso de error HTTP o desconexión.
  Future<void> _enviarTokenAlBackend(String token) async {
    try {
      final plataforma = Platform.isAndroid
          ? 'android'
          : (Platform.isIOS
              ? 'ios'
              : (Platform.isMacOS
                  ? 'macos'
                  : (Platform.isWindows ? 'windows' : 'web')));

      final response = await ApiService.instance.post(
        ApiConstants.registrarDispositivo,
        {
          'token': token,
          'plataforma': plataforma,
        },
        auth: true,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('[FCM] Dispositivo registrado exitosamente en el backend.');
      } else {
        debugPrint(
          '[FCM] Registro de dispositivo en backend respondió HTTP ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('[FCM] Error enviando token al backend (silenciado): $e');
    }
  }

  /// Permite forzar la sincronización del token cuando el usuario inicia sesión.
  Future<void> sincronizarTokenConBackend() async {
    if (_fcmToken != null && _fcmToken!.isNotEmpty) {
      unawaited(_enviarTokenAlBackend(_fcmToken!));
    }
  }

  /// Despliega un SnackBar flotante no intrusivo con diseño premium cuando llega una notificación en primer plano.
  void _mostrarSnackBarPrimerPlano(RemoteMessage message) {
    final notification = message.notification;
    final titulo = notification?.title ?? message.data['titulo'] ?? 'Kantu Market';
    final cuerpo = notification?.body ??
        message.data['cuerpo'] ??
        message.data['mensaje'] ??
        'Tienes una nueva actualización.';
    final pedidoId = extraerPedidoId(message.data) ??
        extraerPedidoIdDeTexto(notification?.title) ??
        extraerPedidoIdDeTexto(notification?.body);

    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: const Color(0xFF1E293B), // Slate oscuro elegante
        elevation: 6,
        duration: const Duration(seconds: 5),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: pedidoId != null
                    ? KantuColors.primary.withAlpha(50)
                    : Colors.white10,
                shape: BoxShape.circle,
              ),
              child: Icon(
                pedidoId != null
                    ? Icons.local_shipping_outlined
                    : Icons.notifications_active_outlined,
                color: pedidoId != null ? KantuColors.primaryLight : Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    cuerpo,
                    style: const TextStyle(
                      color: Color(0xFFCBD5E1),
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        action: pedidoId != null
            ? SnackBarAction(
                label: 'VER',
                textColor: KantuColors.primaryLight,
                onPressed: () => navegarAPedido(pedidoId),
              )
            : null,
      ),
    );
  }

  /// Maneja el toque en la notificación (desde background o terminated).
  void _manejarNotificacionTap(RemoteMessage message) {
    debugPrint('[FCM Tap] Notificación pulsada. Data: ${message.data}');
    final pedidoId = extraerPedidoId(message.data) ??
        extraerPedidoIdDeTexto(message.notification?.title) ??
        extraerPedidoIdDeTexto(message.notification?.body);

    if (pedidoId != null) {
      navegarAPedido(pedidoId);
    }
  }

  /// Enrutamiento reactivo:
  /// Navega limpiamente hacia "Mis Pedidos" (pestaña índice 2) y abre el `SeguimientoPedidoSheet`.
  Future<void> navegarAPedido(int pedidoId) async {
    try {
      final nav = navigatorKey.currentState;
      if (nav == null) {
        debugPrint('[FCM] NavigatorState no disponible.');
        return;
      }

      // 1. Limpiar pantallas o modales secundarios apilados en el Navigator
      nav.popUntil((route) => route.isFirst);

      // 2. Conmutar reactivamente la pestaña hacia "Mis Pedidos" (índice 2)
      tabChangeNotifier.value = 2;

      // 3. Desplegar el SeguimientoPedidoSheet de la Fase 4
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = navigatorKey.currentContext;
        if (context != null) {
          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => SeguimientoPedidoSheet.porId(pedidoId: pedidoId),
          );
        }
      });
    } catch (e) {
      debugPrint('[FCM] Error en enrutamiento reactivo hacia pedido #$pedidoId: $e');
    }
  }

  /// Extrae el ID del pedido desde los datos (payload) de la notificación FCM.
  static int? extraerPedidoId(Map<String, dynamic>? data) {
    if (data == null) return null;
    final dynamic valor = data['pedido_id'] ??
        data['pedidoId'] ??
        data['order_id'] ??
        data['id'];
    if (valor == null) return null;
    if (valor is int) return valor;
    return int.tryParse(valor.toString());
  }

  /// Extrae un ID de pedido numérico de patrones como "#123" en títulos o cuerpos de texto.
  static int? extraerPedidoIdDeTexto(String? texto) {
    if (texto == null || texto.isEmpty) return null;
    final match = RegExp(r'#(\d+)').firstMatch(texto);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }
    return null;
  }
}
