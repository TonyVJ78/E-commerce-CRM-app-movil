import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../core/models/pedido.dart';
import '../../core/services/pedidos_service.dart';

class SeguimientoPedidoSheet extends StatefulWidget {
  const SeguimientoPedidoSheet({super.key, required this.pedido});

  final Pedido pedido;

  @override
  State<SeguimientoPedidoSheet> createState() => _SeguimientoPedidoSheetState();
}

class _SeguimientoPedidoSheetState extends State<SeguimientoPedidoSheet> {
  final _service = PedidosService();
  final _comentarioController = TextEditingController();
  Map<String, dynamic>? _detalle;
  List<Map<String, dynamic>> _resenas = [];
  bool _cargando = true;
  bool _guardando = false;
  String _tipo = 'producto';
  int? _productoId;
  int _calificacion = 5;
  String? _error;
  String? _mensaje;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _comentarioController.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final detalle = await _service.obtenerDetalle(widget.pedido.id);
      if (!mounted) return;
      final productos = _productos(detalle);
      setState(() {
        _detalle = detalle;
        _resenas = (detalle['resenas'] as List? ?? const [])
            .cast<Map<String, dynamic>>();
        _productoId ??= productos.isEmpty
            ? null
            : _entero(productos.first['producto_id']);
        _cargando = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _textoError(error);
        _cargando = false;
      });
    }
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    if (_tipo == 'producto' && _productoId == null) {
      setState(() => _error = 'Elige un producto de este pedido.');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
      _mensaje = null;
    });
    try {
      await _service.guardarResena(
        widget.pedido.id,
        tipo: _tipo,
        productoId: _productoId,
        calificacion: _calificacion,
        comentario: _comentarioController.text.trim(),
      );
      _comentarioController.clear();
      await _cargar();
      if (mounted) {
        setState(() {
          _guardando = false;
          _mensaje = 'La calificación quedó registrada.';
        });
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _guardando = false;
        _error = _textoError(error);
      });
    }
  }

  List<Map<String, dynamic>> _productos(Map<String, dynamic> detalle) {
    final items = (detalle['items'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    final unicos = <int, Map<String, dynamic>>{};
    for (final item in items) {
      final id = _entero(item['producto_id']);
      if (id > 0) unicos.putIfAbsent(id, () => item);
    }
    return unicos.values.toList();
  }

  int _entero(dynamic value) =>
      value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;

  String _textoError(Object error) =>
      error.toString().replaceFirst('Exception: ', '');

  bool get _calificable {
    final estado = (_detalle?['estado'] ?? widget.pedido.estadoActual)
        .toString()
        .trim()
        .toLowerCase();
    return {
      'completado',
      'completada',
      'entregado',
      'finalizado',
      'completed',
    }.contains(estado);
  }

  String _fecha(dynamic raw) {
    final fecha = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (fecha == null) return 'Fecha no disponible';
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    final hora = fecha.hour.toString().padLeft(2, '0');
    final minuto = fecha.minute.toString().padLeft(2, '0');
    return '$dia/$mes/${fecha.year} · $hora:$minuto';
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: .82,
          minChildSize: .5,
          maxChildSize: .96,
          builder: (context, scrollController) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: _cargando && _detalle == null
                ? const Center(
                    child: CircularProgressIndicator(
                      color: KantuColors.primary,
                    ),
                  )
                : _contenido(scrollController),
          ),
        ),
      ),
    );
  }

  Widget _contenido(ScrollController scrollController) {
    final detalle = _detalle;
    final items = detalle == null
        ? <Map<String, dynamic>>[]
        : (detalle['items'] as List? ?? const []).cast<Map<String, dynamic>>();
    final historial = detalle == null
        ? <Map<String, dynamic>>[]
        : (detalle['historial'] as List? ?? const [])
              .cast<Map<String, dynamic>>();
    final productos = detalle == null
        ? <Map<String, dynamic>>[]
        : _productos(detalle);

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: KantuColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Text(
                'Pedido #${widget.pedido.id}',
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: KantuColors.textPrimary,
                ),
              ),
            ),
            Text(
              (detalle?['estado'] ?? widget.pedido.estadoActual)
                  .toString()
                  .toUpperCase(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: KantuColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          (detalle?['tienda_nombre'] ?? widget.pedido.tiendaNombre).toString(),
          style: const TextStyle(color: KantuColors.textSecondary),
        ),
        if (_error != null) _aviso(_error!, error: true),
        if (_mensaje != null) _aviso(_mensaje!),
        const SizedBox(height: 16),
        const Text(
          'Productos',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        ...items.map(
          (item) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(item['producto_nombre']?.toString() ?? 'Producto'),
            subtitle: Text(
              '${item['variante_nombre'] ?? ''} · ${item['cantidad'] ?? 0} unidad(es)',
            ),
            trailing: Text('Bs. ${item['subtotal'] ?? '0.00'}'),
          ),
        ),
        const Divider(height: 24),
        const Text(
          'Historial de estados',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        if (historial.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Aún no hay cambios de estado registrados.'),
          ),
        ...historial.map(_evento),
        if (_calificable) ...[
          const Divider(height: 28),
          const Text(
            'Califica tu compra',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          if (_resenas.isNotEmpty) ...[
            const SizedBox(height: 8),
            ..._resenas.map(_resenaCard),
          ],
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _tipo,
            decoration: const InputDecoration(
              labelText: 'Qué deseas calificar',
            ),
            items: const [
              DropdownMenuItem(
                value: 'producto',
                child: Text('Producto adquirido'),
              ),
              DropdownMenuItem(value: 'tienda', child: Text('Tienda')),
            ],
            onChanged: (value) => setState(() => _tipo = value ?? 'producto'),
          ),
          if (_tipo == 'producto')
            DropdownButtonFormField<int>(
              initialValue:
                  productos.any(
                    (item) => _entero(item['producto_id']) == _productoId,
                  )
                  ? _productoId
                  : null,
              decoration: const InputDecoration(labelText: 'Producto'),
              items: productos
                  .map(
                    (item) => DropdownMenuItem<int>(
                      value: _entero(item['producto_id']),
                      child: Text(
                        item['producto_nombre']?.toString() ?? 'Producto',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _productoId = value),
            ),
          DropdownButtonFormField<int>(
            initialValue: _calificacion,
            decoration: const InputDecoration(labelText: 'Puntuación'),
            items: List.generate(5, (index) {
              final puntos = 5 - index;
              return DropdownMenuItem(
                value: puntos,
                child: Text('$puntos de 5 estrellas'),
              );
            }),
            onChanged: (value) => setState(() => _calificacion = value ?? 5),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _comentarioController,
            maxLength: 5000,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Comentario',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          FilledButton.icon(
            onPressed: _guardando ? null : _guardar,
            icon: const Icon(Icons.rate_review_outlined),
            label: Text(_guardando ? 'Guardando...' : 'Guardar calificación'),
          ),
        ] else ...[
          const Divider(height: 28),
          const Text(
            'Las reseñas están disponibles cuando el pedido se completa o entrega.',
            style: TextStyle(color: KantuColors.textSecondary),
          ),
        ],
      ],
    );
  }

  Widget _evento(Map<String, dynamic> evento) {
    final observacion = evento['observacion']?.toString() ?? '';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(
        Icons.radio_button_checked,
        size: 18,
        color: KantuColors.primary,
      ),
      title: Text(
        evento['estado']?.toString().replaceAll('_', ' ').toUpperCase() ?? '',
      ),
      subtitle: Text(
        [
          _fecha(evento['fecha']),
          if (observacion.isNotEmpty) observacion,
        ].join('\n'),
      ),
    );
  }

  Widget _resenaCard(Map<String, dynamic> resena) {
    final esTienda = resena['tipo'] == 'tienda';
    final nombre = esTienda
        ? resena['tienda_nombre']
        : resena['producto_nombre'];
    final calificacion = _entero(resena['calificacion']).clamp(0, 5);
    final comentario = resena['comentario']?.toString() ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: KantuColors.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            esTienda ? 'Tienda · $nombre' : 'Producto · $nombre',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Text(
            '${'★' * calificacion}${'☆' * (5 - calificacion)}',
            style: const TextStyle(color: KantuColors.warning, fontSize: 18),
          ),
          if (comentario.isNotEmpty) Text(comentario),
        ],
      ),
    );
  }

  Widget _aviso(String mensaje, {bool error = false}) => Container(
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: error ? const Color(0xFFFFEEEE) : const Color(0xFFE9F5EF),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      mensaje,
      style: TextStyle(color: error ? KantuColors.error : KantuColors.success),
    ),
  );
}
