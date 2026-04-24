import 'dart:async';

import 'package:flutter/material.dart';

import 'package:birdle/core/config/app_config.dart';
import 'package:birdle/core/services/push_notification_service.dart';
import 'package:birdle/core/storage/token_storage.dart';
import 'package:birdle/core/theme/app_colors.dart';
import 'package:birdle/core/theme/app_dimensions.dart';
import 'package:birdle/core/theme/app_text_styles.dart';
import 'package:birdle/features/auth/data/auth_api.dart';
import 'package:birdle/features/auth/presentation/register_page.dart';
import 'package:birdle/features/auth/presentation/widgets/auth_widgets.dart';
import 'package:birdle/features/auth/presentation/widgets/recaptcha_v2.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _authApi = const AuthApi();
  final _tokenStorage = TokenStorage();
  late final RecaptchaV2Controller _recaptchaController;

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = true;
  String? _recaptchaToken;
  String? _errorMessage;
  String? _infoMessage;

  @override
  void initState() {
    super.initState();
    _recaptchaController = createRecaptchaV2Controller();
    _restoreSession();
  }

  @override
  void dispose() {
    _recaptchaController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _restoreSession() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    var redirected = false;
    var shouldClearSession = false;

    try {
      final savedEmail = await _tokenStorage.getLastEmail();
      if (savedEmail != null && savedEmail.isNotEmpty) {
        _emailController.text = savedEmail;
      }

      final accessToken = await _tokenStorage.getToken();
      final remember = await _tokenStorage.getRememberMe();
      final refreshToken = await _tokenStorage.getRefreshToken();

      setState(() => _rememberMe = remember);

      if (accessToken == null || accessToken.isEmpty) return;

      var activeAccessToken = accessToken;
      UserMeResult me;

      try {
        me = await _authApi.me(token: activeAccessToken);
      } on AuthApiException catch (error) {
        if (refreshToken == null ||
            refreshToken.isEmpty ||
            !error.isAuthFailure) {
          if (_shouldClearSessionOnRestoreError(error)) {
            shouldClearSession = true;
          }
          rethrow;
        }
        final refreshed = await _authApi.refresh(refreshToken: refreshToken);
        activeAccessToken = refreshed.accessToken;
        await _tokenStorage.saveSession(
          accessToken: refreshed.accessToken,
          refreshToken: refreshed.refreshToken ?? refreshToken,
          rememberMe: remember,
          email: savedEmail,
        );
        me = await _authApi.me(token: activeAccessToken);
      } on Exception catch (error) {
        if (refreshToken == null || refreshToken.isEmpty) {
          if (_shouldClearSessionOnRestoreError(error)) {
            shouldClearSession = true;
          }
          rethrow;
        }
        final refreshed = await _authApi.refresh(refreshToken: refreshToken);
        activeAccessToken = refreshed.accessToken;
        await _tokenStorage.saveSession(
          accessToken: refreshed.accessToken,
          refreshToken: refreshed.refreshToken ?? refreshToken,
          rememberMe: remember,
          email: savedEmail,
        );
        me = await _authApi.me(token: activeAccessToken);
      }

      unawaited(
        PushNotificationService.requestTokenAndRegister(
          accessToken: activeAccessToken,
        ),
      );

      if (!mounted) return;
      redirected = true;
      final profileEmail = me.email.isNotEmpty ? me.email : (savedEmail ?? '');
      _openByRole(role: me.role.toUpperCase(), email: profileEmail);
    } on Exception catch (error) {
      final shouldClear =
          shouldClearSession || _shouldClearSessionOnRestoreError(error);
      if (shouldClear) {
        await _tokenStorage.clearSession(keepLastEmail: true);
      }
      if (!mounted) return;
      setState(() {
        _infoMessage = shouldClear
            ? 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.'
            : 'Không thể khôi phục phiên lúc này. Vui lòng thử tải lại.';
      });
    } finally {
      if (mounted && !redirected) setState(() => _isLoading = false);
    }
  }

  void _openByRole({required String role, required String email}) {
    if (role == 'ADMIN') {
      Navigator.of(
        context,
      ).pushReplacementNamed('/admin', arguments: {'email': email});
      return;
    }
    Navigator.of(
      context,
    ).pushReplacementNamed('/home', arguments: {'email': email});
  }

  bool _shouldClearSessionOnRestoreError(Exception error) {
    if (error is! AuthApiException) return false;
    final code = error.statusCode;
    return code == 401 || code == 403;
  }

  bool get _recaptchaRequired => AppConfig.recaptchaSiteKey.trim().isNotEmpty;

  String _friendlyError(Object error, {required String fallback}) {
    var message = error.toString().trim();
    if (message.startsWith('Exception: ')) {
      message = message.substring('Exception: '.length).trim();
    }
    return message.isEmpty ? fallback : message;
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    if (_recaptchaRequired &&
        (_recaptchaToken == null || _recaptchaToken!.trim().isEmpty)) {
      setState(() {
        _errorMessage = 'Vui lòng xác minh reCAPTCHA trước khi đăng nhập.';
        _infoMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      final result = await _authApi.login(
        email: email,
        password: password,
        rememberMe: _rememberMe,
        recaptchaToken: _recaptchaToken,
      );

      await _tokenStorage.saveSession(
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
        rememberMe: _rememberMe,
        email: email,
      );

      UserMeResult? me;
      try {
        me = await _authApi.me(token: result.accessToken);
      } on Exception catch (_) {
        // Fallback to USER flow if /auth/me temporarily fails.
      }

      unawaited(
        PushNotificationService.requestTokenAndRegister(
          accessToken: result.accessToken,
        ),
      );

      if (!mounted) return;

      final profileEmail = (me?.email ?? '').isNotEmpty ? me!.email : email;
      final role = (me?.role ?? 'USER').toUpperCase();
      _openByRole(role: role, email: profileEmail);
    } on AuthApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Đăng nhập thất bại: ${e.message}');
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Đăng nhập thất bại: ${_friendlyError(e, fallback: 'Không thể đăng nhập lúc này.')}';
      });
      if (_recaptchaRequired) {
        _recaptchaController.reset();
        _recaptchaToken = null;
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _goToRegister() async {
    final registeredEmail = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const RegisterPage()));
    if (!mounted || registeredEmail == null || registeredEmail.isEmpty) return;
    setState(() {
      _emailController.text = registeredEmail;
      _passwordController.clear();
      _errorMessage = null;
      _infoMessage = 'Tài khoản đã tạo. Bạn đăng nhập để tiếp tục.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: const AuthBrandHeader(),
      ),
      body: Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSizes.loginFormMaxWidth,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.xxxl,
                ),
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadius.cardAll,
                    boxShadow: AppShadows.elevated,
                  ),
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Chào mừng quay lại',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.headerTitle.copyWith(
                            color: AppColors.textPrimary,
                            
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Đăng nhập để tiếp tục chấm công.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        if (_errorMessage != null)
                          AuthBanner(text: _errorMessage!, isError: true),
                        if (_infoMessage != null)
                          AuthBanner(text: _infoMessage!, isError: false),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          decoration: authInputDecoration(
                            label: 'Email',
                            icon: Icons.alternate_email,
                          ),
                          validator: (value) {
                            final input = value?.trim() ?? '';
                            if (input.isEmpty) {
                              return 'Nhập email';
                            }
                            if (!input.contains('@')) {
                              return 'Email không hợp lệ';
                            }
                            return null;
                          },
                          onChanged: (_) {
                            if (_errorMessage != null || _infoMessage != null) {
                              setState(() {
                                _errorMessage = null;
                                _infoMessage = null;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) {
                            if (!_isLoading) _submit();
                          },
                          autofillHints: const [AutofillHints.password],
                          decoration: authInputDecoration(
                            label: 'Mật khẩu',
                            icon: Icons.lock_outline,
                            suffixIcon: IconButton(
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Nhập mật khẩu';
                            }
                            if (value.length < 6) {
                              return 'Mật khẩu tối thiểu 6 ký tự';
                            }
                            return null;
                          },
                          onChanged: (_) {
                            if (_errorMessage != null || _infoMessage != null) {
                              setState(() {
                                _errorMessage = null;
                                _infoMessage = null;
                              });
                            }
                          },
                        ),
                        if (_recaptchaRequired) ...[
                          const SizedBox(height: AppSpacing.md),
                          buildRecaptchaV2Widget(
                            siteKey: AppConfig.recaptchaSiteKey.trim(),
                            controller: _recaptchaController,
                            onTokenChanged: (token) {
                              if (!mounted) return;
                              setState(() {
                                _recaptchaToken = token;
                                if (token != null &&
                                    token.isNotEmpty &&
                                    _errorMessage != null &&
                                    _errorMessage!.contains('reCAPTCHA')) {
                                  _errorMessage = null;
                                }
                              });
                            },
                          ),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                value: _rememberMe,
                                onChanged: _isLoading
                                    ? null
                                    : (value) => setState(
                                        () => _rememberMe = value ?? true,
                                      ),
                                title: const Text(
                                  'Ghi nhớ đăng nhập',
                                  style: AppTextStyles.body,
                                ),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                dense: true,
                              ),
                            ),
                            TextButton(
                              onPressed: _isLoading
                                  ? null
                                  : () => Navigator.of(
                                      context,
                                    ).pushNamed('/forgot-password'),
                              child: const Text('Quên mật khẩu?'),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        SizedBox(
                          height: AppSizes.touchTargetMin,
                          child: FilledButton.icon(
                            onPressed: _isLoading ? null : _submit,
                            icon: _isLoading
                                ? const SizedBox(
                                    width: AppSpacing.lg,
                                    height: AppSpacing.lg,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.surface,
                                    ),
                                  )
                                : const Icon(Icons.login),
                            label: Text(
                              _isLoading ? 'Đang đăng nhập...' : 'Đăng nhập',
                              style: AppTextStyles.buttonLabel,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextButton(
                          onPressed: _isLoading ? null : _goToRegister,
                          child: const Text('Chưa có tài khoản? Tạo tài khoản'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_isLoading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
      ),
    );
  }
}
