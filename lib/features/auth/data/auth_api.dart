import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';

class LoginResult {
  const LoginResult({
    required this.accessToken,
    required this.tokenType,
    this.refreshToken,
    this.accessExpiresInMinutes,
    this.refreshExpiresInDays,
  });

  final String accessToken;
  final String tokenType;
  final String? refreshToken;
  final int? accessExpiresInMinutes;
  final int? refreshExpiresInDays;
}

class RegisterResult {
  const RegisterResult({
    required this.id,
    required this.email,
    required this.role,
  });

  final int id;
  final String email;
  final String role;
}

class UserMeResult {
  const UserMeResult({
    required this.id,
    required this.email,
    required this.role,
    this.fullName,
    this.phone,
  });

  final int id;
  final String email;
  final String role;
  final String? fullName;
  final String? phone;
}

class AuthApiException implements Exception {
  const AuthApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isAuthFailure => statusCode == 401 || statusCode == 403;

  @override
  String toString() {
    final code = statusCode;
    if (code == null) {
      return message;
    }
    return '$message ($code)';
  }
}

class AuthApi {
  const AuthApi();

  static const Duration _requestTimeout = Duration(seconds: 12);

  Future<LoginResult> login({
    required String email,
    required String password,
    bool rememberMe = true,
    String? recaptchaToken,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/auth/login');

    final body = <String, dynamic>{
      'email': email,
      'password': password,
      'remember_me': rememberMe,
    };
    if (recaptchaToken != null && recaptchaToken.trim().isNotEmpty) {
      body['recaptcha_token'] = recaptchaToken.trim();
    }

    final response = await _safePost(
      uri,
      body: jsonEncode(body),
      timeoutMessage: 'Đăng nhập quá thời gian. Vui lòng thử lại.',
      networkMessage: 'Không thể kết nối máy chủ. Vui lòng kiểm tra mạng.',
    );

    final data = _parseJsonMap(response.body);

    if (response.statusCode == 200) {
      return _toLoginResult(data);
    }

    throw AuthApiException(
      _extractErrorMessage(data, 'Login failed (${response.statusCode})'),
      statusCode: response.statusCode,
    );
  }

  Future<LoginResult> refresh({required String refreshToken}) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/auth/refresh');
    final response = await _safePost(
      uri,
      body: jsonEncode({'refresh_token': refreshToken}),
      timeoutMessage: 'Làm mới phiên quá thời gian. Vui lòng thử lại.',
      networkMessage: 'Không thể kết nối máy chủ. Vui lòng kiểm tra mạng.',
    );

    final data = _parseJsonMap(response.body);

    if (response.statusCode == 200) {
      return _toLoginResult(data);
    }

    throw AuthApiException(
      _extractErrorMessage(
        data,
        'Refresh token failed (${response.statusCode})',
      ),
      statusCode: response.statusCode,
    );
  }

  Future<void> logout({required String refreshToken}) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/auth/logout');
    final response = await _safePost(
      uri,
      body: jsonEncode({'refresh_token': refreshToken}),
      timeoutMessage: 'Đăng xuất quá thời gian. Vui lòng thử lại.',
      networkMessage: 'Không thể kết nối máy chủ. Vui lòng kiểm tra mạng.',
    );

    if (response.statusCode == 200) {
      return;
    }

    final data = _parseJsonMap(response.body);
    throw AuthApiException(
      _extractErrorMessage(data, 'Logout failed (${response.statusCode})'),
      statusCode: response.statusCode,
    );
  }

  Future<UserMeResult> me({required String token}) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/auth/me');
    final response = await _safeGet(
      uri,
      headers: {'Authorization': 'Bearer $token'},
      timeoutMessage: 'Lấy hồ sơ quá thời gian. Vui lòng thử lại.',
      networkMessage: 'Không thể kết nối máy chủ. Vui lòng kiểm tra mạng.',
    );

    final data = _parseJsonMap(response.body);

    if (response.statusCode == 200) {
      return UserMeResult(
        id: (data['id'] as num?)?.toInt() ?? 0,
        email: data['email'] as String? ?? '',
        role: data['role'] as String? ?? 'USER',
        fullName: data['full_name'] as String?,
        phone: data['phone'] as String?,
      );
    }

    throw AuthApiException(
      _extractErrorMessage(data, 'Get profile failed (${response.statusCode})'),
      statusCode: response.statusCode,
    );
  }

  Future<void> changePassword({
    required String token,
    required String currentPassword,
    required String newPassword,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/auth/change-password');
    final response = await _safePost(
      uri,
      body: jsonEncode({
        'current_password': currentPassword,
        'new_password': newPassword,
      }),
      headers: {'Authorization': 'Bearer $token'},
      timeoutMessage: 'Đổi mật khẩu quá thời gian. Vui lòng thử lại.',
      networkMessage: 'Không thể kết nối máy chủ. Vui lòng kiểm tra mạng.',
    );

    if (response.statusCode == 200) return;

    final data = _parseJsonMap(response.body);
    throw AuthApiException(
      _extractErrorMessage(data, 'Đổi mật khẩu thất bại (${response.statusCode})'),
      statusCode: response.statusCode,
    );
  }

  Future<RegisterResult> register({
    required String email,
    required String password,
    required String fullName,
    required String phone,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/auth/register');
    final response = await _safePost(
      uri,
      body: jsonEncode({
        'email': email,
        'password': password,
        'full_name': fullName,
        'phone': phone,
      }),
      timeoutMessage: 'Đăng ký quá thời gian. Vui lòng thử lại.',
      networkMessage: 'Không thể kết nối máy chủ. Vui lòng kiểm tra mạng.',
    );

    final data = _parseJsonMap(response.body);

    if (response.statusCode == 201) {
      return RegisterResult(
        id: data['id'] as int,
        email: data['email'] as String,
        role: data['role'] as String,
      );
    }

    throw AuthApiException(
      _extractErrorMessage(data, 'Register failed (${response.statusCode})'),
      statusCode: response.statusCode,
    );
  }

  Future<http.Response> _safePost(
    Uri uri, {
    required String body,
    required String timeoutMessage,
    required String networkMessage,
    Map<String, String>? headers,
  }) async {
    try {
      final mergedHeaders = {'Content-Type': 'application/json', ...?headers};
      return await http
          .post(uri, headers: mergedHeaders, body: body)
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw AuthApiException(timeoutMessage);
    } on http.ClientException {
      throw AuthApiException(networkMessage);
    }
  }

  Future<http.Response> _safeGet(
    Uri uri, {
    required Map<String, String> headers,
    required String timeoutMessage,
    required String networkMessage,
  }) async {
    try {
      return await http.get(uri, headers: headers).timeout(_requestTimeout);
    } on TimeoutException {
      throw AuthApiException(timeoutMessage);
    } on http.ClientException {
      throw AuthApiException(networkMessage);
    }
  }

  LoginResult _toLoginResult(Map<String, dynamic> data) {
    return LoginResult(
      accessToken: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String?,
      tokenType: data['token_type'] as String? ?? 'bearer',
      accessExpiresInMinutes: (data['access_expires_in_minutes'] as num?)
          ?.toInt(),
      refreshExpiresInDays: (data['refresh_expires_in_days'] as num?)?.toInt(),
    );
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
