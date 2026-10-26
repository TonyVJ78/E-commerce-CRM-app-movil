import 'package:firebase_core/firebase_core.dart';

/// Public client configuration supplied at build time; never service-account keys.
class FirebaseRuntime {
  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const senderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static bool get configured =>
      [apiKey, appId, projectId, senderId].every((v) => v.isNotEmpty);

  static Future<bool> initialize() async {
    if (!configured) return false;
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: apiKey,
          appId: appId,
          projectId: projectId,
          messagingSenderId: senderId,
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
