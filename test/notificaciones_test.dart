import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kantu_market/core/services/marketing_api.dart';
import 'package:kantu_market/core/services/notificaciones_service.dart';
import 'package:kantu_market/core/services/push_notification_service.dart';
import 'package:kantu_market/core/services/firebase_runtime.dart';
import 'package:kantu_market/features/cliente/notificaciones_screen.dart';

Map<String, dynamic> aviso(int id, {bool leida = false}) => {
  'id': id,
  'titulo': 'Reponer café',
  'mensaje': 'Consulta los productos disponibles.',
  'tienda_nombre': 'Tienda de prueba',
  'tienda_id': 3,
  'tipo': 'recompra',
  'leida': leida,
  'fecha': '2026-10-26T10:00:00Z',
  'datos': {'producto_id': '8'},
};
http.Response ok(dynamic data) => http.Response(
  jsonEncode(data),
  200,
  headers: {'content-type': 'application/json'},
);

void main() {
  test('cupones y recompra nunca se interpretan como pedidos', () {
    for (final tipo in ['cupon', 'promocion', 'recompra', 'desconocido']) {
      expect(
        PushNotificationService.extraerPedidoId({
          'tipo': tipo,
          'id': 42,
          'pedido_id': 42,
        }),
        isNull,
      );
    }
    for (final id in [0, -1, 'abc', null]) {
      expect(
        PushNotificationService.extraerPedidoId({'pedido_id': id}),
        isNull,
      );
    }
    expect(
      PushNotificationService.destinoValido({
        'tipo': 'recompra',
        'tienda_id': 3,
        'producto_id': 8,
      }),
      isTrue,
    );
    expect(
      PushNotificationService.destinoValido({
        'tipo': 'recompra',
        'tienda_id': 3,
        'producto_id': -8,
      }),
      isFalse,
    );
    expect(
      PushNotificationService.destinoValido({'tipo': 'cupon', 'tienda_id': 3}),
      isTrue,
    );
    expect(
      PushNotificationService.destinoValido({
        'tipo': 'url',
        'url': 'https://example.test',
      }),
      isFalse,
    );
  });

  test(
    'Firebase ausente permite abrir la app y no solicita permisos',
    () async {
      expect(FirebaseRuntime.configured, isFalse);
      expect(await FirebaseRuntime.initialize(), isFalse);
      await PushNotificationService.instance.init();
      expect(
        PushNotificationService.instance.estado.value,
        EstadoPush.sinConfigurar,
      );
    },
  );

  test('bandeja usa autenticación, cursor y lectura remota', () async {
    String? lectura;
    final service = NotificacionesService(
      api: MarketingApi(
        online: () => true,
        get: (path) async {
          expect(path, '/marketing/notificaciones/?antes=15');
          return ok({
            'notificaciones': [aviso(14)],
            'siguiente': null,
          });
        },
        patch: (path, body) async {
          lectura = path;
          expect(body['leida'], true);
          return ok({'leida': true});
        },
      ),
    );
    final pagina = await service.listar(antes: 15);
    expect(pagina.items.single.datos['producto_id'], '8');
    expect(pagina.items.single.datos['tienda_id'], 3);
    await service.marcarLeida(14);
    expect(lectura, '/marketing/notificaciones/14/');
  });

  testWidgets(
    'cliente ve aviso, lo marca leído y abre producto en pantalla pequeña',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Map<String, dynamic>? abierto;
      bool guardado = false;
      final service = NotificacionesService(
        api: MarketingApi(
          online: () => true,
          get: (_) async => ok({
            'notificaciones': [aviso(1)],
            'siguiente': null,
          }),
          patch: (_, _) async {
            guardado = true;
            return ok({'leida': true});
          },
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: NotificacionesScreen(
            service: service,
            onAbrir: (d) async {
              abierto = d;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Mis notificaciones'), findsOneWidget);
      expect(
        find.textContaining('push aún no están disponibles'),
        findsOneWidget,
      );
      await tester.tap(find.text('Reponer café'));
      await tester.pumpAndSettle();
      expect(guardado, isTrue);
      expect(abierto?['producto_id'], '8');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('error de sesión permite reintentar sin inventar avisos', (
    tester,
  ) async {
    var intentos = 0;
    final service = NotificacionesService(
      api: MarketingApi(
        online: () => true,
        get: (_) async {
          intentos++;
          return intentos == 1
              ? http.Response('{}', 401)
              : ok({'notificaciones': [], 'siguiente': null});
        },
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: NotificacionesScreen(service: service)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Tu sesión venció'), findsOneWidget);
    expect(find.text('Todavía no tienes notificaciones.'), findsNothing);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Todavía no tienes notificaciones.'), findsOneWidget);
  });

  testWidgets('carga avisos anteriores conservando los recientes', (
    tester,
  ) async {
    final service = NotificacionesService(
      api: MarketingApi(
        online: () => true,
        get: (path) async => ok({
          'notificaciones': [aviso(path.contains('?') ? 1 : 2)],
          'siguiente': path.contains('?') ? null : 2,
        }),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: NotificacionesScreen(service: service)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver anteriores'));
    await tester.pumpAndSettle();
    expect(find.text('Reponer café'), findsNWidgets(2));
    expect(find.text('Ver anteriores'), findsNothing);
  });

  testWidgets('si falla marcar lectura no cambia el aviso ni navega', (
    tester,
  ) async {
    bool abierto = false;
    final service = NotificacionesService(
      api: MarketingApi(
        online: () => true,
        get: (_) async => ok({
          'notificaciones': [aviso(1)],
          'siguiente': null,
        }),
        patch: (_, _) async => http.Response('{}', 500),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: NotificacionesScreen(
          service: service,
          onAbrir: (_) async {
            abierto = true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reponer café'));
    await tester.pumpAndSettle();
    expect(abierto, isFalse);
    expect(
      find.textContaining('El servicio no está disponible'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.notifications_active), findsOneWidget);
  });
}
