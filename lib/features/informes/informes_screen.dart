import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/constants/colors.dart';
import '../../core/models/informe.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/informes_service.dart';
import 'informe_detalle_screen.dart';

/// Informes de tienda con IA (CU-34) para administradores y encargados.
///
/// El pedido se escribe o se dicta. Si es muy general, el analista pregunta
/// antes de consultar; cuando arma el informe aparece una tarjeta que abre la
/// tabla, el análisis y la exportación a PDF o Excel.
class InformesScreen extends StatefulWidget {
  const InformesScreen({super.key});

  @override
  State<InformesScreen> createState() => _InformesScreenState();
}

class _InformesScreenState extends State<InformesScreen> {
  final _texto = TextEditingController();
  final _scroll = ScrollController();
  final _voz = SpeechToText();
  bool _vozLista = false;
  bool _escuchando = false;
  String _textoAntesDeDictar = '';
  int _cantidadVista = 0;

  @override
  void initState() {
    super.initState();
    final servicio = context.read<InformesService>();
    servicio.prepararPara(context.read<AuthService>().currentUser?.id);
    if (servicio.contexto == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => servicio.cargarContexto());
    }
    _texto.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _voz.stop();
    _texto.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _enviar(String texto) {
    final servicio = context.read<InformesService>();
    if (texto.trim().isEmpty || servicio.enviando) return;
    if (_escuchando) _voz.stop();
    servicio.enviar(texto);
    _texto.clear();
  }

