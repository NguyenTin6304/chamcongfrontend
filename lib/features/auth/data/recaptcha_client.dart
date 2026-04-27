import 'package:birdle/features/auth/data/recaptcha/recaptcha_client_stub.dart'
    if (dart.library.html) 'recaptcha/recaptcha_client_web.dart';

class RecaptchaClient {
  const RecaptchaClient._();

  static Future<String?> getLoginToken() {
    return getLoginRecaptchaToken();
  }
}
