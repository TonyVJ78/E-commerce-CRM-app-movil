import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/colors.dart';
import '../../core/models/informe.dart';
import '../../core/services/informes_service.dart';

final _moneda = NumberFormat('#,##0.00', 'es');
final _entero = NumberFormat('#,##0', 'es');
final _fecha = DateFormat('dd/MM/yyyy HH:mm');

/// Formatea una celda según el tipo de su columna.
String formatoCelda(dynamic valor, ColumnaInforme columna) {
  if (valor == null) return '—';
  if (valor is! num) return valor.toString();
  switch (columna.tipo) {
    case 'moneda':
      return 'Bs ${_moneda.format(valor)}';
    case 'entero':
      return _entero.format(valor);
    case 'decimal':
      return _moneda.format(valor);
    default:
      return valor.toString();
  }
}

/// Informe completo (CU-34): análisis de la IA, gráfico, tabla con los datos
/// de la base y exportación a PDF o Excel.
class InformeDetalleScreen extends StatefulWidget {
  final Informe informe;

  const InformeDetalleScreen({super.key, required this.informe});

  @override
  State<InformeDetalleScreen> createState() => _InformeDetalleScreenState();
}

class _InformeDetalleScreenState extends State<InformeDetalleScreen> {
  String? _exportando;
  int? _ordenColumna;
  bool _ordenAsc = true;
  late List<List<dynamic>> _filas = List.of(widget.informe.filas);

  Informe get informe => widget.informe;

