import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kantu_market/core/models/tienda.dart';
import 'package:kantu_market/core/services/api_service.dart';
import 'package:kantu_market/core/services/crm_service.dart';
import 'package:kantu_market/features/empresa/crm/tienda_crm_screen.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    ApiService.instance.setOnlineBackend(false);
  });

  final testTienda = Tienda(
    id: 1,
    propietarioId: 10,
    propietarioEmail: 'vendedor@kantu.bo',
    nombre: 'Café Yungas Especial',
    slug: 'cafe-yungas-especial',
    colorPrimario: '#C8102E',
    descripcion: 'Café orgánico de altura cultivado en los Yungas paceños',
    fechaCreacion: '2026-10-04T12:00:00',
    activa: true,
  );

  testWidgets('TiendaCrmScreen renderiza métricas, buscador y clientes de la tienda (CU-15)', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final crmService = CrmService();
    await crmService.loadClientes(testTienda.id);

    await tester.pumpWidget(
      ChangeNotifierProvider<CrmService>.value(
        value: crmService,
        child: MaterialApp(
          home: TiendaCrmScreen(tienda: testTienda),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Título y métricas en AppBar y StatCards
    expect(find.text('Micro-CRM • Café Yungas Especial'), findsOneWidget);
    expect(find.text('Cartera Total'), findsOneWidget);
    expect(find.text('LTV Promedio'), findsOneWidget);
    expect(find.text('Clientes VIP'), findsOneWidget);

    // 2. Chips de segmentos
    expect(find.text('Todos'), findsOneWidget);
    expect(find.text('VIP'), findsWidgets);
    expect(find.text('Frecuente'), findsWidgets);
    expect(find.text('Nuevo'), findsWidgets);
    expect(find.text('Inactivo'), findsWidgets);

    // 3. Tarjeta de cliente
    expect(find.text('Elena Ramos Velasco'), findsOneWidget);
    expect(find.text('elena.ramos@kantu.bo'), findsOneWidget);

    // 4. Filtrar por segmento VIP
    await tester.tap(find.text('VIP').first);
    await tester.pumpAndSettle();

    expect(crmService.selectedSegmento, 'VIP');
    expect(find.text('Elena Ramos Velasco'), findsOneWidget);
    expect(find.text('Mariana Zeballos Pardo'), findsOneWidget);
    expect(find.text('Carlos Mendoza Arteaga'), findsNothing); // Frecuente oculto

    // 5. Restablecer a Todos
    await tester.tap(find.text('Todos').first);
    await tester.pumpAndSettle();

    // 6. Abrir FichaClienteSheet
    await tester.tap(find.text('Elena Ramos Velasco'));
    await tester.pumpAndSettle();

    // 7. Verificar Ficha del Cliente en BottomSheet
    expect(find.text('Compras'), findsOneWidget);
    expect(find.text('Deseos'), findsOneWidget);
    expect(find.text('Bitácora & Notas'), findsOneWidget);
    expect(find.text('Total Pedidos'), findsOneWidget);

    // 8. Cambiar a Bitácora & Notas
    await tester.tap(find.text('Bitácora & Notas'));
    await tester.pumpAndSettle();

    expect(find.text('Nueva Nota Comercial'), findsOneWidget);
    expect(find.text('Guardar en Bitácora'), findsOneWidget);
  });
}
