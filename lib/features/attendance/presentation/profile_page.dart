import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter/material.dart';

import 'package:birdle/core/storage/token_storage.dart';
import 'package:birdle/core/theme/app_colors.dart';
import 'package:birdle/core/theme/app_dimensions.dart';
import 'package:birdle/core/theme/app_text_styles.dart';
import 'package:birdle/features/auth/data/auth_api.dart';
import 'package:birdle/features/attendance/data/attendance_api.dart';

enum _AuthState { ok, failed, requiresLogin }

enum _EmpState { ok, failed, notAssigned, inactive }

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
  _AuthState _authState = _AuthState.ok;
  _EmpState _empState = _EmpState.ok;
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
      unawaited(Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false));
      return;
    }

    setState(() {
      _isLoading = true;
      _authState = _AuthState.ok;
      _empState = _EmpState.ok;
      _authErrorMessage = null;
    });

    UserMeResult? me;
    EmployeeProfile? emp;
    var authState = _AuthState.ok;
    var empState = _EmpState.ok;
    String? authErrorMessage;

    await Future.wait<void>([
      () async {
        try {
          me = await _authApi.me(token: token);
        } on AuthApiException catch (error) {
          authState = error.isAuthFailure
              ? _AuthState.requiresLogin
              : _AuthState.failed;
          authErrorMessage = error.isAuthFailure
              ? 'Phiên đăng nhập không hợp lệ hoặc đã hết hạn.'
              : error.message;
        } on Exception catch (e) {
          authState = _AuthState.failed;
          authErrorMessage = 'Không thể tải hồ sơ đăng nhập. Vui lòng thử lại.';
          dev.log('_loadProfile auth: $e', name: 'ProfilePageBody');
        }
      }(),
      () async {
        try {
          emp = await _attendanceApi.getMyEmployeeProfile(token);
        } on EmployeeNotAssignedException {
          empState = _EmpState.notAssigned;
        } on Exception catch (e) {
          empState = _EmpState.failed;
          dev.log('_loadProfile emp: $e', name: 'ProfilePageBody');
        }
      }(),
    ]);

    if (!mounted) return;

    setState(() {
      _authState = authState;
      _authErrorMessage = authErrorMessage;
      if (authState == _AuthState.ok && emp != null && !emp!.active) {
        empState = _EmpState.inactive;
      }
      _empState = empState;
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
      } else if (empState == _EmpState.failed || empState == _EmpState.notAssigned) {
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
        } on Exception catch (e) {
          dev.log('logout best-effort: $e', name: 'ProfilePageBody');
        }
      }
      await _tokenStorage.clearSession();
      if (mounted) {
        unawaited(Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false));
      }
    } on Exception catch (e) {
      dev.log('_handleLogout: $e', name: 'ProfilePageBody');
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

    try {
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
              setDialogState(() { saving = false; errorText = e.message; });
            } on Exception catch (e) {
              dev.log('changePassword: $e', name: 'ProfilePageBody');
              setDialogState(() { saving = false; errorText = 'Đổi mật khẩu thất bại. Vui lòng thử lại.'; });
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
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.surface),
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
    } finally {
      currentCtrl.dispose();
      newCtrl.dispose();
      confirmCtrl.dispose();
    }
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

  String get _roleLabel => switch (_role.toUpperCase()) {
    'ADMIN' => 'Quản trị viên',
    _ => 'Nhân viên',
  };

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _authState != _AuthState.ok
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Text(
            'Cá nhân',
            style: AppTextStyles.headerTitle.copyWith(
              color: AppColors.textPrimary,
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
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 48, color: AppColors.error),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: _loadProfile,
                  child: const Text('Thử lại'),
                ),
                if (_authState == _AuthState.requiresLogin) ...[
                  const SizedBox(width: AppSpacing.md),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    onPressed: () async {
                      await _tokenStorage.clearSession();
                      if (mounted) {
                        unawaited(Navigator.of(
                          context,
                        ).pushNamedAndRemoveUntil('/login', (_) => false));
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
      margin: AppSpacing.paddingHLg,
      padding: AppSpacing.paddingAllMd,
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: AppColors.error, width: 0.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.block, size: 20, color: AppColors.error),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Tài khoản nhân viên của bạn đang bị vô hiệu hoá. Vui lòng liên hệ quản trị viên.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpErrorBanner() {
    return Container(
      margin: AppSpacing.paddingHLg,
      padding: AppSpacing.paddingAllMd,
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: AppColors.warning, width: 0.5),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 20,
            color: AppColors.warning,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Không tải được thông tin nhân viên.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
          GestureDetector(
            onTap: _loadProfile,
            child: Text(
              'Thử lại',
              style: AppTextStyles.bodySmall.copyWith(
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
      margin: AppSpacing.paddingHLg,
      padding: AppSpacing.paddingAllMd,
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: AppColors.warning, width: 0.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.hourglass_empty, size: 20, color: AppColors.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Tài khoản chưa được admin gán nhân viên. Bạn chưa thể chấm công cho đến khi được duyệt.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textPrimary,
              ),
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
              const SizedBox(height: AppSpacing.xxxl),
              _buildAvatarSection(),
              if (_empState == _EmpState.inactive) ...[
                const SizedBox(height: AppSpacing.md),
                _buildEmployeeInactiveBanner(),
              ],
              if (_empState == _EmpState.failed) ...[
                const SizedBox(height: AppSpacing.md),
                _buildEmpErrorBanner(),
              ],
              if (_empState == _EmpState.notAssigned) ...[
                const SizedBox(height: AppSpacing.md),
                _buildEmployeePendingBanner(),
              ],
              const SizedBox(height: AppSpacing.xl),
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
                  const _InfoRow(label: 'Ngày sinh', value: '—'),
                  const _InfoRow(label: 'Giới tính', value: '—'),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
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
              const SizedBox(height: AppSpacing.xl),
              _buildSettingsSection(),
              const SizedBox(height: AppSpacing.xxl),
              _buildLogoutButton(),
              const SizedBox(height: AppSpacing.xxxl + AppSpacing.sm),
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
          width: AppSizes.avatarSize,
          height: AppSizes.avatarSize,
          decoration: const BoxDecoration(
            color: AppColors.primaryLight,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              _avatarInitials,
              style: AppTextStyles.kpiNumber.copyWith(
                fontSize: 28,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          _displayName,
          style: AppTextStyles.headerTitle.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        if (_employeeCode.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            _employeeCode,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
        if (_role.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: chipBg,
              borderRadius: AppRadius.chipAll,
            ),
            child: Text(
              _roleLabel,
              style: AppTextStyles.captionBold.copyWith(color: chipColor),
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
      margin: AppSpacing.paddingHLg,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardAll,
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Text(
              title,
              style: AppTextStyles.sectionTitle.copyWith(
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Text(
            row.label,
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
          const Spacer(),
          Text(
            row.value,
            style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Container(
      margin: AppSpacing.paddingHLg,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardAll,
        boxShadow: AppShadows.card,
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
      borderRadius: AppRadius.cardAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: iconColor),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.sectionTitle.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (valueText != null)
              Text(
                valueText,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            if (onTap != null) ...[
              const SizedBox(width: AppSpacing.xs),
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
      padding: AppSpacing.paddingHLg,
      child: SizedBox(
        width: double.infinity,
        height: AppSizes.buttonHeight,
        child: Material(
          color: _isLoggingOut ? AppColors.border : AppColors.error,
          borderRadius: AppRadius.buttonAll,
          child: InkWell(
            onTap: _isLoggingOut ? null : _handleLogout,
            borderRadius: AppRadius.buttonAll,
            child: Center(
              child: _isLoggingOut
                  ? const SizedBox(
                      width: AppSpacing.xxl,
                      height: AppSpacing.xxl,
                      child: CircularProgressIndicator(
                        color: AppColors.surface,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      'Đăng xuất',
                      style: AppTextStyles.buttonLabel.copyWith(
                        color: AppColors.surface,
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
