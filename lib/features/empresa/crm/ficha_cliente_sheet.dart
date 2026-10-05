import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/colors.dart';
import '../../../core/models/crm_cliente_model.dart';
import '../../../core/models/crm_interaccion_model.dart';
import '../../../core/models/tienda.dart';
import '../../../core/services/crm_service.dart';
import '../../shared/custom_button.dart';
import '../../shared/custom_text_field.dart';

/// Modal BottomSheet nativo que muestra la Ficha Integral del Cliente (CU-15).
///
/// Incluye métricas comerciales (LTV, ticket promedio), historial de pedidos,
/// lista de deseos para la tienda y bitácora interactiva con formulario para
/// agregar nuevas notas comerciales.
class FichaClienteSheet extends StatefulWidget {
  final CrmClienteModel cliente;
  final Tienda tienda;

  const FichaClienteSheet({
    super.key,
    required this.cliente,
    required this.tienda,
  });

  static Future<void> show(BuildContext context, {
    required CrmClienteModel cliente,
    required Tienda tienda,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FichaClienteSheet(cliente: cliente, tienda: tienda),
    );
  }

  @override
  State<FichaClienteSheet> createState() => _FichaClienteSheetState();
}

class _FichaClienteSheetState extends State<FichaClienteSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Formulario de nueva interacción
  final _formKey = GlobalKey<FormState>();
  final _notaController = TextEditingController();
  String _tipoSeleccionado = 'Consulta';
  String _estadoSeleccionado = 'Resuelto';
  bool _guardandoNota = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final crm = context.read<CrmService>();
      crm.loadInteracciones(widget.cliente.id, widget.tienda.id);
      crm.loadHistorialCompras(widget.cliente.id, widget.tienda.id);
      crm.loadWishlist(widget.cliente.id, widget.tienda.id);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _notaController.dispose();
    super.dispose();
  }

  Color get _storeColor {
    try {
      final clean = widget.tienda.colorPrimario.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return KantuColors.primary;
    }
  }

  Color _getSegmentColor(String seg) {
    switch (seg.toLowerCase()) {
      case 'vip':
        return const Color(0xFFD4AC0D);
      case 'frecuente':
        return const Color(0xFF27AE60);
      case 'nuevo':
        return const Color(0xFF8B5CF6);
      case 'inactivo':
      default:
        return const Color(0xFF64748B);
    }
  }

  Future<void> _handleGuardarNota() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardandoNota = true);
    final crm = context.read<CrmService>();

    final ok = await crm.registrarInteraccion(
      clienteId: widget.cliente.id,
      tiendaId: widget.tienda.id,
      tipo: _tipoSeleccionado,
      mensaje: _notaController.text.trim(),
      estado: _estadoSeleccionado,
    );

    if (!mounted) return;
    setState(() => _guardandoNota = false);

    if (ok) {
      _notaController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nota comercial guardada en la bitácora.'),
          backgroundColor: KantuColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.watch<CrmService>();
    final segmentColor = _getSegmentColor(widget.cliente.segmento);

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: KantuColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Header Cliente
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: _storeColor.withAlpha(25),
                  child: Text(
                    widget.cliente.initials,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _storeColor,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.cliente.nombre,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: KantuColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: segmentColor.withAlpha(25),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              widget.cliente.segmento.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: segmentColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.cliente.correo,
                        style: const TextStyle(fontSize: 12, color: KantuColors.textSecondary),
                      ),
                      if (widget.cliente.telefono != null && widget.cliente.telefono!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.phone_outlined, size: 12, color: KantuColors.textMuted),
                            const SizedBox(width: 4),
                            Text(
                              widget.cliente.telefono!,
                              style: const TextStyle(fontSize: 12, color: KantuColors.textMuted),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: KantuColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Métricas Resumen
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: KantuColors.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: KantuColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _MetricaMini(
                    titulo: 'LTV Acumulado',
                    valor: widget.cliente.formattedLtv,
                    color: _storeColor,
                  ),
                  Container(width: 1, height: 28, color: KantuColors.border),
                  _MetricaMini(
                    titulo: 'Total Pedidos',
                    valor: '${widget.cliente.totalPedidos}',
                    color: KantuColors.info,
                  ),
                  Container(width: 1, height: 28, color: KantuColors.border),
                  _MetricaMini(
                    titulo: 'Ticket Promedio',
                    valor: widget.cliente.formattedTicketPromedio,
                    color: KantuColors.success,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // TabBar
          TabBar(
            controller: _tabController,
            indicatorColor: _storeColor,
            labelColor: _storeColor,
            unselectedLabelColor: KantuColors.textMuted,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            tabs: const [
              Tab(text: 'Compras'),
              Tab(text: 'Deseos'),
              Tab(text: 'Bitácora & Notas'),
            ],
          ),

          // TabBarView Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildComprasTab(crm),
                _buildWishlistTab(crm),
                _buildBitacoraTab(crm),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComprasTab(CrmService crm) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: crm.loadHistorialCompras(widget.cliente.id, widget.tienda.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data!;
        if (items.isEmpty) {
          return const Center(
            child: Text('Sin compras registradas aún en esta tienda.', style: TextStyle(color: KantuColors.textMuted)),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final p = items[i];
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: KantuColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Pedido #${p['id']}',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: KantuColors.textPrimary),
                      ),
                      Text(
                        'Bs. ${(p['total'] as num).toStringAsFixed(2)}',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: _storeColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    p['items']?.toString() ?? '',
                    style: const TextStyle(fontSize: 12, color: KantuColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        p['fecha']?.toString().split('T').first ?? '',
                        style: const TextStyle(fontSize: 11, color: KantuColors.textMuted),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: KantuColors.successLight,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          p['estado']?.toString() ?? 'Completado',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: KantuColors.success),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildWishlistTab(CrmService crm) {
    return FutureBuilder<List<String>>(
      future: crm.loadWishlist(widget.cliente.id, widget.tienda.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data!;
        if (items.isEmpty) {
          return const Center(
            child: Text('El cliente no tiene productos en lista de deseos.', style: TextStyle(color: KantuColors.textMuted)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: items.length,
          itemBuilder: (context, i) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: KantuColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.favorite, size: 18, color: KantuColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      items[i],
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: KantuColors.textPrimary),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBitacoraTab(CrmService crm) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Formulario para Registrar Nueva Interacción
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: KantuColors.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: KantuColors.border),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.edit_note_outlined, size: 20, color: KantuColors.textPrimary),
                      SizedBox(width: 6),
                      Text(
                        'Nueva Nota Comercial',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: KantuColors.textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _tipoSeleccionado,
                          decoration: InputDecoration(
                            labelText: 'Tipo',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Consulta', child: Text('Consulta')),
                            DropdownMenuItem(value: 'Soporte', child: Text('Soporte')),
                            DropdownMenuItem(value: 'Venta', child: Text('Venta')),
                          ],
                          onChanged: (v) => setState(() => _tipoSeleccionado = v!),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _estadoSeleccionado,
                          decoration: InputDecoration(
                            labelText: 'Estado',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Pendiente', child: Text('Pendiente')),
                            DropdownMenuItem(value: 'En Seguimiento', child: Text('Seguimiento')),
                            DropdownMenuItem(value: 'Resuelto', child: Text('Resuelto')),
                          ],
                          onChanged: (v) => setState(() => _estadoSeleccionado = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  CustomTextField(
                    label: 'Detalle o acuerdo con el cliente',
                    hint: 'Ej: Se le contactó por WhatsApp para coordinar entrega...',
                    controller: _notaController,
                    maxLines: 2,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Ingresa el detalle de la nota';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  CustomButton(
                    text: 'Guardar en Bitácora',
                    icon: Icons.save_outlined,
                    color: _storeColor,
                    isLoading: _guardandoNota,
                    onPressed: _handleGuardarNota,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          const Text(
            'Historial de Contactos',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: KantuColors.textPrimary),
          ),
          const SizedBox(height: 10),

          FutureBuilder<List<CrmInteraccionModel>>(
            future: crm.loadInteracciones(widget.cliente.id, widget.tienda.id),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
              }
              final items = snapshot.data!;
              if (items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text('Sin notas previas registradas.', style: TextStyle(color: KantuColors.textMuted)),
                  ),
                );
              }
              return Column(
                children: items.map((inter) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: KantuColors.border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: inter.color.withAlpha(25),
                          child: Icon(inter.icon, size: 16, color: inter.color),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    inter.tipo,
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: inter.color),
                                  ),
                                  Text(
                                    inter.estado,
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: KantuColors.textMuted),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                inter.mensaje,
                                style: const TextStyle(fontSize: 12, color: KantuColors.textPrimary),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${inter.fecha.day}/${inter.fecha.month}/${inter.fecha.year} ${inter.fecha.hour.toString().padLeft(2, '0')}:${inter.fecha.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(fontSize: 10, color: KantuColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MetricaMini extends StatelessWidget {
  final String titulo;
  final String valor;
  final Color color;

  const _MetricaMini({
    required this.titulo,
    required this.valor,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(titulo, style: const TextStyle(fontSize: 10, color: KantuColors.textSecondary, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(valor, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }
}
