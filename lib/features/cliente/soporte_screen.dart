import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/colors.dart';
import '../../core/models/pedido.dart';
import '../../core/models/ticket_soporte.dart';
import '../../core/services/soporte_service.dart';
import '../shared/kantu_app_bar.dart';

class SoporteScreen extends StatefulWidget {
  final SoporteService? servicio;
  const SoporteScreen({super.key, this.servicio});
  @override
  State<SoporteScreen> createState() => _SoporteScreenState();
}

class _SoporteScreenState extends State<SoporteScreen> {
  late final SoporteService _servicio = widget.servicio ?? SoporteService();
  List<TicketSoporte> _tickets = [];
  bool _cargando = true;
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
      final tickets = await _servicio.listar();
      if (mounted) setState(() => _tickets = tickets);
    } catch (error) {
      if (mounted) {
        setState(() {
          _tickets = [];
          _error = error.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _nuevo() async {
    final creado = await Navigator.of(context).push<TicketSoporte>(
      MaterialPageRoute(builder: (_) => NuevoTicketScreen(servicio: _servicio)),
    );
    if (!mounted || creado == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            DetalleTicketScreen(ticketId: creado.id, servicio: _servicio),
      ),
    );
    if (mounted) await _cargar();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: KantuColors.background,
    appBar: const KantuAppBar(title: 'Consultas y reclamos'),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _nuevo,
      icon: const Icon(Icons.add),
      label: const Text('Nueva solicitud'),
    ),
    body: _cargando
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _cargar,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                if (_error != null)
                  _ErrorSoporte(mensaje: _error!, reintentar: _cargar)
                else if (_tickets.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 56),
                    child: Text(
                      'Aún no tienes solicitudes. Puedes enviar una consulta o reclamo a una tienda.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                for (final ticket in _tickets)
                  Card(
                    child: ListTile(
                      isThreeLine: true,
                      title: Text(ticket.asunto),
                      subtitle: Text(
                        '${ticket.codigo} · ${ticket.estadoEtiqueta}\n${ticket.tienda}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        await Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => DetalleTicketScreen(
                              ticketId: ticket.id,
                              servicio: _servicio,
                            ),
                          ),
                        );
                        if (mounted) await _cargar();
                      },
                    ),
                  ),
              ],
            ),
          ),
  );
}

class NuevoTicketScreen extends StatefulWidget {
  final Pedido? pedido;
  final SoporteService? servicio;
  const NuevoTicketScreen({super.key, this.pedido, this.servicio});
  @override
  State<NuevoTicketScreen> createState() => _NuevoTicketScreenState();
}

class _NuevoTicketScreenState extends State<NuevoTicketScreen> {
  late final SoporteService _servicio = widget.servicio ?? SoporteService();
  final _form = GlobalKey<FormState>();
  final _asunto = TextEditingController();
  final _descripcion = TextEditingController();
  final _adjunto = TextEditingController();
  Map<int, String> _tiendas = {};
  int? _tiendaId;
  String _tipo = 'consulta';
  bool _cargandoTiendas = false;
  bool _enviando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.pedido == null) _cargarTiendas();
  }

  Future<void> _cargarTiendas() async {
    setState(() {
      _cargandoTiendas = true;
      _error = null;
    });
    try {
      final tiendas = await _servicio.tiendas();
      if (mounted) setState(() => _tiendas = tiendas);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _cargandoTiendas = false);
    }
  }

  @override
  void dispose() {
    _asunto.dispose();
    _descripcion.dispose();
    _adjunto.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (_enviando || !_form.currentState!.validate()) return;
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      final ticket = await _servicio.crear(
        pedidoId: widget.pedido?.id,
        tiendaId: _tiendaId,
        tipo: _tipo,
        asunto: _asunto.text,
        descripcion: _descripcion.text,
        adjunto: _adjunto.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Solicitud ${ticket.codigo} registrada.')),
      );
      Navigator.of(context).pop(ticket);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: KantuColors.background,
    appBar: const KantuAppBar(title: 'Nueva solicitud'),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (widget.pedido != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.receipt_long_outlined),
              title: Text('Pedido #${widget.pedido!.id}'),
              subtitle: Text(widget.pedido!.tiendaNombre),
            )
          else if (_cargandoTiendas)
            const LinearProgressIndicator()
          else
            DropdownButtonFormField<int>(
              initialValue: _tiendaId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Tienda'),
              items: [
                for (final tienda in _tiendas.entries)
                  DropdownMenuItem(
                    value: tienda.key,
                    child: Text(tienda.value, overflow: TextOverflow.ellipsis),
                  ),
              ],
              validator: (value) =>
                  value == null ? 'Selecciona una tienda.' : null,
              onChanged: _enviando
                  ? null
                  : (value) => setState(() => _tiendaId = value),
            ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _tipo,
            decoration: const InputDecoration(labelText: 'Motivo'),
            items: const [
              DropdownMenuItem(
                value: 'consulta',
                child: Text('Consulta general'),
              ),
              DropdownMenuItem(
                value: 'reclamo_producto',
                child: Text('Reclamo por producto'),
              ),
              DropdownMenuItem(
                value: 'demora_envio',
                child: Text('Demora en el envío'),
              ),
              DropdownMenuItem(value: 'devolucion', child: Text('Devolución')),
            ],
            onChanged: _enviando
                ? null
                : (value) => setState(() => _tipo = value!),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _asunto,
            enabled: !_enviando,
            maxLength: 200,
            decoration: const InputDecoration(labelText: 'Asunto'),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Escribe el asunto.'
                : null,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _descripcion,
            enabled: !_enviando,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Descripción',
              alignLabelWithHint: true,
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Describe tu consulta o reclamo.'
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _adjunto,
            enabled: !_enviando,
            maxLength: 500,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Enlace a comprobante o captura (opcional)',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return null;
              final uri = Uri.tryParse(value.trim());
              return uri != null &&
                      uri.hasAuthority &&
                      ['https', 'http'].contains(uri.scheme)
                  ? null
                  : 'Ingresa un enlace HTTP o HTTPS válido.';
            },
          ),
          if (_error != null)
            _ErrorSoporte(
              mensaje: _error!,
              reintentar: widget.pedido == null && _tiendas.isEmpty
                  ? _cargarTiendas
                  : null,
            ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _enviando || _cargandoTiendas ? null : _enviar,
            icon: _enviando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_outlined),
            label: Text(_enviando ? 'Enviando…' : 'Enviar solicitud'),
          ),
        ],
      ),
    ),
  );
}

