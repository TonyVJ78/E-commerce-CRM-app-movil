import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kantu_market/core/services/api_service.dart';
import 'package:kantu_market/core/services/informes_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response respuesta(Object body, int status) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status);

Map<String, Object> contexto() => {
  'tiendas': [
    {'id': 7, 'nombre': 'Tienda Café'},
  ],
  'es_administrador': false,
  'puede_crear': true,
  'puede_eliminar': false,
  'ejemplos': ['Ventas por semana'],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'km_access_token': 'simulado'});
    ApiService.instance.setOnlineBackend(true);
  });

  test(
    '404 de Vercel explica que falta habilitar informes sin mostrar HTML',
    () async {
      final service = InformesService();
      addTearDown(service.dispose);
      await http.runWithClient(
        () => service.cargarContexto(),
        () => MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/ia/informes/contexto/');
          expect(request.headers['Authorization'], 'Bearer simulado');
          return http.Response(
            '<html>Detalle interno que no debe mostrarse</html>',
            404,
          );
        }),
      );
      expect(service.errorContexto, contains('servidor'));
      expect(service.errorContexto, contains('actualizarlo'));
      expect(service.errorContexto, isNot(contains('Detalle interno')));
      expect(service.contexto, isNull);
      expect(service.sinPermiso, isFalse);
      expect(service.cargandoContexto, isFalse);
    },
  );

  test('401 exige renovar la sesión y no acusa un fallo del módulo', () async {
    final service = InformesService();
    addTearDown(service.dispose);
    await http.runWithClient(
      () => service.cargarContexto(),
      () => MockClient((_) async => respuesta({}, 401)),
    );
    expect(service.errorContexto, contains('sesión venció'));
    expect(service.sinPermiso, isFalse);
    expect(service.cargandoContexto, isFalse);
  });

  test(
    'reintentar distingue permisos, módulo ausente y servidor actualizado',
    () async {
      final service = InformesService();
      addTearDown(service.dispose);
      final statuses = [403, 404, 200];
      var call = 0;
      await http.runWithClient(
        () async {
          await service.cargarContexto();
          expect(service.sinPermiso, isTrue);
          await service.cargarContexto();
          expect(service.sinPermiso, isFalse);
          expect(service.errorContexto, contains('actualizarlo'));
          await service.cargarContexto();
        },
        () => MockClient((_) async => respuesta(contexto(), statuses[call++])),
      );
      expect(call, 3);
      expect(service.errorContexto, isNull);
      expect(service.sinPermiso, isFalse);
      expect(service.contexto!.tiendas.single.nombre, 'Tienda Café');
      expect(service.contexto!.puedeCrear, isTrue);
      expect(service.tiendaId, 7);
    },
  );

  test(
    'contexto cargado envía texto o dictado con la tienda y sesión correctas',
    () async {
      final service = InformesService();
      addTearDown(service.dispose);
      await http.runWithClient(
        () async {
          await service.cargarContexto();
          await service.enviar('Ventas por semana');
        },
        () => MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer simulado');
          if (request.method == 'GET') return respuesta(contexto(), 200);
          expect(request.url.path, '/api/ia/informes/generar/');
          final body = jsonDecode(request.body) as Map;
          expect(body['tienda_id'], 7);
          expect((body['mensajes'] as List).last, {
            'rol': 'usuario',
            'contenido': 'Ventas por semana',
          });
          return respuesta({
            'mensaje': '¿De qué mes?',
            'sugerencias': [],
            'informe': null,
          }, 200);
        }),
      );
      expect(service.mensajes.last.contenido, '¿De qué mes?');
      expect(service.mensajes.last.error, isFalse);
      expect(service.enviando, isFalse);
    },
  );

  test(
    'un fallo de red permite reintentar sin conservar datos anteriores',
    () async {
      final service = InformesService();
      addTearDown(service.dispose);
      await http.runWithClient(() async {
        await service.cargarContexto();
        expect(service.contexto, isNotNull);
      }, () => MockClient((_) async => respuesta(contexto(), 200)));
      await http.runWithClient(
        () => service.cargarContexto(),
        () => MockClient((_) async => throw http.ClientException('sin red')),
      );
      expect(service.contexto, isNull);
      expect(service.tiendaId, isNull);
      expect(service.errorContexto, contains('conexión'));
      expect(service.cargandoContexto, isFalse);
    },
  );
}
