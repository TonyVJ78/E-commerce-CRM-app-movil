import 'producto.dart';

/// Línea del carrito. Apunta a una **variante** concreta, que es la que tiene
/// precio y stock, igual que `pedidos.ItemCarrito` en el backend.
class ItemCarrito {
  /// Id de la fila en la tabla local `item_carrito`.
  final int id;

  /// Id del `item_carrito` en el backend, cuando el ítem se creó contra la API.
  /// Es lo que necesitan `PATCH`/`DELETE /pedidos/carrito/items/<id>/`.
  int? idRemoto;

  final Producto producto;
  final Variante variante;
  int cantidad;

  ItemCarrito({
    required this.id,
    required this.producto,
    required this.variante,
    this.cantidad = 1,
    this.idRemoto,
  });

  double get precioUnitario => variante.precioEfectivo;
  double get total => precioUnitario * cantidad;

  /// Nombre de variante que vale la pena mostrar: 'Unica' no aporta nada.
  String get etiquetaVariante =>
      variante.nombre.toLowerCase() == 'unica' ? '' : variante.nombre;
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
  final int varianteId;
  final String productoNombre;
  final String varianteNombre;
  final int cantidad;
  final double precioUnitario;

  ItemPedido({
    required this.id,
    required this.pedidoId,
    required this.productoId,
    this.varianteId = 0,
    required this.productoNombre,
    this.varianteNombre = '',
    required this.cantidad,
    required this.precioUnitario,
  });

  double get subtotal => cantidad * precioUnitario;

  /// Descripción de una línea del pedido, con la variante sólo si aporta.
  String get descripcion => varianteNombre.isEmpty || varianteNombre.toLowerCase() == 'unica'
      ? productoNombre
      : '$productoNombre · $varianteNombre';

  factory ItemPedido.fromMap(Map<String, dynamic> map) {
    return ItemPedido(
      id: map['id'] is int ? map['id'] : int.tryParse(map['id'].toString()) ?? 0,
      pedidoId: map['pedido_id'] is int ? map['pedido_id'] : int.tryParse(map['pedido_id'].toString()) ?? 0,
      productoId: map['producto_id'] is int ? map['producto_id'] : int.tryParse(map['producto_id'].toString()) ?? 0,
      varianteId: map['variante_id'] is int
          ? map['variante_id']
          : int.tryParse(map['variante_id']?.toString() ?? '0') ?? 0,
      productoNombre: map['producto_nombre'] ?? '',
      varianteNombre: map['variante_nombre'] ?? '',
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
      'variante_id': varianteId,
      'producto_nombre': productoNombre,
      'variante_nombre': varianteNombre,
      'cantidad': cantidad,
      'precio_unitario': precioUnitario,
    };
  }
}
