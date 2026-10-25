/// Contrato de la API de soporte compartida con Web (CU-25 del Sprint 3).
class MensajeSoporte {
  final String autor;
  final String contenido;
  final String? adjunto;
  final DateTime? fecha;

  MensajeSoporte.fromJson(Map<String, dynamic> json)
    : autor = (json['autor']?['nombre'] ?? json['autor']?['email'] ?? 'Soporte')
          .toString(),
      contenido = (json['contenido'] ?? '').toString(),
      adjunto = json['archivo_adjunto'] as String?,
      fecha = DateTime.tryParse((json['fecha_envio'] ?? '').toString());
}

class TicketSoporte {
  final int id;
  final String codigo;
  final String asunto;
  final String descripcion;
  final String tienda;
  final String estado;
  final String estadoEtiqueta;
  final String tipoEtiqueta;
  final String? pedidoCodigo;
  final List<MensajeSoporte> mensajes;

  TicketSoporte.fromJson(Map<String, dynamic> json)
    : id = (json['id'] as num).toInt(),
      codigo = (json['codigo_ticket'] ?? '').toString(),
      asunto = (json['asunto'] ?? '').toString(),
      descripcion = (json['descripcion'] ?? '').toString(),
      tienda = (json['tienda_nombre'] ?? '').toString(),
      estado = (json['estado'] ?? '').toString(),
      estadoEtiqueta = (json['estado_display'] ?? json['estado'] ?? '')
          .toString(),
      tipoEtiqueta = (json['tipo_display'] ?? json['tipo'] ?? '').toString(),
      pedidoCodigo = json['pedido_codigo'] as String?,
      mensajes = (json['mensajes'] as List? ?? [])
          .map(
            (item) =>
                MensajeSoporte.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(growable: false);
}
