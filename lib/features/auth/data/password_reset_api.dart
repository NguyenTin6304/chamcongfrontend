import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';

class PasswordResetApi {
  const PasswordResetApi();

  static const Duration _requestTimeout = Duration(seconds: 12);

  Future<String> forgotPassword({required String email}) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/auth/forgot-password');
    final response = await _safePost(
      uri,
      body: jsonEncode({'email': email}),
      timeoutMessage: 'Yêu cầu quá thời gian. Vui lòng thử lại.',
      networkMessage: 'Không thể kết nối máy chủ. Vui lòng kiểm tra mạng.',
    );

    final data = _parseJsonMap(response.body);
    if (response.statusCode == 200) {
      final message = data['message'] as String?;
      return (message == null || message.isEmpty)
          ? 'Nếu email tồn tại, hệ thống đã gửi hướng dẫn đặt lại mật khẩu.'
          : message;
    }

    throw Exception(_extractErrorMessage(data, 'Yêu cầu đặt lại mật khẩu thất bại (${response.statusCode})'));
  }

  Future<String> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/auth/reset-password');
    final response = await _safePost(
      uri,
      body: jsonEncode({'token': token, 'new_password': newPassword}),
      timeoutMessage: 'Đặt lại mật khẩu quá thời gian. Vui lòng thử lại.',
      networkMessage: 'Không thể kết nối máy chủ. Vui lòng kiểm tra mạng.',
    );

    final data = _parseJsonMap(response.body);
    if (response.statusCode == 200) {
      final message = data['message'] as String?;
      return (message == null || message.isEmpty)
          ? 'Đặt lại mật khẩu thành công'
          : message;
    }

    throw Exception(_extractErrorMessage(data, 'Đặt lại mật khẩu thất bại (${response.statusCode})'));
  }

  Future<http.Response> _safePost(
    Uri uri, {
    required String body,
    required String timeoutMessage,
    required String networkMessage,
  }) async {
    try {
      return await http
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw Exception(timeoutMessage);
    } on http.ClientException {
      throw Exception(networkMessage);
    }
  }

  Map<String, dynamic> _parseJsonMap(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}
    return <String, dynamic>{};
  }

  String _extractErrorMessage(Map<String, dynamic> data, String fallback) {
    final error = data['error'];
    if (error is Map<String, dynamic>) {
      final message = error['message'] as String?;
      if (message != null && message.isNotEmpty) {
        return message;
      }
    }

    final detail = data['detail'];
    if (detail is String && detail.isNotEmpty) {
      return detail;
    }
    if (detail is Map<String, dynamic>) {
      final message = detail['message'] as String?;
      if (message != null && message.isNotEmpty) {
        return message;
      }
    }

    return fallback;
  }
}
