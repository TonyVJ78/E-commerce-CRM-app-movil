import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../constants/api_constants.dart';
import '../database/db_helper.dart';
import '../models/producto.dart';
import '../models/tienda.dart';
import 'api_service.dart';

/// Resultado de una operación de catálogo.
///
/// `guardadoLocal` distingue el caso incómodo de CU-08: estando en modo
/// servidor, la API no pudo atender (Cloudinary sin configurar, red caída) y el
/// producto quedó guardado sólo en el teléfono. La UI debe decirlo, no fingir
/// que todo salió bien.
class ResultadoCatalogo {
  final bool exito;
  final String mensaje;
  final bool guardadoLocal;
  final Producto? producto;

  const ResultadoCatalogo({
    required this.exito,
    this.mensaje = '',
    this.guardadoLocal = false,
    this.producto,
  });
}

/// Catálogo de productos: registro (CU-08), edición y baja (CU-09) para la
/// empresa, y la vitrina que consume el cliente (CU-11).
///
/// Cada operación intenta primero la API cuando el modo servidor está activo
/// y cae a SQLite si no hay respuesta, igual que `TiendaService`.
class CatalogoService extends ChangeNotifier {
  List<Producto> _productos = [];
  List<Categoria> _categorias = [];
  List<Tienda> _tiendas = [];
  int? _selectedTiendaId;
  int? _selectedCategoriaId;
  String _searchQuery = '';
  bool _isLoading = false;
  bool _incluirInactivos = false;
  String? _errorMessage;

  List<Producto> get productos => _productos;
  List<Categoria> get categorias => _categorias;
  List<Tienda> get tiendas => _tiendas;
  int? get selectedTiendaId => _selectedTiendaId;
  int? get selectedCategoriaId => _selectedCategoriaId;

  /// Nombre de la tienda filtrada, para que la vitrina pueda decir qué se está
  /// viendo sin volver a buscar en la lista.
  String? get selectedTiendaNombre {
    if (_selectedTiendaId == null) return null;
    for (final t in _tiendas) {
      if (t.id == _selectedTiendaId) return t.nombre;
    }
    return null;
  }

  /// Nombre de la categoría seleccionada. En el catálogo general el filtro
  /// viaja por nombre y no por id: cada tienda tiene su propia fila para
  /// "Accesorios", así que el id sólo alcanzaría a los productos de una.
  String? get selectedCategoriaNombre {
    if (_selectedCategoriaId == null) return null;
    for (final c in _categorias) {
      if (c.id == _selectedCategoriaId) return c.nombre;
    }
    return null;
  }

  bool get hayFiltrosActivos =>
      _selectedTiendaId != null || _selectedCategoriaId != null || _searchQuery.trim().isNotEmpty;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  bool get incluirInactivos => _incluirInactivos;
  String? get errorMessage => _errorMessage;

  bool get _online => ApiService.instance.useOnlineBackend;

  // Resumen de inventario de la tienda abierta (CU-10). Cuenta sólo productos
  // activos: los dados de baja siguen listados con el filtro de inactivos, pero
  // ya no son stock vendible.
  Iterable<Producto> get _activos => _productos.where((p) => p.activo);
  int get productosActivos => _activos.length;
  int get stockTotal => _activos.fold(0, (suma, p) => suma + p.stockTotal);
  double get valorInventario => _activos.fold(0.0, (suma, p) => suma + p.valorInventario);
  int get productosAgotados => _activos.where((p) => p.agotado).length;

