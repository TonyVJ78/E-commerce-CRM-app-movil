import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kantu_market/core/constants/api_constants.dart';
import 'package:kantu_market/core/models/pedido.dart';
import 'package:kantu_market/core/services/soporte_service.dart';
import 'package:kantu_market/features/cliente/soporte_screen.dart';

Map<String, dynamic> ticket({
  String estado = 'abierto',
  List<dynamic>? mensajes,
}) => {
  'id': 7,
  'codigo_ticket': 'TCK-2026-0007',
  'asunto': 'Producto incompleto',
  'descripcion': 'Falta un artículo del pedido.',
  'tienda_nombre': 'Tienda de prueba',
  'estado': estado,
  'estado_display': estado == 'resuelto' ? 'Resuelto' : 'Abierto',
  'tipo_display': 'Defecto de Producto',
  'pedido_codigo': 'PED-00003',
  'mensajes':
      mensajes ??
      [
        {
          'autor': {'id': 1, 'nombre': 'Cliente de prueba'},
          'contenido': 'Falta un artículo del pedido.',
          'fecha_envio': '2026-10-25T12:00:00Z',
          'archivo_adjunto': null,
        },
      ],
};

http.Response respuesta(Object data, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(data)), status);

void main() {
  group('CU-25: integración con la API de soporte', () {
    test('lista tickets remotos con su código, estado e historial', () async {
      final servicio = SoporteService(
        online: () => true,
        get: (path) async {
          expect(path, ApiConstants.misTickets);
          return respuesta([ticket()]);
        },
      );
      final tickets = await servicio.listar();
      expect(tickets.single.codigo, 'TCK-2026-0007');
      expect(tickets.single.mensajes.single.autor, 'Cliente de prueba');
      expect(tickets.single.mensajes.single.contenido, contains('artículo'));
    });

    test(
      'asocia el reclamo al pedido y deja que el backend determine su tienda',
      () async {
        final servicio = SoporteService(
          online: () => true,
          post: (path, body) async {
            expect(path, ApiConstants.crearTicket);
            expect(body, {
              'pedido_id': 3,
              'tipo': 'reclamo_producto',
              'prioridad': 'media',
              'asunto': 'Producto incompleto',
              'descripcion': 'Falta un artículo.',
              'archivo_adjunto': 'https://example.com/comprobante.png',
            });
            return respuesta(ticket(), 201);
          },
        );
        final creado = await servicio.crear(
          pedidoId: 3,
          tiendaId: 999,
          tipo: 'reclamo_producto',
          asunto: ' Producto incompleto ',
          descripcion: ' Falta un artículo. ',
          adjunto: 'https://example.com/comprobante.png',
        );
        expect(creado.id, 7);
      },
    );

    test(
      'permite una consulta general por tienda, sin pedido ni adjunto',
      () async {
        final servicio = SoporteService(
          online: () => true,
          post: (path, body) async {
            expect(body['tienda_id'], 2);
            expect(body.containsKey('pedido_id'), isFalse);
            expect(body.containsKey('archivo_adjunto'), isFalse);
            return respuesta(ticket(), 201);
          },
        );
        await servicio.crear(
          tiendaId: 2,
          tipo: 'consulta',
          asunto: 'Consulta',
          descripcion: 'Detalle',
        );
      },
    );

    test('rechaza campos vacíos, falta de tienda y adjuntos inválidos antes de enviar', () async {
      var envios = 0;
      final servicio = SoporteService(
        online: () => true,
        post: (_, body) async {
          envios++;
          return respuesta(ticket(), 201);
        },
      );
      await expectLater(
        servicio.crear(
          tipo: 'consulta',
          asunto: 'Asunto',
          descripcion: 'Detalle',
        ),
        throwsA(isA<SoporteException>()),
      );
      await expectLater(
        servicio.crear(
          tiendaId: 2,
          tipo: 'consulta',
          asunto: ' ',
          descripcion: 'Detalle',
        ),
        throwsA(isA<SoporteException>()),
      );
      await expectLater(
        servicio.crear(
          tiendaId: 2,
          tipo: 'consulta',
          asunto: 'Asunto',
          descripcion: 'Detalle',
          adjunto: 'javascript:alert(1)',
        ),
        throwsA(isA<SoporteException>()),
      );
      expect(envios, 0);
    });

    test(
      'no simula envíos exitosos en modo local ni ante fallos de red',
      () async {
        final offline = SoporteService(
          online: () => false,
          post: (_, body) async => throw StateError('No debe enviarse'),
        );
        await expectLater(
          offline.crear(
            tiendaId: 2,
            tipo: 'consulta',
            asunto: 'Asunto',
            descripcion: 'Detalle',
          ),
          throwsA(isA<SoporteException>()),
        );
        final lento = SoporteService(
          online: () => true,
          post: (_, body) async => throw TimeoutException('Prueba'),
        );
        await expectLater(
          lento.crear(
            tiendaId: 2,
            tipo: 'consulta',
            asunto: 'Asunto',
            descripcion: 'Detalle',
          ),
          throwsA(predicate((e) => e.toString().contains('antes de reenviar'))),
        );
      },
    );

    for (final status in [401, 403, 404, 503]) {
      test('maneja HTTP $status sin mostrar tickets de ejemplo', () async {
        final servicio = SoporteService(
          online: () => true,
          get: (_) async => http.Response('<html>Error</html>', status),
        );
        await expectLater(servicio.listar(), throwsA(isA<SoporteException>()));
      });
    }

    test('propaga errores de validación del backend y envía respuestas al ticket correcto', () async {
      final invalido = SoporteService(
        online: () => true,
        post: (_, body) async => respuesta({
          'pedido_id': ['El pedido no pertenece a tu cuenta.'],
        }, 400),
      );
      await expectLater(
        invalido.crear(
          pedidoId: 3,
          tipo: 'consulta',
          asunto: 'Asunto',
          descripcion: 'Detalle',
        ),
        throwsA(predicate((e) => e.toString().contains('no pertenece'))),
      );
      final servicio = SoporteService(
        online: () => true,
        post: (path, body) async {
          expect(path, '/soporte/tickets/7/responder/');
          expect(body, {'contenido': 'Gracias por responder'});
          return respuesta({'id': 8}, 201);
        },
      );
      await servicio.responder(7, ' Gracias por responder ');
    });
  });

  group('CU-25: pantallas móviles', () {
    testWidgets(
      'registra una consulta general y abre su detalle desde la lista',
      (tester) async {
        Map<String, dynamic>? enviado;
        final servicio = SoporteService(
          online: () => true,
          get: (path) async {
            if (path == ApiConstants.catalogoTiendas) {
              return respuesta([
                {'id': 2, 'nombre': 'Tienda de prueba'},
              ]);
            }
            return respuesta(path == ApiConstants.misTickets ? [] : ticket());
          },
          post: (path, body) async {
            enviado = body;
            return respuesta(ticket(), 201);
          },
        );
        await tester.pumpWidget(
          MaterialApp(home: SoporteScreen(servicio: servicio)),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Nueva solicitud'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(DropdownButtonFormField<int>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Tienda de prueba').last);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextFormField).at(0),
          'Producto incompleto',
        );
        await tester.enterText(
          find.byType(TextFormField).at(1),
          'Falta un artículo.',
        );
        tester.testTextInput.hide();
        await tester.ensureVisible(find.text('Enviar solicitud'));
        await tester.tap(find.text('Enviar solicitud'));
        await tester.pumpAndSettle();
        expect(enviado?['tienda_id'], 2);
        expect(enviado?['tipo'], 'consulta');
        expect(find.text('TCK-2026-0007'), findsOneWidget);
        expect(find.text('Abierto'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'muestra un error de autorización y permite reintentar sin inventar tickets',
      (tester) async {
        var llamadas = 0;
        final servicio = SoporteService(
          online: () => true,
          get: (_) async {
            llamadas++;
            return llamadas == 1 ? respuesta({}, 403) : respuesta([ticket()]);
          },
        );
        await tester.pumpWidget(
          MaterialApp(home: SoporteScreen(servicio: servicio)),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('No tienes permiso'), findsOneWidget);
        expect(find.text('Producto incompleto'), findsNothing);
        await tester.tap(find.text('Reintentar'));
        await tester.pumpAndSettle();
        expect(find.text('Producto incompleto'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'valida el formulario y conserva el texto si el backend rechaza el pedido',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var envios = 0;
        final servicio = SoporteService(
          online: () => true,
          post: (_, body) async {
            envios++;
            return respuesta({
              'pedido_id': ['El pedido no pertenece a tu cuenta.'],
            }, 400);
          },
        );
        final pedido = Pedido(
          id: 3,
          clienteId: 1,
          tiendaId: 2,
          tiendaNombre: 'Tienda de prueba',
          fecha: '2026-10-25',
          subtotal: 10,
          total: 10,
          items: [],
        );
        await tester.pumpWidget(
          MaterialApp(
            home: NuevoTicketScreen(pedido: pedido, servicio: servicio),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Enviar solicitud'));
        await tester.tap(find.text('Enviar solicitud'));
        await tester.pumpAndSettle();
        expect(envios, 0);
        await tester.enterText(
          find.byType(TextFormField).at(0),
          'Producto incompleto',
        );
        await tester.enterText(
          find.byType(TextFormField).at(1),
          'Falta un artículo.',
        );
        tester.testTextInput.hide();
        await tester.ensureVisible(find.text('Enviar solicitud'));
        await tester.tap(find.text('Enviar solicitud'));
        await tester.pumpAndSettle();
        expect(envios, 1);
        expect(find.textContaining('no pertenece'), findsOneWidget);
        expect(find.text('Producto incompleto'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'actualiza el estado remoto, muestra respuestas y detiene el sondeo al salir',
      (tester) async {
        var consultas = 0;
        final servicio = SoporteService(
          online: () => true,
          get: (_) async {
            consultas++;
            return respuesta(
              ticket(estado: consultas == 1 ? 'abierto' : 'resuelto'),
            );
          },
        );
        await tester.pumpWidget(
          MaterialApp(
            home: DetalleTicketScreen(ticketId: 7, servicio: servicio),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Abierto'), findsOneWidget);
        expect(find.text('Falta un artículo del pedido.'), findsOneWidget);
        await tester.pump(const Duration(seconds: 15));
        await tester.pumpAndSettle();
        expect(find.text('Resuelto'), findsOneWidget);
        expect(consultas, 2);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 30));
        expect(consultas, 2);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
