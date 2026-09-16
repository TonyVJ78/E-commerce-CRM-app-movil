import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../constants/api_constants.dart';
import '../database/db_helper.dart';
import '../models/pedido.dart';
import '../models/producto.dart';
import '../models/usuario.dart';
import 'api_service.dart';

/// Carrito de compras (CU-11).
///
/// Tiene dos respaldos según el modo de la app:
/// - **Autónomo**: las tablas `carrito` / `item_carrito` de SQLite, así el
///   carrito sobrevive al cierre de la app.
/// - **Servidor**: el carrito del backend es la fuente de verdad; se lee con
///   `GET /pedidos/carrito/` y se modifica con los endpoints de ítems.
///
/// El backend agrupa por tienda (un `Carrito` por cliente y tienda), y aquí se
/// respeta esa forma con [porTienda].
class CartService extends ChangeNotifier {
  List<ItemCarrito> _items = [];
  final Map<int, String> _nombresTienda = {};
  List<Pedido> _pedidos = [];
  bool _isLoading = false;
  String? _errorMessage;
  int? _clienteId;

  List<ItemCarrito> get itemsList => _items;
  bool get isEmpty => _items.isEmpty;
  int get itemCount => _items.fold(0, (suma, item) => suma + item.cantidad);
  double get totalAmount => _items.fold(0.0, (suma, item) => suma + item.total);
  List<Pedido> get pedidos => _pedidos;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool get _online => ApiService.instance.useOnlineBackend;

  /// Ítems agrupados por tienda, en el mismo orden en que se agregaron.
  Map<int, List<ItemCarrito>> get porTienda {
    final grupos = <int, List<ItemCarrito>>{};
    for (final item in _items) {
      grupos.putIfAbsent(item.producto.tiendaId, () => []).add(item);
    }
    return grupos;
  }

  String nombreTienda(int tiendaId) {
    if (_nombresTienda.containsKey(tiendaId)) return _nombresTienda[tiendaId]!;
    for (final item in _items) {
      if (item.producto.tiendaId == tiendaId && item.producto.tiendaNombre.isNotEmpty) {
        return item.producto.tiendaNombre;
      }
    }
    return 'Kantu Market';
  }

  // =========================================================================
  // Carga
  // =========================================================================

