import 'dart:async';
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

const String _scriptIdPrefix = 'recaptcha-v2-script';
const Duration _scriptLoadTimeout = Duration(seconds: 20);
const Duration _grecaptchaReadyTimeout = Duration(seconds: 10);
const Duration _containerAttachTimeout = Duration(seconds: 10);
const Duration _renderRetryTimeout = Duration(seconds: 8);
const List<String> _scriptUrls = [
  'https://www.google.com/recaptcha/api.js?render=explicit',
  'https://www.recaptcha.net/recaptcha/api.js?render=explicit',
];

Future<void>? _scriptFuture;
int _widgetCounter = 0;

class RecaptchaV2ControllerImpl {
  String? token;

  js.JsObject? _grecaptcha;
  dynamic _widgetId;
  ValueChanged<String?>? _onTokenChanged;
  bool _disposed = false;

  void _attach({
    required js.JsObject grecaptcha,
    required dynamic widgetId,
    required ValueChanged<String?> onTokenChanged,
  }) {
    _grecaptcha = grecaptcha;
    _widgetId = widgetId;
    _onTokenChanged = onTokenChanged;
  }

  void _setToken(String? value) {
    if (_disposed) {
      return;
    }

    final normalized = (value ?? '').trim();
    token = normalized.isEmpty ? null : normalized;
    _onTokenChanged?.call(token);
  }

  void _clearBinding() {
    _grecaptcha = null;
    _widgetId = null;
    _onTokenChanged = null;
  }

  void reset() {
    if (_grecaptcha != null && _widgetId != null) {
      try {
        _grecaptcha!.callMethod('reset', [_widgetId]);
      } on Object catch (_) {
        // Ignore reset errors when webview is disposed/recreated.
      }
    }
    _setToken(null);
  }

  void dispose() {
    _disposed = true;
    token = null;
    _clearBinding();
  }
}

RecaptchaV2ControllerImpl createController() => RecaptchaV2ControllerImpl();

Widget buildWidget({
  required String siteKey,
  required RecaptchaV2ControllerImpl controller,
  required ValueChanged<String?> onTokenChanged,
}) {
  return _RecaptchaV2WebBox(
    siteKey: siteKey,
    controller: controller,
    onTokenChanged: onTokenChanged,
  );
}

class _RecaptchaV2WebBox extends StatefulWidget {
  const _RecaptchaV2WebBox({
    required this.siteKey,
    required this.controller,
    required this.onTokenChanged,
  });

  final String siteKey;
  final RecaptchaV2ControllerImpl controller;
  final ValueChanged<String?> onTokenChanged;

  @override
  State<_RecaptchaV2WebBox> createState() => _RecaptchaV2WebBoxState();
}

class _RecaptchaV2WebBoxState extends State<_RecaptchaV2WebBox> {
  late final String _viewType;
  html.DivElement? _container;

  String? _error;
  bool _isRendered = false;

  @override
  void initState() {
    super.initState();

    _widgetCounter += 1;
    _viewType = 'recaptcha-v2-view-$_widgetCounter';

    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
      final container = html.DivElement()
        ..id = 'recaptcha-v2-container-$_widgetCounter'
        ..style.width = '304px'
        ..style.height = '78px'
        ..style.minHeight = '78px'
        ..style.display = 'block';

      _container = container;
      return container;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrap();
    });
  }

  @override
  void dispose() {
    if (_isRendered) {
      widget.controller.reset();
    }
    widget.controller._clearBinding();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final siteKey = widget.siteKey.trim();
    if (siteKey.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Thiếu Site Key reCAPTCHA. Vui lòng kiểm tra cấu hình.';
      });
      widget.controller._setToken(null);
      return;
    }

    try {
      await _ensureScriptLoaded();
      final container = await _waitForContainerAttached();
      if (!mounted) {
        return;
      }
      await _renderRecaptcha(siteKey: siteKey, container: container);
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = _mapRecaptchaError(error);
      });
      widget.controller._setToken(null);
    }
  }

  Future<void> _renderRecaptcha({
    required String siteKey,
    required html.DivElement container,
  }) async {
    if (_isRendered) {
      return;
    }

    final raw = js.context['grecaptcha'];
    if (raw is! js.JsObject) {
      throw StateError('grecaptcha not ready');
    }

    final grecaptcha = raw;
    final options = js.JsObject.jsify({
      'sitekey': siteKey,
      'callback': js.JsFunction.withThis((dynamic _, dynamic token) {
        widget.controller._setToken((token ?? '').toString());
      }),
      'expired-callback': js.JsFunction.withThis((dynamic _) {
        widget.controller._setToken(null);
      }),
      'error-callback': js.JsFunction.withThis((dynamic _) {
        widget.controller._setToken(null);
      }),
    });

    final endAt = DateTime.now().add(_renderRetryTimeout);
    Object? lastError;

    while (DateTime.now().isBefore(endAt)) {
      try {
        final widgetId = grecaptcha.callMethod('render', [container, options]);
        widget.controller._attach(
          grecaptcha: grecaptcha,
          widgetId: widgetId,
          onTokenChanged: widget.onTokenChanged,
        );
        widget.controller._setToken(null);

        if (!mounted) {
          return;
        }

        setState(() {
          _isRendered = true;
          _error = null;
        });
        return;
      } on Object catch (error) {
        lastError = error;
        await Future<void>.delayed(const Duration(milliseconds: 120));
      }
    }

    throw lastError ?? TimeoutException('recaptcha render timeout');
  }

  Future<html.DivElement> _waitForContainerAttached() async {
    final endAt = DateTime.now().add(_containerAttachTimeout);

    while (DateTime.now().isBefore(endAt)) {
      final container = _container;
      if (container != null) {
        final connected = container.isConnected == true;
        final inBody = html.document.body?.contains(container) == true;
        if (connected || inBody) {
          return container;
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    throw TimeoutException('recaptcha container not attached');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 2),
        SizedBox(
          width: 304,
          height: 78,
          child: HtmlElementView(viewType: _viewType),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _error!,
              style: TextStyle(color: Colors.red.shade700, fontSize: 12),
            ),
          ),
      ],
    );
  }
}

