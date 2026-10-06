import 'dart:io';
import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../core/models/pedido.dart';
import '../../core/services/pedidos_service.dart';

/// Modal BottomSheet para la trazabilidad y seguimiento en tiempo real del pedido (CU-20)
/// y el registro de calificaciones con estrellas tÃ¡ctiles nativas (CU-21).
class SeguimientoPedidoSheet extends StatefulWidget {
  const SeguimientoPedidoSheet({super.key, required this.pedido});

  SeguimientoPedidoSheet.porId({
    super.key,
    required int pedidoId,
  }) : pedido = Pedido(
          id: pedidoId,
          clienteId: 0,
          tiendaId: 0,
          fecha: '',
          subtotal: 0.0,
          total: 0.0,
        );

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
  String _tipo = 'producto'; // 'producto' | 'tienda'
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

      // Resiliencia ante errores HTTP 404 o caÃ­das de red:
      // Si la carga inicial falla, cerramos el bottomsheet de forma segura y regresamos
      // a la lista principal desplegando un SnackBar descriptivo sin provocar crashes.
      Navigator.of(context).pop();

      final is404 = error is PedidoNotFoundException ||
          error is HttpException ||
          error.toString().contains('404') ||
          error.toString().toLowerCase().contains('no encontrado');

      final mensaje = is404
          ? 'El pedido #${widget.pedido.id} no fue encontrado o no tienes permiso para verlo.'
          : 'Error de conexiÃ³n al consultar el pedido #${widget.pedido.id}. Revisa tu conexiÃ³n.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                is404 ? Icons.search_off_rounded : Icons.wifi_off_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  mensaje,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: KantuColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    if (_tipo == 'producto' && _productoId == null) {
      setState(() => _error = 'Selecciona el producto a calificar.');
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
      await _cargarSilencioso();

