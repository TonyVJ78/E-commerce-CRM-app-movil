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

La app habla siempre con el despliegue del proyecto
(`https://kantumarket.vercel.app/api`), que es la misma base de datos que ve la
web. Esa direccion es el valor por defecto en `ApiConstants.apiProduccion`, asi
que basta con:

```bash
flutter build apk --release
```

El APK queda en `build/app/outputs/flutter-apk/app-release.apk` (~53 MB) y
funciona en cualquier telefono con internet, sin depender de que ninguna PC este
encendida ni de configurar nada dentro de la app.

Para apuntar a otro servidor (una PC de la red, un despliegue de pruebas) se
compila con la direccion dentro:

```bash
flutter build apk --release --dart-define=API_BASE_URL=http://IP-DE-LA-PC:8000/api
```

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

La app no tiene pantalla para cambiar el servidor: la direccion se fija al
compilar y nada mas. Se quito a proposito, porque un ajuste mal tocado dejaba la
app leyendo la base local sin que se notara.

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
