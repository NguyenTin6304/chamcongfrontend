class AppConfig {
  const AppConfig._();

  // Localhost fallback site key for reCAPTCHA v2 checkbox.
  // Override when needed:
  // flutter run --dart-define=RECAPTCHA_SITE_KEY=your_real_site_key
  static const String _localRecaptchaFallbackKey =
      '6LeacZQsAAAAAALm3dRgXSUaAEmSWVwdt1Zbk1wE';

  // You can override at runtime:
  // flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  // Web login reCAPTCHA v2 site key.
  // Priority: --dart-define key -> local fallback key.
  static const String recaptchaSiteKey = String.fromEnvironment(
    'RECAPTCHA_SITE_KEY',
    defaultValue: _localRecaptchaFallbackKey,
  );
}
