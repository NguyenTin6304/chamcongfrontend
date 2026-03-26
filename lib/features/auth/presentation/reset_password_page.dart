import 'package:flutter/material.dart';

import '../data/password_reset_api.dart';

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
      _errorMessage = 'Link đặt lại mật khẩu thiếu token. Vui lòng yêu cầu gửi lại email.';
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
      setState(() {
        _missingTokenFromLink = isMissing;
      });
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
    if (direct != null && direct.trim().isNotEmpty) {
      return direct.trim();
    }

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

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.6),
      ),
    );
  }

  Widget _buildBanner({required String text, required bool isError}) {
    final color = isError ? Colors.red : Colors.blue;
    final icon = isError ? Icons.error_outline : Icons.info_outline;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      setState(() {
        _errorMessage = 'Thiếu token đặt lại mật khẩu. Vui lòng yêu cầu gửi lại email.';
      });
      return;
    }

    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

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

      if (!mounted) {
        return;
      }

      setState(() {
        _infoMessage = message;
      });

      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đặt lại mật khẩu thành công. Hãy đăng nhập lại.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = _friendlyError(error, fallback: 'Không thể đặt lại mật khẩu lúc này.');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đặt lại mật khẩu')),
      body: Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Đổi mật khẩu mới',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Nhập token và mật khẩu mới để hoàn tất.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey.shade700,
                                ),
                          ),
                          const SizedBox(height: 14),
                          if (_missingTokenFromLink)
                            _buildBanner(
                              text: 'Link không có token. Vui lòng yêu cầu gửi lại email hoặc dán token thủ công.',
                              isError: true,
                            ),
                          if (_errorMessage != null) _buildBanner(text: _errorMessage!, isError: true),
                          if (_infoMessage != null) _buildBanner(text: _infoMessage!, isError: false),
                          TextFormField(
                            controller: _tokenController,
                            obscureText: _obscureToken,
                            enableSuggestions: false,
                            autocorrect: false,
                            textInputAction: TextInputAction.next,
                            onChanged: (_) {
                              if (_errorMessage != null) {
                                setState(() {
                                  _errorMessage = null;
                                });
                              }
                            },
                            decoration: _inputDecoration(
                              label: 'Token reset',
                              icon: Icons.vpn_key_outlined,
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _obscureToken = !_obscureToken;
                                  });
                                },
                                icon: Icon(
                                  _obscureToken ? Icons.visibility : Icons.visibility_off,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if ((value ?? '').trim().isEmpty) {
                                return 'Nhập token reset';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.next,
                            decoration: _inputDecoration(
                              label: 'Mật khẩu mới',
                              icon: Icons.lock_outline,
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Nhập mật khẩu mới';
                              }
                              if (value.length < 6) {
                                return 'Mật khẩu tối thiểu 6 ký tự';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmPassword,
                            textInputAction: TextInputAction.done,
                            decoration: _inputDecoration(
                              label: 'Nhập lại mật khẩu mới',
                              icon: Icons.lock_reset,
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _obscureConfirmPassword = !_obscureConfirmPassword;
                                  });
                                },
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Nhập lại mật khẩu';
                              }
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
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 48,
                            child: FilledButton.icon(
                              onPressed: (_isLoading || _tokenController.text.trim().isEmpty) ? null : _submit,
                              icon: _isLoading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.save_outlined),
                              label: Text(_isLoading ? 'Đang xử lý...' : 'Đặt lại mật khẩu'),
                            ),
                          ),
                        ],
                      ),
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
