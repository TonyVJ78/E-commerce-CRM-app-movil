class Categoria {
  final int id;
  final int tiendaId;
  final String nombre;
  final int? categoriaPadreId;

  Categoria({
    required this.id,
    required this.tiendaId,
    required this.nombre,
    this.categoriaPadreId,
  });

  factory Categoria.fromMap(Map<String, dynamic> map) {
    return Categoria(
      id: map['id'] is int ? map['id'] : int.tryParse(map['id'].toString()) ?? 0,
      tiendaId: map['tienda_id'] is int ? map['tienda_id'] : int.tryParse(map['tienda_id'].toString()) ?? 0,
      nombre: map['nombre'] ?? '',
      categoriaPadreId: map['categoria_padre_id'] != null
          ? int.tryParse(map['categoria_padre_id'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tienda_id': tiendaId,
      'nombre': nombre,
      'categoria_padre_id': categoriaPadreId,
    };
  }
}

class Producto {
  final int id;
  final int tiendaId;
  final String tiendaNombre;
  final int? categoriaId;
  final String categoriaNombre;
  final String nombre;
  final String descripcion;
  final double precioBase;
  final String sku;
  final bool activo;
  final String imagenUrl;
  final int stock;

  Producto({
    required this.id,
    required this.tiendaId,
    this.tiendaNombre = '',
    this.categoriaId,
    this.categoriaNombre = '',
    required this.nombre,
    this.descripcion = '',
    required this.precioBase,
    this.sku = '',
    this.activo = true,
    this.imagenUrl = '',
    this.stock = 10,
  });

  factory Producto.fromMap(Map<String, dynamic> map) {
    return Producto(
      id: map['id'] is int ? map['id'] : int.tryParse(map['id'].toString()) ?? 0,
      tiendaId: map['tienda_id'] is int ? map['tienda_id'] : int.tryParse(map['tienda_id'].toString()) ?? 0,
      tiendaNombre: map['tienda_nombre'] ?? '',
      categoriaId: map['categoria_id'] != null ? int.tryParse(map['categoria_id'].toString()) : null,
      categoriaNombre: map['categoria_nombre'] ?? '',
      nombre: map['nombre'] ?? '',
      descripcion: map['descripcion'] ?? '',
      precioBase: (map['precio_base'] is num)
          ? (map['precio_base'] as num).toDouble()
          : double.tryParse(map['precio_base']?.toString() ?? '0.0') ?? 0.0,
      sku: map['sku'] ?? '',
      activo: map['activo'] == 1 || map['activo'] == true,
      imagenUrl: map['imagen_url'] ?? '',
      stock: map['stock'] is int ? map['stock'] : int.tryParse(map['stock']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tienda_id': tiendaId,
      'tienda_nombre': tiendaNombre,
      'categoria_id': categoriaId,
      'categoria_nombre': categoriaNombre,
      'nombre': nombre,
      'descripcion': descripcion,
      'precio_base': precioBase,
      'sku': sku,
      'activo': activo ? 1 : 0,
      'imagen_url': imagenUrl,
      'stock': stock,
    };
  }
}

class VarianteProducto {
  final int id;
  final int tiendaId;
  final int productoId;
  final String nombreVariante;
  final double precioAdicional;
  final String skuVariante;

  VarianteProducto({
    required this.id,
    required this.tiendaId,
    required this.productoId,
    required this.nombreVariante,
    this.precioAdicional = 0.0,
    this.skuVariante = '',
  });

  factory VarianteProducto.fromMap(Map<String, dynamic> map) {
    return VarianteProducto(
      id: map['id'] is int ? map['id'] : int.tryParse(map['id'].toString()) ?? 0,
      tiendaId: map['tienda_id'] is int ? map['tienda_id'] : int.tryParse(map['tienda_id'].toString()) ?? 0,
      productoId: map['producto_id'] is int ? map['producto_id'] : int.tryParse(map['producto_id'].toString()) ?? 0,
      nombreVariante: map['nombre_variante'] ?? '',
      precioAdicional: (map['precio_adicional'] is num)
          ? (map['precio_adicional'] as num).toDouble()
          : double.tryParse(map['precio_adicional']?.toString() ?? '0.0') ?? 0.0,
      skuVariante: map['sku_variante'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tienda_id': tiendaId,
      'producto_id': productoId,
      'nombre_variante': nombreVariante,
      'precio_adicional': precioAdicional,
      'sku_variante': skuVariante,
    };
  }
}
