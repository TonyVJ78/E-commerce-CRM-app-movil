import 'package:flutter_test/flutter_test.dart';
import 'package:kantu_market/core/models/crm_cliente_model.dart';
import 'package:kantu_market/core/models/crm_interaccion_model.dart';
import 'package:kantu_market/core/services/api_service.dart';
import 'package:kantu_market/core/services/crm_service.dart';

void main() {
  setUp(() {
    ApiService.instance.setOnlineBackend(false);
  });

  group('CrmClienteModel & CrmInteraccionModel (CU-15)', () {
    test('CrmClienteModel serializa y calcula iniciales y ticket promedio', () {
      final now = DateTime.now();
      final cliente = CrmClienteModel(
        id: 1,
        tiendaId: 10,
        nombre: 'Elena Ramos',
        correo: 'elena.ramos@kantu.bo',
        telefono: '+591 72019482',
        fechaPrimeraCompra: now.subtract(const Duration(days: 90)),
        fechaUltimaCompra: now,
        ltv: 1200.00,
        totalPedidos: 4,
        segmento: 'VIP',
      );

      expect(cliente.initials, 'ER');
      expect(cliente.formattedLtv, 'Bs. 1200.00');
      expect(cliente.ticketPromedio, 300.00);
      expect(cliente.formattedTicketPromedio, 'Bs. 300.00');

      final map = cliente.toMap();
      final fromMap = CrmClienteModel.fromMap(map);
      expect(fromMap.id, 1);
      expect(fromMap.nombre, 'Elena Ramos');
      expect(fromMap.segmento, 'VIP');
      expect(fromMap.ltv, 1200.00);
    });

    test('CrmInteraccionModel serializa y mapea tipo/estado correctamente', () {
      final now = DateTime.now();
      final inter = CrmInteraccionModel(
        id: 42,
        clienteId: 1,
        tiendaId: 10,
        tipo: 'Venta',
        mensaje: 'Coordinó compra mayorista de quinua',
        fecha: now,
        estado: 'Resuelto',
      );

      final map = inter.toMap();
      final fromMap = CrmInteraccionModel.fromMap(map);
      expect(fromMap.id, 42);
      expect(fromMap.tipo, 'Venta');
      expect(fromMap.mensaje, 'Coordinó compra mayorista de quinua');
      expect(fromMap.estado, 'Resuelto');
    });
  });

  group('CrmService (CU-15)', () {
    test('loadClientes carga cartera y calcula métricas agregadas', () async {
      final crm = CrmService();
      await crm.loadClientes(10);

      expect(crm.totalClientes, greaterThan(0));
      expect(crm.ltvPromedio, greaterThan(0));
      expect(crm.clientesVipCount, greaterThan(0));
      expect(crm.clientesFrecuentesCount, greaterThan(0));
      expect(crm.clientesFiltrados.length, crm.totalClientes);
    });

    test('setSegmento filtra por segmento adecuadamente', () async {
      final crm = CrmService();
      await crm.loadClientes(10);

      crm.setSegmento('VIP');
      expect(crm.selectedSegmento, 'VIP');
      for (final c in crm.clientesFiltrados) {
        expect(c.segmento.toLowerCase(), 'vip');
      }

      crm.setSegmento('Todos');
      expect(crm.selectedSegmento, isNull);
      expect(crm.clientesFiltrados.length, crm.totalClientes);
    });

    test('setSearch filtra en tiempo real por nombre, correo o teléfono', () async {
      final crm = CrmService();
      await crm.loadClientes(10);

      crm.setSearch('Elena');
      expect(crm.clientesFiltrados.length, 1);
      expect(crm.clientesFiltrados.first.nombre, contains('Elena'));

      crm.setSearch('71538921');
      expect(crm.clientesFiltrados.length, 1);
      expect(crm.clientesFiltrados.first.telefono, contains('71538921'));

      crm.setSearch('busqueda-sin-resultados-xyz');
      expect(crm.clientesFiltrados, isEmpty);
    });

    test('registrarInteraccion añade nota a la bitácora del cliente', () async {
      final crm = CrmService();
      await crm.loadClientes(10);

      final ok = await crm.registrarInteraccion(
        clienteId: 101,
        tiendaId: 10,
        tipo: 'Consulta',
        mensaje: 'Preguntó por nuevo lote de café orgánico',
        estado: 'Pendiente',
      );

      expect(ok, isTrue);

      final interacciones = await crm.loadInteracciones(101, 10);
      expect(interacciones.first.mensaje, 'Preguntó por nuevo lote de café orgánico');
      expect(interacciones.first.tipo, 'Consulta');
      expect(interacciones.first.estado, 'Pendiente');
    });

    test('loadHistorialCompras y loadWishlist retornan datos demostrables', () async {
      final crm = CrmService();
      final compras = await crm.loadHistorialCompras(101, 10);
      expect(compras, isNotEmpty);
      expect(compras.first['total'], isNotNull);

      final wishlist = await crm.loadWishlist(101, 10);
      expect(wishlist, isNotEmpty);
      expect(wishlist.first, isNotEmpty);
    });
  });
}
