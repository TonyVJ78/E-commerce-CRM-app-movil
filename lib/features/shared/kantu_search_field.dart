import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';

/// Campo de búsqueda del catálogo, compartido por la vitrina del cliente
/// (CU-11) y el catálogo de la empresa (CU-08/CU-09).
class KantuSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;

  /// Se dispara en cada tecla. Úsalo en modo local, donde filtrar es barato.
  final ValueChanged<String>? onChanged;

  /// Se dispara al pulsar buscar en el teclado. Es la vía preferida cuando el
  /// filtrado lo hace el servidor, para no lanzar una petición por carácter.
  final ValueChanged<String>? onSubmitted;

  /// Se llama al pulsar la "x". Quien lo use debe limpiar el controlador.
  final VoidCallback onLimpiar;

  const KantuSearchField({
    super.key,
    required this.controller,
    required this.onLimpiar,
    this.hint = 'Buscar en el catálogo...',
    this.onChanged,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder borde(Color color, [double ancho = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: ancho),
        );

    return TextField(
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.search,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: KantuColors.textMuted),
        prefixIcon: const Icon(Icons.search, size: 20, color: KantuColors.textMuted),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: onLimpiar,
              ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: borde(KantuColors.border),
        enabledBorder: borde(KantuColors.border),
        focusedBorder: borde(KantuColors.primary, 1.5),
      ),
    );
  }
}

/// Fila de filtros del catálogo: las categorías se desplazan en horizontal y,
/// si se pasa [onInactivos], queda fijo a la derecha el filtro de inactivos que
/// usa el panel de la empresa (CU-09, porque el borrado es lógico).
class FiltrosCategoria extends StatelessWidget {
  final List<({int? id, String nombre})> categorias;
  final int? seleccionada;
  final Color color;
  final ValueChanged<int?> onSeleccionar;
  final bool incluirInactivos;
  final ValueChanged<bool>? onInactivos;

  const FiltrosCategoria({
    super.key,
    required this.categorias,
    required this.seleccionada,
    required this.onSeleccionar,
    this.color = KantuColors.primary,
    this.incluirInactivos = false,
    this.onInactivos,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: categorias.length,
              itemBuilder: (ctx, idx) {
                final categoria = categorias[idx];
                final seleccionado = seleccionada == categoria.id;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(categoria.nombre),
                    selected: seleccionado,
                    selectedColor: color,
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: seleccionado ? Colors.white : KantuColors.textPrimary,
                    ),
                    onSelected: (_) => onSeleccionar(categoria.id),
                  ),
                );
              },
            ),
          ),
          if (onInactivos != null) ...[
            Container(width: 1, height: 24, color: KantuColors.border),
            const SizedBox(width: 8),
            FilterChip(
              avatar: Icon(
                incluirInactivos ? Icons.visibility : Icons.visibility_off_outlined,
                size: 16,
                color: incluirInactivos ? Colors.white : KantuColors.textSecondary,
              ),
              label: const Text('Inactivos'),
              selected: incluirInactivos,
              selectedColor: KantuColors.textSecondary,
              backgroundColor: Colors.white,
              showCheckmark: false,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: incluirInactivos ? Colors.white : KantuColors.textSecondary,
              ),
              onSelected: onInactivos,
            ),
          ],
        ],
      ),
    );
  }
}