      if (mounted) {
        setState(() {
          _guardando = false;
          _mensaje = 'Â¡Tu calificaciÃ³n fue registrada exitosamente!';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 12),
                Text('Â¡CalificaciÃ³n guardada correctamente!'),
              ],
            ),
            backgroundColor: KantuColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = _textoError(error);
      });
    }
  }

  Future<void> _cargarSilencioso() async {
    try {
      final detalle = await _service.obtenerDetalle(widget.pedido.id);
      if (!mounted) return;
      setState(() {
        _detalle = detalle;
        _resenas = (detalle['resenas'] as List? ?? const [])
            .cast<Map<String, dynamic>>();
      });
    } catch (_) {}
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

  Color _colorPorEstado(String estado) {
    switch (estado.toLowerCase()) {
      case 'completado':
      case 'completada':
      case 'entregado':
      case 'finalizado':
        return KantuColors.success;
      case 'en_camino':
      case 'enviado':
      case 'en_proceso':
        return KantuColors.info;
      case 'pagado':
        return const Color(0xFF0D9488);
      case 'cancelado':
        return KantuColors.error;
      case 'pendiente':
      default:
        return KantuColors.warning;
    }
  }

  IconData _iconoPorEstado(String estado) {
    switch (estado.toLowerCase()) {
      case 'completado':
      case 'completada':
      case 'entregado':
      case 'finalizado':
        return Icons.check_circle_rounded;
      case 'en_camino':
      case 'enviado':
        return Icons.local_shipping_rounded;
      case 'en_proceso':
        return Icons.inventory_2_rounded;
      case 'pagado':
        return Icons.paid_rounded;
      case 'cancelado':
        return Icons.cancel_rounded;
      case 'pendiente':
      default:
        return Icons.pending_actions_rounded;
    }
  }

  String _fecha(dynamic raw) {
    final fecha = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (fecha == null) return 'Fecha no disponible';
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    final hora = fecha.hour.toString().padLeft(2, '0');
    final minuto = fecha.minute.toString().padLeft(2, '0');
    return '$dia/$mes/${fecha.year} Â· $hora:$minuto';
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: _cargando
              ? const SizedBox(
                  height: 320,
                  child: Center(
                    child: CircularProgressIndicator(color: KantuColors.primary),
                  ),
                )
              : DraggableScrollableSheet(
                  initialChildSize: 0.85,
                  minChildSize: 0.5,
                  maxChildSize: 0.95,
                  expand: false,
                  builder: (context, scrollController) => _contenido(scrollController),
                ),
        ),
      ),
    );
  }

  Widget _contenido(ScrollController scrollController) {
    final detalle = _detalle;
    final estadoActual = (detalle?['estado'] ?? widget.pedido.estadoActual).toString();
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
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        // Grab handle bar
        Center(
          child: Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: KantuColors.border,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
        const SizedBox(height: 18),

        // Cabecera del pedido
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pedido #${widget.pedido.id}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: KantuColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    (detalle?['tienda_nombre'] ?? widget.pedido.tiendaNombre).toString(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: KantuColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _colorPorEstado(estadoActual).withAlpha(30),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _colorPorEstado(estadoActual).withAlpha(80),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _iconoPorEstado(estadoActual),
                    size: 15,
                    color: _colorPorEstado(estadoActual),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    estadoActual.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _colorPorEstado(estadoActual),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        if (_error != null) _aviso(_error!, error: true),
        if (_mensaje != null) _aviso(_mensaje!),

        const SizedBox(height: 20),

        // Resumen financiero
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: KantuColors.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: KantuColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total del Pedido',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: KantuColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Bs. ${detalle?['total'] ?? widget.pedido.total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: KantuColors.primary,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'MÃ©todo de Pago',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: KantuColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    (detalle?['metodo_pago'] ?? widget.pedido.metodoPago).toString(),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: KantuColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 22),

        // Lista de Ãtems
        const Text(
          'Productos Adquiridos',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        ...items.map((item) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: KantuColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: KantuColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(Icons.shopping_bag_outlined, color: KantuColors.primary, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['producto_nombre']?.toString() ?? 'Producto',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    Text(
                      '${item['variante_nombre'] ?? ''} Â· ${item['cantidad'] ?? 0} unid.',
                      style: const TextStyle(color: KantuColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(
                'Bs. ${item['subtotal'] ?? '0.00'}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ],
          ),
        )),

        const SizedBox(height: 22),

        // Timeline de Seguimiento de Estados (CU-20)
        const Row(
          children: [
            Icon(Icons.timeline_rounded, color: KantuColors.primary, size: 20),
            SizedBox(width: 8),
            Text(
              'LÃ­nea de Tiempo de Seguimiento',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (historial.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: KantuColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'No hay registros histÃ³ricos para este pedido aÃºn.',
              style: TextStyle(color: KantuColors.textSecondary),
            ),
          )
        else
          ...List.generate(historial.length, (index) {
            final evento = historial[index];
            final esUltimo = index == historial.length - 1;
            return _timelineItem(evento, esUltimo: esUltimo);
          }),

        // SecciÃ³n de ReseÃ±as y CalificaciÃ³n TÃ¡ctil (CU-21)
        const SizedBox(height: 28),
        const Divider(height: 1),
        const SizedBox(height: 20),

        if (_calificable) ...[
          const Row(
            children: [
              Icon(Icons.star_rounded, color: KantuColors.warning, size: 22),
              SizedBox(width: 8),
              Text(
                'Califica tu Compra',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Comparte tu opiniÃ³n sobre el producto y la tienda para ayudar a la comunidad.',
            style: TextStyle(fontSize: 12, color: KantuColors.textSecondary),
          ),
          const SizedBox(height: 14),

          // Selector de Tipo de ReseÃ±a (Producto vs Tienda)
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('ðŸ·ï¸ Producto')),
                  selected: _tipo == 'producto',
                  selectedColor: KantuColors.primaryLight,
                  onSelected: (val) => setState(() => _tipo = 'producto'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('ðŸ¬ Tienda')),
                  selected: _tipo == 'tienda',
                  selectedColor: KantuColors.primaryLight,
                  onSelected: (val) => setState(() => _tipo = 'tienda'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Selector de Producto si aplica
          if (_tipo == 'producto') ...[
            DropdownButtonFormField<int>(
              initialValue: productos.any(
                (item) => _entero(item['producto_id']) == _productoId,
              )
                  ? _productoId
                  : null,
              decoration: InputDecoration(
                labelText: 'Producto a calificar',
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: productos.map(
                (item) => DropdownMenuItem<int>(
                  value: _entero(item['producto_id']),
                  child: Text(
                    item['producto_nombre']?.toString() ?? 'Producto',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ).toList(),
              onChanged: (value) => setState(() => _productoId = value),
            ),
            const SizedBox(height: 14),
          ],

          // Componente Nativo TÃ¡ctil de 5 Estrellas
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: KantuColors.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: KantuColors.border),
            ),
            child: Column(
              children: [
                const Text(
                  'Tu PuntuaciÃ³n',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 8),
                _selectorEstrellasTactil(),
                const SizedBox(height: 4),
                Text(
                  _descripcionEstrellas(_calificacion),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: KantuColors.warning,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Campo de Comentario
          TextField(
            controller: _comentarioController,
            maxLength: 500,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'CuÃ©ntanos tu experiencia (opcional)',
              alignLabelWithHint: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 10),

          // BotÃ³n Guardar
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: KantuColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _guardando ? null : _guardar,
              icon: _guardando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.rate_review_rounded),
              label: Text(_guardando ? 'Guardando reseÃ±a...' : 'Publicar CalificaciÃ³n'),
            ),
          ),

          // ReseÃ±as existentes
          if (_resenas.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'ReseÃ±as registradas en este pedido:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ..._resenas.map(_resenaCard),
          ],
        ] else ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: KantuColors.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: KantuColors.border),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: KantuColors.textSecondary),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Las calificaciones y reseÃ±as estarÃ¡n disponibles cuando tu pedido haya sido completado o entregado.',
                    style: TextStyle(fontSize: 13, color: KantuColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _selectorEstrellasTactil() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final estrellaNum = index + 1;
        final activa = estrellaNum <= _calificacion;
        return InkWell(
          onTap: () => setState(() => _calificacion = estrellaNum),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: AnimatedScale(
              scale: activa ? 1.15 : 1.0,
              duration: const Duration(milliseconds: 150),
              child: Icon(
                activa ? Icons.star_rounded : Icons.star_outline_rounded,
                color: activa ? KantuColors.warning : KantuColors.border,
                size: 38,
              ),
            ),
          ),
        );
      }),
    );
  }

  String _descripcionEstrellas(int calificacion) {
    switch (calificacion) {
      case 5:
        return '5 / 5 â€” Â¡Excelente experiencia!';
      case 4:
        return '4 / 5 â€” Muy bueno';
      case 3:
        return '3 / 5 â€” Regular / Aceptable';
      case 2:
        return '2 / 5 â€” Mejorable';
      case 1:
      default:
        return '1 / 5 â€” Mala experiencia';
    }
  }

  Widget _timelineItem(Map<String, dynamic> evento, {required bool esUltimo}) {
    final estado = evento['estado']?.toString() ?? '';
    final color = _colorPorEstado(estado);
    final observacion = evento['observacion']?.toString() ?? '';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Columna de nodos y lÃ­nea vertical conectora
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withAlpha(30),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: Center(
                  child: Icon(_iconoPorEstado(estado), size: 14, color: color),
                ),
              ),
              if (!esUltimo)
                Expanded(
                  child: Container(
                    width: 2,
                    color: KantuColors.border,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),

          // Contenido del evento
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: esUltimo ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    estado.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _fecha(evento['fecha']),
                    style: const TextStyle(
                      fontSize: 12,
                      color: KantuColors.textSecondary,
                    ),
                  ),
                  if (observacion.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: KantuColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: KantuColors.border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 14,
                            color: KantuColors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              observacion,
                              style: const TextStyle(
                                fontSize: 12,
                                color: KantuColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KantuColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  esTienda ? 'ðŸ¬ Tienda Â· $nombre' : 'ðŸ·ï¸ Producto Â· $nombre',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    index < calificacion ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 16,
                    color: KantuColors.warning,
                  );
                }),
              ),
            ],
          ),
          if (comentario.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              comentario,
              style: const TextStyle(fontSize: 13, color: KantuColors.textPrimary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _aviso(String mensaje, {bool error = false}) => Container(
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: error ? const Color(0xFFFFEEEE) : const Color(0xFFE9F5EF),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: error ? KantuColors.error.withAlpha(60) : KantuColors.success.withAlpha(60),
      ),
    ),
    child: Row(
      children: [
        Icon(
          error ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
          size: 18,
          color: error ? KantuColors.error : KantuColors.success,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            mensaje,
            style: TextStyle(
              color: error ? KantuColors.error : KantuColors.success,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}
