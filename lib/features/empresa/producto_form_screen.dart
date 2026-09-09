import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/models/producto.dart';
import '../../core/models/tienda.dart';
import '../../core/services/api_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/catalogo_service.dart';
import '../shared/custom_button.dart';
import '../shared/custom_text_field.dart';
import '../shared/kantu_app_bar.dart';
import '../shared/producto_imagen.dart';

/// Formulario de producto. Sirve para registrar (CU-08) y para editar (CU-09):
/// si recibe [producto] entra en modo edición.
///
/// Es pantalla completa y no un bottom sheet porque el producto tiene bastantes
/// campos —incluida una lista de variantes de largo variable— y un sheet con el
/// teclado abierto deja muy poco espacio útil.
class ProductoFormScreen extends StatefulWidget {
  final Tienda tienda;
  final Producto? producto;

  const ProductoFormScreen({super.key, required this.tienda, this.producto});

  bool get esEdicion => producto != null;

  @override
  State<ProductoFormScreen> createState() => _ProductoFormScreenState();
}

/// Controladores de una fila de variante. Se mantienen vivos mientras la
/// variante siga en el formulario y se liberan al quitarla.
class _VarianteForm {
  final int id; // 0 = variante nueva
  final TextEditingController nombre;
  final TextEditingController sku;
  final TextEditingController precio;
  final TextEditingController precioOferta;
  final TextEditingController stock;
  final TextEditingController stockMinimo;
  bool activa;

  _VarianteForm({
    this.id = 0,
    String nombreInicial = 'Unica',
    String skuInicial = '',
    String precioInicial = '',
    String precioOfertaInicial = '',
    String stockInicial = '0',
    String stockMinimoInicial = '5',
    this.activa = true,
  })  : nombre = TextEditingController(text: nombreInicial),
        sku = TextEditingController(text: skuInicial),
        precio = TextEditingController(text: precioInicial),
        precioOferta = TextEditingController(text: precioOfertaInicial),
        stock = TextEditingController(text: stockInicial),
        stockMinimo = TextEditingController(text: stockMinimoInicial);

  factory _VarianteForm.desde(Variante variante) {
    return _VarianteForm(
      id: variante.id,
      nombreInicial: variante.nombre,
      skuInicial: variante.sku,
      precioInicial: variante.precio.toStringAsFixed(2),
      precioOfertaInicial: variante.precioOferta?.toStringAsFixed(2) ?? '',
      stockInicial: '${variante.stock}',
      stockMinimoInicial: '${variante.stockMinimo}',
      activa: variante.activa,
    );
  }

  Variante aVariante() {
    return Variante(
      id: id,
      nombre: nombre.text.trim().isEmpty ? 'Unica' : nombre.text.trim(),
      sku: sku.text.trim(),
      precio: double.tryParse(precio.text.trim()) ?? 0.0,
      precioOferta: double.tryParse(precioOferta.text.trim()),
      stock: int.tryParse(stock.text.trim()) ?? 0,
      stockMinimo: int.tryParse(stockMinimo.text.trim()) ?? 5,
      activa: activa,
    );
  }

  void dispose() {
    nombre.dispose();
    sku.dispose();
    precio.dispose();
    precioOferta.dispose();
    stock.dispose();
    stockMinimo.dispose();
  }
}

