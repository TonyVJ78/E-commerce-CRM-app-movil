import 'marketing_api.dart';

class NotificacionCliente {
  final int id;
  final String titulo, mensaje, tiendaNombre;
  final DateTime? fecha;
  final Map<String, dynamic> datos;
  bool leida;
  NotificacionCliente.fromJson(Map<String, dynamic> j)
    : id = j['id'] as int,
      titulo = j['titulo']?.toString() ?? 'Kantu Market',
      mensaje = j['mensaje']?.toString() ?? '',
      tiendaNombre = j['tienda_nombre']?.toString() ?? '',
      fecha = DateTime.tryParse(j['fecha']?.toString() ?? '')?.toLocal(),
      datos = {
        ...Map<String, dynamic>.from(j['datos'] ?? {}),
        'tipo': j['tipo'],
        'tienda_id': j['tienda_id'],
      },
      leida = j['leida'] == true;
}

class PaginaNotificaciones {
  final List<NotificacionCliente> items;
  final int? siguiente;
  PaginaNotificaciones(this.items, this.siguiente);
}

class NotificacionesService {
  final MarketingApi api;
  NotificacionesService({MarketingApi? api}) : api = api ?? MarketingApi();
  Future<PaginaNotificaciones> listar({int? antes}) async {
    final data = await api.get(
      '/marketing/notificaciones/${antes == null ? '' : '?antes=$antes'}',
    );
    return PaginaNotificaciones(
      (data['notificaciones'] as List)
          .map(
            (e) => NotificacionCliente.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList(),
      data['siguiente'] as int?,
    );
  }

  Future<void> marcarLeida(int id) async {
    await api.patch('/marketing/notificaciones/$id/', {'leida': true});
  }
}
