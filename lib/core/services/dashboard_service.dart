import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../constants/api_constants.dart';
import '../database/db_helper.dart';
import '../models/usuario.dart';
import 'api_service.dart';

/// Un día de la serie de ventas de la última semana.
class VentaDia {
  final String fecha; // 'dd/MM'
  final int cantidad;

  const VentaDia({required this.fecha, required this.cantidad});

  factory VentaDia.fromJson(Map<String, dynamic> json) {
    final cantidad = json['cantidad'];
    return VentaDia(
      fecha: json['fecha']?.toString() ?? '',
      cantidad: cantidad is num ? cantidad.toInt() : int.tryParse('$cantidad') ?? 0,
    );
  }
}

/// KPIs del panel del vendedor (CU-10).
///
/// Tiene exactamente los campos que devuelve `GET /api/tiendas/dashboard/`,
/// para que la pantalla no distinga si vino del servidor o de SQLite.
class ResumenVendedor {
  final int totalProductos;
  final int productosActivos;
  final int totalPedidos;
  final int pedidosPendientes;
  final double ingresosTotales;
  final int productosBajoStock;
  final List<VentaDia> graficoVentas;

  const ResumenVendedor({
    this.totalProductos = 0,
    this.productosActivos = 0,
    this.totalPedidos = 0,
    this.pedidosPendientes = 0,
    this.ingresosTotales = 0.0,
    this.productosBajoStock = 0,
    this.graficoVentas = const [],
  });

  int get productosInactivos => totalProductos - productosActivos;
  int get unidadesVendidasSemana => graficoVentas.fold(0, (suma, d) => suma + d.cantidad);
  bool get sinVentasEstaSemana => unidadesVendidasSemana == 0;

  factory ResumenVendedor.fromJson(Map<String, dynamic> json) {
    int entero(dynamic valor) {
      if (valor is num) return valor.toInt();
      return int.tryParse(valor?.toString() ?? '') ?? 0;
    }

    return ResumenVendedor(
      totalProductos: entero(json['total_productos']),
      productosActivos: entero(json['productos_activos']),
      totalPedidos: entero(json['total_pedidos']),
      pedidosPendientes: entero(json['pedidos_pendientes']),
      ingresosTotales: (json['ingresos_totales'] is num)
          ? (json['ingresos_totales'] as num).toDouble()
          : double.tryParse(json['ingresos_totales']?.toString() ?? '0') ?? 0.0,
      productosBajoStock: entero(json['productos_bajo_stock']),
      graficoVentas: (json['grafico_ventas'] as List? ?? const [])
          .map((d) => VentaDia.fromJson(Map<String, dynamic>.from(d as Map)))
          .toList(),
    );
  }
}

/// CU-10 — Métricas del panel de gestión de la empresa.
class DashboardService extends ChangeNotifier {
  ResumenVendedor _resumen = const ResumenVendedor();
  bool _isLoading = false;
  bool _desdeServidor = false;
  String? _errorMessage;

  ResumenVendedor get resumen => _resumen;
  bool get isLoading => _isLoading;

  /// `true` si los KPIs mostrados vienen de la API y no de la base local.
  bool get desdeServidor => _desdeServidor;
  String? get errorMessage => _errorMessage;

  Future<void> loadDashboard(Usuario? usuario) async {
    if (usuario == null) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (ApiService.instance.useOnlineBackend) {
        try {
          final res = await ApiService.instance.get(
            ApiConstants.dashboardVendedor,
            auth: true,
          );
          if (res.statusCode == 200) {
            _resumen = ResumenVendedor.fromJson(jsonDecode(res.body));
            _desdeServidor = true;
            _isLoading = false;
            notifyListeners();
            return;
          }
        } catch (_) {
          // Cae al cálculo local.
        }
      }

      final datos = await DatabaseHelper.instance.getDashboardVendedor(usuario.id);
      _resumen = ResumenVendedor.fromJson(datos);
      _desdeServidor = false;
    } catch (e) {
      _errorMessage = 'No se pudieron cargar las métricas: $e';
    }

    _isLoading = false;
    notifyListeners();
  }
}
