class Tienda {
  final int id;
  final int propietarioId;
  final String propietarioEmail;
  final String nombre;
  final String slug;
  final String logoUrl;
  final String colorPrimario;
  final String descripcion;
  final String? fechaCreacion;
  final bool activa;

  Tienda({
    required this.id,
    required this.propietarioId,
    this.propietarioEmail = '',
    required this.nombre,
    required this.slug,
    this.logoUrl = '',
    this.colorPrimario = '#C8102E',
    this.descripcion = '',
    this.fechaCreacion,
    this.activa = true,
  });

  factory Tienda.fromJson(Map<String, dynamic> json) {
    return Tienda(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      propietarioId: json['propietario'] is int
          ? json['propietario']
          : int.tryParse(json['propietario']?.toString() ?? '0') ?? 0,
      propietarioEmail: json['propietario_email'] ?? '',
      nombre: json['nombre'] ?? '',
      slug: json['slug'] ?? '',
      logoUrl: json['logo_url'] ?? '',
      colorPrimario: json['color_primario'] ?? '#C8102E',
      descripcion: json['descripcion'] ?? '',
      fechaCreacion: json['fecha_creacion']?.toString(),
      activa: json['activa'] ?? true,
    );
  }

  factory Tienda.fromMap(Map<String, dynamic> map) {
    return Tienda(
      id: map['id'] is int ? map['id'] : int.tryParse(map['id'].toString()) ?? 0,
      propietarioId: map['propietario_id'] is int
          ? map['propietario_id']
          : int.tryParse(map['propietario_id'].toString()) ?? 0,
      propietarioEmail: map['propietario_email'] ?? '',
      nombre: map['nombre'] ?? '',
      slug: map['slug'] ?? '',
      logoUrl: map['logo_url'] ?? '',
      colorPrimario: map['color_primario'] ?? '#C8102E',
      descripcion: map['descripcion'] ?? '',
      fechaCreacion: map['fecha_creacion'],
      activa: map['activa'] == 1 || map['activa'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'propietario_id': propietarioId,
      'propietario_email': propietarioEmail,
      'nombre': nombre,
      'slug': slug,
      'logo_url': logoUrl,
      'color_primario': colorPrimario,
      'descripcion': descripcion,
      'fecha_creacion': fechaCreacion ?? DateTime.now().toIso8601String(),
      'activa': activa ? 1 : 0,
    };
  }
}
