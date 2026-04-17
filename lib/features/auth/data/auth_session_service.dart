import '../../../core/storage/token_storage.dart';
import 'auth_api.dart';

class AuthSessionService {
  AuthSessionService({
    TokenStorage? tokenStorage,
    AuthApi authApi = const AuthApi(),
  }) : _tokenStorage = tokenStorage ?? TokenStorage(),
       _authApi = authApi;

  final TokenStorage _tokenStorage;
  final AuthApi _authApi;

  Future<String?> resolveAccessToken() async {
    final accessToken = await _tokenStorage.getToken();
    if (accessToken == null || accessToken.isEmpty) {
      return null;
    }

    try {
      await _authApi.me(token: accessToken);
      return accessToken;
    } catch (error) {
      if (!_isAuthFailure(error)) {
        rethrow;
      }
    }

    final refreshToken = await _tokenStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      await _tokenStorage.clearSession(keepLastEmail: true);
      return null;
    }

    try {
      final rememberMe = await _tokenStorage.getRememberMe();
      final lastEmail = await _tokenStorage.getLastEmail();
      final refreshed = await _authApi.refresh(refreshToken: refreshToken);
      await _tokenStorage.saveSession(
        accessToken: refreshed.accessToken,
        refreshToken: refreshed.refreshToken ?? refreshToken,
        rememberMe: rememberMe,
        email: lastEmail,
      );
      return refreshed.accessToken;
    } catch (_) {
      await _tokenStorage.clearSession(keepLastEmail: true);
      return null;
    }
  }

  bool _isAuthFailure(Object error) {
    if (error is AuthApiException) {
      return error.isAuthFailure;
    }

    final message = error.toString().toLowerCase();
    return message.contains('401') ||
        message.contains('403') ||
        message.contains('unauthorized') ||
        message.contains('forbidden') ||
        message.contains('could not validate credentials') ||
        message.contains('credentials') ||
        message.contains('invalid token') ||
        message.contains('token không hợp lệ') ||
        message.contains('hết hạn');
  }
}