class _ProductoFormScreenState extends State<ProductoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _etiquetaController = TextEditingController();
  final _urlImagenController = TextEditingController();

  final List<_VarianteForm> _variantes = [];
  final List<String> _etiquetas = [];

  int? _categoriaId;
  String? _rutaImagenLocal;
  bool _isLoading = false;
  String? _errorGeneral;

  bool get _online => ApiService.instance.useOnlineBackend;

  @override
  void initState() {
    super.initState();

    final producto = widget.producto;
    if (producto != null) {
      _nombreController.text = producto.nombre;
      _descripcionController.text = producto.descripcion;
      _categoriaId = producto.categoriaId;
      _etiquetas.addAll(producto.etiquetas);
      if (producto.imagenPrincipal.isNotEmpty) {
        final imagen = producto.imagenPrincipal;
        if (imagen.startsWith('http')) {
          _urlImagenController.text = imagen;
        } else {
          _rutaImagenLocal = imagen;
        }
      }
      _variantes.addAll(producto.variantes.map(_VarianteForm.desde));
    }

    if (_variantes.isEmpty) _variantes.add(_VarianteForm());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CatalogoService>().loadCatalogoEmpresa(widget.tienda.id);
    });
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    _etiquetaController.dispose();
    _urlImagenController.dispose();
    for (final variante in _variantes) {
      variante.dispose();
    }
    super.dispose();
  }

  // --- Imagen ---

  Future<void> _elegirImagen(ImageSource origen) async {
    try {
      final archivo = await ImagePicker().pickImage(
        source: origen,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (archivo == null) return;
      setState(() {
        _rutaImagenLocal = archivo.path;
        _urlImagenController.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorGeneral = 'No se pudo abrir el selector de imágenes: $e');
    }
  }

  void _mostrarOpcionesImagen() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: KantuColors.primary),
              title: const Text('Elegir de la galería'),
              onTap: () {
                Navigator.pop(ctx);
                _elegirImagen(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: KantuColors.primary),
              title: const Text('Tomar una foto'),
              onTap: () {
                Navigator.pop(ctx);
                _elegirImagen(ImageSource.camera);
              },
            ),
            if (_rutaImagenLocal != null || _urlImagenController.text.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: KantuColors.error),
                title: const Text('Quitar la imagen', style: TextStyle(color: KantuColors.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _rutaImagenLocal = null;
                    _urlImagenController.clear();
                  });
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String get _imagenActual =>
      _rutaImagenLocal ?? _urlImagenController.text.trim();

  // --- Etiquetas ---

  void _agregarEtiqueta() {
    final texto = _etiquetaController.text.trim();
    if (texto.isEmpty) return;
    if (_etiquetas.any((e) => e.toLowerCase() == texto.toLowerCase())) {
      _etiquetaController.clear();
      return;
    }
    setState(() {
      _etiquetas.add(texto);
      _etiquetaController.clear();
    });
  }

  // --- Categorías ---

  Future<void> _crearCategoria() async {
    final controller = TextEditingController();
    final nombre = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva categoría', style: TextStyle(fontWeight: FontWeight.w800)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Ej. Textiles Andinos'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: KantuColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: KantuColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (nombre == null || nombre.isEmpty || !mounted) return;
    final categoria = await context.read<CatalogoService>().crearCategoriaLocal(
          widget.tienda.id,
          nombre,
        );
    if (!mounted) return;
    setState(() => _categoriaId = categoria.id);
  }

  // --- Variantes ---

  void _agregarVariante() {
    setState(() => _variantes.add(_VarianteForm(nombreInicial: '')));
  }

  void _quitarVariante(int indice) {
    setState(() {
      _variantes.removeAt(indice).dispose();
    });
  }

  /// Valida lo que el formulario no puede comprobar campo por campo: que haya
  /// al menos una variante, que los SKU no se repitan y que haya imagen cuando
  /// el backend la exige. Espeja `ProductoCreateSerializer` del backend.
  String? _validarConjunto() {
    if (_variantes.isEmpty) {
      return 'Agrega al menos una variante con su precio y stock.';
    }

    final skus = <String>{};
    for (final variante in _variantes) {
      final sku = variante.sku.text.trim().toLowerCase();
      if (!skus.add(sku)) {
        return 'Los SKU deben ser únicos dentro del producto: "$sku" está repetido.';
      }
    }

    // Sólo al crear: el PATCH de edición no manda archivos.
    if (!widget.esEdicion && _online && _rutaImagenLocal == null) {
      return 'El servidor exige una imagen del producto. Elige una foto o desactiva el modo servidor.';
    }
    return null;
  }

  Future<void> _guardar() async {
    setState(() => _errorGeneral = null);
    if (!_formKey.currentState!.validate()) return;

    final errorConjunto = _validarConjunto();
    if (errorConjunto != null) {
      setState(() => _errorGeneral = errorConjunto);
      return;
    }

    setState(() => _isLoading = true);

    final catalogo = context.read<CatalogoService>();
    final usuario = context.read<AuthService>().currentUser;
    final variantes = _variantes.map((v) => v.aVariante()).toList();
    final imagen = _imagenActual;

    final producto = Producto(
      id: widget.producto?.id ?? 0,
      tiendaId: widget.tienda.id,
      tiendaNombre: widget.tienda.nombre,
      categoriaId: _categoriaId,
      categoriaNombre: _nombreCategoria(catalogo, _categoriaId),
      nombre: _nombreController.text.trim(),
      slug: widget.producto?.slug ?? '',
      descripcion: _descripcionController.text.trim(),
      etiquetas: List.of(_etiquetas),
      imagenes: imagen.isEmpty ? const [] : [imagen],
      activo: widget.producto?.activo ?? true,
      variantes: variantes,
    );

    // CU-09 al editar, CU-08 al registrar: mismo formulario, distinta llamada.
    final resultado = widget.esEdicion
        ? await catalogo.updateProducto(
            producto: producto,
            variantes: variantes,
            imagenUrl: imagen.startsWith('http') ? imagen : null,
            usuarioEmail: usuario?.email,
          )
        : await catalogo.createProducto(
            producto: producto,
            variantes: variantes,
            rutasImagenes: _rutaImagenLocal != null ? [_rutaImagenLocal!] : const [],
            usuarioEmail: usuario?.email,
          );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!resultado.exito) {
      setState(() => _errorGeneral = resultado.mensaje);
      return;
    }

    Navigator.pop(context, resultado);
  }

  String _nombreCategoria(CatalogoService catalogo, int? categoriaId) {
    if (categoriaId == null) return '';
    for (final categoria in catalogo.categorias) {
      if (categoria.id == categoriaId) return categoria.nombre;
    }
    return widget.producto?.categoriaNombre ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final catalogo = context.watch<CatalogoService>();

    return Scaffold(
      backgroundColor: KantuColors.background,
      appBar: KantuAppBar(
        title: widget.esEdicion ? 'Editar Producto' : 'Nuevo Producto',
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(12),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: CustomButton(
            text: widget.esEdicion ? 'Guardar Cambios' : 'Registrar Producto',
            icon: widget.esEdicion ? Icons.save_outlined : Icons.add_box_outlined,
            isLoading: _isLoading,
            onPressed: _guardar,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_errorGeneral != null) ...[
              _AvisoError(mensaje: _errorGeneral!),
              const SizedBox(height: 16),
            ],
            if (widget.esEdicion && _online && _variantes.length > 1) ...[
              const _AvisoInfo(
                mensaje:
                    'El servidor sólo sincroniza el precio y el stock de la primera variante. '
                    'Los cambios en las demás quedan guardados en este dispositivo.',
              ),
              const SizedBox(height: 16),
            ],

            _Seccion(
              titulo: 'Información general',
              icono: Icons.inventory_2_outlined,
              children: [
                CustomTextField(
                  label: 'Nombre del producto',
                  hint: 'Ej. Chompa de Alpaca Escote V',
                  controller: _nombreController,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'El nombre es obligatorio' : null,
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  label: 'Descripción',
                  hint: 'Material, tallas, cuidados...',
                  controller: _descripcionController,
                  maxLines: 3,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'La descripción es obligatoria' : null,
                ),
                const SizedBox(height: 12),
                _SelectorCategoria(
                  categorias: catalogo.categorias,
                  seleccionada: _categoriaId,
                  onChanged: (valor) => setState(() => _categoriaId = valor),
                  onCrear: _crearCategoria,
                ),
              ],
            ),
            const SizedBox(height: 16),

            _Seccion(
              titulo: 'Imagen del producto',
              icono: Icons.image_outlined,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: _mostrarOpcionesImagen,
                      child: Stack(
                        children: [
                          ProductoImagen(
                            origen: _imagenActual,
                            width: 96,
                            height: 96,
                            emojiPlaceholder: '🖼️',
                          ),
                          Positioned(
                            right: 4,
                            bottom: 4,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: KantuColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.edit, size: 12, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomTextField(
                            label: 'URL de la imagen',
                            hint: 'https://...',
                            controller: _urlImagenController,
                            keyboardType: TextInputType.url,
                            onChanged: (valor) {
                              if (valor.trim().isNotEmpty && _rutaImagenLocal != null) {
                                setState(() => _rutaImagenLocal = null);
                              } else {
                                setState(() {});
                              }
                            },
                          ),
                          const SizedBox(height: 6),
                          Text(
                            !widget.esEdicion && _online
                                ? 'En modo servidor la foto es obligatoria y se sube a Cloudinary.'
                                : 'Toca la miniatura para elegir una foto del teléfono.',
                            style: const TextStyle(fontSize: 11, color: KantuColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            _Seccion(
              titulo: 'Etiquetas',
              icono: Icons.sell_outlined,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _etiquetaController,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _agregarEtiqueta(),
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Ej. alpaca, invierno',
                          hintStyle: const TextStyle(fontSize: 13, color: KantuColors.textMuted),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: KantuColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: KantuColors.border),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      style: IconButton.styleFrom(backgroundColor: KantuColors.primary),
                      icon: const Icon(Icons.add, size: 20),
                      onPressed: _agregarEtiqueta,
                    ),
                  ],
                ),
                if (_etiquetas.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final etiqueta in _etiquetas)
                        Chip(
                          label: Text(etiqueta, style: const TextStyle(fontSize: 12)),
                          backgroundColor: KantuColors.accentLight,
                          side: const BorderSide(color: KantuColors.border),
                          deleteIcon: const Icon(Icons.close, size: 14),
                          onDeleted: () => setState(() => _etiquetas.remove(etiqueta)),
                        ),
                    ],
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            _Seccion(
              titulo: 'Variantes',
              icono: Icons.layers_outlined,
              subtitulo: 'El precio y el stock se definen por variante',
              children: [
                for (var i = 0; i < _variantes.length; i++) ...[
                  _TarjetaVariante(
                    variante: _variantes[i],
                    indice: i,
                    puedeEliminar: _variantes.length > 1,
                    onEliminar: () => _quitarVariante(i),
                    onCambio: () => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                ],
                OutlinedButton.icon(
                  onPressed: _agregarVariante,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Añadir variante'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: KantuColors.primary,
                    side: const BorderSide(color: KantuColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    minimumSize: const Size(double.infinity, 44),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Widgets auxiliares del formulario
// ===========================================================================

class _Seccion extends StatelessWidget {
  final String titulo;
  final String? subtitulo;
  final IconData icono;
  final List<Widget> children;

  const _Seccion({
    required this.titulo,
    required this.icono,
    required this.children,
    this.subtitulo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KantuColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, size: 18, color: KantuColors.primary),
              const SizedBox(width: 8),
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: KantuColors.textPrimary,
                ),
              ),
            ],
          ),
          if (subtitulo != null) ...[
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Text(
                subtitulo!,
                style: const TextStyle(fontSize: 11, color: KantuColors.textMuted),
              ),
            ),
          ],
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _SelectorCategoria extends StatelessWidget {
  final List<Categoria> categorias;
  final int? seleccionada;
  final ValueChanged<int?> onChanged;
  final VoidCallback onCrear;

  const _SelectorCategoria({
    required this.categorias,
    required this.seleccionada,
    required this.onChanged,
    required this.onCrear,
  });

  @override
  Widget build(BuildContext context) {
    // Si el producto trae una categoría que aún no está en la lista cargada,
    // el DropdownButton lanzaría una aserción por valor sin item.
    final valor = categorias.any((c) => c.id == seleccionada) ? seleccionada : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Categoría',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: KantuColors.textPrimary),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int?>(
                initialValue: valor,
                isExpanded: true,
                style: const TextStyle(fontSize: 14, color: KantuColors.textPrimary),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: KantuColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: KantuColors.border),
                  ),
                ),
                hint: const Text('Sin categoría', style: TextStyle(fontSize: 13)),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Sin categoría', style: TextStyle(fontSize: 13)),
                  ),
                  for (final categoria in categorias)
                    DropdownMenuItem<int?>(
                      value: categoria.id,
                      child: Text(categoria.nombre, style: const TextStyle(fontSize: 13)),
                    ),
                ],
                onChanged: onChanged,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.outlined(
              tooltip: 'Nueva categoría',
              icon: const Icon(Icons.create_new_folder_outlined, size: 20),
              style: IconButton.styleFrom(foregroundColor: KantuColors.primary),
              onPressed: onCrear,
            ),
          ],
        ),
      ],
    );
  }
}

