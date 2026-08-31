import 'package:flutter/foundation.dart';
import '../database/db_helper.dart';
import '../models/producto.dart';
import '../models/pedido.dart';
import '../models/usuario.dart';

class CartService extends ChangeNotifier {
  final Map<int, ItemCarrito> _items = {};
  List<Pedido> _pedidos = [];
  bool _isLoading = false;

  Map<int, ItemCarrito> get items => _items;
  List<ItemCarrito> get itemsList => _items.values.toList();
  int get itemCount => _items.values.fold(0, (sum, item) => sum + item.cantidad);
  double get totalAmount => _items.values.fold(0.0, (sum, item) => sum + item.total);
  List<Pedido> get pedidos => _pedidos;
  bool get isLoading => _isLoading;

  void addItem(Producto producto, {int cantidad = 1}) {
    if (_items.containsKey(producto.id)) {
      _items[producto.id]!.cantidad += cantidad;
    } else {
      _items[producto.id] = ItemCarrito(
        id: DateTime.now().millisecondsSinceEpoch,
        producto: producto,
        cantidad: cantidad,
      );
    }
    notifyListeners();
  }

  void removeSingleItem(int productoId) {
    if (!_items.containsKey(productoId)) return;
    if (_items[productoId]!.cantidad > 1) {
      _items[productoId]!.cantidad -= 1;
    } else {
      _items.remove(productoId);
    }
    notifyListeners();
  }

  void removeItem(int productoId) {
    _items.remove(productoId);
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }

  Future<Pedido?> checkout({
    required Usuario cliente,
    required String metodoPago,
  }) async {
    if (_items.isEmpty) return null;
    _isLoading = true;
    notifyListeners();

    try {
      final firstItem = _items.values.first;
      final pedido = await DatabaseHelper.instance.createPedido(
        clienteId: cliente.id,
        clienteEmail: cliente.email,
        tiendaId: firstItem.producto.tiendaId,
        tiendaNombre: firstItem.producto.tiendaNombre.isNotEmpty
            ? firstItem.producto.tiendaNombre
            : 'Kantu Market',
        total: totalAmount,
        metodoPago: metodoPago,
        items: itemsList,
      );

      _items.clear();
      _pedidos.insert(0, pedido);
      _isLoading = false;
      notifyListeners();
      return pedido;
    } catch (_) {
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<void> loadPedidos({int? clienteId, int? tiendaId}) async {
    _isLoading = true;
    notifyListeners();
    try {
      _pedidos = await DatabaseHelper.instance.getPedidos(clienteId: clienteId, tiendaId: tiendaId);
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
  }
}
