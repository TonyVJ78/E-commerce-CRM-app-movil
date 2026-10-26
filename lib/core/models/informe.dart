/// Informes de tienda generados con IA (CU-34).
library;

/// Columna de la tabla del informe. `tipo` define formato y alineación:
/// `texto`, `entero`, `moneda`, `decimal` o `fecha`.
class ColumnaInforme {
  final String clave;
  final String titulo;
  final String tipo;

  /// Se totaliza al pie. Los conteos distintos y los promedios no.
  final bool esSumable;

  const ColumnaInforme({required this.clave, required this.titulo, required this.tipo, this.esSumable = false});

  bool get esNumerica => tipo == 'entero' || tipo == 'moneda' || tipo == 'decimal';

  factory ColumnaInforme.fromJson(Map<String, dynamic> json) => ColumnaInforme(
        clave: (json['clave'] ?? '').toString(),
        titulo: (json['titulo'] ?? '').toString(),
        tipo: (json['tipo'] ?? 'texto').toString(),
        esSumable: json['sumable'] == true,
      );
}

/// Fila del historial (`GET /api/ia/informes/`).
class InformeResumen {
  final int id;
  final String titulo;
  final String pregunta;
  final String? tiendaNombre;
  final int totalFilas;
  final DateTime? fecha;

  const InformeResumen({
    required this.id,
    required this.titulo,
    required this.pregunta,
    required this.tiendaNombre,
    required this.totalFilas,
    required this.fecha,
  });

  factory InformeResumen.fromJson(Map<String, dynamic> json) => InformeResumen(
        id: json['id'] as int,
        titulo: (json['titulo'] ?? 'Informe').toString(),
        pregunta: (json['pregunta'] ?? '').toString(),
        tiendaNombre: json['tienda_nombre']?.toString(),
        totalFilas: (json['total_filas'] as num?)?.toInt() ?? 0,
        fecha: DateTime.tryParse((json['fecha_generacion'] ?? '').toString())?.toLocal(),
      );
}

/// Informe completo: tabla con datos de la base + análisis de la IA.
class Informe extends InformeResumen {
  final String analisis;
  final List<ColumnaInforme> columnas;
  final List<List<dynamic>> filas;
  final bool truncado;
  final String filtros;
  final String? graficoTipo;
  final String? graficoEtiqueta;
  final String? graficoValor;

  const Informe({
    required super.id,
    required super.titulo,
    required super.pregunta,
    required super.tiendaNombre,
    required super.totalFilas,
    required super.fecha,
    required this.analisis,
    required this.columnas,
    required this.filas,
    required this.truncado,
    required this.filtros,
    this.graficoTipo,
    this.graficoEtiqueta,
    this.graficoValor,
  });

  factory Informe.fromJson(Map<String, dynamic> json) {
    final resumen = InformeResumen.fromJson(json);
    final grafico = (json['grafico'] as Map?) ?? const {};
    return Informe(
      id: resumen.id,
      titulo: resumen.titulo,
      pregunta: resumen.pregunta,
      tiendaNombre: resumen.tiendaNombre,
      totalFilas: resumen.totalFilas,
      fecha: resumen.fecha,
      analisis: (json['analisis'] ?? '').toString(),
      columnas: (json['columnas'] as List? ?? [])
          .map((c) => ColumnaInforme.fromJson(Map<String, dynamic>.from(c as Map)))
          .toList(),
      filas: (json['filas'] as List? ?? []).map((f) => List<dynamic>.from(f as List)).toList(),
      truncado: json['truncado'] == true,
      filtros: (json['filtros'] ?? '').toString(),
      graficoTipo: grafico['tipo']?.toString(),
      graficoEtiqueta: grafico['etiqueta']?.toString(),
      graficoValor: grafico['valor']?.toString(),
    );
  }
}

class TiendaInforme {
  final int id;
  final String nombre;

  const TiendaInforme(this.id, this.nombre);
}

class ContextoInformes {
  final List<TiendaInforme> tiendas;
  final bool esAdministrador;
  final bool puedeCrear;
  final bool puedeEliminar;
  final List<String> ejemplos;

  const ContextoInformes({
    required this.tiendas,
    required this.esAdministrador,
    required this.puedeCrear,
    required this.puedeEliminar,
    required this.ejemplos,
  });

  factory ContextoInformes.fromJson(Map<String, dynamic> json) => ContextoInformes(
        tiendas: (json['tiendas'] as List? ?? [])
            .map((t) => TiendaInforme((t as Map)['id'] as int, (t['nombre'] ?? '').toString()))
            .toList(),
        esAdministrador: json['es_administrador'] == true,
        puedeCrear: json['puede_crear'] == true,
        puedeEliminar: json['puede_eliminar'] == true,
        ejemplos: (json['ejemplos'] as List? ?? []).map((e) => e.toString()).toList(),
      );
}

/// Mensaje de la conversación con el analista.
class MensajeInforme {
  final bool esUsuario;
  final String contenido;
  final List<String> sugerencias;
  final bool error;
  final Informe? informe;

  const MensajeInforme({
    required this.esUsuario,
    required this.contenido,
    this.sugerencias = const [],
    this.error = false,
    this.informe,
  });

  /// El modelo recuerda qué informe armó por su título y su análisis.
  Map<String, String> toApiJson() => {
        'rol': esUsuario ? 'usuario' : 'asistente',
        'contenido': informe != null ? 'Informe "${informe!.titulo}":\n$contenido' : contenido,
      };
}
