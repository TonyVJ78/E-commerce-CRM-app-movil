import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/constants/colors.dart';
import '../../core/models/tienda.dart';
import '../../core/services/cupones_service.dart';
import '../shared/kantu_app_bar.dart';

class CuponesScreen extends StatefulWidget {
  final Tienda? tienda;
  final CuponesService? servicio;
  const CuponesScreen({super.key, this.tienda, this.servicio});
  @override
  State<CuponesScreen> createState() => _CuponesScreenState();
}

class _CuponesScreenState extends State<CuponesScreen> {
  late final _servicio = widget.servicio ?? CuponesService();
  List<Map<String, dynamic>> _cupones = [];
  List<Map<String, dynamic>> _segmentos = [];
  bool _cargando = true;
  bool _actualizando = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final tienda = widget.tienda;
      if (tienda == null) {
        final cupones = await _servicio.disponibles();
        if (mounted) setState(() => _cupones = cupones);
      } else {
        final datos = await _servicio.deTienda(tienda.id);
        if (!mounted) return;
        setState(() {
          _cupones = (datos['cupones'] as List)
              .map((x) => Map<String, dynamic>.from(x as Map))
              .toList();
          _segmentos = (datos['segmentos'] as List)
              .map((x) => Map<String, dynamic>.from(x as Map))
              .toList();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cupones = [];
          _error = e.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _crear() async {
    final creado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => NuevoCuponScreen(
          tienda: widget.tienda!,
          segmentos: _segmentos,
          servicio: _servicio,
        ),
      ),
    );
    if (creado == true && mounted) await _cargar();
  }

  Future<void> _activar(Map<String, dynamic> cupon, bool value) async {
    if (_actualizando) return;
    setState(() => _actualizando = true);
    try {
      await _servicio.activar(
        widget.tienda!.id,
        (cupon['id'] as num).toInt(),
        value,
      );
      if (mounted) await _cargar();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _actualizando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: KantuColors.background,
    appBar: KantuAppBar(
      title: widget.tienda == null ? 'Mis promociones' : 'Cupones de la tienda',
    ),
    floatingActionButton: widget.tienda == null || _error != null
        ? null
        : FloatingActionButton.extended(
            onPressed: _cargando ? null : _crear,
            icon: const Icon(Icons.add),
            label: const Text('Crear cupón'),
          ),
    body: _cargando
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _cargar,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
              children: [
                if (widget.tienda != null)
                  Text(
                    widget.tienda!.nombre,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: const TextStyle(color: KantuColors.error),
                  ),
                  TextButton(
                    onPressed: _cargar,
                    child: const Text('Reintentar'),
                  ),
                ] else if (_cupones.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Text('No hay cupones disponibles.'),
                  ),
                for (final c in _cupones)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c['codigo'].toString(),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(c['tienda_nombre'].toString()),
                          Text(
                            c['tipo_descuento'] == 'porcentaje'
                                ? '${c['valor_descuento']} % de descuento'
                                : 'Descuento de Bs ${c['valor_descuento']}',
                          ),
                          Text('Compra mínima: Bs ${c['monto_minimo']}'),
                          Text(
                            'Vigencia: ${c['fecha_inicio']} al ${c['fecha_expiracion']}',
                          ),
                          if (widget.tienda != null) ...[
                            Text(
                              'Usos: ${c['usos_realizados']} de ${c['usos_maximos']} · Por cliente: ${c['limite_por_cliente']}',
                            ),
                            Text(
                              'Segmento: ${c['segmento_nombre'] ?? 'Todos'}',
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Activo'),
                              value: c['activo'] == true,
                              onChanged: _actualizando
                                  ? null
                                  : (v) => _activar(c, v),
                            ),
                          ] else ...[
                            TextButton.icon(
                              onPressed: () async {
                                await Clipboard.setData(
                                  ClipboardData(text: c['codigo'].toString()),
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Código copiado. Aplícalo en el carrito de esta tienda.',
                                      ),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.copy),
                              label: const Text('Copiar código'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
  );
}

class NuevoCuponScreen extends StatefulWidget {
  final Tienda tienda;
  final List<Map<String, dynamic>> segmentos;
  final CuponesService servicio;
  const NuevoCuponScreen({
    super.key,
    required this.tienda,
    required this.segmentos,
    required this.servicio,
  });
  @override
  State<NuevoCuponScreen> createState() => _NuevoCuponScreenState();
}

class _NuevoCuponScreenState extends State<NuevoCuponScreen> {
  final _form = GlobalKey<FormState>();
  final _codigo = TextEditingController();
  final _valor = TextEditingController();
  final _minimo = TextEditingController(text: '0');
  final _usos = TextEditingController(text: '100');
  final _porCliente = TextEditingController(text: '1');
  String _tipo = 'porcentaje';
  int _segmento = 0;
  DateTime _inicio = DateUtils.dateOnly(DateTime.now());
  DateTime _fin = DateUtils.dateOnly(
    DateTime.now().add(const Duration(days: 7)),
  );
  bool _guardando = false;
  String? _error;
  @override
  void dispose() {
    for (final c in [_codigo, _valor, _minimo, _usos, _porCliente]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _fecha(bool inicio) async {
    final seleccion = await showDatePicker(
      context: context,
      initialDate: inicio ? _inicio : _fin,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (seleccion != null && mounted) {
      setState(() {
        if (inicio) {
          _inicio = seleccion;
        } else {
          _fin = seleccion;
        }
      });
    }
  }

  String? _entero(String? value) => (int.tryParse(value ?? '') ?? 0) > 0
      ? null
      : 'Ingresa un entero mayor que cero.';
  double? _decimal(String? value) =>
      double.tryParse((value ?? '').replaceAll(',', '.'));
  Future<void> _guardar() async {
    if (_guardando || !_form.currentState!.validate()) return;
    if (_fin.isBefore(_inicio)) {
      setState(
        () => _error = 'La expiración debe ser igual o posterior al inicio.',
      );
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await widget.servicio.crear(widget.tienda.id, {
        'codigo': _codigo.text.trim().toUpperCase(),
        'tipo_descuento': _tipo,
        'valor_descuento': _decimal(_valor.text)!.toStringAsFixed(2),
        'monto_minimo': _decimal(_minimo.text)!.toStringAsFixed(2),
        'usos_maximos': int.parse(_usos.text),
        'limite_por_cliente': int.parse(_porCliente.text),
        'fecha_inicio': DateFormat('yyyy-MM-dd').format(_inicio),
        'fecha_expiracion': DateFormat('yyyy-MM-dd').format(_fin),
        'segmento_id': _segmento == 0 ? null : _segmento,
        'activo': true,
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: KantuColors.background,
    appBar: const KantuAppBar(title: 'Crear cupón'),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            widget.tienda.nombre,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          TextFormField(
            controller: _codigo,
            enabled: !_guardando,
            maxLength: 30,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Código'),
            validator: (v) =>
                RegExp(r'^[A-Z0-9_-]{3,30}$')
                    .hasMatch((v ?? '').trim().toUpperCase())
                ? null
                : 'Usa de 3 a 30 letras, números o guiones.',
          ),
          DropdownButtonFormField<String>(
            initialValue: _tipo,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Tipo de descuento'),
            items: const [
              DropdownMenuItem(value: 'porcentaje', child: Text('Porcentaje')),
              DropdownMenuItem(
                value: 'monto_fijo',
                child: Text('Monto fijo en Bs'),
              ),
            ],
            onChanged: _guardando ? null : (v) => setState(() => _tipo = v!),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _valor,
            enabled: !_guardando,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Valor del descuento'),
            validator: (v) {
              final n = _decimal(v);
              return n == null ||
                      !n.isFinite ||
                      n <= 0 ||
                      (_tipo == 'porcentaje' && n > 100)
                  ? 'Ingresa un descuento válido.'
                  : null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _minimo,
            enabled: !_guardando,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Compra mínima (Bs)'),
            validator: (v) {
              final n = _decimal(v);
              return n == null || !n.isFinite || n < 0
                  ? 'Ingresa un monto válido.'
                  : null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _usos,
            enabled: !_guardando,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Usos máximos'),
            validator: _entero,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _porCliente,
            enabled: !_guardando,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Límite por cliente'),
            validator: _entero,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: _segmento,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Segmento de clientes',
            ),
            items: [
              const DropdownMenuItem(value: 0, child: Text('Todos')),
              for (final s in widget.segmentos)
                DropdownMenuItem(
                  value: (s['id'] as num).toInt(),
                  child: Text(
                    s['nombre'].toString(),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: _guardando
                ? null
                : (v) => setState(() => _segmento = v!),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _guardando ? null : () => _fecha(true),
            icon: const Icon(Icons.calendar_today),
            label: Text('Inicio: ${DateFormat('dd/MM/yyyy').format(_inicio)}'),
          ),
          OutlinedButton.icon(
            onPressed: _guardando ? null : () => _fecha(false),
            icon: const Icon(Icons.event),
            label: Text('Expira: ${DateFormat('dd/MM/yyyy').format(_fin)}'),
          ),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: KantuColors.error)),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _guardando ? null : _guardar,
            child: Text(_guardando ? 'Guardando…' : 'Crear cupón'),
          ),
        ],
      ),
    ),
  );
}
