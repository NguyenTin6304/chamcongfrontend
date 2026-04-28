import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:birdle/core/config/app_config.dart';

class PushNotificationService {
  const PushNotificationService._();

  static Future<void> initializeFirebase() async {
    if (Firebase.apps.isNotEmpty) return;
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: AppConfig.firebaseApiKey,
          appId: AppConfig.firebaseAppId,
          messagingSenderId: AppConfig.firebaseMessagingSenderId,
          projectId: AppConfig.firebaseProjectId,
          authDomain: AppConfig.firebaseAuthDomain,
          storageBucket: AppConfig.firebaseStorageBucket,
        ),
      );
      debugPrint('[FCM] Firebase initialized');
    } on Object catch (e) {
      debugPrint('[FCM] Firebase init failed: $e');
    }
  }

  /// Requests notification permission, gets FCM token, registers with backend.
  static Future<String?> requestTokenAndRegister({
    required String accessToken,
  }) async {
    try {
      if (Firebase.apps.isEmpty) {
        debugPrint('[FCM] Firebase not initialized — skipping token request');
        return null;
      }

      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        debugPrint('[FCM] Permission denied — no token');
        return null;
      }

      final token = await messaging.getToken(vapidKey: AppConfig.fcmVapidKey);
      if (token == null || token.isEmpty) {
        debugPrint('[FCM] getToken returned null');
        return null;
      }

      debugPrint('[FCM] Token obtained: ${token.substring(0, 20)}…');
      await _sendTokenToBackend(token, accessToken: accessToken);
      debugPrint('[FCM] Token registered with backend');
      return token;
    } on Object catch (e, st) {
      debugPrint('[FCM] requestTokenAndRegister error: $e\n$st');
      return null;
    }
  }

  static void setupForegroundHandler(
    void Function(String title, String body) onMessage,
  ) {
    FirebaseMessaging.onMessage.listen((message) {
      final title = message.notification?.title ?? '';
      final body = message.notification?.body ?? '';
      debugPrint('[FCM] Foreground message: $title');
      if (title.isNotEmpty) onMessage(title, body);
    });
  }

  /// Checks whether the app was launched by tapping a notification
  /// (terminated state). Calls [onRoute] with the route string if found.
  static Future<void> handleInitialMessage(
    void Function(String route) onRoute,
  ) async {
    try {
      final message = await FirebaseMessaging.instance.getInitialMessage();
      if (message == null) return;
      final route = message.data['route'] as String? ?? '';
      debugPrint('[FCM] getInitialMessage: route=$route');
      if (route.isNotEmpty) onRoute(route);
    } on Object catch (e) {
      debugPrint('[FCM] getInitialMessage error: $e');
    }
  }

  /// Listens for notification taps while the app is in the background.
  /// Calls [onRoute] with the route string extracted from the data payload.
  static void setupBackgroundTapHandler(
    void Function(String route) onRoute,
  ) {
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final route = message.data['route'] as String? ?? '';
      debugPrint('[FCM] onMessageOpenedApp: route=$route');
      if (route.isNotEmpty) onRoute(route);
    });
  }

  static Future<void> _sendTokenToBackend(
    String fcmToken, {
    required String accessToken,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/auth/fcm-token');
    final res = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
          body: jsonEncode({'fcm_token': fcmToken}),
        )
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      debugPrint('[FCM] Backend register failed: ${res.statusCode} ${res.body}');
    }
  }
}
