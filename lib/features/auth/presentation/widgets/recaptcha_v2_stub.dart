import 'package:flutter/material.dart';

class RecaptchaV2ControllerImpl {
  String? token;

  void reset() {
    token = null;
  }

  void dispose() {}
}

RecaptchaV2ControllerImpl createController() => RecaptchaV2ControllerImpl();

Widget buildWidget({
  required String siteKey,
  required RecaptchaV2ControllerImpl controller,
  required ValueChanged<String?> onTokenChanged,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      border: Border.all(color: Colors.orange.shade300),
      borderRadius: BorderRadius.circular(10),
      color: Colors.orange.withValues(alpha: 0.08),
    ),
    child: const Text(
      'reCAPTCHA v2 checkbox chỉ hỗ trợ trên Flutter Web.',
      style: TextStyle(fontSize: 13),
    ),
  );
}