  Future<void> _exportar(String formato) async {
    if (_exportando != null) return;
    setState(() => _exportando = formato);
    final resultado = await context.read<InformesService>().exportar(informe, formato);
    if (!mounted) return;
    setState(() => _exportando = null);

    if (!resultado.ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(resultado.error!)));
      return;
    }
    final ruta = resultado.valor!;
    final nombre = formato == 'pdf' ? 'PDF' : 'Excel';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (hoja) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Informe en $nombre listo',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: KantuColors.textPrimary)),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.open_in_new_rounded, color: KantuColors.primary),
                title: const Text('Abrir'),
                subtitle: Text('Con la app de $nombre del teléfono'),
                onTap: () async {
                  Navigator.pop(hoja);
                  final r = await OpenFilex.open(ruta);
                  if (r.type != ResultType.done && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('No hay una app para abrir $nombre. Usa Compartir para guardarlo.')),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_rounded, color: KantuColors.success),
                title: const Text('Compartir o guardar'),
                subtitle: const Text('WhatsApp, correo, Drive, Archivos…'),
                onTap: () {
                  Navigator.pop(hoja);
                  SharePlus.instance.share(ShareParams(files: [XFile(ruta)], subject: informe.titulo));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _ordenar(int columna) {
    final asc = _ordenColumna == columna ? !_ordenAsc : !informe.columnas[columna].esNumerica;
    final filas = List.of(informe.filas)
      ..sort((a, b) {
        final x = a[columna];
        final y = b[columna];
        if (x == y) return 0;
        if (x == null) return 1;
        if (y == null) return -1;
        final r = (x is num && y is num) ? x.compareTo(y) : x.toString().compareTo(y.toString());
        return asc ? r : -r;
      });
    setState(() {
      _ordenColumna = columna;
      _ordenAsc = asc;
      _filas = filas;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KantuColors.background,
      appBar: AppBar(
        backgroundColor: KantuColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Informe', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text(
            informe.titulo,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: KantuColors.textPrimary, height: 1.25),
          ),
          const SizedBox(height: 4),
          Text(
            [informe.tiendaNombre ?? 'Varias tiendas', if (informe.fecha != null) _fecha.format(informe.fecha!)]
                .join(' · '),
            style: const TextStyle(fontSize: 12.5, color: KantuColors.textSecondary),
          ),
          if (informe.filtros.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: KantuColors.accentLight, borderRadius: BorderRadius.circular(8)),
              child: Text(informe.filtros,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF8A6200))),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _BotonExportar(
                  etiqueta: 'PDF',
                  icono: Icons.picture_as_pdf_rounded,
                  color: KantuColors.primary,
                  cargando: _exportando == 'pdf',
                  onTap: () => _exportar('pdf'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BotonExportar(
                  etiqueta: 'Excel',
                  icono: Icons.table_chart_rounded,
                  color: KantuColors.success,
                  cargando: _exportando == 'xlsx',
                  onTap: () => _exportar('xlsx'),
                ),
              ),
            ],
          ),
          if (informe.analisis.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: const Border(left: BorderSide(color: KantuColors.accent, width: 4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ANÁLISIS',
                      style: TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: KantuColors.primary)),
                  const SizedBox(height: 6),
                  MarkdownBody(data: informe.analisis, softLineBreak: true, styleSheet: estiloMarkdown(context)),
                ],
              ),
            ),
          ],
          if (_GraficoBarras.aplica(informe)) ...[
            const SizedBox(height: 16),
            _GraficoBarras(informe: informe),
          ],
          const SizedBox(height: 16),
          _tabla(),
          if (informe.truncado)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Se muestran ${informe.filas.length} de ${informe.totalFilas} filas. Pide un filtro más específico para ver el resto.',
                style: const TextStyle(fontSize: 12, color: KantuColors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tabla() {
    if (informe.filas.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
        child: const Text('La consulta no devolvió filas con esos filtros.',
            textAlign: TextAlign.center, style: TextStyle(color: KantuColors.textSecondary)),
      );
    }

    final columnas = informe.columnas;
    final conTotal = informe.filas.length > 1 && columnas.any((c) => c.esSumable);
    const estiloTotal = TextStyle(fontWeight: FontWeight.w800, color: KantuColors.textPrimary);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KantuColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: const WidgetStatePropertyAll(KantuColors.background),
          headingTextStyle: const TextStyle(
              fontWeight: FontWeight.w800, fontSize: 12, color: KantuColors.textSecondary),
          dataTextStyle: const TextStyle(fontSize: 13, color: KantuColors.textPrimary),
          columnSpacing: 22,
          horizontalMargin: 14,
          dataRowMinHeight: 40,
          dataRowMaxHeight: 52,
          sortColumnIndex: _ordenColumna,
          sortAscending: _ordenAsc,
          columns: [
            for (var j = 0; j < columnas.length; j++)
              DataColumn(
                label: Text(columnas[j].titulo),
                numeric: columnas[j].esNumerica,
                onSort: (_, _) => _ordenar(j),
              ),
          ],
          rows: [
            for (final fila in _filas)
              DataRow(cells: [
                for (var j = 0; j < columnas.length; j++)
                  DataCell(ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: Text(formatoCelda(j < fila.length ? fila[j] : null, columnas[j]),
                        overflow: TextOverflow.ellipsis),
                  )),
              ]),
            if (conTotal)
              DataRow(
                color: const WidgetStatePropertyAll(KantuColors.background),
                cells: [
                  for (var j = 0; j < columnas.length; j++)
                    DataCell(Text(
                      j == 0
                          ? 'Total'
                          : columnas[j].esSumable
                              ? formatoCelda(
                                  informe.filas.fold<num>(0, (acc, f) => acc + ((f[j] as num?) ?? 0)), columnas[j])
                              : '',
                      style: estiloTotal,
                    )),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

MarkdownStyleSheet estiloMarkdown(BuildContext context) {
  const base = TextStyle(fontSize: 14, height: 1.45, color: KantuColors.textPrimary);
  return MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
    p: base,
    listBullet: base.copyWith(color: KantuColors.primary),
    strong: const TextStyle(fontWeight: FontWeight.w800),
    h1: base.copyWith(fontSize: 16, fontWeight: FontWeight.w800),
    h2: base.copyWith(fontSize: 15.5, fontWeight: FontWeight.w800),
    h3: base.copyWith(fontSize: 15, fontWeight: FontWeight.w800),
    blockSpacing: 8,
    listIndent: 20,
  );
}

class _BotonExportar extends StatelessWidget {
  final String etiqueta;
  final IconData icono;
  final Color color;
  final bool cargando;
  final VoidCallback onTap;

  const _BotonExportar({
    required this.etiqueta,
    required this.icono,
    required this.color,
    required this.cargando,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: cargando ? null : onTap,
      style: FilledButton.styleFrom(
        backgroundColor: color,
        disabledBackgroundColor: color.withAlpha(140),
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: cargando
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Icon(icono, size: 19),
      label: Text(cargando ? 'Generando…' : etiqueta, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}

/// Barras horizontales con widgets simples (como `VentasBarChart`): sirve
/// tanto para rankings como para series por fecha, sin otra dependencia.
class _GraficoBarras extends StatelessWidget {
  static const _maxBarras = 12;
  final Informe informe;

  const _GraficoBarras({required this.informe});

  static bool aplica(Informe informe) {
    final claves = informe.columnas.map((c) => c.clave).toList();
    return informe.graficoTipo != null &&
        claves.contains(informe.graficoEtiqueta) &&
        claves.contains(informe.graficoValor) &&
        informe.filas.length > 1;
  }

  @override
  Widget build(BuildContext context) {
    final claves = informe.columnas.map((c) => c.clave).toList();
    final iEtiqueta = claves.indexOf(informe.graficoEtiqueta!);
    final iValor = claves.indexOf(informe.graficoValor!);
    final columnaValor = informe.columnas[iValor];
    var filas = informe.filas;
    // En series de tiempo importan los últimos periodos; en rankings, los primeros.
    filas = informe.graficoTipo == 'lineas'
        ? filas.sublist(filas.length > _maxBarras ? filas.length - _maxBarras : 0)
        : filas.take(_maxBarras).toList();
    final valores = filas.map((f) => ((f[iValor] as num?) ?? 0).toDouble()).toList();
    final maximo = valores.fold<double>(0, (a, b) => b > a ? b : a);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KantuColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${columnaValor.titulo} por ${informe.columnas[iEtiqueta].titulo.toLowerCase()}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: KantuColors.textPrimary),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < filas.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 96,
                    child: Text(
                      '${filas[i][iEtiqueta] ?? '—'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, color: KantuColors.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (_, c) => Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          height: 14,
                          width: maximo <= 0 ? 0 : (c.maxWidth * valores[i] / maximo).clamp(2, c.maxWidth),
                          decoration: BoxDecoration(
                            color: KantuColors.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 84,
                    child: Text(
                      formatoCelda(filas[i][iValor], columnaValor),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
