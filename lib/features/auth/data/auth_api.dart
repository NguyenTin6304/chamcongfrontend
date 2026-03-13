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
  });

  final int id;
  final String email;
  final String role;
}

class AuthApi {
  const AuthApi();

  Future<LoginResult> login({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/auth/login');
    final response = await http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password, 'remember_me': rememberMe}),
    );

    final data = _parseJsonMap(response.body);

    if (response.statusCode == 200) {
      return _toLoginResult(data);
    }

    throw Exception(_extractErrorMessage(data, 'Login failed (${response.statusCode})'));
  }

  Future<LoginResult> refresh({required String refreshToken}) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/auth/refresh');
    final response = await http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh_token': refreshToken}),
    );

    final data = _parseJsonMap(response.body);

    if (response.statusCode == 200) {
      return _toLoginResult(data);
    }

    throw Exception(_extractErrorMessage(data, 'Refresh token failed (${response.statusCode})'));
  }

  Future<void> logout({required String refreshToken}) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/auth/logout');
    final response = await http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh_token': refreshToken}),
    );

    if (response.statusCode == 200) {
      return;
    }

    final data = _parseJsonMap(response.body);
    throw Exception(_extractErrorMessage(data, 'Logout failed (${response.statusCode})'));
  }

  Future<UserMeResult> me({required String token}) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/auth/me');
    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    final data = _parseJsonMap(response.body);

    if (response.statusCode == 200) {
      return UserMeResult(
        id: (data['id'] as num?)?.toInt() ?? 0,
        email: data['email'] as String? ?? '',
        role: data['role'] as String? ?? 'USER',
      );
    }

    throw Exception(_extractErrorMessage(data, 'Get profile failed (${response.statusCode})'));
  }

  Future<RegisterResult> register({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/auth/register');
    final response = await http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    final data = _parseJsonMap(response.body);

    if (response.statusCode == 201) {
      return RegisterResult(
        id: data['id'] as int,
        email: data['email'] as String,
        role: data['role'] as String,
      );
    }

    throw Exception(_extractErrorMessage(data, 'Register failed (${response.statusCode})'));
  }

  LoginResult _toLoginResult(Map<String, dynamic> data) {
    return LoginResult(
      accessToken: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String?,
      tokenType: data['token_type'] as String? ?? 'bearer',
      accessExpiresInMinutes: (data['access_expires_in_minutes'] as num?)?.toInt(),
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

    return fallback;
  }
}