  void _bajarAlFinal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _aviso(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  // ------------------------------------------------------------------ voz

  Future<void> _alternarVoz() async {
    if (_escuchando) {
      await _voz.stop();
      return;
    }
    if (!_vozLista) {
      _vozLista = await _voz.initialize(
        onStatus: (estado) {
          if (!mounted) return;
          if (estado == SpeechToText.doneStatus || estado == SpeechToText.notListeningStatus) {
            setState(() => _escuchando = false);
          }
        },
        onError: (error) {
          if (!mounted) return;
          setState(() => _escuchando = false);
          if (error.errorMsg.contains('no_match') || error.errorMsg.contains('speech_timeout')) {
            _aviso('No te escuché. Toca el micrófono e intenta de nuevo.');
          }
        },
      );
      if (!_vozLista) {
        _aviso('El dictado no está disponible. Revisa el permiso del micrófono.');
        return;
      }
    }

    // Español de Bolivia si el teléfono lo tiene; si no, cualquier español.
    final idiomas = await _voz.locales();
    final idioma = idiomas.where((l) => l.localeId.replaceAll('-', '_') == 'es_BO').firstOrNull ??
        idiomas.where((l) => l.localeId.toLowerCase().startsWith('es')).firstOrNull;

    _textoAntesDeDictar = _texto.text.trim().isEmpty ? '' : '${_texto.text.trim()} ';
    setState(() => _escuchando = true);
    await _voz.listen(
      onResult: (resultado) {
        final dictado = '$_textoAntesDeDictar${resultado.recognizedWords}';
        _texto.value = TextEditingValue(
          text: dictado,
          selection: TextSelection.collapsed(offset: dictado.length),
        );
      },
      listenOptions: SpeechListenOptions(
        localeId: idioma?.localeId,
        partialResults: true,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        cancelOnError: true,
      ),
    );
  }

  // ------------------------------------------------------------------ informes

  Future<void> _abrirInforme(Informe informe) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => InformeDetalleScreen(informe: informe)),
    );
  }

  Future<void> _abrirHistorial() async {
    final servicio = context.read<InformesService>();
    final informe = await showModalBottomSheet<Informe>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => ChangeNotifierProvider<InformesService>.value(
        value: servicio,
        child: const _HistorialSheet(),
      ),
    );
    if (informe != null && mounted) _abrirInforme(informe);
  }

  @override
  Widget build(BuildContext context) {
    final servicio = context.watch<InformesService>();
    final contexto = servicio.contexto;
    final mensajes = servicio.mensajes;

    final cantidad = mensajes.length + (servicio.enviando ? 1 : 0);
    if (cantidad != _cantidadVista) {
      _cantidadVista = cantidad;
      _bajarAlFinal();
    }

    return Scaffold(
      backgroundColor: KantuColors.background,
      appBar: AppBar(
        backgroundColor: KantuColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Informes IA', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            Text('Pide un informe escrito o por voz',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.white70)),
          ],
        ),
        actions: [
          if (contexto != null) ...[
            IconButton(
              tooltip: 'Mis informes',
              icon: const Icon(Icons.history_rounded),
              onPressed: _abrirHistorial,
            ),
            IconButton(
              tooltip: 'Nueva conversación',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: servicio.enviando ? null : servicio.reiniciar,
            ),
          ],
        ],
      ),
      body: _cuerpo(servicio),
    );
  }

  Widget _cuerpo(InformesService servicio) {
    if (servicio.cargandoContexto && servicio.contexto == null) {
      return const Center(child: CircularProgressIndicator(color: KantuColors.primary));
    }
    if (servicio.sinPermiso) {
      return const _Estado(
        icono: Icons.lock_outline_rounded,
        titulo: 'Sin acceso a informes',
        texto: 'Tu rol no tiene el permiso "Ver · Informes con IA". Pídele a un administrador que te lo asigne en Roles y permisos.',
      );
    }
    if (servicio.contexto == null) {
      return _Estado(
        icono: Icons.cloud_off_rounded,
        titulo: 'No se pudo cargar',
        texto: servicio.errorContexto ?? 'Intenta de nuevo.',
        accion: TextButton(onPressed: servicio.cargarContexto, child: const Text('Reintentar')),
      );
    }

    final contexto = servicio.contexto!;
    final mensajes = servicio.mensajes;
    final ultimo = mensajes.last;
    final sugerencias = !servicio.enviando && !ultimo.esUsuario
        ? (mensajes.length == 1 ? contexto.ejemplos : ultimo.sugerencias)
        : const <String>[];
    final puedeEscribir = contexto.puedeCrear && contexto.tiendas.isNotEmpty;

    return Column(
      children: [
        if (contexto.tiendas.length > 1) _SelectorTienda(contexto: contexto, servicio: servicio),
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
            itemCount: mensajes.length + (servicio.enviando ? 1 : 0),
            itemBuilder: (_, i) {
              if (i == mensajes.length) return const _Consultando();
              return _Mensaje(mensaje: mensajes[i], onAbrirInforme: _abrirInforme);
            },
          ),
        ),
        if (sugerencias.isNotEmpty && puedeEscribir)
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              itemCount: sugerencias.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => ActionChip(
                label: Text(sugerencias[i]),
                onPressed: () => _enviar(sugerencias[i]),
                backgroundColor: Colors.white,
                side: const BorderSide(color: KantuColors.primary, width: 1.3),
                labelStyle: const TextStyle(color: KantuColors.primary, fontWeight: FontWeight.w700, fontSize: 12.5),
                shape: const StadiumBorder(),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        if (!contexto.puedeCrear)
          const _Nota('Puedes ver y exportar tus informes, pero tu rol no tiene permiso para generar nuevos.')
        else if (contexto.tiendas.isEmpty)
          const _Nota('No tienes tiendas asignadas todavía. Crea una o pide que te asignen como encargado.')
        else
          _BarraEntrada(
            controller: _texto,
            habilitado: !servicio.enviando,
            escuchando: _escuchando,
            onVoz: _alternarVoz,
            onEnviar: () => _enviar(_texto.text),
          ),
      ],
    );
  }
}

class _SelectorTienda extends StatelessWidget {
  final ContextoInformes contexto;
  final InformesService servicio;

