/// Modelo para la cartera de clientes de una tienda en el Micro-CRM (CU-15).
///
/// Alineado con los modelos Django `crm.FichaCliente`, `crm.Segmento` y las
/// métricas calculadas sobre los pedidos de la tienda.
class CrmClienteModel {
  final int id;
  final int tiendaId;
  final String nombre;
  final String correo;
  final String? telefono;
  final DateTime? fechaPrimeraCompra;
  final DateTime? fechaUltimaCompra;
  final double ltv; // Life-Time Value acumulado en Bs.
  final int totalPedidos;
  final String segmento; // 'VIP', 'Frecuente', 'Nuevo', 'Inactivo'

  const CrmClienteModel({
    required this.id,
    required this.tiendaId,
    required this.nombre,
    required this.correo,
    this.telefono,
    this.fechaPrimeraCompra,
    this.fechaUltimaCompra,
    required this.ltv,
    required this.totalPedidos,
    required this.segmento,
  });

  /// Iniciales del cliente para el avatar visual
  String get initials {
    final parts = nombre.trim().split(' ');
    if (parts.isEmpty || parts[0].isEmpty) return 'CL';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  /// Formato amigable en Bolivianos (Bs.)
  String get formattedLtv {
    return 'Bs. ${ltv.toStringAsFixed(2)}';
  }

  /// Ticket promedio por compra
  double get ticketPromedio {
    if (totalPedidos <= 0) return 0.0;
    return ltv / totalPedidos;
  }

  String get formattedTicketPromedio {
    return 'Bs. ${ticketPromedio.toStringAsFixed(2)}';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tienda_id': tiendaId,
      'nombre': nombre,
      'correo': correo,
      'telefono': telefono,
      'fecha_primera_compra': fechaPrimeraCompra?.toIso8601String(),
      'fecha_ultima_compra': fechaUltimaCompra?.toIso8601String(),
      'ltv': ltv,
      'total_pedidos': totalPedidos,
      'segmento': segmento,
    };
  }

  factory CrmClienteModel.fromMap(Map<String, dynamic> map) {
    return CrmClienteModel(
      id: map['id'] is int ? map['id'] : int.tryParse(map['id']?.toString() ?? '0') ?? 0,
      tiendaId: map['tienda_id'] is int
          ? map['tienda_id']
          : int.tryParse(map['tienda_id']?.toString() ?? '0') ?? 0,
      nombre: map['nombre']?.toString() ??
          ('${map['first_name'] ?? ''} ${map['last_name'] ?? ''}').trim(),
      correo: map['correo']?.toString() ?? map['email']?.toString() ?? '',
      telefono: map['telefono']?.toString(),
      fechaPrimeraCompra: map['fecha_primera_compra'] != null
          ? DateTime.tryParse(map['fecha_primera_compra'].toString())
          : null,
      fechaUltimaCompra: map['fecha_ultima_compra'] != null
          ? DateTime.tryParse(map['fecha_ultima_compra'].toString())
          : null,
      ltv: map['ltv'] != null
          ? (map['ltv'] is num ? (map['ltv'] as num).toDouble() : double.tryParse(map['ltv'].toString()) ?? 0.0)
          : 0.0,
      totalPedidos: map['total_pedidos'] is int
          ? map['total_pedidos']
          : int.tryParse(map['total_pedidos']?.toString() ?? '0') ?? 0,
      segmento: map['segmento']?.toString() ?? 'Nuevo',
    );
  }

  CrmClienteModel copyWith({
    int? id,
    int? tiendaId,
    String? nombre,
    String? correo,
    String? telefono,
    DateTime? fechaPrimeraCompra,
    DateTime? fechaUltimaCompra,
    double? ltv,
    int? totalPedidos,
    String? segmento,
  }) {
    return CrmClienteModel(
      id: id ?? this.id,
      tiendaId: tiendaId ?? this.tiendaId,
      nombre: nombre ?? this.nombre,
      correo: correo ?? this.correo,
      telefono: telefono ?? this.telefono,
      fechaPrimeraCompra: fechaPrimeraCompra ?? this.fechaPrimeraCompra,
      fechaUltimaCompra: fechaUltimaCompra ?? this.fechaUltimaCompra,
      ltv: ltv ?? this.ltv,
      totalPedidos: totalPedidos ?? this.totalPedidos,
      segmento: segmento ?? this.segmento,
    );
  }
}
