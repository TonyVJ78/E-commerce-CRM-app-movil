import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../core/models/tienda.dart';
import '../../core/services/campana_carrito_service.dart';
import '../shared/kantu_app_bar.dart';

class CampanaCarritoScreen extends StatefulWidget {
  final Tienda tienda;
  final CampanaCarritoService? servicio;
  const CampanaCarritoScreen({super.key, required this.tienda, this.servicio});
  @override
  State<CampanaCarritoScreen> createState() => _CampanaCarritoScreenState();
}

class _CampanaCarritoScreenState extends State<CampanaCarritoScreen> {
  late final _servicio = widget.servicio ?? CampanaCarritoService();
  final _form = GlobalKey<FormState>();
  final _horas = TextEditingController();
  final _asunto = TextEditingController();
  final _mensaje = TextEditingController();
  final _descuento = TextEditingController();
  final _codigo = TextEditingController();
  bool _activo = false;
  bool _cargando = true;
  bool _guardando = false;
  bool _probando = false;
  bool _disponible = false;
  String? _error;
  Map<String, dynamic> _metricas = {};
  List<Map<String, dynamic>> _carritos = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    for (final c in [_horas, _asunto, _mensaje, _descuento, _codigo]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final datos = await Future.wait([
        _servicio.obtener(widget.tienda.id),
        _servicio.carritos(widget.tienda.id),
      ]);
      if (!mounted) return;
      final respuesta = datos[0] as Map<String, dynamic>;
      final campana = respuesta['campana'] as Map;
      _horas.text = campana['horas_inactividad'].toString();
      _asunto.text = campana['asunto_email'].toString();
      _mensaje.text = campana['mensaje_email'].toString();
      _descuento.text = campana['descuento_porcentaje'].toString();
      _codigo.text = campana['codigo_cupon']?.toString() ?? '';
      setState(() {
        _activo = campana['activo'] == true;
        _metricas = Map<String, dynamic>.from(respuesta['metricas'] as Map);
        _carritos = datos[1] as List<Map<String, dynamic>>;
        _disponible = true;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _disponible = false;
          _carritos = [];
        });
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _guardar() async {
    if (_guardando || !_form.currentState!.validate()) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await _servicio.guardar(widget.tienda.id, {
        'activo': _activo,
        'horas_inactividad': int.parse(_horas.text.trim()),
        'asunto_email': _asunto.text.trim(),
        'mensaje_email': _mensaje.text.trim(),
        'descuento_porcentaje': int.parse(_descuento.text.trim()),
        'codigo_cupon': _codigo.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Campaña guardada.')));
      await _cargar();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _probar() async {
    if (_probando) return;
    setState(() => _probando = true);
    try {
      final enviado = await _servicio.enviarPrueba(widget.tienda.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enviado
                ? 'Correo de prueba enviado a la cuenta de la empresa.'
                : 'El servidor no confirmó el envío del correo de prueba.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _probando = false);
    }
  }

  String? _rango(String? text, int min, int max) {
    final n = int.tryParse(text?.trim() ?? '');
    return n == null || n < min || n > max
        ? 'Ingresa un entero entre $min y $max.'
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final horas = int.tryParse(_horas.text) ?? 2;
    final abandonados = _carritos
        .where(
          (c) =>
              c['recuperado'] != true &&
              (double.tryParse(c['horas_inactivo'].toString()) ?? 0) >= horas,
        )
        .toList();
    return Scaffold(
      backgroundColor: KantuColors.background,
      appBar: const KantuAppBar(title: 'Carritos abandonados'),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargar,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    widget.tienda.nombre,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: const TextStyle(color: KantuColors.error),
                    ),
                    if (!_disponible)
                      TextButton(
                        onPressed: _cargar,
                        child: const Text('Reintentar'),
                      ),
                  ],
                  if (_disponible) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(
                          label: Text(
                            'Detectados: ${_metricas['carritos_detectados'] ?? 0}',
                          ),
                        ),
                        Chip(
                          label: Text(
                            'Recuperados: ${_metricas['carritos_recuperados'] ?? 0}',
                          ),
                        ),
                        Chip(
                          label: Text(
                            'Correos: ${_metricas['emails_enviados'] ?? 0}',
                          ),
                        ),
                        Chip(
                          label: Text(
                            'Conversión: ${_metricas['tasa_conversion'] ?? 0} %',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Form(
                      key: _form,
                      child: Column(
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Campaña activa'),
                            value: _activo,
                            onChanged: _guardando
                                ? null
                                : (v) => setState(() => _activo = v),
                          ),
                          TextFormField(
                            controller: _horas,
                            enabled: !_guardando,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Horas de inactividad',
                            ),
                            validator: (v) => _rango(v, 1, 72),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _asunto,
                            enabled: !_guardando,
                            maxLength: 200,
                            decoration: const InputDecoration(
                              labelText: 'Asunto del correo',
                            ),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Completa el asunto.'
                                : null,
                          ),
                          TextFormField(
                            controller: _mensaje,
                            enabled: !_guardando,
                            minLines: 3,
                            maxLines: 6,
                            decoration: const InputDecoration(
                              labelText: 'Mensaje',
                              alignLabelWithHint: true,
                            ),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Completa el mensaje.'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _descuento,
                            enabled: !_guardando,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Descuento (%)',
                            ),
                            validator: (v) => _rango(v, 0, 50),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _codigo,
                            enabled: !_guardando,
                            maxLength: 50,
                            decoration: const InputDecoration(
                              labelText: 'Código promocional (opcional)',
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _guardando ? null : _guardar,
                            icon: const Icon(Icons.save_outlined),
                            label: Text(
                              _guardando ? 'Guardando…' : 'Guardar campaña',
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _guardando || _probando ? null : _probar,
                            icon: const Icon(Icons.mail_outline),
                            label: Text(
                              _probando
                                  ? 'Enviando…'
                                  : 'Enviar correo de prueba',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 32),
                    Text(
                      'Carritos inactivos',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (abandonados.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'No hay carritos abandonados para el umbral guardado.',
                        ),
                      ),
                    for (final c in abandonados)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (c['cliente'] as Map?)?['nombre']?.toString() ??
                                    'Cliente',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${c['horas_inactivo']} horas · Bs ${c['monto_total']}',
                              ),
                              for (final item in c['items'] as List? ?? [])
                                Text(
                                  '${item['cantidad']} × ${item['producto_nombre']}',
                                ),
                              const SizedBox(height: 8),
                              Text(
                                c['notificado'] == true
                                    ? 'Recordatorio enviado'
                                    : 'Sin recordatorio enviado',
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
    );
  }
}
