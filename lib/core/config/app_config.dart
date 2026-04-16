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

  // Geoapify key for geocoding/reverse-geocoding requests.
  // Must be provided via --dart-define in each environment.
  static const String geoapifyApiKey = String.fromEnvironment(
    'GEOAPIFY_API_KEY',
    defaultValue: '',
  );

  // Geoapify map style id. See Geoapify map style documentation.
  static const String geoapifyMapStyle = String.fromEnvironment(
    'GEOAPIFY_MAP_STYLE',
    defaultValue: 'osm-carto',
  );

  // "lat,lng" string. Example: "10.776889,106.700806".
  static const String defaultMapCenter = String.fromEnvironment(
    'DEFAULT_MAP_CENTER',
    defaultValue: '10.776889,106.700806',
  );

  // Firebase project config (public values — safe to hardcode).
  // Override at build time if needed:
  //   --dart-define=FIREBASE_API_KEY=...  --dart-define=FIREBASE_APP_ID=...
  static const String firebaseApiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: 'AIzaSyB14n5rnaDTqxdXb0_HZ3KRqObnphYt5nc',
  );

  static const String firebaseAppId = String.fromEnvironment(
    'FIREBASE_APP_ID',
    defaultValue: '1:926798360325:web:648064645cce7275c2116c',
  );

  static const String firebaseProjectId = 'chamcongfcm';
  static const String firebaseMessagingSenderId = '926798360325';
  static const String firebaseAuthDomain = 'chamcongfcm.firebaseapp.com';
  static const String firebaseStorageBucket = 'chamcongfcm.firebasestorage.app';

  // VAPID key for Web Push (Firebase Console → Project Settings → Cloud Messaging → Web Push certificates).
  static const String fcmVapidKey =
      'BGO9eCn8_xCCHw7aQrke0ydfxzZQoXezudIfB2irJB5t5bg3xfg4P2fvCKiY8nR60r53MnSisD8nASiI7PzCLRU';

  static double get defaultMapCenterLat {
    return _parseMapCenterPart(index: 0, fallback: 10.776889);
  }

  static double get defaultMapCenterLng {
    return _parseMapCenterPart(index: 1, fallback: 106.700806);
  }

  static double _parseMapCenterPart({
    required int index,
    required double fallback,
  }) {
    final parts = defaultMapCenter.split(',');
    if (parts.length != 2) {
      return fallback;
    }

    final value = double.tryParse(parts[index].trim());
    if (value == null) {
      return fallback;
    }

    if (index == 0) {
      if (value < -90 || value > 90) {
        return fallback;
      }
      return value;
    }

    if (value < -180 || value > 180) {
      return fallback;
    }
    return value;
  }
}
