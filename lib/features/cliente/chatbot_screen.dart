import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/constants/colors.dart';
import '../../core/models/producto.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/chatbot_service.dart';
import '../shared/producto_imagen.dart';
import 'producto_detail_sheet.dart';

/// Chat con Kantu, el asistente de recomendaciones.
///
/// Las respuestas llegan en Markdown. Los productos citados se pueden abrir
/// tocando su enlace en el texto o la tarjeta que aparece debajo; ambos abren
/// la misma hoja de detalle del catálogo, desde donde se agrega al carrito.
///
/// Se le puede hablar: el micrófono dicta el mensaje y lo envía al terminar la
/// frase, y la respuesta a un mensaje hablado se lee en voz alta (flutter_tts).
class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final _texto = TextEditingController();
  final _scroll = ScrollController();
  int _cantidadVista = 0;

  late final ChatbotService _chat;
  int _cantidadMensajes = 0;

  final _voz = SpeechToText();
  bool _vozLista = false;
  bool _escuchando = false;
  String _textoAntesDeDictar = '';

  final _tts = FlutterTts();
  bool _ttsListo = false;
  bool _hablando = false;

  /// La próxima respuesta del asistente se lee en voz alta (la pregunta fue hablada).
  bool _leerProximaRespuesta = false;

  @override
  void initState() {
    super.initState();
    final usuario = context.read<AuthService>().currentUser;
    _chat = context.read<ChatbotService>()..prepararPara(usuario?.id);
    _cantidadMensajes = _chat.mensajes.length;
    _chat.addListener(_alCambiarChat);
    _texto.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _chat.removeListener(_alCambiarChat);
    _voz.cancel();
    _tts.stop();
    _texto.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _enviar(String texto, {bool porVoz = false}) {
    if (texto.trim().isEmpty || _chat.enviando) return;
    if (_escuchando) _voz.cancel();
    _callar();
    _leerProximaRespuesta = porVoz;
    _chat.enviar(texto);
    _texto.clear();
  }

  /// Lee en voz alta la respuesta que llega tras un mensaje hablado.
  void _alCambiarChat() {
    final mensajes = _chat.mensajes;
    final hayNuevo = mensajes.length > _cantidadMensajes;
    _cantidadMensajes = mensajes.length;
    if (!hayNuevo || !_leerProximaRespuesta || mensajes.last.esUsuario) return;
    _leerProximaRespuesta = false;
    _leerEnVozAlta(mensajes.last.contenido);
  }

  void _aviso(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  // ------------------------------------------------------------------ voz

  Future<void> _alternarVoz() async {
    if (_escuchando) {
      await _voz.stop();
      return;
    }
    await _callar();
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
        _aviso('La voz no está disponible. Revisa el permiso del micrófono.');
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
        // Al terminar la frase el mensaje se envía solo, como en una conversación.
        if (resultado.finalResult && resultado.recognizedWords.trim().isNotEmpty) {
          _enviar(dictado, porVoz: true);
        }
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

  Future<void> _prepararTts() async {
    if (_ttsListo) return;
    _ttsListo = true;
    for (final idioma in const ['es-BO', 'es-US', 'es-ES', 'es-MX']) {
      if (await _tts.isLanguageAvailable(idioma) == true) {
        await _tts.setLanguage(idioma);
        break;
      }
    }
    await _tts.setSpeechRate(0.5);
    void terminar() {
      if (mounted) setState(() => _hablando = false);
    }

    _tts.setCompletionHandler(terminar);
    _tts.setCancelHandler(terminar);
    _tts.setErrorHandler((_) => terminar());
  }

  Future<void> _leerEnVozAlta(String markdown) async {
    final texto = textoParaLeer(markdown);
    if (texto.isEmpty || !mounted) return;
    await _prepararTts();
    if (!mounted) return;
    setState(() => _hablando = true);
    final resultado = await _tts.speak(texto);
    if (resultado != 1 && mounted) {
      setState(() => _hablando = false);
      _aviso('No pude leer la respuesta en voz alta. Revisa el motor de voz del teléfono.');
    }
  }

  Future<void> _callar() async {
    _leerProximaRespuesta = false;
    if (!_hablando) return;
    await _tts.stop();
    if (mounted) setState(() => _hablando = false);
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

  Future<void> _abrirProducto(Producto producto) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProductoDetailSheet(producto: producto),
    );
  }

  /// El asistente solo enlaza productos (`producto:ID`); cualquier otro
  /// enlace se ignora.
  void _alTocarEnlace(String? href) {
    if (href == null || !href.startsWith('producto:')) return;
    final id = int.tryParse(href.substring('producto:'.length));
    if (id == null) return;
    final producto = context.read<ChatbotService>().productoCitado(id);
    if (producto != null) {
      _abrirProducto(producto);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ese producto ya no está disponible.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatbotService>();
    final mensajes = chat.mensajes;

    // Cada mensaje nuevo (o el indicador de escritura) baja la lista.
    final cantidad = mensajes.length + (chat.enviando ? 1 : 0);
    if (cantidad != _cantidadVista) {
      _cantidadVista = cantidad;
      _bajarAlFinal();
    }

    final ultimo = mensajes.isNotEmpty ? mensajes.last : null;
    final sugerencias =
        !chat.enviando && ultimo != null && !ultimo.esUsuario ? ultimo.sugerencias : const <String>[];

    return Scaffold(
      backgroundColor: KantuColors.background,
      appBar: AppBar(
        backgroundColor: KantuColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        title: const Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: KantuColors.accent,
              child: Text(
                'K',
                style: TextStyle(color: KantuColors.textPrimary, fontWeight: FontWeight.w800),
              ),
            ),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Kantu', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                Text(
                  'Asistente de compras con IA',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (_hablando)
            IconButton(
              tooltip: 'Silenciar',
              icon: const Icon(Icons.volume_off_rounded),
              onPressed: _callar,
            ),
          IconButton(
            tooltip: 'Nueva conversación',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: chat.enviando
                ? null
                : () {
                    _callar();
                    chat.reiniciar();
                  },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
              itemCount: mensajes.length + (chat.enviando ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == mensajes.length) return const _Escribiendo();
                final m = mensajes[i];
                return _Mensaje(
                  mensaje: m,
                  onTapLink: _alTocarEnlace,
                  onAbrirProducto: _abrirProducto,
                );
              },
            ),
          ),
          if (sugerencias.isNotEmpty)
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
                  labelStyle: const TextStyle(
                    color: KantuColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                  shape: const StadiumBorder(),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          _BarraEntrada(
            controller: _texto,
            habilitado: !chat.enviando,
            escuchando: _escuchando,
            onEnviar: () => _enviar(_texto.text),
            onVoz: _alternarVoz,
          ),
        ],
      ),
    );
  }
}

