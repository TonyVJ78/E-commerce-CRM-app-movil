import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../database/db_helper.dart';
import '../models/tienda.dart';
import '../models/usuario.dart';
import 'api_service.dart';
import '../constants/api_constants.dart';

class TiendaService extends ChangeNotifier {
  List<Tienda> _tiendas = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Tienda> get tiendas => _tiendas;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadTiendas({Usuario? usuario}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (ApiService.instance.useOnlineBackend) {
        try {
          final res = await ApiService.instance.get(ApiConstants.tiendas, auth: true);
          if (res.statusCode == 200) {
            final List<dynamic> data = jsonDecode(res.body);
            _tiendas = data.map((json) => Tienda.fromJson(json)).toList();
            _isLoading = false;
            notifyListeners();
            return;
          }
        } catch (_) {}
      }

      // Base de datos Local
      if (usuario != null && usuario.rol == 'empresa') {
        _tiendas = await DatabaseHelper.instance.getTiendas(propietarioId: usuario.id);
      } else {
        _tiendas = await DatabaseHelper.instance.getTiendas();
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error al cargar tiendas: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Tienda?> createTienda({
    required Usuario usuario,
    required String nombre,
    String? slug,
    String? logoUrl,
    String colorPrimario = '#C8102E',
    String? descripcion,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final payload = {
        'nombre': nombre.trim(),
        'slug': slug?.trim().isNotEmpty == true ? slug!.trim() : null,
        'logo_url': logoUrl?.trim().isNotEmpty == true ? logoUrl!.trim() : '',
        'color_primario': colorPrimario,
        'descripcion': descripcion?.trim() ?? '',
      };

      if (ApiService.instance.useOnlineBackend) {
        try {
          final res = await ApiService.instance.post(ApiConstants.tiendas, payload, auth: true);
          if (res.statusCode == 201 || res.statusCode == 200) {
            final t = Tienda.fromJson(jsonDecode(res.body));
            _tiendas.insert(0, t);
            _isLoading = false;
            notifyListeners();
            return t;
          }
        } catch (_) {}
      }

      final nuevaTienda = await DatabaseHelper.instance.createTienda(payload, usuario);
      _tiendas.insert(0, nuevaTienda);
      _isLoading = false;
      notifyListeners();
      return nuevaTienda;
    } catch (e) {
      _errorMessage = 'Error al crear la tienda: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }
}
