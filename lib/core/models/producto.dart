import 'dart:convert';

/// Helpers de parseo tolerante: el mismo modelo se llena desde SQLite (donde
/// todo es INTEGER/REAL/TEXT) y desde la API (donde los decimales llegan como
/// cadenas, p. ej. "280.00").
int _toInt(dynamic value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

int? _toIntOrNull(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double _toDouble(dynamic value, [double fallback = 0.0]) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

double? _toDoubleOrNull(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

bool _toBool(dynamic value, [bool fallback = true]) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final texto = value?.toString().toLowerCase();
  if (texto == null || texto.isEmpty) return fallback;
  return texto == 'true' || texto == '1';
}

/// SQLite guarda listas y mapas como texto JSON; la API los manda ya decodificados.
List<dynamic> _toList(dynamic value) {
  if (value is List) return value;
  if (value is String && value.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is List) return decoded;
    } catch (_) {}
  }
  return const [];
}

Map<String, dynamic> _toMapJson(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  if (value is String && value.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
  }
  return <String, dynamic>{};
}

class Categoria {
  final int id;
  final int tiendaId;
  final String nombre;
  final int? categoriaPadreId;

  Categoria({
    required this.id,
    this.tiendaId = 0,
    required this.nombre,
    this.categoriaPadreId,
  });

  factory Categoria.fromJson(Map<String, dynamic> json) {
    return Categoria(
      id: _toInt(json['id']),
      tiendaId: _toInt(json['tienda'] ?? json['tienda_id']),
      nombre: json['nombre'] ?? '',
      categoriaPadreId: _toIntOrNull(json['categoria_padre']),
    );
  }

