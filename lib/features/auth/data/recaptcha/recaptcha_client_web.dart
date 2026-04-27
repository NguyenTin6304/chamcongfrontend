import 'dart:async';
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:js' as js;

import 'package:birdle/core/config/app_config.dart';

const Duration _scriptLoadTimeout = Duration(seconds: 8);
const Duration _readyTimeout = Duration(seconds: 8);
const Duration _executeTimeout = Duration(seconds: 8);
const String _scriptId = 'recaptcha-v3-script';

Future<void>? _scriptFuture;

Future<String?> getLoginRecaptchaToken() async {
  final siteKey = AppConfig.recaptchaSiteKey.trim();
  if (siteKey.isEmpty) {
    return null;
  }

  await _ensureScriptLoaded(siteKey);

  final grecaptcha = js.context['grecaptcha'];
  if (grecaptcha == null) {
    throw Exception('reCAPTCHA chưa sẵn sàng');
  }

  final readyCompleter = Completer<void>();
  grecaptcha.callMethod('ready', [
    js.JsFunction.withThis((dynamic _) {
      if (!readyCompleter.isCompleted) {
        readyCompleter.complete();
      }
    }),
  ]);

  await readyCompleter.future.timeout(
    _readyTimeout,
    onTimeout: () {
      throw TimeoutException('reCAPTCHA ready timeout');
    },
  );

  final executeOptions = js.JsObject.jsify(<String, String>{'action': 'login'});
  final executePromise = grecaptcha.callMethod('execute', [siteKey, executeOptions]) as js.JsObject;

  final tokenCompleter = Completer<String>();
  executePromise.callMethod('then', [
    js.JsFunction.withThis((dynamic _, dynamic token) {
      if (!tokenCompleter.isCompleted) {
        tokenCompleter.complete((token ?? '').toString());
      }
    }),
  ]);
  executePromise.callMethod('catch', [
    js.JsFunction.withThis((dynamic _, dynamic error) {
      if (!tokenCompleter.isCompleted) {
        tokenCompleter.completeError(Exception('reCAPTCHA execute failed: $error'));
      }
    }),
  ]);

  final token = await tokenCompleter.future.timeout(
    _executeTimeout,
    onTimeout: () {
      throw TimeoutException('reCAPTCHA execute timeout');
    },
  );

  final normalized = token.trim();
  if (normalized.isEmpty) {
    throw Exception('Không lấy được mã reCAPTCHA');
  }

  return normalized;
}

Future<void> _ensureScriptLoaded(String siteKey) {
  _scriptFuture ??= _loadScript(siteKey);
  return _scriptFuture!;
}

Future<void> _loadScript(String siteKey) async {
  if (_hasGrecaptcha()) {
    return;
  }

  final existing = html.document.getElementById(_scriptId);
  if (existing == null) {
    final script = html.ScriptElement()
      ..id = _scriptId
      ..async = true
      ..defer = true
      ..src = 'https://www.google.com/recaptcha/api.js?render=$siteKey';
    html.document.head?.append(script);
  }

  final end = DateTime.now().add(_scriptLoadTimeout);
  while (DateTime.now().isBefore(end)) {
    if (_hasGrecaptcha()) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 120));
  }

  throw TimeoutException('Không tải được script reCAPTCHA');
}

bool _hasGrecaptcha() {
  return js.context['grecaptcha'] != null;
}
