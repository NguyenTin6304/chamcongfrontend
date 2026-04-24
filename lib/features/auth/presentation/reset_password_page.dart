import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter/material.dart';

import 'package:birdle/core/theme/app_colors.dart';
import 'package:birdle/core/theme/app_dimensions.dart';
import 'package:birdle/core/theme/app_text_styles.dart';
import 'package:birdle/features/auth/data/password_reset_api.dart';
import 'package:birdle/features/auth/presentation/widgets/auth_widgets.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _tokenController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _api = const PasswordResetApi();

  bool _isLoading = false;
  bool _obscureToken = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _missingTokenFromLink = false;
  String? _errorMessage;
  String? _infoMessage;

  @override
  void initState() {
    super.initState();
    final initialToken = _extractTokenFromCurrentUrl();
    if (initialToken.isNotEmpty) {
      _tokenController.text = initialToken;
      _infoMessage = 'Đã tự điền token từ link.';
    } else {
      _missingTokenFromLink = true;
      _errorMessage =
          'Link đặt lại mật khẩu thiếu token. Vui lòng yêu cầu gửi lại email.';
    }
    _tokenController.addListener(_syncTokenMissingState);
  }

  @override
  void dispose() {
    _tokenController.removeListener(_syncTokenMissingState);
    _tokenController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _syncTokenMissingState() {
    final isMissing = _tokenController.text.trim().isEmpty;
    if (_missingTokenFromLink != isMissing) {
      setState(() => _missingTokenFromLink = isMissing);
    }
  }

  String _friendlyError(Object error, {required String fallback}) {
    var message = error.toString().trim();
    if (message.startsWith('Exception: ')) {
      message = message.substring('Exception: '.length).trim();
    }
    return message.isEmpty ? fallback : message;
  }

  String _extractTokenFromCurrentUrl() {
    final uri = Uri.base;
    final direct = uri.queryParameters['token'];
    if (direct != null && direct.trim().isNotEmpty) return direct.trim();

    final fragment = uri.fragment;
    final questionIndex = fragment.indexOf('?');
    if (questionIndex >= 0 && questionIndex < fragment.length - 1) {
      final query = fragment.substring(questionIndex + 1);
      final fragmentQuery = Uri(query: query).queryParameters['token'];
      if (fragmentQuery != null && fragmentQuery.trim().isNotEmpty) {
        return fragmentQuery.trim();
      }
    }
    return '';
  }

  Future<void> _submit() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      setState(() {
        _errorMessage =
            'Thiếu token đặt lại mật khẩu. Vui lòng yêu cầu gửi lại email.';
      });
      return;
    }

    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      final message = await _api.resetPassword(
        token: token,
        newPassword: _passwordController.text,
      );

      if (!mounted) return;
      setState(() => _infoMessage = message);

      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      unawaited(Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đặt lại mật khẩu thành công. Hãy đăng nhập lại.'),
        ),
      );
    } on Exception catch (e) {
      dev.log('resetPassword: $e', name: 'ResetPasswordPage');
      if (!mounted) return;
      setState(() {
        _errorMessage = _friendlyError(e, fallback: 'Không thể đặt lại mật khẩu lúc này.');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: Text(
          'Đặt lại mật khẩu',
          style: AppTextStyles.sectionTitle.copyWith(color: AppColors.textPrimary),
        ),
      ),
      body: Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppSizes.loginFormMaxWidth),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Đổi mật khẩu mới',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.headerTitle.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Nhập token và mật khẩu mới để hoàn tất.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        if (_missingTokenFromLink)
                          const AuthBanner(
                            text:
                                'Link không có token. Vui lòng yêu cầu gửi lại email hoặc dán token thủ công.',
                            isError: true,
                          ),
                        if (_errorMessage != null)
                          AuthBanner(text: _errorMessage!, isError: true),
                        if (_infoMessage != null)
                          AuthBanner(text: _infoMessage!, isError: false),
                        TextFormField(
                          controller: _tokenController,
                          obscureText: _obscureToken,
                          enableSuggestions: false,
                          autocorrect: false,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) {
                            if (_errorMessage != null) {
                              setState(() => _errorMessage = null);
                            }
                          },
                          decoration: authInputDecoration(
                            label: 'Token reset',
                            icon: Icons.vpn_key_outlined,
                            suffixIcon: IconButton(
                              onPressed: () =>
                                  setState(() => _obscureToken = !_obscureToken),
                              icon: Icon(
                                _obscureToken
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) return 'Nhập token reset';
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.next,
                          decoration: authInputDecoration(
                            label: 'Mật khẩu mới',
                            icon: Icons.lock_outline,
                            suffixIcon: IconButton(
                              onPressed: () =>
                                  setState(() => _obscurePassword = !_obscurePassword),
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Nhập mật khẩu mới';
                            if (value.length < 6) return 'Mật khẩu tối thiểu 6 ký tự';
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          textInputAction: TextInputAction.done,
                          decoration: authInputDecoration(
                            label: 'Nhập lại mật khẩu mới',
                            icon: Icons.lock_reset,
                            suffixIcon: IconButton(
                              onPressed: () => setState(
                                () =>
                                    _obscureConfirmPassword = !_obscureConfirmPassword,
                              ),
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Nhập lại mật khẩu';
                            if (value != _passwordController.text) {
                              return 'Mật khẩu nhập lại không khớp';
                            }
                            return null;
                          },
                          onFieldSubmitted: (_) {
                            if (!_isLoading && _tokenController.text.trim().isNotEmpty) {
                              _submit();
                            }
                          },
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        SizedBox(
                          height: AppSizes.touchTargetMin,
                          child: FilledButton.icon(
                            onPressed:
                                (_isLoading || _tokenController.text.trim().isEmpty)
                                    ? null
                                    : _submit,
                            icon: _isLoading
                                ? const SizedBox(
                                    width: AppSpacing.lg,
                                    height: AppSpacing.lg,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.surface,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: Text(
                              _isLoading ? 'Đang xử lý...' : 'Đặt lại mật khẩu',
                              style: AppTextStyles.buttonLabel,
                            ),
                          ),
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