  Future<void> loadCarrito(Usuario? cliente) async {
    if (cliente == null) return;
    _clienteId = cliente.id;
    _isLoading = true;
    notifyListeners();

    try {
      if (_online && await _loadCarritoRemoto()) {
        _isLoading = false;
        notifyListeners();
        return;
      }
      _items = await DatabaseHelper.instance.getItemsCarrito(cliente.id);
    } catch (e) {
      _errorMessage = 'No se pudo cargar el carrito: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> _loadCarritoRemoto() async {
    try {
      final res = await ApiService.instance.get(ApiConstants.carrito, auth: true);
      if (res.statusCode != 200) return false;

      final data = jsonDecode(res.body);
      final carritos = data['carritos'];
      if (carritos is! List) return false;

      final items = <ItemCarrito>[];
      for (final carrito in carritos) {
        final tiendaId = _entero(carrito['tienda_id']);
        final tiendaNombre = carrito['tienda_nombre']?.toString() ?? '';
        if (tiendaNombre.isNotEmpty) _nombresTienda[tiendaId] = tiendaNombre;

        for (final item in (carrito['items'] as List? ?? const [])) {
          items.add(_itemDesdeApi(Map<String, dynamic>.from(item)));
        }
      }

      _items = items;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Reconstruye producto y variante desde `ItemCarritoDetalleSerializer`, que
  /// trae los datos aplanados en vez de los objetos completos.
  ItemCarrito _itemDesdeApi(Map<String, dynamic> json) {
    final tiendaId = _entero(json['tienda_id']);
    final productoId = _entero(json['producto_id']);
    final varianteId = _entero(json['variante_id']);
    final imagen = json['producto_imagen']?.toString() ?? '';

    final variante = Variante(
      id: varianteId,
      productoId: productoId,
      tiendaId: tiendaId,
      nombre: json['variante_nombre']?.toString() ?? 'Unica',
      sku: json['variante_sku']?.toString() ?? '',
      precio: double.tryParse(json['precio_unitario']?.toString() ?? '0') ?? 0.0,
      stock: _entero(json['stock_disponible']),
    );

    return ItemCarrito(
      id: _entero(json['id']),
      idRemoto: _entero(json['id']),
      cantidad: _entero(json['cantidad'], 1),
      variante: variante,
      producto: Producto(
        id: productoId,
        tiendaId: tiendaId,
        tiendaNombre: json['tienda_nombre']?.toString() ?? '',
        nombre: json['producto_nombre']?.toString() ?? '',
        imagenes: imagen.isNotEmpty ? [imagen] : const [],
        variantes: [variante],
      ),
    );
  }

  static int _entero(dynamic valor, [int fallback = 0]) {
    if (valor is int) return valor;
    if (valor is num) return valor.toInt();
    return int.tryParse(valor?.toString() ?? '') ?? fallback;
  }

  // =========================================================================
  // Agregar al carrito (CU-11)
  // =========================================================================

  /// Agrega [cantidad] unidades de [variante] al carrito.
  ///
  /// En modo servidor el backend fija `cantidad = 1` al crear el ítem, así que
  /// para pedir más de una unidad se hace un `PATCH` con el total. Si la
  /// variante ya estaba en el carrito, se ajusta el ítem existente en vez de
  /// crear uno duplicado.
  Future<bool> agregar({
    required Producto producto,
    required Variante variante,
    int cantidad = 1,
    Usuario? cliente,
  }) async {
    if (cantidad < 1) return false;
    _errorMessage = null;

    final existente = _buscarPorVariante(variante.id);
    final nuevaCantidad = (existente?.cantidad ?? 0) + cantidad;

    if (variante.stock > 0 && nuevaCantidad > variante.stock) {
      _errorMessage = 'Solo quedan ${variante.stock} unidades de ${variante.nombre}.';
      notifyListeners();
      return false;
    }

    if (_online) {
      final ok = await _agregarRemoto(
        producto: producto,
        variante: variante,
        existente: existente,
        nuevaCantidad: nuevaCantidad,
      );
      if (ok) return true;
      // Si el servidor falla se sigue por la vía local para no perder la acción.
    }

    final clienteId = cliente?.id ?? _clienteId;
    if (clienteId == null) return false;
    _clienteId = clienteId;

    await DatabaseHelper.instance.upsertItemCarrito(
      clienteId: clienteId,
      producto: producto,
      variante: variante,
      cantidad: cantidad,
    );
    _items = await DatabaseHelper.instance.getItemsCarrito(clienteId);
    notifyListeners();
    return true;
  }

  Future<bool> _agregarRemoto({
    required Producto producto,
    required Variante variante,
    required ItemCarrito? existente,
    required int nuevaCantidad,
  }) async {
    try {
      if (existente?.idRemoto != null) {
        return await _patchCantidadRemota(existente!.idRemoto!, nuevaCantidad);
      }

      final res = await ApiService.instance.post(
        ApiConstants.carritoItems,
        {'tienda_id': producto.tiendaId, 'variante_id': variante.id},
        auth: true,
      );
      if (res.statusCode != 201) {
        if (res.statusCode < 500) {
          _errorMessage = _mensajeError(res.body);
          notifyListeners();
        }
        return false;
      }

      final creado = jsonDecode(res.body);
      final itemId = _entero(creado['id']);

      // El backend siempre crea el ítem con cantidad 1.
      if (nuevaCantidad > 1 && itemId > 0) {
        await _patchCantidadRemota(itemId, nuevaCantidad, recargar: false);
      }

      await _loadCarritoRemoto();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _patchCantidadRemota(int itemId, int cantidad, {bool recargar = true}) async {
    try {
      final res = await ApiService.instance.patch(
        ApiConstants.carritoItemDetalle(itemId),
        {'cantidad': cantidad},
        auth: true,
      );
      if (res.statusCode != 200) return false;
      if (recargar) {
        await _loadCarritoRemoto();
        notifyListeners();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  ItemCarrito? _buscarPorVariante(int varianteId) {
    for (final item in _items) {
      if (item.variante.id == varianteId) return item;
    }
    return null;
  }

  // =========================================================================
  // Modificar y quitar
  // =========================================================================

  Future<void> cambiarCantidad(ItemCarrito item, int cantidad) async {
    if (cantidad <= 0) {
      await eliminar(item);
      return;
    }
    if (item.variante.stock > 0 && cantidad > item.variante.stock) {
      _errorMessage = 'Solo quedan ${item.variante.stock} unidades disponibles.';
      notifyListeners();
      return;
    }

    if (_online && item.idRemoto != null) {
      if (await _patchCantidadRemota(item.idRemoto!, cantidad)) return;
    }

    await DatabaseHelper.instance.setCantidadItemCarrito(item.id, cantidad);
    item.cantidad = cantidad;
    notifyListeners();
  }

  Future<void> incrementar(ItemCarrito item) => cambiarCantidad(item, item.cantidad + 1);
  Future<void> decrementar(ItemCarrito item) => cambiarCantidad(item, item.cantidad - 1);

  Future<void> eliminar(ItemCarrito item) async {
    if (_online && item.idRemoto != null) {
      try {
        final res = await ApiService.instance.delete(
          ApiConstants.carritoItemDetalle(item.idRemoto!),
          auth: true,
        );
        if (res.statusCode >= 200 && res.statusCode < 300) {
          await _loadCarritoRemoto();
          notifyListeners();
          return;
        }
      } catch (_) {}
    }

    await DatabaseHelper.instance.removeItemCarrito(item.id);
    _items.removeWhere((i) => i.id == item.id);
    notifyListeners();
  }

  Future<void> vaciar() async {
    if (_online) {
      try {
        await ApiService.instance.delete(ApiConstants.carrito, auth: true);
      } catch (_) {}
    }
    if (_clienteId != null) {
      await DatabaseHelper.instance.clearCarrito(_clienteId!);
    }
    _items = [];
    notifyListeners();
  }

  void limpiarError() {
    _errorMessage = null;
  }

  // =========================================================================
  // Checkout y pedidos
  // =========================================================================

  /// Confirma el pedido.
  ///
  /// El backend todavía no expone un endpoint para crear pedidos desde el
  /// carrito, así que el pedido se registra en la base local en ambos modos; en
  /// modo servidor además se vacía el carrito remoto.
  Future<Pedido?> checkout({
    required Usuario cliente,
    required String metodoPago,
  }) async {
    if (_items.isEmpty) return null;
    // Descuenta el stock de las variantes registradas en CU-08.
    _isLoading = true;
    _clienteId = cliente.id;
    notifyListeners();

    try {
      final primerItem = _items.first;
      final tiendaId = primerItem.producto.tiendaId;
      final itemsDeLaTienda = _items.where((i) => i.producto.tiendaId == tiendaId).toList();
      final totalTienda = itemsDeLaTienda.fold(0.0, (suma, i) => suma + i.total);

      final pedido = await DatabaseHelper.instance.createPedido(
        clienteId: cliente.id,
        clienteEmail: cliente.email,
        tiendaId: tiendaId,
        tiendaNombre: nombreTienda(tiendaId),
        total: totalTienda,
        metodoPago: metodoPago,
        items: itemsDeLaTienda,
      );

      for (final item in itemsDeLaTienda) {
        await eliminar(item);
      }

      _pedidos.insert(0, pedido);
      _isLoading = false;
      notifyListeners();
      return pedido;
    } catch (e) {
      _errorMessage = 'No se pudo confirmar el pedido: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // =========================================================================
  // Pago con tarjeta — Stripe (CU-19 / RF-M-05)
  // =========================================================================

  /// Crea el PaymentIntent de Stripe para el total actual del carrito remoto.
  /// Solo tiene sentido en modo servidor: el pago se valida contra el backend.
  Future<Map<String, dynamic>?> crearIntentoPagoStripe() async {
    try {
      final res = await ApiService.instance.post(ApiConstants.carritoPagoIntento, {}, auth: true);
      if (res.statusCode != 200) {
        _errorMessage = _mensajeError(res.body);
        notifyListeners();
        return null;
      }
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      _errorMessage = 'No se pudo iniciar el pago con Stripe: $e';
      notifyListeners();
      return null;
    }
  }

  /// Confirma la compra contra el backend real una vez que el pago con
  /// Stripe ya se confirmó del lado del cliente.
  ///
  /// A diferencia de [checkout] (que solo escribe en SQLite y sólo procesa la
  /// primera tienda), este método sí llama a `POST /pedidos/carrito/checkout/`
  /// y liquida TODAS las tiendas del carrito en un único pedido por tienda,
  /// igual que el checkout web: tiene que ser así porque el PaymentIntent ya
  /// se cobró por el total combinado del carrito, no por una tienda sola.
  Future<Pedido?> checkoutStripeRemoto({
    required Usuario cliente,
    required String paymentIntentId,
  }) async {
    if (_items.isEmpty) return null;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiService.instance.post(
        ApiConstants.carritoCheckout,
        {'metodo_pago': 'stripe', 'payment_intent_id': paymentIntentId},
        auth: true,
      );

      if (res.statusCode != 201) {
        _errorMessage = _mensajeError(res.body);
        _isLoading = false;
        notifyListeners();
        return null;
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final idsPedidos = (data['pedidos'] as List? ?? const [])
          .map((e) => _entero(e))
          .toList();
      final primerTiendaId = _items.first.producto.tiendaId;

      final pedido = Pedido(
        id: idsPedidos.isNotEmpty ? idsPedidos.first : 0,
        clienteId: cliente.id,
        clienteEmail: cliente.email,
        tiendaId: primerTiendaId,
        tiendaNombre: nombreTienda(primerTiendaId),
        estadoActual: 'completado',
        fecha: DateTime.now().toIso8601String(),
        subtotal: totalAmount,
        total: totalAmount,
        metodoPago: 'Tarjeta (Stripe)',
      );

      _items = [];
      _pedidos.insert(0, pedido);
      _isLoading = false;
      notifyListeners();
      return pedido;
    } catch (e) {
      _errorMessage = 'No se pudo confirmar el pedido: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<void> loadPedidos({int? clienteId, int? tiendaId, int? propietarioId}) async {
    _isLoading = true;
    notifyListeners();
    try {
      _pedidos = await DatabaseHelper.instance.getPedidos(
        clienteId: clienteId,
        tiendaId: tiendaId,
        propietarioId: propietarioId,
      );
    } catch (e) {
      _errorMessage = 'No se pudieron cargar los pedidos: $e';
    }
    _isLoading = false;
    notifyListeners();
  }

  static String _mensajeError(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map) {
        if (data['detail'] != null) return data['detail'].toString();
        final partes = <String>[];
        data.forEach((campo, valor) {
          partes.add(valor is List ? valor.join(' ') : valor.toString());
        });
        if (partes.isNotEmpty) return partes.join('\n');
      }
      return data.toString();
    } catch (_) {
      return 'El servidor rechazó la operación.';
    }
  }
}
