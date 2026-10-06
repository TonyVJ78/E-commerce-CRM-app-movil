import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/services/catalogo_service.dart';

/// Modal BottomSheet para filtros avanzados del catálogo móvil:
/// - Rango de precio (min y max)
/// - Disponibilidad (solo en stock)
/// - Criterio de ordenamiento
class FiltroCatalogoSheet extends StatefulWidget {
  final CatalogoService catalogo;

  const FiltroCatalogoSheet({
    super.key,
    required this.catalogo,
  });

  @override
  State<FiltroCatalogoSheet> createState() => _FiltroCatalogoSheetState();
}

class _FiltroCatalogoSheetState extends State<FiltroCatalogoSheet> {
  late final TextEditingController _minController;
  late final TextEditingController _maxController;
  late bool _enStock;
  late String _orden;

  @override
  void initState() {
    super.initState();
    _minController = TextEditingController(
      text: widget.catalogo.precioMin != null ? widget.catalogo.precioMin!.toInt().toString() : '',
    );
    _maxController = TextEditingController(
      text: widget.catalogo.precioMax != null ? widget.catalogo.precioMax!.toInt().toString() : '',
    );
    _enStock = widget.catalogo.enStock;
    _orden = widget.catalogo.orden;
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  void _aplicar() {
    final minVal = double.tryParse(_minController.text.trim());
    final maxVal = double.tryParse(_maxController.text.trim());

    widget.catalogo.setFiltrosAvanzados(
      precioMin: minVal,
      precioMax: maxVal,
      enStock: _enStock,
      orden: _orden,
    );
    Navigator.of(context).pop();
  }

  void _restablecer() {
    _minController.clear();
    _maxController.clear();
    setState(() {
      _enStock = false;
      _orden = 'recientes';
    });
    widget.catalogo.setFiltrosAvanzados(
      precioMin: null,
      precioMax: null,
      enStock: false,
      orden: 'recientes',
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.tune, color: KantuColors.primary, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Filtros del Catálogo',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: KantuColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 24),

            // Rango de Precio
            const Text(
              'RANGO DE PRECIO (Bs.)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: KantuColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Mínimo',
                      prefixText: 'Bs. ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('—', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                Expanded(
                  child: TextField(
                    controller: _maxController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Máximo',
                      prefixText: 'Bs. ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                _PresetChip(
                  label: 'Hasta 50 Bs',
                  onTap: () {
                    _minController.text = '0';
                    _maxController.text = '50';
                  },
                ),
                _PresetChip(
                  label: '50 a 150 Bs',
                  onTap: () {
                    _minController.text = '50';
                    _maxController.text = '150';
                  },
                ),
                _PresetChip(
                  label: '+150 Bs',
                  onTap: () {
                    _minController.text = '150';
                    _maxController.clear();
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Disponibilidad
            const Text(
              'DISPONIBILIDAD',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: KantuColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Solo productos en stock',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Ocultar productos agotados temporalmente',
                style: TextStyle(fontSize: 12, color: KantuColors.textMuted),
              ),
              activeColor: KantuColors.primary,
              value: _enStock,
              onChanged: (val) => setState(() => _enStock = val),
            ),
            const SizedBox(height: 16),

            // Ordenamiento
            const Text(
              'ORDENAR POR',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: KantuColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SortChip(
                  label: 'Más recientes',
                  value: 'recientes',
                  selected: _orden == 'recientes',
                  onSelected: (v) => setState(() => _orden = v),
                ),
                _SortChip(
                  label: 'Menor precio',
                  value: 'precio_asc',
                  selected: _orden == 'precio_asc',
                  onSelected: (v) => setState(() => _orden = v),
                ),
                _SortChip(
                  label: 'Mayor precio',
                  value: 'precio_desc',
                  selected: _orden == 'precio_desc',
                  onSelected: (v) => setState(() => _orden = v),
                ),
                _SortChip(
                  label: 'Nombre (A-Z)',
                  value: 'nombre_asc',
                  selected: _orden == 'nombre_asc',
                  onSelected: (v) => setState(() => _orden = v),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Botones de acción
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: const BorderSide(color: KantuColors.border),
                    ),
                    onPressed: _restablecer,
                    child: const Text('Restablecer', style: TextStyle(color: KantuColors.textPrimary)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: KantuColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _aplicar,
                    child: const Text('Aplicar Filtros', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PresetChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      backgroundColor: Colors.grey.shade100,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onPressed: onTap,
    );
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final ValueChanged<String> onSelected;

  const _SortChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: KantuColors.primary,
      backgroundColor: Colors.grey.shade100,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: selected ? Colors.white : KantuColors.textPrimary,
      ),
      onSelected: (_) => onSelected(value),
    );
  }
}
