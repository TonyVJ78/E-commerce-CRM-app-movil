import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:kantu_market/core/models/pedido.dart';
import 'package:kantu_market/core/models/producto.dart';
import 'package:kantu_market/core/models/usuario.dart';
import 'package:kantu_market/core/models/tienda.dart';
import 'package:kantu_market/core/services/api_service.dart';
import 'package:kantu_market/core/services/cart_service.dart';
import 'package:kantu_market/core/services/cupones_service.dart';
import 'package:kantu_market/core/services/marketing_api.dart';
import 'package:kantu_market/features/cliente/cupon_carrito_field.dart';
import 'package:kantu_market/features/cliente/cupones_screen.dart';

http.Response respuesta(Object data, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(data)), status);
void llenar(CartService cart) {
  final variante = Variante(
    id: 1,
    productoId: 1,
    tiendaId: 4,
    precio: 20,
    stock: 10,
  );
  cart.itemsList.add(
    ItemCarrito(
      id: 1,
      idRemoto: 1,
      producto: Producto(
        id: 1,
        tiendaId: 4,
        nombre: 'Producto',
        variantes: [variante],
      ),
      variante: variante,
      cantidad: 2,
    ),
  );
}

Map<String, dynamic> quote() => {
  'tienda_id': 4,
  'codigo': 'AHORRA25',
  'subtotal': '40.00',
  'descuento': '10.00',
  'total': '30.00',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'empresa crea un cupón con vigencia y límites sin perder la validación',
    (tester) async {
      Map<String, dynamic>? enviado;
      bool? creado;
      final service = CuponesService(
        api: MarketingApi(
          online: () => true,
          post: (path, body) async {
            expect(path, '/tiendas/4/cupones/');
            enviado = body;
            return respuesta({'id': 2}, 201);
          },
        ),
      );
      final tienda = Tienda(
        id: 4,
        propietarioId: 1,
        propietarioEmail: 'empresa@example.test',
        nombre: 'Prueba',
        slug: 'prueba',
        fechaCreacion: '2026-10-25',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  creado = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => NuevoCuponScreen(
                        tienda: tienda,
                        segmentos: const [],
                        servicio: service,
                      ),
                    ),
                  );
                },
                child: const Text('Abrir formulario'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir formulario'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'nuevo10');
      await tester.enterText(find.byType(TextFormField).at(1), '10');
      tester.testTextInput.hide();
      await tester.drag(find.byType(ListView), const Offset(0, -1100));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Crear cupón'));
      await tester.pumpAndSettle();
      expect(
        enviado,
        isNotNull,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .join(' | '),
      );
      expect(creado, isTrue);
      expect(enviado?['codigo'], 'NUEVO10');
      expect(enviado?['valor_descuento'], '10.00');
      expect(enviado?['usos_maximos'], 100);
      expect(enviado?['limite_por_cliente'], 1);
      expect(tester.takeException(), isNull);
    },
  );
  setUp(() {
    ApiService.instance.setOnlineBackend(true);
    SharedPreferences.setMockInitialValues({'km_access_token': 'simulado'});
  });
  test(
    'el cupón descuenta solo la tienda cotizada y permite quitarlo',
    () async {
      final service = CuponesService(
        api: MarketingApi(
          online: () => true,
          post: (p, b) async {
            expect(p, '/marketing/cupones/validar/');
            expect(b, {'tienda_id': 4, 'codigo': 'AHORRA25'});
            return respuesta(quote());
          },
        ),
      );
      final cart = CartService(cuponesService: service);
      llenar(cart);
      expect(await cart.aplicarCupon(4, 'ahorra25'), isTrue);
      expect(cart.subtotalAmount, 40);
      expect(cart.totalAmount, 30);
      expect(cart.cuponesParaCheckout, {'4': 'AHORRA25'});
      cart.quitarCupon(4);
      expect(cart.totalAmount, 40);
    },
  );
  test(
    'no aplica cotizaciones de otra tienda ni de un carrito desactualizado',
    () async {
      final cart = CartService(
        cuponesService: CuponesService(
          api: MarketingApi(
            online: () => true,
            post: (_, b) async => respuesta({...quote(), 'tienda_id': 9}),
          ),
        ),
      );
      llenar(cart);
      expect(await cart.aplicarCupon(4, 'AHORRA25'), isFalse);
      expect(cart.totalAmount, 40);
    },
  );
  test('un error de autorización no se convierte en cupón aplicado', () async {
    final cart = CartService(
      cuponesService: CuponesService(
        api: MarketingApi(
          online: () => true,
          post: (_, b) async => respuesta({}, 403),
        ),
      ),
    );
    llenar(cart);
    expect(await cart.aplicarCupon(4, 'AHORRA25'), isFalse);
    expect(cart.errorMessage, contains('permiso'));
    expect(cart.descuentoAmount, 0);
  });
  test('checkout en efectivo va al servidor con los cupones y conserva monto confirmado', () async {
    final cart = CartService(
      cuponesService: CuponesService(
        api: MarketingApi(
          online: () => true,
          post: (_, b) async => respuesta(quote()),
        ),
      ),
    );
    llenar(cart);
    await cart.aplicarCupon(4, 'AHORRA25');
    final cliente = Usuario(
      id: 8,
      email: 'cliente@example.test',
      firstName: 'Cliente',
      lastName: 'Prueba',
      rol: 'cliente',
    );
    await http.runWithClient(
      () async {
        final pedido = await cart.checkout(
          cliente: cliente,
          metodoPago: 'efectivo',
        );
        expect(pedido?.id, 123);
        expect(pedido?.total, 30);
        expect(cart.itemsList, isEmpty);
        expect(cart.cuponesParaCheckout, isEmpty);
      },
      () => MockClient((request) async {
        expect(request.url.path, endsWith('/pedidos/carrito/checkout/'));
        expect(jsonDecode(request.body)['cupones'], {'4': 'AHORRA25'});
        expect(jsonDecode(request.body)['metodo_pago'], 'efectivo');
        return respuesta({
          'pedidos': [123],
        }, 201);
      }),
    );
  });
  test('si el carrito remoto falla no carga una copia SQLite ni deja descuentos viejos', () async {
    final cart = CartService();
    llenar(cart);
    final cliente = Usuario(
      id: 8,
      email: 'cliente@example.test',
      firstName: 'Cliente',
      lastName: 'Prueba',
      rol: 'cliente',
    );
    await http.runWithClient(() async {
      await cart.loadCarrito(cliente);
      expect(cart.itemsList, isEmpty);
      expect(cart.errorMessage, isNotNull);
    }, () => MockClient((_) async => respuesta({}, 503)));
  });
  testWidgets(
    'campo de cupón en pantalla pequeña muestra el descuento del servidor',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final cart = CartService(
        cuponesService: CuponesService(
          api: MarketingApi(
            online: () => true,
            post: (_, b) async => respuesta(quote()),
          ),
        ),
      );
      llenar(cart);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: cart,
          child: const MaterialApp(
            home: Scaffold(body: CuponCarritoField(tiendaId: 4)),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'AHORRA25');
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();
      expect(find.textContaining('descuento Bs 10.00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'promociones no muestra datos falsos cuando el endpoint no existe',
    (tester) async {
      final service = CuponesService(
        api: MarketingApi(
          online: () => true,
          get: (_) async => respuesta({}, 404),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(home: CuponesScreen(servicio: service)),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('no está disponible'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    },
  );
}
