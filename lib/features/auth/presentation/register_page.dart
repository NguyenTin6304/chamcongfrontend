import 'dart:developer' as dev;

import 'package:flutter/material.dart';

import 'package:birdle/core/theme/app_colors.dart';
import 'package:birdle/core/theme/app_dimensions.dart';
import 'package:birdle/core/theme/app_text_styles.dart';
import 'package:birdle/features/auth/data/auth_api.dart';
import 'package:birdle/features/auth/presentation/widgets/auth_widgets.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _nameFocusNode = FocusNode();
  final _phoneFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();

  final _authApi = const AuthApi();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameFocusNode.dispose();
    _phoneFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  String _normalizePhone(String value) =>
      value.trim().replaceAll(RegExp(r'[\s.-]'), '');

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final fullName = _nameController.text.trim();
      final phone = _normalizePhone(_phoneController.text);
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      final result = await _authApi.register(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
      );

      if (!mounted) return;
      Navigator.of(context).pop(result.email);
    } on AuthApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Đăng ký thất bại: ${e.message}');
    } on Exception catch (e) {
      dev.log('register: $e', name: 'RegisterPage');
      if (!mounted) return;
      setState(() => _errorMessage = 'Đăng ký thất bại. Vui lòng thử lại.');
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
          'Đăng ký tài khoản',
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
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Tạo tài khoản mới',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.headerTitle.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Tài khoản sẽ được tạo với quyền USER.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        if (_errorMessage != null)
                          AuthBanner(text: _errorMessage!, isError: true),
                        TextFormField(
                          controller: _nameController,
                          focusNode: _nameFocusNode,
                          keyboardType: TextInputType.text,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.name],
                          decoration: authInputDecoration(
                            label: 'Họ và tên',
                            icon: Icons.person,
                          ),
                          validator: (value) {
                            final input = value?.trim() ?? '';
                            if (input.isEmpty) return 'Nhập họ và tên';
                            if (input.length < 2) return 'Họ và tên tối thiểu 2 ký tự';
                            if (RegExp(r'\d').hasMatch(input)) {
                              return 'Họ và tên không được chứa số';
                            }
                            return null;
                          },
                          onFieldSubmitted: (_) => _emailFocusNode.requestFocus(),
                          onChanged: (_) {
                            if (_errorMessage != null) {
                              setState(() => _errorMessage = null);
                            }
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextFormField(
                          controller: _emailController,
                          focusNode: _emailFocusNode,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          decoration: authInputDecoration(
                            label: 'Email',
                            icon: Icons.alternate_email,
                          ),
                          validator: (value) {
                            final input = value?.trim() ?? '';
                            if (input.isEmpty) return 'Nhập email';
                            if (!input.contains('@')) return 'Email không hợp lệ';
                            return null;
                          },
                          onFieldSubmitted: (_) => _phoneFocusNode.requestFocus(),
                          onChanged: (_) {
                            if (_errorMessage != null) {
                              setState(() => _errorMessage = null);
                            }
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextFormField(
                          controller: _phoneController,
                          focusNode: _phoneFocusNode,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.telephoneNumber],
                          decoration: authInputDecoration(
                            label: 'Số điện thoại',
                            icon: Icons.phone,
                          ),
                          validator: (value) {
                            final input = value?.trim() ?? '';
                            final normalized = _normalizePhone(input);
                            if (input.isEmpty) return 'Nhập số điện thoại';
                            if (!RegExp(r'^\d{10,11}$').hasMatch(normalized)) {
                              return 'Số điện thoại không hợp lệ';
                            }
                            return null;
                          },
                          onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
                          onChanged: (_) {
                            if (_errorMessage != null) {
                              setState(() => _errorMessage = null);
                            }
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextFormField(
                          controller: _passwordController,
                          focusNode: _passwordFocusNode,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.newPassword],
                          decoration: authInputDecoration(
                            label: 'Mật khẩu',
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
                            if (value == null || value.isEmpty) return 'Nhập mật khẩu';
                            if (value.length < 6) return 'Mật khẩu tối thiểu 6 ký tự';
                            return null;
                          },
                          onFieldSubmitted: (_) =>
                              _confirmPasswordFocusNode.requestFocus(),
                          onChanged: (_) {
                            if (_errorMessage != null) {
                              setState(() => _errorMessage = null);
                            }
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextFormField(
                          controller: _confirmPasswordController,
                          focusNode: _confirmPasswordFocusNode,
                          obscureText: _obscureConfirmPassword,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.newPassword],
                          decoration: authInputDecoration(
                            label: 'Nhập lại mật khẩu',
                            icon: Icons.lock_reset,
                            suffixIcon: IconButton(
                              onPressed: () => setState(
                                () => _obscureConfirmPassword = !_obscureConfirmPassword,
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
                            if (!_isLoading) _submit();
                          },
                          onChanged: (_) {
                            if (_errorMessage != null) {
                              setState(() => _errorMessage = null);
                            }
                          },
                        ),
                        const SizedBox(height: AppSpacing.lg),
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
                                : const Icon(Icons.person_add_alt_1),
                            label: Text(
                              _isLoading ? 'Đang tạo...' : 'Tạo tài khoản',
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
