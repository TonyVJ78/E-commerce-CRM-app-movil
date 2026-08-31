import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/services/api_service.dart';
import '../shared/custom_button.dart';
import '../shared/custom_text_field.dart';
import '../shared/kantu_app_bar.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _urlController = TextEditingController();
  bool _useOnline = false;

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

  Future<void> _saveSettings() async {
    await ApiService.instance.setConfig(
      baseUrl: _urlController.text.trim(),
      useOnline: _useOnline,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configuración guardada exitosamente'),
          backgroundColor: KantuColors.success,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KantuColors.background,
      appBar: const KantuAppBar(title: 'Configuración del Servidor'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: KantuColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Text('⚙️', style: TextStyle(fontSize: 24)),
                  SizedBox(width: 8),
                  Text(
                    'Conectividad con Backend Django',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: KantuColors.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Puedes usar Kantu Market en modo 100% Autónomo (Base de Datos Local SQLite con datos semilla) o conectarlo al servidor Django REST en ejecución.',
                style: TextStyle(fontSize: 13, color: KantuColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 20),

              // Switch Online/Offline
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: KantuColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: KantuColors.border),
                ),
                child: SwitchListTile(
                  title: const Text(
                    'Conectar con Django REST API',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    _useOnline ? 'Modo Servidor Remoto Activo' : 'Modo Autónomo Local (SQLite)',
                    style: const TextStyle(fontSize: 12, color: KantuColors.textSecondary),
                  ),
                  value: _useOnline,
                  activeThumbColor: KantuColors.primary,
                  onChanged: (val) => setState(() => _useOnline = val),
                ),
              ),
              const SizedBox(height: 20),

              CustomTextField(
                label: 'URL Base del Backend API',
                hint: 'http://10.0.2.2:8000/api o IP de tu PC',
                controller: _urlController,
                prefixIcon: const Icon(Icons.link, size: 20, color: KantuColors.textMuted),
              ),
              const SizedBox(height: 8),
              const Text(
                '• Emulador Android: http://10.0.2.2:8000/api\n• Celular físico (WiFi): http://192.168.x.x:8000/api',
                style: TextStyle(fontSize: 11, color: KantuColors.textMuted),
              ),
              const SizedBox(height: 24),

              CustomButton(
                text: 'Guardar Cambios',
                onPressed: _saveSettings,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
