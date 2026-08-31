import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/services/tienda_service.dart';
import '../../core/services/auth_service.dart';
import '../shared/custom_button.dart';
import '../shared/custom_text_field.dart';

class CreateTiendaDialog extends StatefulWidget {
  const CreateTiendaDialog({super.key});

  @override
  State<CreateTiendaDialog> createState() => _CreateTiendaDialogState();
}

class _CreateTiendaDialogState extends State<CreateTiendaDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _slugController = TextEditingController();
  final _descripcionController = TextEditingController();
  String _selectedColor = '#C8102E';

  final List<Map<String, String>> _colorOptions = [
    {'name': 'Rojo Kantu', 'hex': '#C8102E'},
    {'name': 'Verde Andino', 'hex': '#27AE60'},
    {'name': 'Amarillo Dorado', 'hex': '#F4D03F'},
    {'name': 'Azul Colonial', 'hex': '#3B82F6'},
    {'name': 'Púrpura Textil', 'hex': '#8E44AD'},
  ];

  @override
  void dispose() {
    _nombreController.dispose();
    _slugController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  void _onNombreChanged(String val) {
    if (_slugController.text.isEmpty || _slugController.text == _slugify(_nombreController.text.substring(0, _nombreController.text.isNotEmpty ? _nombreController.text.length - 1 : 0))) {
      _slugController.text = _slugify(val);
    }
  }

  String _slugify(String text) {
    return text.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9]'), '-');
  }

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return KantuColors.primary;
    }
  }

  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;
    final user = context.read<AuthService>().currentUser;
    if (user == null) return;

    final tiendaService = context.read<TiendaService>();
    final created = await tiendaService.createTienda(
      usuario: user,
      nombre: _nombreController.text.trim(),
      slug: _slugController.text.trim(),
      colorPrimario: _selectedColor,
      descripcion: _descripcionController.text.trim(),
    );

    if (created != null && mounted) {
      Navigator.pop(context, created);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Tienda "${created.nombre}" creada con éxito!'),
          backgroundColor: KantuColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tiendaService = context.watch<TiendaService>();

    return Container(
      padding: EdgeInsets.only(
        top: 24,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: KantuColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Text('🏢 ', style: TextStyle(fontSize: 22)),
                  Text(
                    'Registrar Nueva Tienda',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: KantuColors.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (tiendaService.errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Text(
                    tiendaService.errorMessage!,
                    style: const TextStyle(fontSize: 12, color: KantuColors.error),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              CustomTextField(
                label: 'Nombre de la Tienda',
                hint: 'Ej. Tejidos del Illimani',
                controller: _nombreController,
                onChanged: _onNombreChanged,
                validator: (v) => v == null || v.trim().isEmpty ? 'El nombre es obligatorio' : null,
              ),
              const SizedBox(height: 14),

              CustomTextField(
                label: 'Slug / URL Identificador',
                hint: 'tejidos-del-illimani',
                controller: _slugController,
              ),
              const SizedBox(height: 14),

              // Color Primario Selector
              const Text(
                'Color Corporativo de la Tienda',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: KantuColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _colorOptions.map((opt) {
                  final hex = opt['hex']!;
                  final color = _parseColor(hex);
                  final isSelected = _selectedColor == hex;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = hex),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.black : Colors.transparent,
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: color.withAlpha(80),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              CustomTextField(
                label: 'Descripción de la Tienda',
                hint: 'Describe los productos o servicios que ofrece tu empresa...',
                controller: _descripcionController,
                maxLines: 3,
              ),
              const SizedBox(height: 24),

              CustomButton(
                text: 'Crear Tienda',
                isLoading: tiendaService.isLoading,
                onPressed: _handleCreate,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
