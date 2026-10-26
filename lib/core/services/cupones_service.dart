import '../constants/api_constants.dart';
import 'marketing_api.dart';

class CuponesService {
  final MarketingApi api;
  CuponesService({MarketingApi? api}) : api = api ?? MarketingApi();
  Future<Map<String, dynamic>> deTienda(int id) async =>
      Map<String, dynamic>.from(
        await api.get(ApiConstants.cuponesTienda(id)) as Map,
      );
  Future<List<Map<String, dynamic>>> disponibles() async =>
      (await api.get(ApiConstants.cuponesCliente) as List)
          .map((x) => Map<String, dynamic>.from(x as Map))
          .toList();
  Future<void> crear(int id, Map<String, dynamic> datos) async {
    await api.post(ApiConstants.cuponesTienda(id), datos);
  }

  Future<void> activar(int tiendaId, int id, bool activo) async {
    await api.patch(ApiConstants.cuponTienda(tiendaId, id), {'activo': activo});
  }

  Future<Map<String, dynamic>> validar(int tiendaId, String codigo) async {
    if (codigo.trim().isEmpty) {
      throw const MarketingException('Escribe el código del cupón.');
    }
    return Map<String, dynamic>.from(
      await api.post(ApiConstants.validarCupon, {
        'tienda_id': tiendaId,
        'codigo': codigo.trim().toUpperCase(),
      }) as Map,
    );
  }
}
