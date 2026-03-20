import 'package:flutter/material.dart';

import '../../../core/storage/token_storage.dart';
import '../../admin/presentation/admin_page.dart';
import '../../home/presentation/home_page.dart';
import '../data/auth_api.dart';
import 'register_page.dart';

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

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = true;

  String? _errorMessage;
  String? _infoMessage;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  @override
  void dispose() {
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

    try {
      final savedEmail = await _tokenStorage.getLastEmail();
      if (savedEmail != null && savedEmail.isNotEmpty) {
        _emailController.text = savedEmail;
      }

      final accessToken = await _tokenStorage.getToken();
      final remember = await _tokenStorage.getRememberMe();
      final refreshToken = await _tokenStorage.getRefreshToken();

      setState(() {
        _rememberMe = remember;
      });

      if (accessToken == null || accessToken.isEmpty) {
        return;
      }

      var activeAccessToken = accessToken;
      UserMeResult me;

      try {
        me = await _authApi.me(token: activeAccessToken);
      } catch (_) {
        if (refreshToken == null || refreshToken.isEmpty) {
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

      if (!mounted) {
        return;
      }

      redirected = true;
      final profileEmail = me.email.isNotEmpty ? me.email : (savedEmail ?? '');
      _openByRole(role: me.role.toUpperCase(), email: profileEmail);
    } catch (_) {
      await _tokenStorage.clearSession(keepLastEmail: true);
      if (!mounted) {
        return;
      }
      setState(() {
        _infoMessage = 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
      });
    } finally {
      if (mounted && !redirected) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _openByRole({
    required String role,
    required String email,
  }) {
    if (role == 'ADMIN') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => AdminPage(email: email)),
      );
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => HomePage(email: email)),
    );
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
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.6),
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

  String _friendlyError(Object error, {required String fallback}) {
    var message = error.toString().trim();
    if (message.startsWith('Exception: ')) {
      message = message.substring('Exception: '.length).trim();
    }
    return message.isEmpty ? fallback : message;
  }

  Future<void> _submit() async {
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
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      final result = await _authApi.login(
        email: email,
        password: password,
        rememberMe: _rememberMe,
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
      } catch (_) {
        // Fallback to USER flow if /auth/me temporarily fails.
      }

      if (!mounted) {
        return;
      }

      final profileEmail = (me?.email ?? '').isNotEmpty ? me!.email : email;
      final role = (me?.role ?? 'USER').toUpperCase();
      _openByRole(role: role, email: profileEmail);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = "Đăng nhập thất bại: ${_friendlyError(error, fallback: 'Không thể đăng nhập lúc này.')}";
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _goToRegister() async {
    final registeredEmail = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const RegisterPage()),
    );

    if (!mounted || registeredEmail == null || registeredEmail.isEmpty) {
      return;
    }

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
      appBar: AppBar(title: const Text('Đăng nhập')),
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
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Chào mừng quay lại',
                            style: Theme.of(context).textTheme.titleLarge,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Đăng nhập để tiếp tục chấm công.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 14),
                          if (_errorMessage != null) _buildBanner(text: _errorMessage!, isError: true),
                          if (_infoMessage != null) _buildBanner(text: _infoMessage!, isError: false),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            decoration: _inputDecoration(
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
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (value) => {
                              if (!_isLoading) {
                                _submit()
                              }
                            },
                            autofillHints: const [AutofillHints.password],
                            decoration: _inputDecoration(
                              label: 'Mật khẩu',
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
                          Row(
                            children: [
                              Expanded(
                                child: CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  value: _rememberMe,
                                  onChanged: _isLoading
                                      ? null
                                      : (value) {
                                          setState(() {
                                            _rememberMe = value ?? true;
                                          });
                                        },
                                  title: const Text('Ghi nhớ đăng nhập'),
                                  controlAffinity: ListTileControlAffinity.leading,
                                  dense: true,
                                ),
                              ),
                              TextButton(
                                onPressed: _isLoading
                                    ? null
                                    : () => Navigator.of(context).pushNamed('/forgot-password'),
                                child: const Text('Quên mật khẩu?'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            height: 48,
                            child: FilledButton.icon(
                              onPressed: _isLoading ? null : _submit,
                              icon: _isLoading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.login),
                              label: Text(_isLoading ? 'Đang đăng nhập...' : 'Đăng nhập'),
                            ),
                          ),
                          const SizedBox(height: 8),
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




