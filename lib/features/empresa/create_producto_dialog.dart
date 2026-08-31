import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/models/tienda.dart';
import '../../core/services/catalogo_service.dart';
import '../shared/custom_button.dart';
import '../shared/custom_text_field.dart';

class CreateProductoDialog extends StatefulWidget {
  final Tienda tienda;

  const CreateProductoDialog({super.key, required this.tienda});

  @override
  State<CreateProductoDialog> createState() => _CreateProductoDialogState();
}

class _CreateProductoDialogState extends State<CreateProductoDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _precioController = TextEditingController();
  final _skuController = TextEditingController();
  final _stockController = TextEditingController(text: '10');
  bool _isLoading = false;

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    _precioController.dispose();
    _skuController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final catalogo = context.read<CatalogoService>();
    final success = await catalogo.createProducto(
      tiendaId: widget.tienda.id,
      tiendaNombre: widget.tienda.nombre,
      nombre: _nombreController.text.trim(),
      descripcion: _descripcionController.text.trim(),
      precioBase: double.tryParse(_precioController.text.trim()) ?? 0.0,
      sku: _skuController.text.trim(),
      imagenUrl: '',
      stock: int.tryParse(_stockController.text.trim()) ?? 10,
    );

    setState(() => _isLoading = false);

    if (success && mounted) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Producto agregado al catálogo de la tienda!'),
          backgroundColor: KantuColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
              Text(
                'Nuevo Producto para ${widget.tienda.nombre}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: KantuColors.textPrimary),
              ),
              const SizedBox(height: 16),

              CustomTextField(
                label: 'Nombre del Producto',
                hint: 'Ej. Chompa de Alpaca Escote V',
                controller: _nombreController,
                validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      label: 'Precio (Bs.)',
                      hint: '150.00',
                      controller: _precioController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) => v == null || double.tryParse(v) == null ? 'Inválido' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomTextField(
                      label: 'Stock Inicial',
                      hint: '10',
                      controller: _stockController,
                      keyboardType: TextInputType.number,
                      validator: (v) => v == null || int.tryParse(v) == null ? 'Inválido' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              CustomTextField(
                label: 'Código SKU',
                hint: 'ALP-CHO-001',
                controller: _skuController,
              ),
              const SizedBox(height: 12),

              CustomTextField(
                label: 'Descripción',
                hint: 'Detalles sobre material, tallas y cuidados...',
                controller: _descripcionController,
                maxLines: 2,
              ),
              const SizedBox(height: 24),

              CustomButton(
                text: 'Guardar Producto',
                isLoading: _isLoading,
                onPressed: _handleCreate,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
