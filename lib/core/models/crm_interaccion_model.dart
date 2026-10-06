import 'package:flutter/material.dart';

/// Modelo para el registro de contactos, consultas y notas comerciales (CU-15).
///
/// Refleja la entidad Django `crm.InteraccionCliente`.
class CrmInteraccionModel {
  final int? id;
  final int clienteId;
  final int tiendaId;
  final String tipo; // 'Consulta', 'Soporte', 'Venta'
  final String mensaje;
  final DateTime fecha;
  final String estado; // 'Pendiente', 'Resuelto', 'En Seguimiento'

  const CrmInteraccionModel({
    this.id,
    required this.clienteId,
    required this.tiendaId,
    required this.tipo,
    required this.mensaje,
    required this.fecha,
    required this.estado,
  });

  IconData get icon {
    switch (tipo.toLowerCase()) {
      case 'venta':
        return Icons.shopping_bag_outlined;
      case 'soporte':
        return Icons.support_agent_outlined;
      case 'consulta':
      default:
        return Icons.chat_bubble_outline;
    }
  }

  Color get color {
    switch (tipo.toLowerCase()) {
      case 'venta':
        return const Color(0xFF27AE60);
      case 'soporte':
        return const Color(0xFFEF4444);
      case 'consulta':
      default:
        return const Color(0xFF3B82F6);
    }
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'cliente_id': clienteId,
      'tienda_id': tiendaId,
      'tipo': tipo,
      'mensaje': mensaje,
      'fecha': fecha.toIso8601String(),
      'estado': estado,
    };
  }

  factory CrmInteraccionModel.fromMap(Map<String, dynamic> map) {
    return CrmInteraccionModel(
      id: map['id'] is int ? map['id'] : int.tryParse(map['id']?.toString() ?? ''),
      clienteId: map['cliente_id'] is int
          ? map['cliente_id']
          : int.tryParse(map['cliente_id']?.toString() ?? '0') ?? 0,
      tiendaId: map['tienda_id'] is int
          ? map['tienda_id']
          : int.tryParse(map['tienda_id']?.toString() ?? '0') ?? 0,
      tipo: map['tipo']?.toString() ?? 'Consulta',
      mensaje: map['mensaje']?.toString() ?? '',
      fecha: map['fecha'] != null
          ? DateTime.tryParse(map['fecha'].toString()) ?? DateTime.now()
          : DateTime.now(),
      estado: map['estado']?.toString() ?? 'Resuelto',
    );
  }
}
