import 'producto.dart';

class ItemCarrito {
  final int id;
  final Producto producto;
  int cantidad;

  ItemCarrito({
    required this.id,
    required this.producto,
    this.cantidad = 1,
  });

  double get total => producto.precioBase * cantidad;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'producto_id': producto.id,
      'cantidad': cantidad,
    };
  }
}

class Pedido {
  final int id;
  final int clienteId;
  final String clienteEmail;
  final int tiendaId;
  final String tiendaNombre;
  final String estadoActual;
  final String fecha;
  final double subtotal;
  final double total;
  final String metodoPago;
  final List<ItemPedido> items;

  Pedido({
    required this.id,
    required this.clienteId,
    this.clienteEmail = '',
    required this.tiendaId,
    this.tiendaNombre = '',
    this.estadoActual = 'pendiente',
    required this.fecha,
    required this.subtotal,
    required this.total,
    this.metodoPago = 'QR Simple (Bolivia)',
    this.items = const [],
  });

  factory Pedido.fromMap(Map<String, dynamic> map, {List<ItemPedido> items = const []}) {
    return Pedido(
      id: map['id'] is int ? map['id'] : int.tryParse(map['id'].toString()) ?? 0,
      clienteId: map['cliente_id'] is int ? map['cliente_id'] : int.tryParse(map['cliente_id'].toString()) ?? 0,
      clienteEmail: map['cliente_email'] ?? '',
      tiendaId: map['tienda_id'] is int ? map['tienda_id'] : int.tryParse(map['tienda_id'].toString()) ?? 0,
      tiendaNombre: map['tienda_nombre'] ?? '',
      estadoActual: map['estado_actual'] ?? 'pendiente',
      fecha: map['fecha'] ?? '',
      subtotal: (map['subtotal'] is num)
          ? (map['subtotal'] as num).toDouble()
          : double.tryParse(map['subtotal']?.toString() ?? '0.0') ?? 0.0,
      total: (map['total'] is num)
          ? (map['total'] as num).toDouble()
          : double.tryParse(map['total']?.toString() ?? '0.0') ?? 0.0,
      metodoPago: map['metodo_pago'] ?? 'QR Simple (Bolivia)',
      items: items,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cliente_id': clienteId,
      'cliente_email': clienteEmail,
      'tienda_id': tiendaId,
      'tienda_nombre': tiendaNombre,
      'estado_actual': estadoActual,
      'fecha': fecha,
      'subtotal': subtotal,
      'total': total,
      'metodo_pago': metodoPago,
    };
  }
}

class ItemPedido {
  final int id;
  final int pedidoId;
  final int productoId;
  final String productoNombre;
  final int cantidad;
  final double precioUnitario;

  ItemPedido({
    required this.id,
    required this.pedidoId,
    required this.productoId,
    required this.productoNombre,
    required this.cantidad,
    required this.precioUnitario,
  });

  double get subtotal => cantidad * precioUnitario;

  factory ItemPedido.fromMap(Map<String, dynamic> map) {
    return ItemPedido(
      id: map['id'] is int ? map['id'] : int.tryParse(map['id'].toString()) ?? 0,
      pedidoId: map['pedido_id'] is int ? map['pedido_id'] : int.tryParse(map['pedido_id'].toString()) ?? 0,
      productoId: map['producto_id'] is int ? map['producto_id'] : int.tryParse(map['producto_id'].toString()) ?? 0,
      productoNombre: map['producto_nombre'] ?? '',
      cantidad: map['cantidad'] is int ? map['cantidad'] : int.tryParse(map['cantidad'].toString()) ?? 1,
      precioUnitario: (map['precio_unitario'] is num)
          ? (map['precio_unitario'] as num).toDouble()
          : double.tryParse(map['precio_unitario']?.toString() ?? '0.0') ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'pedido_id': pedidoId,
      'producto_id': productoId,
      'producto_nombre': productoNombre,
      'cantidad': cantidad,
      'precio_unitario': precioUnitario,
    };
  }
}
