class BitacoraAcceso {
  final int id;
  final int usuarioId;
  final String usuarioEmail;
  final String fecha;
  final String ip;
  final String dispositivo;

  BitacoraAcceso({
    required this.id,
    required this.usuarioId,
    required this.usuarioEmail,
    required this.fecha,
    required this.ip,
    required this.dispositivo,
  });

  factory BitacoraAcceso.fromMap(Map<String, dynamic> map) {
    return BitacoraAcceso(
      id: map['id'] is int ? map['id'] : int.tryParse(map['id'].toString()) ?? 0,
      usuarioId: map['usuario_id'] is int ? map['usuario_id'] : int.tryParse(map['usuario_id'].toString()) ?? 0,
      usuarioEmail: map['usuario_email'] ?? '',
      fecha: map['fecha'] ?? '',
      ip: map['ip'] ?? '127.0.0.1',
      dispositivo: map['dispositivo'] ?? 'Móvil Android',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'usuario_id': usuarioId,
      'usuario_email': usuarioEmail,
      'fecha': fecha,
      'ip': ip,
      'dispositivo': dispositivo,
    };
  }
}

class LogAuditoria {
  final int id;
  final String usuarioEmail;
  final String tablaAfectada;
  final int registroId;
  final String accion;
  final String fecha;

  LogAuditoria({
    required this.id,
    required this.usuarioEmail,
    required this.tablaAfectada,
    required this.registroId,
    required this.accion,
    required this.fecha,
  });

  factory LogAuditoria.fromMap(Map<String, dynamic> map) {
    return LogAuditoria(
      id: map['id'] is int ? map['id'] : int.tryParse(map['id'].toString()) ?? 0,
      usuarioEmail: map['usuario_email'] ?? '',
      tablaAfectada: map['tabla_afectada'] ?? '',
      registroId: map['registro_id'] is int ? map['registro_id'] : int.tryParse(map['registro_id'].toString()) ?? 0,
      accion: map['accion'] ?? '',
      fecha: map['fecha'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'usuario_email': usuarioEmail,
      'tabla_afectada': tablaAfectada,
      'registro_id': registroId,
      'accion': accion,
      'fecha': fecha,
    };
  }
}
