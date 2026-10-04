import 'package:flutter_test/flutter_test.dart';
import 'package:kantu_market/core/services/push_notification_service.dart';
import 'package:kantu_market/features/cliente/seguimiento_pedido_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PushNotificationService (CU-18) - Tests Unitarios', () {
    test('extraerPedidoId extrae correctamente enteros y cadenas en diversos formatos de payload', () {
      expect(PushNotificationService.extraerPedidoId({'pedido_id': 123}), equals(123));
      expect(PushNotificationService.extraerPedidoId({'pedido_id': '456'}), equals(456));
      expect(PushNotificationService.extraerPedidoId({'pedidoId': 789}), equals(789));
      expect(PushNotificationService.extraerPedidoId({'pedidoId': '101112'}), equals(101112));
      expect(PushNotificationService.extraerPedidoId({'order_id': 99}), equals(99));
      expect(PushNotificationService.extraerPedidoId({'id': '42'}), equals(42));
      expect(PushNotificationService.extraerPedidoId(null), isNull);
      expect(PushNotificationService.extraerPedidoId({}), isNull);
      expect(PushNotificationService.extraerPedidoId({'tipo': 'promocion'}), isNull);
    });

    test('extraerPedidoIdDeTexto identifica IDs con prefijo # en títulos o cuerpos', () {
      expect(
        PushNotificationService.extraerPedidoIdDeTexto('Tu pedido #123 está en camino'),
        equals(123),
      );
      expect(
        PushNotificationService.extraerPedidoIdDeTexto('¡El pedido #98765 ha sido entregado con éxito!'),
        equals(98765),
      );
      expect(
        PushNotificationService.extraerPedidoIdDeTexto('Bienvenido a Kantu Market'),
        isNull,
      );
      expect(PushNotificationService.extraerPedidoIdDeTexto(null), isNull);
      expect(PushNotificationService.extraerPedidoIdDeTexto(''), isNull);
    });

    test('tabChangeNotifier notifica reactivamente el índice de pestaña 2 para Mis Pedidos', () {
      int? ultimoIndice;
      void listener() {
        ultimoIndice = PushNotificationService.tabChangeNotifier.value;
      }

      PushNotificationService.tabChangeNotifier.addListener(listener);
      PushNotificationService.tabChangeNotifier.value = 2;

      expect(ultimoIndice, equals(2));

      PushNotificationService.tabChangeNotifier.removeListener(listener);
    });

    test('init() maneja la ausencia de Firebase de forma resiliente y sin provocar crash', () async {
      // En entorno de test unitario local sin google-services.json ni Firebase mock,
      // init() debe capturar la excepción silenciosamente e imprimir en log sin lanzar un error no manejado.
      expect(
        () async => await PushNotificationService.instance.init(),
        returnsNormally,
      );
    });

    test('SeguimientoPedidoSheet.porId inicializa el widget con el pedidoId correcto', () {
      final sheet = SeguimientoPedidoSheet.porId(pedidoId: 777);
      expect(sheet.pedido.id, equals(777));
      expect(sheet.pedido.estadoActual, equals('pendiente'));
    });
  });
}
