import 'package:shared_preferences/shared_preferences.dart';

import 'package:birdle/core/storage/session_storage.dart';

class TokenStorage {
  static const _persistentAccessTokenKey = 'access_token';
  static const _persistentRefreshTokenKey = 'refresh_token';
  static const _sessionAccessTokenKey = 'session_access_token';
  static const _sessionRefreshTokenKey = 'session_refresh_token';
  static const _rememberMeKey = 'remember_me';
  static const _lastEmailKey = 'last_login_email';

  final SessionStorage _sessionStorage = SessionStorage();

  Future<void> saveSession({
    required String accessToken,
    String? refreshToken,
    required bool rememberMe,
    String? email,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (rememberMe) {
      await prefs.setString(_persistentAccessTokenKey, accessToken);
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await prefs.setString(_persistentRefreshTokenKey, refreshToken);
      } else {
        await prefs.remove(_persistentRefreshTokenKey);
      }
      _sessionStorage.removeItem(_sessionAccessTokenKey);
      _sessionStorage.removeItem(_sessionRefreshTokenKey);
    } else {
      _sessionStorage.setItem(_sessionAccessTokenKey, accessToken);
      if (refreshToken != null && refreshToken.isNotEmpty) {
        _sessionStorage.setItem(_sessionRefreshTokenKey, refreshToken);
      } else {
        _sessionStorage.removeItem(_sessionRefreshTokenKey);
      }
      await prefs.remove(_persistentAccessTokenKey);
      await prefs.remove(_persistentRefreshTokenKey);
    }

    await prefs.setBool(_rememberMeKey, rememberMe);

    if (email != null && email.isNotEmpty) {
      await prefs.setString(_lastEmailKey, email);
    }
  }

  Future<void> saveToken(String token) async {
    final rememberMe = await getRememberMe();
    await saveSession(accessToken: token, rememberMe: rememberMe);
  }

  Future<String?> getToken() async {
    final sessionToken = _sessionStorage.getItem(_sessionAccessTokenKey);
    if (sessionToken != null && sessionToken.isNotEmpty) {
      return sessionToken;
    }

    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_persistentAccessTokenKey);
  }

  Future<void> saveRefreshToken(String token) async {
    final rememberMe = await getRememberMe();
    final currentToken = await getToken();
    if (currentToken == null || currentToken.isEmpty) {
      return;
    }
    await saveSession(
      accessToken: currentToken,
      refreshToken: token,
      rememberMe: rememberMe,
    );
  }

  Future<String?> getRefreshToken() async {
    final sessionRefreshToken = _sessionStorage.getItem(_sessionRefreshTokenKey);
    if (sessionRefreshToken != null && sessionRefreshToken.isNotEmpty) {
      return sessionRefreshToken;
    }

    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_persistentRefreshTokenKey);
  }

  Future<void> setRememberMe(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberMeKey, value);
  }

  Future<bool> getRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rememberMeKey) ?? false;
  }

  Future<void> saveLastEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastEmailKey, email);
  }

  Future<String?> getLastEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastEmailKey);
  }

  Future<void> clearSession({bool keepLastEmail = true}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_persistentAccessTokenKey);
    await prefs.remove(_persistentRefreshTokenKey);
    await prefs.remove(_rememberMeKey);
    _sessionStorage.removeItem(_sessionAccessTokenKey);
    _sessionStorage.removeItem(_sessionRefreshTokenKey);

    if (!keepLastEmail) {
      await prefs.remove(_lastEmailKey);
    }
  }

  Future<void> clearToken() async {
    await clearSession(keepLastEmail: true);
  }
}