  const _SelectorTienda({required this.contexto, required this.servicio});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
      child: Row(
        children: [
          const Icon(Icons.storefront_outlined, size: 18, color: KantuColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int?>(
                value: servicio.tiendaId,
                isExpanded: true,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: KantuColors.textPrimary),
                onChanged: servicio.enviando ? null : servicio.elegirTienda,
                items: [
                  DropdownMenuItem<int?>(
                    value: null,
                    child: Text(contexto.esAdministrador ? 'Todas las tiendas' : 'Todas mis tiendas'),
                  ),
                  for (final t in contexto.tiendas)
                    DropdownMenuItem<int?>(value: t.id, child: Text(t.nombre, overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Mensaje extends StatelessWidget {
  final MensajeInforme mensaje;
  final void Function(Informe) onAbrirInforme;

  const _Mensaje({required this.mensaje, required this.onAbrirInforme});

  @override
  Widget build(BuildContext context) {
    final esUsuario = mensaje.esUsuario;
    final informe = mensaje.informe;
    final anchoMax = MediaQuery.sizeOf(context).width * 0.86;

    final Widget contenido;
    if (esUsuario) {
      contenido = Text(mensaje.contenido, style: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.4));
    } else if (informe != null) {
      contenido = _TarjetaInforme(informe: informe, onTap: () => onAbrirInforme(informe));
    } else {
      contenido = MarkdownBody(data: mensaje.contenido, softLineBreak: true, styleSheet: estiloMarkdown(context));
    }

    return Align(
      alignment: esUsuario ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(maxWidth: anchoMax),
        padding: informe != null ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: esUsuario ? KantuColors.primary : (mensaje.error ? KantuColors.primaryLight : Colors.white),
          border: esUsuario ? null : Border.all(color: KantuColors.border),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(esUsuario ? 16 : 4),
            topRight: Radius.circular(esUsuario ? 4 : 16),
            bottomLeft: const Radius.circular(16),
            bottomRight: const Radius.circular(16),
          ),
        ),
        child: contenido,
      ),
    );
  }
}

/// Resumen del informe dentro del chat: título, primeras líneas del análisis
/// y acceso a la tabla completa.
class _TarjetaInforme extends StatelessWidget {
  final Informe informe;
  final VoidCallback onTap;

  const _TarjetaInforme({required this.informe, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: KantuColors.primaryLight, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.bar_chart_rounded, color: KantuColors.primary, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(informe.titulo,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: KantuColors.textPrimary)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              informe.analisis.replaceAll(RegExp(r'[#*_`]'), '').trim(),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, height: 1.4, color: KantuColors.textSecondary),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text('${informe.filas.length} filas · ${informe.tiendaNombre ?? 'Varias tiendas'}',
                    style: const TextStyle(fontSize: 11.5, color: KantuColors.textMuted)),
                const Spacer(),
                const Text('Ver tabla y exportar',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: KantuColors.primary)),
                const Icon(Icons.chevron_right_rounded, color: KantuColors.primary, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BarraEntrada extends StatelessWidget {
  final TextEditingController controller;
  final bool habilitado;
  final bool escuchando;
  final VoidCallback onVoz;
  final VoidCallback onEnviar;

  const _BarraEntrada({
    required this.controller,
    required this.habilitado,
    required this.escuchando,
    required this.onVoz,
    required this.onEnviar,
  });

  @override
  Widget build(BuildContext context) {
    final puedeEnviar = habilitado && controller.text.trim().isNotEmpty;
    final borde = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: KantuColors.border),
    );

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: KantuColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                onPressed: habilitado ? onVoz : null,
                tooltip: escuchando ? 'Detener dictado' : 'Dictar por voz',
                style: IconButton.styleFrom(
                  backgroundColor: escuchando ? KantuColors.primary : KantuColors.background,
                  foregroundColor: escuchando ? Colors.white : KantuColors.textPrimary,
                ),
                icon: Icon(escuchando ? Icons.stop_rounded : Icons.mic_none_rounded),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 2000,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onEnviar(),
                  decoration: InputDecoration(
                    hintText: escuchando ? 'Te escucho…' : 'Ej.: lo más vendido del mes',
                    counterText: '',
                    isDense: true,
                    filled: true,
                    fillColor: KantuColors.background,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    border: borde,
                    enabledBorder: borde,
                    focusedBorder: borde.copyWith(borderSide: const BorderSide(color: KantuColors.primary, width: 1.5)),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                onPressed: puedeEnviar ? onEnviar : null,
                style: IconButton.styleFrom(
                  backgroundColor: KantuColors.primary,
                  disabledBackgroundColor: KantuColors.primary.withAlpha(90),
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white,
                ),
                icon: const Icon(Icons.send_rounded, size: 20),
                tooltip: 'Enviar',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistorialSheet extends StatefulWidget {
  const _HistorialSheet();

  @override
  State<_HistorialSheet> createState() => _HistorialSheetState();
}

class _HistorialSheetState extends State<_HistorialSheet> {
  static final _fecha = DateFormat('dd/MM/yyyy HH:mm');
  List<InformeResumen>? _lista;
  String? _error;
  bool _abriendo = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final r = await context.read<InformesService>().historial();
    if (!mounted) return;
    setState(() {
      _lista = r.valor;
      _error = r.error;
    });
  }

  Future<void> _abrir(InformeResumen item) async {
    if (_abriendo) return;
    setState(() => _abriendo = true);
    final r = await context.read<InformesService>().obtener(item.id);
    if (!mounted) return;
    setState(() => _abriendo = false);
    if (r.ok) {
      Navigator.pop(context, r.valor);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.error!)));
    }
  }

  Future<void> _eliminar(InformeResumen item) async {
    final servicio = context.read<InformesService>();
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Eliminar informe'),
        content: Text('¿Eliminar "${item.titulo}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmar != true) return;
    if (await servicio.eliminar(item.id) && mounted) {
      setState(() => _lista = _lista?.where((i) => i.id != item.id).toList());
    }
  }

  @override
  Widget build(BuildContext context) {
    final puedeEliminar = context.read<InformesService>().contexto?.puedeEliminar ?? false;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      builder: (_, scroll) => Column(
        children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: KantuColors.border, borderRadius: BorderRadius.circular(4))),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(children: [
              Text('Mis informes', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ]),
          ),
          if (_abriendo) const LinearProgressIndicator(color: KantuColors.primary, minHeight: 2),
          Expanded(
            child: _lista == null && _error == null
                ? const Center(child: CircularProgressIndicator(color: KantuColors.primary))
                : _error != null
                    ? Center(child: Text(_error!))
                    : _lista!.isEmpty
                        ? const Center(
                            child: Text('Todavía no generaste informes.',
                                style: TextStyle(color: KantuColors.textSecondary)))
                        : ListView.separated(
                            controller: scroll,
                            itemCount: _lista!.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final item = _lista![i];
                              return ListTile(
                                onTap: () => _abrir(item),
                                leading: const Icon(Icons.insert_chart_outlined_rounded, color: KantuColors.primary),
                                title: Text(item.titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
                                subtitle: Text([
                                  if (item.fecha != null) _fecha.format(item.fecha!),
                                  item.tiendaNombre ?? 'Varias tiendas',
                                  '${item.totalFilas} filas',
                                ].join(' · ')),
                                trailing: puedeEliminar
                                    ? IconButton(
                                        tooltip: 'Eliminar',
                                        icon: const Icon(Icons.delete_outline_rounded),
                                        onPressed: () => _eliminar(item),
                                      )
                                    : null,
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _Estado extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String texto;
  final Widget? accion;

  const _Estado({required this.icono, required this.titulo, required this.texto, this.accion});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 48, color: KantuColors.textMuted),
            const SizedBox(height: 12),
            Text(titulo, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(texto, textAlign: TextAlign.center, style: const TextStyle(color: KantuColors.textSecondary)),
            if (accion != null) ...[const SizedBox(height: 8), accion!],
          ],
        ),
      ),
    );
  }
}

class _Nota extends StatelessWidget {
  final String texto;

  const _Nota(this.texto);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: SafeArea(
        top: false,
        child: Text(texto, style: const TextStyle(fontSize: 12.5, color: KantuColors.textSecondary)),
      ),
    );
  }
}

/// Indicador mientras el analista consulta la base.
class _Consultando extends StatefulWidget {
  const _Consultando();

  @override
  State<_Consultando> createState() => _ConsultandoState();
}

class _ConsultandoState extends State<_Consultando> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: KantuColors.border),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _ctrl,
              builder: (_, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < 3; i++)
                    Transform.translate(
                      offset: Offset(0, -4 * math.max(0, math.sin((_ctrl.value - i * 0.15) * 2 * math.pi))),
                      child: Container(
                        width: 7,
                        height: 7,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: const BoxDecoration(color: KantuColors.textSecondary, shape: BoxShape.circle),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Text('Consultando los datos…', style: TextStyle(fontSize: 12.5, color: KantuColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
