import 'package:flutter/material.dart';

import '../../../core/storage/token_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/data/auth_api.dart';
import '../data/attendance_api.dart';

class ProfilePageBody extends StatefulWidget {
  const ProfilePageBody({super.key});

  @override
  State<ProfilePageBody> createState() => _ProfilePageBodyState();
}

class _ProfilePageBodyState extends State<ProfilePageBody> {
  final _tokenStorage = TokenStorage();
  final _authApi = const AuthApi();
  final _attendanceApi = const AttendanceApi();

  String _email = '';
  String _role = '';
  String _fullName = '';
  String _phone = '';
  String _employeeCode = '';
  String? _groupName;
  DateTime? _joinedAt;

  bool _isLoading = true;
  bool _isLoggingOut = false;
  bool _authFailed = false;
  bool _authRequiresLogin = false;
  bool _empFailed = false;
  bool _employeeNotAssigned = false;
  bool _employeeInactive = false;
  String? _authErrorMessage;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final token = await _tokenStorage.getToken();
    if (!mounted) return;

    if (token == null || token.isEmpty) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
      return;
    }

    setState(() {
      _isLoading = true;
      _authFailed = false;
      _authRequiresLogin = false;
      _empFailed = false;
      _employeeNotAssigned = false;
      _employeeInactive = false;
      _authErrorMessage = null;
    });

    UserMeResult? me;
    EmployeeProfile? emp;
    bool authErr = false;
    bool authRequiresLogin = false;
    bool empErr = false;
    bool empNotAssigned = false;
    String? authErrorMessage;

    await Future.wait<void>([
      () async {
        try {
          me = await _authApi.me(token: token);
        } on AuthApiException catch (error) {
          authErr = true;
          authRequiresLogin = error.isAuthFailure;
          authErrorMessage = authRequiresLogin
              ? 'Phiên đăng nhập không hợp lệ hoặc đã hết hạn.'
              : error.message;
        } catch (_) {
          authErr = true;
          authErrorMessage = 'Không thể tải hồ sơ đăng nhập. Vui lòng thử lại.';
        }
      }(),
      () async {
        try {
          emp = await _attendanceApi.getMyEmployeeProfile(token);
        } on EmployeeNotAssignedException {
          empNotAssigned = true;
        } catch (_) {
          empErr = true;
        }
      }(),
    ]);

    if (!mounted) return;

    setState(() {
      _authFailed = authErr;
      _authRequiresLogin = authRequiresLogin;
      _authErrorMessage = authErrorMessage;
      _empFailed = empErr;
      _employeeNotAssigned = empNotAssigned;
      _employeeInactive = emp != null && !emp!.active;
      if (me != null) {
        _email = me!.email;
        _role = me!.role;
        _fullName = me!.fullName ?? '';
        _phone = me!.phone ?? '';
      }
      if (emp != null) {
        _fullName = emp!.fullName;
        _phone = emp!.phone ?? '';
        _employeeCode = emp!.code;
        _groupName = emp!.groupName;
        _joinedAt = emp!.joinedAt;
      } else if (empErr) {
        _employeeCode = '';
        _groupName = null;
        _joinedAt = null;
      } else if (empNotAssigned) {
        _employeeCode = '';
        _groupName = null;
        _joinedAt = null;
      }
      _isLoading = false;
    });
  }

  Future<void> _handleLogout() async {
    if (!mounted) return;
    setState(() => _isLoggingOut = true);
    try {
      final refreshToken = await _tokenStorage.getRefreshToken();
      if (refreshToken != null && refreshToken.isNotEmpty) {
        try {
          await _authApi.logout(refreshToken: refreshToken);
        } catch (_) {
          // best-effort
        }
      }
      await _tokenStorage.clearSession();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoggingOut = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đăng xuất thất bại. Vui lòng thử lại.'),
          ),
        );
      }
    }
  }

  Future<void> _showChangePasswordDialog() async {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    var obscureCurrent = true;
    var obscureNew = true;
    var obscureConfirm = true;
    var saving = false;
    String? errorText;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> onSave() async {
            final current = currentCtrl.text;
            final newPass = newCtrl.text;
            final confirm = confirmCtrl.text;

            if (current.isEmpty) {
              setDialogState(() => errorText = 'Vui lòng nhập mật khẩu hiện tại.');
              return;
            }
            if (newPass.length < 6) {
              setDialogState(() => errorText = 'Mật khẩu mới phải có ít nhất 6 ký tự.');
              return;
            }
            if (newPass != confirm) {
              setDialogState(() => errorText = 'Mật khẩu xác nhận không khớp.');
              return;
            }

            setDialogState(() { saving = true; errorText = null; });

            final nav = Navigator.of(ctx);
            final messenger = ScaffoldMessenger.of(context);

            final token = await _tokenStorage.getToken();
            if (!mounted) return;
            if (token == null || token.isEmpty) {
              setDialogState(() { saving = false; errorText = 'Phiên đăng nhập đã hết hạn.'; });
              return;
            }
            try {
              await _authApi.changePassword(
                token: token,
                currentPassword: current,
                newPassword: newPass,
              );
              if (!mounted) return;
              nav.pop();
              messenger.showSnackBar(
                const SnackBar(content: Text('Đổi mật khẩu thành công.')),
              );
            } on AuthApiException catch (e) {
              if (mounted) setDialogState(() { saving = false; errorText = e.message; });
            } catch (_) {
              if (mounted) setDialogState(() { saving = false; errorText = 'Đổi mật khẩu thất bại. Vui lòng thử lại.'; });
            }
          }

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Đổi mật khẩu',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: currentCtrl,
                      obscureText: obscureCurrent,
                      style: const TextStyle(fontSize: 15),
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu hiện tại',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                        suffixIcon: IconButton(
                          icon: Icon(obscureCurrent ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: newCtrl,
                      obscureText: obscureNew,
                      style: const TextStyle(fontSize: 15),
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu mới',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                        suffixIcon: IconButton(
                          icon: Icon(obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: confirmCtrl,
                      obscureText: obscureConfirm,
                      style: const TextStyle(fontSize: 15),
                      decoration: InputDecoration(
                        labelText: 'Xác nhận mật khẩu mới',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                        suffixIcon: IconButton(
                          icon: Icon(obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                        ),
                      ),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.error_outline, size: 16, color: AppColors.error),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              errorText!,
                              style: const TextStyle(fontSize: 13, color: AppColors.error),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: saving ? null : () => Navigator.of(ctx).pop(),
                          child: const Text('Huỷ'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: saving ? null : onSave,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                          ),
                          child: saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Xác nhận', style: TextStyle(fontSize: 15)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    currentCtrl.dispose();
    newCtrl.dispose();
    confirmCtrl.dispose();
  }

  String get _avatarInitials {
    if (_fullName.trim().isNotEmpty) {
      final parts = _fullName.trim().split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
      }
      return parts.first[0].toUpperCase();
    }
    if (_email.isNotEmpty) return _email[0].toUpperCase();
    return '?';
  }

  String get _displayName =>
      _fullName.isNotEmpty ? _fullName : (_email.isNotEmpty ? _email : '—');

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  String get _roleLabel {
    switch (_role.toUpperCase()) {
      case 'ADMIN':
        return 'Quản trị viên';
      default:
        return 'Nhân viên';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _authFailed
                ? _buildAuthError()
                : _buildScrollBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: const Row(
        children: [
          Text(
            'Cá nhân',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthError() {
    final message =
        _authErrorMessage ??
        'Không thể tải thông tin đăng nhập. Vui lòng thử lại.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: _loadProfile,
                  child: const Text('Thử lại'),
                ),
                if (_authRequiresLogin) ...[
                  const SizedBox(width: 12),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    onPressed: () async {
                      await _tokenStorage.clearSession();
                      if (mounted) {
                        Navigator.of(
                          context,
                        ).pushNamedAndRemoveUntil('/login', (_) => false);
                      }
                    },
                    child: const Text('Đăng nhập lại'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeInactiveBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error, width: 0.5),
      ),
      child: const Row(
        children: [
          Icon(Icons.block, size: 20, color: AppColors.error),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tài khoản nhân viên của bạn đang bị vô hiệu hoá. Vui lòng liên hệ quản trị viên.',
              style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpErrorBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.warning, width: 0.5),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 20,
            color: AppColors.warning,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Không tải được thông tin nhân viên.',
              style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
            ),
          ),
          GestureDetector(
            onTap: _loadProfile,
            child: const Text(
              'Thử lại',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeePendingBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.warning, width: 0.5),
      ),
      child: const Row(
        children: [
          Icon(Icons.hourglass_empty, size: 20, color: AppColors.warning),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tài khoản chưa được admin gán nhân viên. Bạn chưa thể chấm công cho đến khi được duyệt.',
              style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollBody() {
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 28),
              _buildAvatarSection(),
              if (_employeeInactive && !_authFailed) ...[
                const SizedBox(height: 12),
                _buildEmployeeInactiveBanner(),
              ],
              if (_empFailed && !_authFailed) ...[
                const SizedBox(height: 12),
                _buildEmpErrorBanner(),
              ],
              if (_employeeNotAssigned && !_authFailed) ...[
                const SizedBox(height: 12),
                _buildEmployeePendingBanner(),
              ],
              const SizedBox(height: 20),
              _buildInfoSection(
                title: 'Thông tin cá nhân',
                rows: [
                  _InfoRow(
                    label: 'Email',
                    value: _email.isNotEmpty ? _email : '—',
                  ),
                  _InfoRow(
                    label: 'Số điện thoại',
                    value: _phone.isNotEmpty ? _phone : '—',
                  ),
                  _InfoRow(label: 'Ngày sinh', value: '—'),
                  _InfoRow(label: 'Giới tính', value: '—'),
                ],
              ),
              const SizedBox(height: 20),
              _buildInfoSection(
                title: 'Công việc',
                rows: [
                  _InfoRow(label: 'Nhóm', value: _groupName ?? '—'),
                  _InfoRow(
                    label: 'Mã nhân viên',
                    value: _employeeCode.isNotEmpty ? _employeeCode : '—',
                  ),
                  _InfoRow(
                    label: 'Ngày vào làm',
                    value: _formatDate(_joinedAt),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildSettingsSection(),
              const SizedBox(height: 24),
              _buildLogoutButton(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarSection() {
    final isAdmin = _role.toUpperCase() == 'ADMIN';
    final chipColor = isAdmin ? AppColors.primary : AppColors.success;
    final chipBg = isAdmin ? AppColors.primaryLight : AppColors.successLight;

    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: const BoxDecoration(
            color: AppColors.primaryLight,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              _avatarInitials,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _displayName,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        if (_employeeCode.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            _employeeCode,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
        if (_role.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: chipBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _roleLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: chipColor,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoSection({
    required String title,
    required List<_InfoRow> rows,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          for (int i = 0; i < rows.length; i++) ...[
            _buildInfoRow(rows[i]),
            if (i < rows.length - 1)
              const Divider(height: 1, indent: 16, color: AppColors.border),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(_InfoRow row) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(
            row.label,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            row.value,
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildSettingItem(
            icon: Icons.assignment_late_outlined,
            iconColor: AppColors.warning,
            label: 'Giải trình ngoại lệ',
            onTap: () => Navigator.of(context).pushNamed('/home/exceptions'),
          ),
          _buildDivider(),
          _buildSettingItem(
            icon: Icons.lock_outline,
            iconColor: AppColors.primary,
            label: 'Đổi mật khẩu',
            onTap: _showChangePasswordDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    String? valueText,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: iconColor),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (valueText != null)
              Text(
                valueText,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.textSecondary,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, indent: 52, color: AppColors.border);
  }

  Widget _buildLogoutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: Material(
          color: _isLoggingOut ? AppColors.border : AppColors.error,
          borderRadius: BorderRadius.circular(28),
          child: InkWell(
            onTap: _isLoggingOut ? null : _handleLogout,
            borderRadius: BorderRadius.circular(28),
            child: Center(
              child: _isLoggingOut
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: AppColors.surface,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
                      'Đăng xuất',
                      style: TextStyle(
                        color: AppColors.surface,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;
}