class _Mensaje extends StatelessWidget {
  final MensajeChat mensaje;
  final void Function(String? href) onTapLink;
  final void Function(Producto) onAbrirProducto;

  const _Mensaje({
    required this.mensaje,
    required this.onTapLink,
    required this.onAbrirProducto,
  });

  @override
  Widget build(BuildContext context) {
    final esUsuario = mensaje.esUsuario;
    final anchoMax = MediaQuery.sizeOf(context).width * 0.84;

    final burbuja = Container(
      constraints: BoxConstraints(maxWidth: anchoMax),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: esUsuario
            ? KantuColors.primary
            : (mensaje.error ? KantuColors.primaryLight : Colors.white),
        border: esUsuario ? null : Border.all(color: KantuColors.border),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(esUsuario ? 16 : 4),
          topRight: Radius.circular(esUsuario ? 4 : 16),
          bottomLeft: const Radius.circular(16),
          bottomRight: const Radius.circular(16),
        ),
      ),
      child: esUsuario
          ? Text(
              mensaje.contenido,
              style: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.4),
            )
          : MarkdownBody(
              data: mensaje.contenido,
              softLineBreak: true,
              onTapLink: (_, href, _) => onTapLink(href),
              styleSheet: _estilo(context),
            ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: esUsuario ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          burbuja,
          if (mensaje.productos.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: mensaje.productos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => _TarjetaProducto(
                  producto: mensaje.productos[i],
                  onTap: () => onAbrirProducto(mensaje.productos[i]),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  MarkdownStyleSheet _estilo(BuildContext context) {
    const base = TextStyle(fontSize: 14.5, height: 1.45, color: KantuColors.textPrimary);
    return MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: base,
      listBullet: base.copyWith(color: KantuColors.primary),
      strong: const TextStyle(fontWeight: FontWeight.w800),
      a: const TextStyle(
        color: KantuColors.primary,
        fontWeight: FontWeight.w700,
        decoration: TextDecoration.underline,
        decorationColor: KantuColors.primary,
      ),
      h1: base.copyWith(fontSize: 16, fontWeight: FontWeight.w800),
      h2: base.copyWith(fontSize: 15.5, fontWeight: FontWeight.w800),
      h3: base.copyWith(fontSize: 15, fontWeight: FontWeight.w800),
      blockSpacing: 8,
      listIndent: 20,
    );
  }
}

class _TarjetaProducto extends StatelessWidget {
  final Producto producto;
  final VoidCallback onTap;

  const _TarjetaProducto({required this.producto, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 236,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: KantuColors.border),
          ),
          child: Row(
            children: [
              ProductoImagen(origen: producto.imagenPrincipal, width: 72, height: 72, radio: 8),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      producto.nombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                        color: KantuColors.textPrimary,
                      ),
                    ),
                    if (producto.tiendaNombre.isNotEmpty)
                      Text(
                        producto.tiendaNombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: KantuColors.textSecondary),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      'Bs ${producto.precioBase.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: KantuColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: KantuColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarraEntrada extends StatelessWidget {
  final TextEditingController controller;
  final bool habilitado;
  final bool escuchando;
  final VoidCallback onEnviar;
  final VoidCallback onVoz;

  const _BarraEntrada({
    required this.controller,
    required this.habilitado,
    required this.escuchando,
    required this.onEnviar,
    required this.onVoz,
  });

  @override
  Widget build(BuildContext context) {
    final puedeEnviar = habilitado && controller.text.trim().isNotEmpty;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: KantuColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: habilitado ? onVoz : null,
                    tooltip: escuchando ? 'Dejar de escuchar' : 'Hablar con Kantu',
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
                        hintText: escuchando ? 'Te escucho…' : 'Escribe o habla: qué buscas...',
                        counterText: '',
                        isDense: true,
                        filled: true,
                        fillColor: KantuColors.background,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: KantuColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: KantuColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: KantuColors.primary, width: 1.5),
                        ),
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
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Kantu puede equivocarse. Revisa la ficha antes de comprar.',
                  style: TextStyle(fontSize: 10.5, color: KantuColors.textMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tres puntos que rebotan mientras el asistente responde.
class _Escribiendo extends StatefulWidget {
  const _Escribiendo();

  @override
  State<_Escribiendo> createState() => _EscribiendoState();
}

class _EscribiendoState extends State<_Escribiendo> with SingleTickerProviderStateMixin {
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
        child: Semantics(
          label: 'Kantu está escribiendo',
          child: AnimatedBuilder(
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
                      decoration: const BoxDecoration(
                        color: KantuColors.textSecondary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Texto plano para leer en voz alta: los enlaces `[Nombre](producto:ID)` se
/// leen solo por su nombre y se quitan las marcas de Markdown y los emojis.
String textoParaLeer(String markdown) {
  return markdown
      .replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), '')
      .replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]*\)'), (m) => m[1]!)
      .replaceAll(RegExp(r'```[\s\S]*?```'), '')
      .replaceAll(RegExp(r'[*_`~#>|]'), '')
      .replaceAll(RegExp(r'^\s*[-+]\s+', multiLine: true), '')
      // El analizador no tiene en cuenta `unicode: true`; en ejecución es válida.
      // ignore: valid_regexps
      .replaceAll(RegExp(r'\p{Extended_Pictographic}', unicode: true), '')
      .replaceAllMapped(RegExp(r'\bBs\.?\s*(\d+(?:[.,]\d+)?)'), (m) => '${m[1]} bolivianos')
      // Cada línea (ítem de lista, título) termina en pausa al leerse.
      .replaceAllMapped(RegExp(r'([^.!?:;,\s])[ \t]*\n+'), (m) => '${m[1]}. ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
