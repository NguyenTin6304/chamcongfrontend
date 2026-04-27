import 'package:flutter/widgets.dart';

import 'package:birdle/features/auth/presentation/widgets/recaptcha_v2_stub.dart'
    if (dart.library.html) 'recaptcha_v2_web.dart' as impl;

class RecaptchaV2Controller {
  RecaptchaV2Controller._(this._delegate);

  final impl.RecaptchaV2ControllerImpl _delegate;

  String? get token => _delegate.token;

  void reset() => _delegate.reset();

  void dispose() => _delegate.dispose();
}

RecaptchaV2Controller createRecaptchaV2Controller() {
  return RecaptchaV2Controller._(impl.createController());
}

Widget buildRecaptchaV2Widget({
  required String siteKey,
  required RecaptchaV2Controller controller,
  required ValueChanged<String?> onTokenChanged,
}) {
  return impl.buildWidget(
    siteKey: siteKey,
    controller: controller._delegate,
    onTokenChanged: onTokenChanged,
  );
}
