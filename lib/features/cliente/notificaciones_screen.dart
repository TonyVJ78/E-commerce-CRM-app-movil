import 'package:flutter/material.dart';

import '../../core/services/notificaciones_service.dart';
import '../../core/services/push_notification_service.dart';

class NotificacionesScreen extends StatefulWidget {
  final NotificacionesService? service;
  final Future<void> Function(Map<String, dynamic>)? onAbrir;
  const NotificacionesScreen({super.key, this.service, this.onAbrir});
  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  late final service = widget.service ?? NotificacionesService();
  final List<NotificacionCliente> items = [];
  bool cargando = true;
  String? error;
  int? siguiente;
  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar({bool mas = false}) async {
    setState(() {
      cargando = true;
      error = null;
    });
    try {
      final pagina = await service.listar(antes: mas ? siguiente : null);
      if (!mounted) return;
      setState(() {
        if (!mas) items.clear();
        items.addAll(pagina.items);
        siguiente = pagina.siguiente;
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
    if (mounted) setState(() => cargando = false);
  }

  Future<void> _abrir(NotificacionCliente item) async {
    try {
      await service.marcarLeida(item.id);
      if (!mounted) return;
      setState(() => item.leida = true);
      await (widget.onAbrir ?? PushNotificationService.instance.abrirDatos)(
        item.datos,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mis notificaciones')),
    body: RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          ValueListenableBuilder<EstadoPush>(
            valueListenable: PushNotificationService.instance.estado,
            builder: (context, estado, _) => Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(switch (estado) {
                      EstadoPush.sinConfigurar => 'Las notificaciones push aún no están disponibles en esta versión. Puedes consultar tus avisos aquí.',
                      EstadoPush.activo => 'Notificaciones push activadas.',
                      EstadoPush.conectando => 'Activando notificaciones…',
                      EstadoPush.error => 'No se pudieron activar las notificaciones. Intenta nuevamente.',
                      EstadoPush.desactivado => 'Activa las notificaciones para recibir avisos fuera de la app.',
                    }),
                    if (estado != EstadoPush.sinConfigurar &&
                        estado != EstadoPush.activo)
                      TextButton(
                        onPressed: estado == EstadoPush.conectando
                            ? null
                            : PushNotificationService.instance.activar,
                        child: const Text('Activar notificaciones'),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (error != null) ...[
            Text(error!, key: const Key('error-notificaciones')),
            TextButton(
              onPressed: () =>
                  _cargar(mas: items.isNotEmpty && siguiente != null),
              child: const Text('Reintentar'),
            ),
          ],
          if (!cargando && error == null && items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Todavía no tienes notificaciones.'),
            ),
          for (final n in items)
            Card(
              child: ListTile(
                leading: Icon(
                  n.leida
                      ? Icons.notifications_none
                      : Icons.notifications_active,
                  color: n.leida ? null : Theme.of(context).colorScheme.primary,
                ),
                title: Text(
                  n.titulo,
                  style: TextStyle(
                    fontWeight: n.leida ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
                subtitle: Text('${n.tiendaNombre}\n${n.mensaje}'),
                isThreeLine: true,
                onTap: () => _abrir(n),
              ),
            ),
          if (cargando)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            ),
          if (!cargando && siguiente != null)
            TextButton(
              onPressed: () => _cargar(mas: true),
              child: const Text('Ver anteriores'),
            ),
        ],
      ),
    ),
  );
}
