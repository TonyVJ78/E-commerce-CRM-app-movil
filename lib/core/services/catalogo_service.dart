import 'package:flutter/foundation.dart';
import '../database/db_helper.dart';
import '../models/producto.dart';

class CatalogoService extends ChangeNotifier {
  List<Producto> _productos = [];
  List<Categoria> _categorias = [];
  int? _selectedCategoriaId;
  String _searchQuery = '';
  bool _isLoading = false;

  List<Producto> get productos => _productos;
  List<Categoria> get categorias => _categorias;
  int? get selectedCategoriaId => _selectedCategoriaId;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;

  Future<void> loadCatalogo({int? tiendaId}) async {
    _isLoading = true;
    notifyListeners();

    try {
      _categorias = await DatabaseHelper.instance.getCategorias(tiendaId: tiendaId);
      await fetchProductos(tiendaId: tiendaId);
    } catch (_) {}

    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchProductos({int? tiendaId}) async {
    _productos = await DatabaseHelper.instance.getProductos(
      tiendaId: tiendaId,
      categoriaId: _selectedCategoriaId,
      search: _searchQuery,
    );
    notifyListeners();
  }

  void setCategoria(int? categoriaId, {int? tiendaId}) {
    if (_selectedCategoriaId == categoriaId) {
      _selectedCategoriaId = null;
    } else {
      _selectedCategoriaId = categoriaId;
    }
    fetchProductos(tiendaId: tiendaId);
  }

  void setSearch(String query, {int? tiendaId}) {
    _searchQuery = query;
    fetchProductos(tiendaId: tiendaId);
  }

  Future<bool> createProducto({
    required int tiendaId,
    required String tiendaNombre,
    int? categoriaId,
    String? categoriaNombre,
    required String nombre,
    required String descripcion,
    required double precioBase,
    required String sku,
    required String imagenUrl,
    required int stock,
  }) async {
    try {
      await DatabaseHelper.instance.createProducto({
        'tienda_id': tiendaId,
        'tienda_nombre': tiendaNombre,
        'categoria_id': categoriaId,
        'categoria_nombre': categoriaNombre ?? 'General',
        'nombre': nombre,
        'descripcion': descripcion,
        'precio_base': precioBase,
        'sku': sku,
        'activo': 1,
        'imagen_url': imagenUrl.isNotEmpty ? imagenUrl : 'https://images.unsplash.com/photo-1594938298603-c8148c4dae35?w=500',
        'stock': stock,
      });
      await fetchProductos(tiendaId: tiendaId);
      return true;
    } catch (_) {
      return false;
    }
  }
}
