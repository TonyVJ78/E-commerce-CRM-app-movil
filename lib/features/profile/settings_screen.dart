import 'package:flutter/material.dart';

import '../../core/constants/api_constants.dart';
import '../../core/constants/colors.dart';
import '../../core/services/api_service.dart';
import '../shared/custom_button.dart';
import '../shared/custom_text_field.dart';
import '../shared/kantu_app_bar.dart';

/// Conectividad con el backend.
///
/// Es la pantalla que decide si la app trabaja contra la base de datos real del
/// proyecto o contra la copia local de SQLite. En un teléfono físico ese es el
/// fallo más común y más difícil de ver: la app abre igual, pero con datos
/// locales, y las cuentas del equipo no entran. Por eso aquí se puede **probar
/// la conexión** antes de guardar.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _urlController = TextEditingController();
  bool _useOnline = false;
  bool _probando = false;
  String? _resultado;
  bool _conexionOk = false;

  @override
  void initState() {
    super.initState();
    _urlController.text = ApiService.instance.baseUrl;
    _useOnline = ApiService.instance.useOnlineBackend;
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _probarConexion() async {
    setState(() {
      _probando = true;
      _resultado = null;
    });

    final error = await ApiService.instance.probarConexion(_urlController.text);

    if (!mounted) return;
    setState(() {
      _probando = false;
      _conexionOk = error == null;
      _resultado = error ?? 'Conectado. El servidor respondió correctamente.';
    });
  }

  Future<void> _saveSettings() async {
    await ApiService.instance.setConfig(
      baseUrl: _urlController.text.trim(),
      useOnline: _useOnline,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _useOnline
              ? 'Guardado. La app usará el servidor; vuelve a iniciar sesión para cargar tus datos.'
              : 'Guardado. La app trabajará con la base local del dispositivo.',
        ),
        backgroundColor: KantuColors.success,
      ),
    );
    Navigator.pop(context);
  }

  void _usarPreset(String url) {
    _urlController.text = url;
    setState(() {
      _useOnline = true;
      _resultado = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KantuColors.background,
      appBar: const KantuAppBar(title: 'Conexión con el servidor'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _Tarjeta(
            children: [
              const _TituloTarjeta(
                icono: Icons.dns_outlined,
                texto: 'Origen de los datos',
              ),
              const SizedBox(height: 12),
              const Text(
                'Con el servidor activado la app usa la base de datos real del '
                'proyecto: las mismas tiendas, productos y cuentas que la web. '
                'Desactivado trabaja con una copia local en el teléfono, con sus '
                'propios datos de prueba.',
                style: TextStyle(fontSize: 13, color: KantuColors.textSecondary, height: 1.45),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: KantuColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: KantuColors.border),
                ),
                child: SwitchListTile(
                  title: const Text(
                    'Conectar con el servidor',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    _useOnline
                        ? 'Datos reales del proyecto'
                        : 'Base local del dispositivo (SQLite)',
                    style: const TextStyle(fontSize: 12, color: KantuColors.textSecondary),
                  ),
                  value: _useOnline,
                  activeThumbColor: KantuColors.primary,
                  onChanged: (val) => setState(() => _useOnline = val),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Tarjeta(
            children: [
              const _TituloTarjeta(
                icono: Icons.link,
                texto: 'Dirección del servidor',
              ),
              const SizedBox(height: 12),
              CustomTextField(
                label: 'URL base de la API',
                hint: 'https://mi-servidor/api',
                controller: _urlController,
                prefixIcon: const Icon(Icons.link, size: 20, color: KantuColors.textMuted),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _PresetChip(
                    etiqueta: 'Emulador',
                    onTap: () => _usarPreset(ApiConstants.defaultEmulatorUrl),
                  ),
                  if (ApiConstants.buildBaseUrl.isNotEmpty)
                    _PresetChip(
                      etiqueta: 'La de esta versión',
                      onTap: () => _usarPreset(ApiConstants.buildBaseUrl),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'La dirección debe terminar en /api.\n'
                '• Emulador de Android Studio: http://10.0.2.2:8000/api\n'
                '• Teléfono en la misma WiFi que la PC: http://IP-DE-LA-PC:8000/api\n'
                '  (en la PC, Django debe correr con 0.0.0.0)\n'
                '• Servidor publicado: la URL https del despliegue + /api\n\n'
                'Ojo: 10.0.2.2 y localhost sólo existen dentro del emulador. En un '
                'teléfono real nunca van a funcionar.',
                style: TextStyle(fontSize: 11.5, color: KantuColors.textMuted, height: 1.5),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _probando ? null : _probarConexion,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: KantuColors.primary,
                    side: const BorderSide(color: KantuColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _probando
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.wifi_tethering, size: 18),
                  label: Text(
                    _probando ? 'Probando...' : 'Probar conexión',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              if (_resultado != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _conexionOk ? KantuColors.successLight : KantuColors.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _conexionOk ? KantuColors.success : KantuColors.error,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _conexionOk ? Icons.check_circle_outline : Icons.error_outline,
                        size: 18,
                        color: _conexionOk ? KantuColors.success : KantuColors.error,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _resultado!,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.4,
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
          const SizedBox(height: 20),
          CustomButton(text: 'Guardar cambios', onPressed: _saveSettings),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _Tarjeta extends StatelessWidget {
  final List<Widget> children;

  const _Tarjeta({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: KantuColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}

class _TituloTarjeta extends StatelessWidget {
  final IconData icono;
  final String texto;

  const _TituloTarjeta({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icono, size: 20, color: KantuColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            texto,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: KantuColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String etiqueta;
  final VoidCallback onTap;

  const _PresetChip({required this.etiqueta, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(etiqueta, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      onPressed: onTap,
      backgroundColor: Colors.white,
      side: const BorderSide(color: KantuColors.border),
      labelStyle: const TextStyle(color: KantuColors.textPrimary),
    );
  }
}