  /// CU-11 — Catálogo público que ve el cliente, con lo registrado en CU-08
  /// y aún activo tras CU-09.
  Future<void> loadCatalogo({int? tiendaId}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    // El parámetro manda cuando la pantalla abre una tienda concreta; si no,
    // vale el filtro que el cliente eligió en la vitrina.
    final tiendaEfectiva = tiendaId ?? _selectedTiendaId;

    try {
      await _loadTiendas();

      if (_online) {
        final ok = await _loadCatalogoRemoto(tiendaId: tiendaEfectiva);
        if (ok) {
          _isLoading = false;
          notifyListeners();
          return;
        }
        _errorMessage = 'No se pudo contactar al servidor. Mostrando el catálogo '
            'guardado en este dispositivo.';
      }

      _categorias = await DatabaseHelper.instance.getCategorias(tiendaId: tiendaEfectiva);
      _productos = await DatabaseHelper.instance.getProductos(
        tiendaId: tiendaEfectiva,
        // Igual que en remoto: con tienda fija vale el id; sin ella se filtra
        // después por nombre, ya abajo.
        categoriaId: tiendaEfectiva != null ? _selectedCategoriaId : null,
        search: _searchQuery,
      );

      final nombreCategoria = selectedCategoriaNombre;
      if (tiendaEfectiva == null && nombreCategoria != null) {
        _productos = _productos
            .where((p) => p.categoriaNombre.toLowerCase() == nombreCategoria.toLowerCase())
            .toList();
      }
    } catch (e) {
      _errorMessage = 'No se pudo cargar el catálogo: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Tiendas activas para el filtro de la vitrina. Si el servidor no contesta
  /// se queda con las locales, para que el filtro nunca aparezca vacío.
  Future<void> _loadTiendas() async {
    if (_online) {
      try {
        final res = await ApiService.instance.get(ApiConstants.catalogoTiendas);
        if (res.statusCode == 200) {
          _tiendas = _comoLista(res.body).map((t) => Tienda.fromJson(t)).toList();
          return;
        }
      } catch (_) {
        // Cae a las locales.
      }
    }

    try {
      _tiendas = await DatabaseHelper.instance.getTiendas();
    } catch (_) {
      _tiendas = [];
    }
  }

  Future<bool> _loadCatalogoRemoto({int? tiendaId}) async {
    try {
      final categoriasRes = await ApiService.instance.get(
        ApiConstants.catalogoCategorias,
        auth: true,
        query: {if (tiendaId != null) 'tienda': '$tiendaId'},
      );
      if (categoriasRes.statusCode == 200) {
        _categorias = _comoLista(categoriasRes.body).map((c) => Categoria.fromJson(c)).toList();
        // Sin tienda, el listado trae una fila por cada tienda que use ese
        // nombre. Se deduplica aquí y no sólo en el servidor porque el backend
        // desplegado puede ser anterior a ese arreglo.
        if (tiendaId == null) _categorias = _sinNombresRepetidos(_categorias);
      }

      // Con una tienda fija el id de categoría es exacto; sin ella se filtra
      // por nombre para juntar la misma categoría de todas las tiendas.
      final categoriaNombre = selectedCategoriaNombre;
      final productosRes = await ApiService.instance.get(
        ApiConstants.catalogoProductos,
        auth: true,
        query: {
          if (tiendaId != null) 'tienda': '$tiendaId',
          if (_selectedCategoriaId != null && tiendaId != null)
            'categoria': '$_selectedCategoriaId',
          if (_selectedCategoriaId != null && tiendaId == null && categoriaNombre != null)
            'categoria_nombre': categoriaNombre,
          if (_searchQuery.trim().isNotEmpty) 'q': _searchQuery.trim(),
        },
      );
      if (productosRes.statusCode != 200) return false;

      _productos = _comoLista(productosRes.body).map((p) => Producto.fromJson(p)).toList();

      // Red de seguridad: un backend que no conozca `categoria_nombre` ignora
      // el parámetro y devuelve el catálogo entero. Repetir el filtro aquí no
      // cuesta nada cuando el servidor sí lo aplicó, y evita que la categoría
      // elegida parezca no hacer nada cuando no.
      final nombre = categoriaNombre;
      if (tiendaId == null && nombre != null) {
        _productos = _productos
            .where((p) => p.categoriaNombre.toLowerCase() == nombre.toLowerCase())
            .toList();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Catálogo del panel de la empresa. A diferencia del público, incluye los
  /// productos dados de baja en CU-09 si el filtro de inactivos está activo.
  Future<void> loadCatalogoEmpresa(int tiendaId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_online) {
        try {
          final categoriasRes = await ApiService.instance.get(
            ApiConstants.categoriasTienda(tiendaId),
            auth: true,
          );
          if (categoriasRes.statusCode == 200) {
            _categorias = _comoLista(categoriasRes.body).map((c) => Categoria.fromJson(c)).toList();
          }

          final res = await ApiService.instance.get(
            ApiConstants.productosTienda(tiendaId),
            auth: true,
          );
          if (res.statusCode == 200) {
            _productos = _comoLista(res.body).map((p) => Producto.fromJson(p)).toList();
            _aplicarFiltrosEnMemoria();
            _isLoading = false;
            notifyListeners();
            return;
          }
        } catch (_) {
          // Cae al modo local.
        }
      }

      _categorias = await DatabaseHelper.instance.getCategorias(tiendaId: tiendaId);
      _productos = await DatabaseHelper.instance.getProductos(
        tiendaId: tiendaId,
        categoriaId: _selectedCategoriaId,
        search: _searchQuery,
        soloActivos: !_incluirInactivos,
      );
    } catch (e) {
      _errorMessage = 'No se pudo cargar el catálogo: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// El endpoint de la empresa devuelve todos los productos sin filtros, así
  /// que la búsqueda y el filtro por categoría se aplican aquí.
  void _aplicarFiltrosEnMemoria() {
    var lista = _productos;
    if (!_incluirInactivos) {
      lista = lista.where((p) => p.activo).toList();
    }
    if (_selectedCategoriaId != null) {
      lista = lista.where((p) => p.categoriaId == _selectedCategoriaId).toList();
    }
    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      lista = lista
          .where((p) =>
              p.nombre.toLowerCase().contains(q) ||
              p.descripcion.toLowerCase().contains(q) ||
              p.etiquetas.any((e) => e.toLowerCase().contains(q)))
          .toList();
    }
    _productos = lista;
  }

  /// Filtro por tienda de la vitrina del cliente. Volver a tocar la tienda ya
  /// seleccionada la quita, igual que el de categorías.
  ///
  /// Al cambiar de tienda se suelta la categoría: las categorías pertenecen a
  /// una tienda, así que conservarla dejaría la vitrina vacía sin explicación.
  void setTienda(int? tiendaId) {
    final nueva = _selectedTiendaId == tiendaId ? null : tiendaId;
    if (nueva == _selectedTiendaId) return;
    _selectedTiendaId = nueva;
    _selectedCategoriaId = null;
    loadCatalogo();
  }

  void setCategoria(int? categoriaId, {int? tiendaId, bool empresa = false}) {
    _selectedCategoriaId = _selectedCategoriaId == categoriaId ? null : categoriaId;
    if (empresa && tiendaId != null) {
      loadCatalogoEmpresa(tiendaId);
    } else {
      loadCatalogo(tiendaId: tiendaId);
    }
  }

  void setSearch(String query, {int? tiendaId, bool empresa = false}) {
    _searchQuery = query;
    if (empresa && tiendaId != null) {
      loadCatalogoEmpresa(tiendaId);
    } else {
      loadCatalogo(tiendaId: tiendaId);
    }
  }

  void setIncluirInactivos(bool valor, int tiendaId) {
    _incluirInactivos = valor;
    loadCatalogoEmpresa(tiendaId);
  }

  void limpiarFiltros() {
    _selectedTiendaId = null;
    _selectedCategoriaId = null;
    _searchQuery = '';
    _incluirInactivos = false;
    _errorMessage = null;
  }

  /// Quita los filtros de la vitrina y recarga, sin tocar el de inactivos que
  /// es del panel de la empresa.
  void limpiarFiltrosVitrina() {
    _selectedTiendaId = null;
    _selectedCategoriaId = null;
    _searchQuery = '';
    loadCatalogo();
  }

  // =========================================================================
  // CU-08 — Registrar productos
  // =========================================================================

  Future<ResultadoCatalogo> createProducto({
    required Producto producto,
    required List<Variante> variantes,
    List<String> rutasImagenes = const [],
    String? usuarioEmail,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      if (_online) {
        final resultado = await _createProductoRemoto(
          producto: producto,
          variantes: variantes,
          rutasImagenes: rutasImagenes,
        );
        // Un error de validación es del usuario: se le devuelve tal cual en vez
        // de guardar en local a sus espaldas.
        if (resultado != null) {
          _isLoading = false;
          if (resultado.exito && resultado.producto != null) {
            _productos.insert(0, resultado.producto!);
          }
          notifyListeners();
          return resultado;
        }
      }

      final creado = await DatabaseHelper.instance.createProducto(
        producto: producto,
        variantes: variantes,
        usuarioEmail: usuarioEmail,
      );
      _productos.insert(0, creado);
      _isLoading = false;
      notifyListeners();

      return ResultadoCatalogo(
        exito: true,
        producto: creado,
        guardadoLocal: _online,
        mensaje: _online
            ? 'El servidor no pudo registrar el producto (Cloudinary no está configurado). Se guardó en este dispositivo.'
            : 'Producto registrado en el catálogo de la tienda.',
      );
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return ResultadoCatalogo(exito: false, mensaje: 'No se pudo registrar el producto: $e');
    }
  }

  /// Envía el producto al backend como `multipart/form-data`.
  ///
  /// Devuelve `null` cuando el servidor no está disponible (503 de Cloudinary,
  /// timeout, red caída) para que quien llama decida caer al modo local.
  Future<ResultadoCatalogo?> _createProductoRemoto({
    required Producto producto,
    required List<Variante> variantes,
    required List<String> rutasImagenes,
  }) async {
    try {
      final res = await ApiService.instance.multipart(
        ApiConstants.productosTienda(producto.tiendaId),
        campos: {
          'nombre': producto.nombre,
          'descripcion': producto.descripcion,
          if (producto.categoriaId != null) 'categoria_id': '${producto.categoriaId}',
          'activo': producto.activo.toString(),
          'etiquetas': jsonEncode(producto.etiquetas),
          'variantes': jsonEncode(variantes.map((v) => v.toApiJson()).toList()),
        },
        archivos: rutasImagenes,
      );

      if (res.statusCode == 201 || res.statusCode == 200) {
        return ResultadoCatalogo(
          exito: true,
          producto: Producto.fromJson(jsonDecode(res.body)),
          mensaje: 'Producto registrado en el servidor.',
        );
      }

      // 503 = Cloudinary no configurado o caído: es del servidor, no del usuario.
      if (res.statusCode >= 500) return null;

      return ResultadoCatalogo(exito: false, mensaje: _mensajeError(res.body));
    } catch (_) {
      return null;
    }
  }

  // =========================================================================
  // CU-09 — Editar y eliminar productos
  // =========================================================================

  Future<ResultadoCatalogo> updateProducto({
    required Producto producto,
    required List<Variante> variantes,
    String? imagenUrl,
    String? usuarioEmail,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      if (_online) {
        final resultado = await _updateProductoRemoto(
          producto: producto,
          variantes: variantes,
          imagenUrl: imagenUrl,
        );
        if (resultado != null) {
          _isLoading = false;
          if (resultado.exito && resultado.producto != null) {
            _reemplazarEnLista(resultado.producto!);
          }
          notifyListeners();
          return resultado;
        }
      }

      final actualizado = await DatabaseHelper.instance.updateProducto(
        producto: producto,
        variantes: variantes,
        usuarioEmail: usuarioEmail,
      );
      if (actualizado != null) _reemplazarEnLista(actualizado);
      _isLoading = false;
      notifyListeners();

      return ResultadoCatalogo(
        exito: true,
        producto: actualizado,
        guardadoLocal: _online,
        mensaje: _online
            ? 'No se pudo contactar al servidor. Los cambios se guardaron en este dispositivo.'
            : 'Producto actualizado.',
      );
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return ResultadoCatalogo(exito: false, mensaje: 'No se pudo actualizar el producto: $e');
    }
  }

  /// `PATCH` del producto.
  ///
  /// Limitación del backend: su `ProductoSerializer.update` sólo propaga
  /// `precio` y `stock` a la **primera** variante. Las demás variantes se
  /// editan únicamente en la base local; el formulario lo advierte.
  Future<ResultadoCatalogo?> _updateProductoRemoto({
    required Producto producto,
    required List<Variante> variantes,
    String? imagenUrl,
  }) async {
    try {
      final principal = variantes.isNotEmpty ? variantes.first : null;
      final res = await ApiService.instance.patch(
        ApiConstants.productoDetalle(producto.tiendaId, producto.id),
        {
          'nombre': producto.nombre,
          'descripcion': producto.descripcion,
          'activo': producto.activo,
          'etiquetas': producto.etiquetas,
          if (producto.categoriaId != null) 'categoria': producto.categoriaId,
          if (imagenUrl != null && imagenUrl.isNotEmpty) 'imagen_url': imagenUrl,
          if (principal != null) 'precio': principal.precio.toStringAsFixed(2),
          if (principal != null) 'stock': principal.stock,
        },
        auth: true,
      );

      if (res.statusCode == 200) {
        return ResultadoCatalogo(
          exito: true,
          producto: Producto.fromJson(jsonDecode(res.body)),
          mensaje: 'Producto actualizado en el servidor.',
        );
      }
      if (res.statusCode >= 500) return null;
      return ResultadoCatalogo(exito: false, mensaje: _mensajeError(res.body));
    } catch (_) {
      return null;
    }
  }

  /// Baja del producto. Tanto el backend como la base local hacen borrado
  /// **lógico**, para no romper los pedidos históricos que lo referencian.
  Future<ResultadoCatalogo> eliminarProducto(Producto producto, {String? usuarioEmail}) async {
    return _cambiarEstado(producto, activo: false, usuarioEmail: usuarioEmail, esBaja: true);
  }

  Future<ResultadoCatalogo> toggleActivo(Producto producto, {String? usuarioEmail}) async {
    return _cambiarEstado(producto, activo: !producto.activo, usuarioEmail: usuarioEmail);
  }

  Future<ResultadoCatalogo> _cambiarEstado(
    Producto producto, {
    required bool activo,
    String? usuarioEmail,
    bool esBaja = false,
  }) async {
    try {
      var sincronizado = false;

      if (_online) {
        try {
          final res = esBaja
              ? await ApiService.instance.delete(
                  ApiConstants.productoDetalle(producto.tiendaId, producto.id),
                  auth: true,
                )
              : await ApiService.instance.patch(
                  ApiConstants.productoDetalle(producto.tiendaId, producto.id),
                  {'activo': activo},
                  auth: true,
                );
          sincronizado = res.statusCode >= 200 && res.statusCode < 300;
        } catch (_) {
          sincronizado = false;
        }
      }

      await DatabaseHelper.instance.setProductoActivo(
        producto.id,
        activo,
        usuarioEmail: usuarioEmail,
      );

      final actualizado = producto.copyWith(activo: activo);
      if (_incluirInactivos || activo) {
        _reemplazarEnLista(actualizado);
      } else {
        _productos.removeWhere((p) => p.id == producto.id);
      }
      notifyListeners();

      return ResultadoCatalogo(
        exito: true,
        producto: actualizado,
        guardadoLocal: _online && !sincronizado,
        mensaje: esBaja
            ? 'Producto eliminado del catálogo.'
            : (activo ? 'Producto activado.' : 'Producto desactivado.'),
      );
    } catch (e) {
      return ResultadoCatalogo(exito: false, mensaje: 'No se pudo completar la operación: $e');
    }
  }

  void _reemplazarEnLista(Producto producto) {
    final indice = _productos.indexWhere((p) => p.id == producto.id);
    if (indice >= 0) {
      _productos[indice] = producto;
    } else {
      _productos.insert(0, producto);
    }
  }

  // =========================================================================
  // Categorías
  // =========================================================================

  /// Crea la categoría en local y la agrega a la lista en memoria.
  ///
  /// En modo servidor no hay endpoint para crearlas: el backend las crea solo
  /// al editar un producto mandando `categoria` como texto.
  Future<Categoria> crearCategoriaLocal(int tiendaId, String nombre) async {
    final categoria = await DatabaseHelper.instance.getOrCreateCategoria(tiendaId, nombre);
    if (!_categorias.any((c) => c.id == categoria.id)) {
      _categorias = [..._categorias, categoria];
      notifyListeners();
    }
    return categoria;
  }

  // =========================================================================
  // Utilidades
  // =========================================================================

  /// Deja una sola categoría por nombre, conservando el orden de llegada.
  static List<Categoria> _sinNombresRepetidos(List<Categoria> categorias) {
    final vistos = <String>{};
    return categorias.where((c) => vistos.add(c.nombre.toLowerCase())).toList();
  }

  /// Acepta la lista plana que devuelve DRF sin paginación y, por si acaso, la
  /// forma paginada `{"results": [...]}`.
  static List<Map<String, dynamic>> _comoLista(String body) {
    final decoded = jsonDecode(body);
    final lista = decoded is Map && decoded['results'] is List ? decoded['results'] : decoded;
    if (lista is! List) return [];
    return lista.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Convierte el cuerpo de error de DRF en una frase legible.
  static String _mensajeError(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map) {
        if (data['detail'] != null) return data['detail'].toString();
        final partes = <String>[];
        data.forEach((campo, valor) {
          final texto = valor is List ? valor.join(' ') : valor.toString();
          partes.add(campo == 'non_field_errors' ? texto : '$campo: $texto');
        });
        if (partes.isNotEmpty) return partes.join('\n');
      }
      return data.toString();
    } catch (_) {
      return 'El servidor rechazó la operación.';
    }
  }
}
