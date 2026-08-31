# Kantu Market - Aplicacion Movil (Flutter)

Aplicacion movil desarrollada en Flutter para la plataforma de comercio digital Kantu Market, implementando arquitectura limpia, gestion de estado con Provider y persistencia local Offline-First con SQLite.

## Casos de Uso Implementados

1. **CU01: Iniciar Sesion (Login)**
   - Autenticacion mediante correo electronico y contrasena.
   - Validacion de estado activo de la cuenta.
   - Soporte para credenciales de acceso rapido para pruebas (Administrador, Empresa, Cliente).
   - Registro automatico de eventos en bitacora de acceso con IP y dispositivo.

2. **CU02: Registro de Nuevos Usuarios**
   - Formulario de creacion de cuenta con nombre, apellido, correo y seleccion de rol (cliente o empresa).
   - Validacion de complejidad de contrasena en tiempo real (longitud minima, letras, numeros y caracteres especiales).

3. **CU03: Recuperacion de Contrasena**
   - Verificacion de correo registrado.
   - Restablecimiento seguro de contrasena en la base de datos local.

4. **CU04: Consultar y Actualizar Perfil**
   - Visualizacion de la informacion del usuario autenticado (nombre completo, correo, rol asignado e iniciales).
   - Edicion de datos personales (nombre y apellido) con persistencia en SQLite y almacenamiento seguro.

5. **CU05: Cerrar Sesion (Logout)**
   - Confirmacion de cierre de sesion.
   - Limpieza de datos en memoria y almacenamiento local (SharedPreferences).
   - Redireccion segura a la pantalla de inicio de sesion.

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
