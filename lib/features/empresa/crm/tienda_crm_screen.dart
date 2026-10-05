import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/colors.dart';
import '../../../core/models/crm_cliente_model.dart';
import '../../../core/models/tienda.dart';
import '../../../core/services/crm_service.dart';
import '../../shared/kantu_app_bar.dart';
import '../../shared/kantu_search_field.dart';
import '../../shared/stat_card.dart';
import 'ficha_cliente_sheet.dart';

/// Pantalla Principal del Micro-CRM para Vendedores (CU-15).
///
/// Permite gestionar la cartera de clientes de la tienda, filtrar por segmento
/// (VIP, Frecuente, Nuevo, Inactivo), buscar en tiempo real y consultar métricas
/// comerciales consolidadas (LTV acumulado y total de pedidos).
class TiendaCrmScreen extends StatefulWidget {
  final Tienda tienda;

  const TiendaCrmScreen({
    super.key,
    required this.tienda,
  });

  @override
  State<TiendaCrmScreen> createState() => _TiendaCrmScreenState();
}

class _TiendaCrmScreenState extends State<TiendaCrmScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final crm = context.read<CrmService>();
      crm.setSegmento(null);
      crm.setSearch('');
      crm.loadClientes(widget.tienda.id);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
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

  @override
  Widget build(BuildContext context) {
    final crm = context.watch<CrmService>();
    final clientes = crm.clientesFiltrados;

    return Scaffold(
      backgroundColor: KantuColors.background,
      appBar: KantuAppBar(
        title: 'Micro-CRM • ${widget.tienda.nombre}',
        actions: [
          IconButton(
            tooltip: 'Actualizar Cartera',
            icon: const Icon(Icons.refresh, color: KantuColors.textPrimary),
            onPressed: () => crm.loadClientes(widget.tienda.id),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: _storeColor,
        onRefresh: () => crm.loadClientes(widget.tienda.id),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            // Cabecera Resumen CRM
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: 'Cartera Total',
                    value: '${crm.totalClientes}',
                    subtitle: 'clientes activos',
                    icon: Icons.people_alt_outlined,
                    color: _storeColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatCard(
                    title: 'LTV Promedio',
                    value: 'Bs. ${crm.ltvPromedio.toStringAsFixed(0)}',
                    subtitle: 'valor del cliente',
                    icon: Icons.monetization_on_outlined,
                    color: KantuColors.success,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatCard(
                    title: 'Clientes VIP',
                    value: '${crm.clientesVipCount}',
                    subtitle: 'alto impacto',
                    icon: Icons.star_border_purple500_outlined,
                    color: const Color(0xFFD4AC0D),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Buscador en Tiempo Real
            KantuSearchField(
              controller: _searchController,
              hint: 'Buscar por nombre, correo o teléfono...',
              onChanged: (val) => crm.setSearch(val),
              onLimpiar: () {
                _searchController.clear();
                crm.setSearch('');
              },
            ),
            const SizedBox(height: 12),

            // Chips Horizontales de Segmentos
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FiltroSegmentoChip(
                    label: 'Todos',
                    conteo: crm.totalClientes,
                    seleccionado: crm.selectedSegmento == null || crm.selectedSegmento == 'Todos',
                    color: _storeColor,
                    onTap: () => crm.setSegmento('Todos'),
                  ),
                  const SizedBox(width: 8),
                  _FiltroSegmentoChip(
                    label: 'VIP',
                    conteo: crm.clientesVipCount,
                    seleccionado: crm.selectedSegmento == 'VIP',
                    color: const Color(0xFFD4AC0D),
                    onTap: () => crm.setSegmento('VIP'),
                  ),
                  const SizedBox(width: 8),
                  _FiltroSegmentoChip(
                    label: 'Frecuente',
                    conteo: crm.clientesFrecuentesCount,
                    seleccionado: crm.selectedSegmento == 'Frecuente',
                    color: const Color(0xFF27AE60),
                    onTap: () => crm.setSegmento('Frecuente'),
                  ),
                  const SizedBox(width: 8),
                  _FiltroSegmentoChip(
                    label: 'Nuevo',
                    conteo: crm.clientes.where((c) => c.segmento.toLowerCase() == 'nuevo').length,
                    seleccionado: crm.selectedSegmento == 'Nuevo',
                    color: const Color(0xFF8B5CF6),
                    onTap: () => crm.setSegmento('Nuevo'),
                  ),
                  const SizedBox(width: 8),
                  _FiltroSegmentoChip(
                    label: 'Inactivo',
                    conteo: crm.clientes.where((c) => c.segmento.toLowerCase() == 'inactivo').length,
                    seleccionado: crm.selectedSegmento == 'Inactivo',
                    color: const Color(0xFF64748B),
                    onTap: () => crm.setSegmento('Inactivo'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Listado de Tarjetas de Clientes
            if (crm.isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
            else if (clientes.isEmpty)
              _buildEmptyState(crm)
            else
              for (final cliente in clientes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _TarjetaCliente(
                    cliente: cliente,
                    storeColor: _storeColor,
                    segmentColor: _getSegmentColor(cliente.segmento),
                    onTap: () => FichaClienteSheet.show(context, cliente: cliente, tienda: widget.tienda),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(CrmService crm) {
    final tieneFiltros = crm.searchQuery.isNotEmpty || crm.selectedSegmento != null;
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KantuColors.border),
      ),
      child: Column(
        children: [
          Icon(Icons.person_search_outlined, size: 56, color: KantuColors.textMuted.withAlpha(120)),
          const SizedBox(height: 12),
          Text(
            tieneFiltros ? 'No se encontraron clientes' : 'Sin clientes registrados',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: KantuColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            tieneFiltros
                ? 'Prueba modificando la búsqueda o seleccionando otro segmento.'
                : 'Los clientes aparecerán automáticamente conforme realicen pedidos en tu tienda.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: KantuColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _FiltroSegmentoChip extends StatelessWidget {
  final String label;
  final int conteo;
  final bool seleccionado;
  final Color color;
  final VoidCallback onTap;

  const _FiltroSegmentoChip({
    required this.label,
    required this.conteo,
    required this.seleccionado,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: seleccionado ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: seleccionado ? color : KantuColors.border),
          boxShadow: seleccionado
              ? [BoxShadow(color: color.withAlpha(50), blurRadius: 8, offset: const Offset(0, 2))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: seleccionado ? Colors.white : KantuColors.textPrimary,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: seleccionado ? Colors.white.withAlpha(60) : KantuColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$conteo',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: seleccionado ? Colors.white : KantuColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaCliente extends StatelessWidget {
  final CrmClienteModel cliente;
  final Color storeColor;
  final Color segmentColor;
  final VoidCallback onTap;

  const _TarjetaCliente({
    required this.cliente,
    required this.storeColor,
    required this.segmentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: KantuColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: storeColor.withAlpha(20),
                    child: Text(
                      cliente.initials,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: storeColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cliente.nombre,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: KantuColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          cliente.correo,
                          style: const TextStyle(fontSize: 12, color: KantuColors.textSecondary),
                        ),
                        if (cliente.telefono != null && cliente.telefono!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.phone_outlined, size: 12, color: KantuColors.textMuted),
                              const SizedBox(width: 4),
                              Text(
                                cliente.telefono!,
                                style: const TextStyle(fontSize: 12, color: KantuColors.textMuted),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: segmentColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      cliente.segmento.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: segmentColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),

              // Métricas en Footer de la Tarjeta
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        'LTV: ',
                        style: TextStyle(fontSize: 12, color: KantuColors.textMuted, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        cliente.formattedLtv,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: storeColor),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.shopping_bag_outlined, size: 14, color: KantuColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        '${cliente.totalPedidos} pedidos',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: KantuColors.textSecondary),
                      ),
                    ],
                  ),
                  const Row(
                    children: [
                      Text(
                        'Ver Ficha',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: KantuColors.primary),
                      ),
                      Icon(Icons.chevron_right, size: 16, color: KantuColors.primary),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