class DetalleTicketScreen extends StatefulWidget {
  final int ticketId;
  final SoporteService? servicio;
  const DetalleTicketScreen({super.key, required this.ticketId, this.servicio});
  @override
  State<DetalleTicketScreen> createState() => _DetalleTicketScreenState();
}

class _DetalleTicketScreenState extends State<DetalleTicketScreen>
    with WidgetsBindingObserver {
  late final SoporteService _servicio = widget.servicio ?? SoporteService();
  final _mensaje = TextEditingController();
  TicketSoporte? _ticket;
  Timer? _timer;
  bool _cargando = false;
  bool _enviando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cargar();
    _iniciarActualizacion();
  }

  void _iniciarActualizacion() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!_enviando) _cargar();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _cargar();
      _iniciarActualizacion();
    } else {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mensaje.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _cargar() async {
    if (_cargando) return;
    setState(() => _cargando = true);
    try {
      final ticket = await _servicio.detalle(widget.ticketId);
      if (mounted) {
        setState(() {
          _ticket = ticket;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _ticket = null;
          _error = error.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _responder() async {
    if (_enviando || _mensaje.text.trim().isEmpty) return;
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      await _servicio.responder(widget.ticketId, _mensaje.text);
      if (!mounted) return;
      _mensaje.clear();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Respuesta enviada.')));
      await _cargar();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticket = _ticket;
    return Scaffold(
      backgroundColor: KantuColors.background,
      appBar: KantuAppBar(
        title: ticket?.codigo ?? 'Detalle de solicitud',
        actions: [
          IconButton(
            tooltip: 'Actualizar solicitud',
            onPressed: _cargando ? null : _cargar,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_cargando) const LinearProgressIndicator(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _cargar,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  if (_error != null)
                    _ErrorSoporte(mensaje: _error!, reintentar: _cargar),
                  if (ticket != null) ...[
                    Text(
                      ticket.asunto,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text('${ticket.tienda} · ${ticket.tipoEtiqueta}'),
                    if (ticket.pedidoCodigo != null)
                      Text('Pedido ${ticket.pedidoCodigo}'),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Chip(label: Text(ticket.estadoEtiqueta)),
                    ),
                    const Divider(height: 28),
                    if (ticket.mensajes.isEmpty) Text(ticket.descripcion),
                    for (final mensaje in ticket.mensajes)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                mensaje.autor,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (mensaje.fecha != null)
                                Text(
                                  DateFormat('dd/MM/yyyy HH:mm')
                                      .format(mensaje.fecha!.toLocal()),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              const SizedBox(height: 8),
                              Text(mensaje.contenido),
                              if (mensaje.adjunto?.isNotEmpty ?? false) ...[
                                const SizedBox(height: 8),
                                const Text('Comprobante adjunto:'),
                                SelectableText(mensaje.adjunto!),
                              ],
                            ],
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          if (ticket != null)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _mensaje,
                        enabled: !_enviando,
                        minLines: 1,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Escribe una respuesta',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Enviar respuesta',
                      onPressed: _enviando ? null : _responder,
                      icon: _enviando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ErrorSoporte extends StatelessWidget {
  final String mensaje;
  final VoidCallback? reintentar;
  const _ErrorSoporte({required this.mensaje, this.reintentar});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      children: [
        Text(
          mensaje,
          style: const TextStyle(color: KantuColors.error),
          textAlign: TextAlign.center,
        ),
        if (reintentar != null)
          TextButton.icon(
            onPressed: reintentar,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
      ],
    ),
  );
}
