class Rol {
  final int id;
  final String nombre;

  Rol({required this.id, required this.nombre});

  factory Rol.fromMap(Map<String, dynamic> map) {
    return Rol(
      id: map['id'] is int ? map['id'] : int.tryParse(map['id'].toString()) ?? 0,
      nombre: map['nombre'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
    };
  }
}

class Usuario {
  final int id;
  final String email;
  final String firstName;
  final String lastName;
  final String rol;
  final bool activo;
  final String? fechaRegistro;

  Usuario({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.rol,
    this.activo = true,
    this.fechaRegistro,
  });

  String get fullName => '$firstName $lastName'.trim();
  String get initials {
    final f = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final l = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    return f.isNotEmpty ? '$f$l' : email.isNotEmpty ? email[0].toUpperCase() : 'U';
  }

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      email: json['email'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      rol: json['rol'] is Map ? (json['rol']['nombre'] ?? 'cliente') : (json['rol']?.toString() ?? 'cliente'),
      activo: json['activo'] ?? true,
      fechaRegistro: json['fecha_registro']?.toString(),
    );
  }

  factory Usuario.fromMap(Map<String, dynamic> map) {
    return Usuario(
      id: map['id'] is int ? map['id'] : int.tryParse(map['id'].toString()) ?? 0,
      email: map['email'] ?? '',
      firstName: map['first_name'] ?? '',
      lastName: map['last_name'] ?? '',
      rol: map['rol'] ?? 'cliente',
      activo: map['activo'] == 1 || map['activo'] == true,
      fechaRegistro: map['fecha_registro'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'rol': rol,
      'activo': activo ? 1 : 0,
      'fecha_registro': fechaRegistro ?? DateTime.now().toIso8601String(),
    };
  }

  Usuario copyWith({
    int? id,
    String? email,
    String? firstName,
    String? lastName,
    String? rol,
    bool? activo,
    String? fechaRegistro,
  }) {
    return Usuario(
      id: id ?? this.id,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      rol: rol ?? this.rol,
      activo: activo ?? this.activo,
      fechaRegistro: fechaRegistro ?? this.fechaRegistro,
    );
  }
}