class _TarjetaVariante extends StatelessWidget {
  final _VarianteForm variante;
  final int indice;
  final bool puedeEliminar;
  final VoidCallback onEliminar;
  final VoidCallback onCambio;

  const _TarjetaVariante({
    required this.variante,
    required this.indice,
    required this.puedeEliminar,
    required this.onEliminar,
    required this.onCambio,
  });

  String? _validarDecimal(String? valor, {bool obligatorio = true}) {
    final texto = valor?.trim() ?? '';
    if (texto.isEmpty) return obligatorio ? 'Requerido' : null;
    final numero = double.tryParse(texto);
    if (numero == null) return 'Inválido';
    if (numero < 0) return 'No negativo';
    return null;
  }

  String? _validarEntero(String? valor) {
    final texto = valor?.trim() ?? '';
    if (texto.isEmpty) return 'Requerido';
    final numero = int.tryParse(texto);
    if (numero == null) return 'Inválido';
    if (numero < 0) return 'No negativo';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: KantuColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KantuColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: KantuColors.primaryLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    '${indice + 1}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: KantuColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Variante',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
              Switch(
                value: variante.activa,
                activeThumbColor: KantuColors.success,
                onChanged: (valor) {
                  variante.activa = valor;
                  onCambio();
                },
              ),
              if (puedeEliminar)
                IconButton(
                  tooltip: 'Quitar variante',
                  icon: const Icon(Icons.delete_outline, size: 20, color: KantuColors.error),
                  onPressed: onEliminar,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: CustomTextField(
                  label: 'Nombre',
                  hint: 'Talla M',
                  controller: variante.nombre,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CustomTextField(
                  label: 'SKU',
                  hint: 'ALP-CHO-001-M',
                  controller: variante.sku,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Requerido' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: CustomTextField(
                  label: 'Precio (Bs.)',
                  hint: '150.00',
                  controller: variante.precio,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: _validarDecimal,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CustomTextField(
                  label: 'Oferta (opcional)',
                  hint: '129.00',
                  controller: variante.precioOferta,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => _validarDecimal(v, obligatorio: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: CustomTextField(
                  label: 'Stock',
                  hint: '10',
                  controller: variante.stock,
                  keyboardType: TextInputType.number,
                  validator: _validarEntero,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CustomTextField(
                  label: 'Stock mínimo',
                  hint: '5',
                  controller: variante.stockMinimo,
                  keyboardType: TextInputType.number,
                  validator: _validarEntero,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AvisoError extends StatelessWidget {
  final String mensaje;

  const _AvisoError({required this.mensaje});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: KantuColors.error.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KantuColors.error.withAlpha(60)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 18, color: KantuColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              mensaje,
              style: const TextStyle(fontSize: 12, color: KantuColors.error, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvisoInfo extends StatelessWidget {
  final String mensaje;

  const _AvisoInfo({required this.mensaje});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: KantuColors.accentLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KantuColors.accentDark.withAlpha(60)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: KantuColors.accentDark),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              mensaje,
              style: const TextStyle(fontSize: 12, color: KantuColors.textSecondary, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
