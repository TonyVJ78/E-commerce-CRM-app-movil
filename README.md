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

## Generar el APK para repartir

La app puede trabajar contra el servidor del proyecto (los mismos datos que la
web) o contra una copia local de SQLite que lleva dentro. **El APK que se
reparte debe venir con la direccion del servidor ya puesta**, o quien lo instale
abrira la app en modo local y las cuentas del equipo no le entraran.

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://kantumarket.vercel.app/api
```

Esa es la direccion del despliegue del proyecto, la misma base de datos que ve
la web. Un APK compilado asi funciona en cualquier telefono con internet, sin
depender de que ninguna PC este encendida.

El APK queda en `build/app/outputs/flutter-apk/app-release.apk` (~53 MB) y
arranca ya conectado a esa direccion. Sin `--dart-define` el APK arranca en modo
local y hay que configurarlo a mano en Perfil > Ajustes.

Que poner en `API_BASE_URL` (siempre terminado en `/api`):

| Donde corre el backend | URL |
|---|---|
| Despliegue del proyecto (Vercel) | `https://kantumarket.vercel.app/api` |
| PC en la misma WiFi que el telefono | `http://<IP-de-la-PC>:8000/api` |
| Emulador de Android Studio | `http://10.0.2.2:8000/api` |

`10.0.2.2` y `localhost` **solo existen dentro del emulador**: en un telefono
real nunca funcionan. Esa es la causa habitual de "en Android Studio si anda y
en el celular no".

Si el backend corre en una PC de la red, hay que levantarlo abierto a la red y
dejar pasar el puerto en el firewall de Windows:

```bash
python manage.py runserver 0.0.0.0:8000
```

Dentro de la app, **Perfil > Ajustes > Probar conexion** dice si la direccion
responde y, si no, por que.

### Cuentas del servidor

En la base de datos del despliegue las cuentas de prueba llevan numero:
`admin@kantu.bo`, `cliente1@kantu.bo` .. `cliente6@kantu.bo`,
`empresa1@kantu.bo` .. `empresa4@kantu.bo`, todas con `Password123!`.
**No existen `cliente@kantu.bo` ni `empresa@kantu.bo` sin numero** — esos son
los de la base local de SQLite que la app trae dentro.

### Comprobar el APK antes de repartirlo

```bash
flutter build apk --debug     # solo para depurar: pesa mucho, no se reparte
flutter analyze               # sin errores antes de compilar
```

El APK de release no debe pasar de unas decenas de MB. Si sale con cientos de MB
es que se volvio a activar `keepDebugSymbols` en `android/app/build.gradle.kts`:
un archivo asi es incomodo de compartir y algunos telefonos no lo instalan.
