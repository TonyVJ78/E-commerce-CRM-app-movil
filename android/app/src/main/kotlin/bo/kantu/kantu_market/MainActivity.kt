package bo.kantu.kantu_market

import io.flutter.embedding.android.FlutterFragmentActivity

// flutter_stripe usa Fragments internamente (3D Secure, Google Pay), así que
// requiere FlutterFragmentActivity en vez de FlutterActivity — de lo contrario
// Stripe.instance.applySettings() lanza "flutter_stripe initialization failed"
// sin capturar, y como cart_screen.dart no envuelve esa llamada en try/catch,
// el checkout se queda cargando para siempre.
class MainActivity : FlutterFragmentActivity()