  factory Categoria.fromMap(Map<String, dynamic> map) {
    return Categoria(
      id: _toInt(map['id']),
      tiendaId: _toInt(map['tienda_id']),
      nombre: map['nombre'] ?? '',
      categoriaPadreId: _toIntOrNull(map['categoria_padre_id']),
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

/// Variante concreta de un producto (talla, color, presentación...).
/// Es lo que se registra en CU-08 y lo que se agrega al carrito en CU-11.
///
/// Es donde viven el precio y el stock: el producto en sí no los tiene, igual
/// que en el modelo `catalogo.Variante` del backend.
class Variante {
  final int id;
  final int productoId;
  final int tiendaId;
  final String nombre;
  final String sku;
  final double precio;
  final double? precioOferta;
  final int stock;
  final int stockMinimo;
  final Map<String, dynamic> atributos;
  final bool activa;

  Variante({
    required this.id,
    this.productoId = 0,
    this.tiendaId = 0,
    this.nombre = 'Unica',
    this.sku = '',
    required this.precio,
    this.precioOferta,
    this.stock = 0,
    this.stockMinimo = 5,
    this.atributos = const {},
    this.activa = true,
  });

  /// Precio que realmente paga el cliente: el de oferta si existe.
  double get precioEfectivo => precioOferta ?? precio;
  bool get enOferta => precioOferta != null && precioOferta! < precio;
  bool get agotada => stock <= 0;
  bool get bajoStock => stock <= stockMinimo;

  factory Variante.fromJson(Map<String, dynamic> json, {int productoId = 0, int tiendaId = 0}) {
    return Variante(
      id: _toInt(json['id']),
      productoId: _toInt(json['producto'] ?? json['producto_id'], productoId),
      tiendaId: tiendaId,
      nombre: json['nombre'] ?? 'Unica',
      sku: json['sku'] ?? '',
      precio: _toDouble(json['precio']),
      precioOferta: _toDoubleOrNull(json['precio_oferta']),
      stock: _toInt(json['stock']),
      // El serializer del catálogo público no expone stock_minimo.
      stockMinimo: _toInt(json['stock_minimo'], 5),
      atributos: _toMapJson(json['atributos']),
      activa: _toBool(json['activa']),
    );
  }

  factory Variante.fromMap(Map<String, dynamic> map) {
    return Variante(
      id: _toInt(map['id']),
      productoId: _toInt(map['producto_id']),
      tiendaId: _toInt(map['tienda_id']),
      nombre: map['nombre'] ?? 'Unica',
      sku: map['sku'] ?? '',
      precio: _toDouble(map['precio']),
      precioOferta: _toDoubleOrNull(map['precio_oferta']),
      stock: _toInt(map['stock']),
      stockMinimo: _toInt(map['stock_minimo'], 5),
      atributos: _toMapJson(map['atributos']),
      activa: _toBool(map['activa']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id > 0) 'id': id,
      'producto_id': productoId,
      'tienda_id': tiendaId,
      'nombre': nombre,
      'sku': sku,
      'precio': precio,
      'precio_oferta': precioOferta,
      'stock': stock,
      'stock_minimo': stockMinimo,
      'atributos': jsonEncode(atributos),
      'activa': activa ? 1 : 0,
    };
  }

  /// Payload que espera `VarianteInputSerializer` del backend (CU-08).
  Map<String, dynamic> toApiJson() {
    return {
      'sku': sku,
      'nombre': nombre,
      'precio': precio.toStringAsFixed(2),
      if (precioOferta != null) 'precio_oferta': precioOferta!.toStringAsFixed(2),
      'stock': stock,
      'stock_minimo': stockMinimo,
      'atributos': atributos,
      'activa': activa,
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
  final String slug;
  final String descripcion;
  final List<String> etiquetas;
  final List<String> imagenes;
  final bool activo;
  final List<Variante> variantes;

  Producto({
    required this.id,
    required this.tiendaId,
    this.tiendaNombre = '',
    this.categoriaId,
    this.categoriaNombre = '',
    required this.nombre,
    this.slug = '',
    this.descripcion = '',
    this.etiquetas = const [],
    this.imagenes = const [],
    this.activo = true,
    this.variantes = const [],
  });

  List<Variante> get variantesActivas => variantes.where((v) => v.activa).toList();

  /// Variante que se muestra por defecto: la primera activa con stock; si no
  /// hay ninguna con stock, la primera activa; si tampoco, la primera de todas.
  Variante? get variantePrincipal {
    final activas = variantesActivas;
    if (activas.isEmpty) return variantes.isNotEmpty ? variantes.first : null;
    return activas.firstWhere((v) => v.stock > 0, orElse: () => activas.first);
  }

  /// Precio "desde": el más bajo entre las variantes activas.
  double get precioBase {
    final activas = variantesActivas;
    if (activas.isEmpty) return variantes.isEmpty ? 0.0 : variantes.first.precioEfectivo;
    return activas.map((v) => v.precioEfectivo).reduce((a, b) => a < b ? a : b);
  }

  bool get tieneVariasVariantes => variantesActivas.length > 1;
  int get stockTotal => variantesActivas.fold(0, (suma, v) => suma + v.stock);
  bool get agotado => stockTotal <= 0;
  bool get bajoStock => variantesActivas.any((v) => v.bajoStock);

  /// Valor del inventario de este producto, para el resumen por tienda (CU-10).
  double get valorInventario =>
      variantesActivas.fold(0.0, (suma, v) => suma + v.precioEfectivo * v.stock);

  String get imagenPrincipal => imagenes.isNotEmpty ? imagenes.first : '';
  String get sku => variantePrincipal?.sku ?? '';

  /// Lee tanto `ProductoSerializer` (panel de la empresa) como
  /// `ProductoCatalogoSerializer` (catálogo público), que difieren en campos.
  factory Producto.fromJson(Map<String, dynamic> json) {
    final id = _toInt(json['id']);
    final tiendaId = _toInt(json['tienda_id'] ?? json['tienda']);

    return Producto(
      id: id,
      tiendaId: tiendaId,
      tiendaNombre: json['tienda_nombre'] ?? '',
      categoriaId: _toIntOrNull(json['categoria_id'] ?? json['categoria']),
      categoriaNombre: json['categoria_nombre'] ?? '',
      nombre: json['nombre'] ?? '',
      slug: json['slug'] ?? '',
      descripcion: json['descripcion'] ?? '',
      etiquetas: _toList(json['etiquetas']).map((e) => e.toString()).toList(),
      imagenes: _imagenesDesdeJson(json),
      activo: _toBool(json['activo']),
      variantes: _toList(json['variantes'])
          .map((v) => Variante.fromJson(
                Map<String, dynamic>.from(v),
                productoId: id,
                tiendaId: tiendaId,
              ))
          .toList(),
    );
  }

  /// `imagenes` llega como lista de objetos {url, public_id} de Cloudinary,
  /// pero los scripts de seed dejan URLs sueltas. Se acepta cualquiera de las
  /// dos formas, con `imagen_principal`/`imagen_url` como respaldo.
  static List<String> _imagenesDesdeJson(Map<String, dynamic> json) {
    final urls = <String>[];
    for (final imagen in _toList(json['imagenes'])) {
      if (imagen is Map) {
        final url = imagen['url']?.toString() ?? '';
        if (url.isNotEmpty) urls.add(url);
      } else {
        final url = imagen.toString();
        if (url.isNotEmpty) urls.add(url);
      }
    }
    if (urls.isEmpty) {
      final respaldo = json['imagen_principal'] ?? json['imagen_url'] ?? '';
      if (respaldo.toString().isNotEmpty) urls.add(respaldo.toString());
    }
    return urls;
  }

  factory Producto.fromMap(Map<String, dynamic> map, {List<Variante> variantes = const []}) {
    return Producto(
      id: _toInt(map['id']),
      tiendaId: _toInt(map['tienda_id']),
      tiendaNombre: map['tienda_nombre'] ?? '',
      categoriaId: _toIntOrNull(map['categoria_id']),
      categoriaNombre: map['categoria_nombre'] ?? '',
      nombre: map['nombre'] ?? '',
      slug: map['slug'] ?? '',
      descripcion: map['descripcion'] ?? '',
      etiquetas: _toList(map['etiquetas']).map((e) => e.toString()).toList(),
      imagenes: _toList(map['imagenes']).map((e) => e.toString()).toList(),
      activo: _toBool(map['activo']),
      variantes: variantes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id > 0) 'id': id,
      'tienda_id': tiendaId,
      'tienda_nombre': tiendaNombre,
      'categoria_id': categoriaId,
      'categoria_nombre': categoriaNombre,
      'nombre': nombre,
      'slug': slug,
      'descripcion': descripcion,
      'etiquetas': jsonEncode(etiquetas),
      'imagenes': jsonEncode(imagenes),
      'activo': activo ? 1 : 0,
    };
  }

  Producto copyWith({
    int? id,
    int? tiendaId,
    String? tiendaNombre,
    int? categoriaId,
    String? categoriaNombre,
    String? nombre,
    String? slug,
    String? descripcion,
    List<String>? etiquetas,
    List<String>? imagenes,
    bool? activo,
    List<Variante>? variantes,
  }) {
    return Producto(
      id: id ?? this.id,
      tiendaId: tiendaId ?? this.tiendaId,
      tiendaNombre: tiendaNombre ?? this.tiendaNombre,
      categoriaId: categoriaId ?? this.categoriaId,
      categoriaNombre: categoriaNombre ?? this.categoriaNombre,
      nombre: nombre ?? this.nombre,
      slug: slug ?? this.slug,
      descripcion: descripcion ?? this.descripcion,
      etiquetas: etiquetas ?? this.etiquetas,
      imagenes: imagenes ?? this.imagenes,
      activo: activo ?? this.activo,
      variantes: variantes ?? this.variantes,
    );
  }
}
