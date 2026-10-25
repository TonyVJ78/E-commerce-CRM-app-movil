import '../constants/api_constants.dart';
import 'marketing_api.dart';

class CampanaCarritoService {
  final MarketingApi api;
  CampanaCarritoService({MarketingApi? api}) : api = api ?? MarketingApi();

  Future<Map<String, dynamic>> obtener(int tiendaId) async =>
      Map<String, dynamic>.from(
        await api.get(ApiConstants.campanaCarrito(tiendaId)) as Map,
      );

  Future<List<Map<String, dynamic>>> carritos(int tiendaId) async =>
      (await api.get(ApiConstants.carritosAbandonados(tiendaId)) as List)
          .map((x) => Map<String, dynamic>.from(x as Map))
          .toList();

  Future<void> guardar(int tiendaId, Map<String, dynamic> config) async {
    final horas = config['horas_inactividad'];
    final descuento = config['descuento_porcentaje'];
    if (horas is! int || horas < 1 || horas > 72) {
      throw const MarketingException(
        'La inactividad debe estar entre 1 y 72 horas.',
      );
    }
    if (descuento is! int || descuento < 0 || descuento > 50) {
      throw const MarketingException('El descuento debe estar entre 0 y 50 %.');
    }
    if ((config['asunto_email'] as String? ?? '').trim().isEmpty ||
        (config['mensaje_email'] as String? ?? '').trim().isEmpty) {
      throw const MarketingException(
        'Completa el asunto y el mensaje de la campaña.',
      );
    }
    await api.patch(ApiConstants.campanaCarrito(tiendaId), config);
  }

  Future<bool> enviarPrueba(int tiendaId) async {
    final data = await api.post(
      ApiConstants.pruebaCampanaCarrito(tiendaId),
      {},
    );
    // El backend puede devolver HTTP 200 y success=true aunque el correo falle.
    return data['enviado'] == true;
  }
}
