import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kantu_market/core/models/tienda.dart';
import 'package:kantu_market/core/services/campana_carrito_service.dart';
import 'package:kantu_market/core/services/marketing_api.dart';
import 'package:kantu_market/core/services/push_notification_service.dart';
import 'package:kantu_market/features/empresa/campana_carrito_screen.dart';

http.Response respuesta(Object data, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(data)), status);
Map<String, dynamic> config() => {
  'activo': true,
  'horas_inactividad': 2,
  'asunto_email': 'Tu carrito',
  'mensaje_email': 'Vuelve a tu tienda',
  'descuento_porcentaje': 0,
  'codigo_cupon': '',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('consulta y guarda exclusivamente la tienda indicada con las rutas existentes', () async {
    final service = CampanaCarritoService(
      api: MarketingApi(
        online: () => true,
        get: (p) async {
          expect(p, '/tiendas/4/campana-carrito/');
          return respuesta({'campana': config(), 'metricas': {}});
        },
        patch: (p, b) async {
          expect(p, '/tiendas/4/campana-carrito/');
          expect(b['horas_inactividad'], 2);
          return respuesta({'campana': b});
        },
      ),
    );
    expect((await service.obtener(4))['campana']['activo'], isTrue);
    await service.guardar(4, config());
  });
  test('rechaza límites inválidos antes de guardar y conserva errores de autorización', () async {
    final service = CampanaCarritoService(
      api: MarketingApi(
        online: () => true,
        get: (_) async => respuesta({}, 403),
        patch: (_, b) async => throw StateError('No debe enviar'),
      ),
    );
    await expectLater(
      service.guardar(4, {...config(), 'horas_inactividad': 0}),
      throwsA(isA<MarketingException>()),
    );
    await expectLater(
      service.guardar(4, {...config(), 'descuento_porcentaje': 51}),
      throwsA(isA<MarketingException>()),
    );
    await expectLater(
      service.obtener(4),
      throwsA(predicate((e) => e.toString().contains('permiso'))),
    );
  });
  test('HTTP 200 no confirma un correo si enviado es false', () async {
    final service = CampanaCarritoService(
      api: MarketingApi(
        online: () => true,
        post: (_, b) async => respuesta({'success': true, 'enviado': false}),
      ),
    );
    expect(await service.enviarPrueba(4), isFalse);
  });
  test('una notificación de carrito no se interpreta como un pedido', () {
    expect(
      PushNotificationService.esRecuperacionCarrito({
        'tipo': 'carrito_abandonado',
      }),
      isTrue,
    );
    expect(
      PushNotificationService.extraerPedidoId({
        'tipo': 'carrito_abandonado',
        'id': 99,
      }),
      isNull,
    );
    expect(PushNotificationService.extraerPedidoId({'pedido_id': 99}), 99);
  });
  testWidgets(
    'permite guardar en pantalla pequeña y excluye carritos aún activos',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var guardados = 0;
      final service = CampanaCarritoService(
        api: MarketingApi(
          online: () => true,
          get: (p) async => p.contains('carritos-abandonados')
              ? respuesta([
                  {
                    'id': 1,
                    'cliente': {'nombre': 'Carrito reciente'},
                    'horas_inactivo': 1,
                    'recuperado': false,
                    'monto_total': 20,
                    'items': [],
                  },
                  {
                    'id': 2,
                    'cliente': {'nombre': 'Cliente inactivo'},
                    'horas_inactivo': 4,
                    'recuperado': false,
                    'monto_total': 30,
                    'items': [],
                  },
                ])
              : respuesta({
                  'campana': config(),
                  'metricas': {'carritos_detectados': 1},
                }),
          patch: (_, b) async {
            guardados++;
            return respuesta({'campana': b});
          },
        ),
      );
      final tienda = Tienda(
        id: 4,
        propietarioId: 1,
        propietarioEmail: 'empresa@example.test',
        nombre: 'Tienda de prueba',
        slug: 'prueba',
        fechaCreacion: '2026-10-25',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CampanaCarritoScreen(tienda: tienda, servicio: service),
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -650));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar campaña'));
      await tester.pumpAndSettle();
      expect(guardados, 1);
      await tester.drag(find.byType(ListView), const Offset(0, -1400));
      await tester.pumpAndSettle();
      expect(find.text('Carrito reciente'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