Future<void> _ensureScriptLoaded() async {
  if (js.context['grecaptcha'] != null) {
    return;
  }

  _scriptFuture ??= _loadRecaptchaScript();
  try {
    await _scriptFuture!;
  } on Object catch (_) {
    _scriptFuture = null;
    rethrow;
  }
}

Future<void> _loadRecaptchaScript() async {
  Object? lastError;

  for (var i = 0; i < _scriptUrls.length; i++) {
    final src = _scriptUrls[i];
    try {
      await _loadScriptFromUrl(src: src, scriptId: '$_scriptIdPrefix-$i');
      return;
    } on Object catch (error) {
      lastError = error;
    }
  }

  throw lastError ?? TimeoutException('Không tải được script reCAPTCHA.');
}

Future<void> _loadScriptFromUrl({
  required String src,
  required String scriptId,
}) async {
  if (js.context['grecaptcha'] != null) {
    return;
  }

  final existing =
      html.document.getElementById(scriptId) as html.ScriptElement?;
  if (existing == null) {
    final completer = Completer<void>();
    final script = html.ScriptElement()
      ..id = scriptId
      ..src = src
      ..type = 'text/javascript'
      ..async = true
      ..defer = true
      ..crossOrigin = 'anonymous';

    unawaited(
      script.onLoad.first.then((_) {
        if (!completer.isCompleted) {
          completer.complete();
        }
      }),
    );

    unawaited(
      script.onError.first.then((_) {
        if (!completer.isCompleted) {
          completer.completeError(
            StateError('load recaptcha script failed: $src'),
          );
        }
      }),
    );

    html.document.head?.append(script);

    await completer.future.timeout(
      _scriptLoadTimeout,
      onTimeout: () =>
          throw TimeoutException('load recaptcha script timeout: $src'),
    );
  }

  await _waitForGrecaptcha();
}

Future<void> _waitForGrecaptcha() async {
  final endAt = DateTime.now().add(_grecaptchaReadyTimeout);
  while (DateTime.now().isBefore(endAt)) {
    if (js.context['grecaptcha'] != null) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 120));
  }

  throw TimeoutException('grecaptcha not ready');
}

String _mapRecaptchaError(Object error) {
  final raw = error.toString();
  final lower = raw.toLowerCase();

  if (lower.contains('invalid') && lower.contains('site')) {
    return 'Site Key reCAPTCHA không hợp lệ hoặc chưa thêm domain localhost.';
  }
  if (lower.contains('container') ||
      lower.contains('attach') ||
      lower.contains('placeholder')) {
    return 'Không tạo được vùng hiển thị reCAPTCHA. Vui lòng tải lại trang.';
  }
  if (lower.contains('blocked_by_client') ||
      lower.contains('load recaptcha script failed') ||
      lower.contains('net::err')) {
    return 'Trình duyệt hoặc extension đang chặn reCAPTCHA. Hãy tắt AdBlock/Brave Shield/VPN rồi tải lại.';
  }
  if (lower.contains('timeout')) {
    return 'Hết thời gian tải reCAPTCHA. Kiểm tra mạng và thử lại.';
  }

  final short = raw.length > 180 ? raw.substring(0, 180) : raw;
  return 'Không tải được reCAPTCHA: $short';
}
