/// No-op stub for non-web platforms.
class PushNotificationService {
  const PushNotificationService._();

  static Future<void> initializeFirebase() async {}

  static Future<String?> requestTokenAndRegister({
    required String accessToken,
  }) async =>
      null;

  static void setupForegroundHandler(
    void Function(String title, String body) onMessage,
  ) {}
}
