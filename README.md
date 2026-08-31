# Kantu Market - Aplicacion Movil (Flutter)

Aplicacion movil desarrollada en Flutter para la plataforma de comercio digital Kantu Market, implementando arquitectura limpia, gestion de estado con Provider y persistencia local Offline-First con SQLite.
## Estructura del Proyecto

- `lib/core/constants/`: Constantes de diseno, colores y configuracion de API.
- `lib/core/database/`: Controlador SQLite (DatabaseHelper) con esquema relacional y datos iniciales.
- `lib/core/models/`: Modelos de datos (Usuario, Tienda, Producto, Pedido, Bitacora).
- `lib/core/services/`: Servicios de autenticacion (AuthService) y comunicacion HTTP (ApiService).
- `lib/features/auth/`: Pantallas de Login, Registro y Recuperacion de contrasena.
- `lib/features/profile/`: Pantalla de perfil y edicion de cuenta.
- `lib/features/shared/`: Componentes reutilizables de interfaz (botones, campos de texto, app bar).

## Requisitos de Ejecucion

- Flutter SDK (version 3.0 o superior)
- Dart SDK
- Android SDK / Android Studio
- Dispositivo Android fisico o emulador

## Instrucciones de Instalacion y Ejecucion

1. Obtener dependencias:
   ```bash
   flutter pub get
   ```

2. Ejecutar analisis de codigo:
   ```bash
   flutter analyze
   ```

3. Compilar y ejecutar en dispositivo o emulador:
   ```bash
   flutter run
   ```

4. Generar APK debug:
   ```bash
   flutter build apk --debug
   ```
