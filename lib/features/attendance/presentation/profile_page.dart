import 'package:flutter/material.dart';

import '../../../core/layout/responsive.dart';
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
  String _employeeCode = '';
  String? _groupName;
  DateTime? _joinedAt;

  bool _isLoading = true;
  bool _isLoggingOut = false;

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

    try {
      UserMeResult? me;
      EmployeeProfile? emp;

      await Future.wait([
        _authApi.me(token: token).then((r) { me = r; }).catchError((_) {}),
        _attendanceApi.getMyEmployeeProfile(token).then((r) { emp = r; }).catchError((_) {}),
      ]);

      if (mounted) {
        setState(() {
          if (me != null) {
            _email = me!.email;
            _role = me!.role;
          }
          if (emp != null) {
            _fullName = emp!.fullName;
            _employeeCode = emp!.code;
            _groupName = emp!.groupName;
            _joinedAt = emp!.joinedAt;
          }
        });
      }
    } catch (_) {
      // silently degrade — show whatever was loaded
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc muốn đăng xuất không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

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
          const SnackBar(content: Text('Đăng xuất thất bại. Vui lòng thử lại.')),
        );
      }
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

  String get _displayName => _fullName.isNotEmpty ? _fullName : (_email.isNotEmpty ? _email : '—');

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
    final isDesktop = context.isDesktop;

    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : isDesktop
                    ? Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: _buildScrollBody(),
                        ),
                      )
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

  Widget _buildScrollBody() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 28),
          _buildAvatarSection(),
          const SizedBox(height: 20),
          _buildInfoSection(
            title: 'Thông tin cá nhân',
            rows: [
              _InfoRow(label: 'Email', value: _email.isNotEmpty ? _email : '—'),
              _InfoRow(label: 'Số điện thoại', value: '—'),
              _InfoRow(label: 'Ngày sinh', value: '—'),
              _InfoRow(label: 'Giới tính', value: '—'),
            ],
          ),
          const SizedBox(height: 20),
          _buildInfoSection(
            title: 'Công việc',
            rows: [
              _InfoRow(label: 'Nhóm', value: _groupName ?? '—'),
              _InfoRow(label: 'Mã nhân viên', value: _employeeCode.isNotEmpty ? _employeeCode : '—'),
              _InfoRow(label: 'Ngày vào làm', value: _formatDate(_joinedAt)),
            ],
          ),
          const SizedBox(height: 20),
          _buildSettingsSection(),
          const SizedBox(height: 24),
          _buildLogoutButton(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildAvatarSection() {
    final isAdmin = _role.toUpperCase() == 'ADMIN';
    final chipColor = isAdmin ? AppColors.primary : AppColors.success;
    final chipBg = isAdmin ? AppColors.primaryLight : AppColors.successLight;

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
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
            Positioned(
              bottom: 0,
              right: -2,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border, width: 1.5),
                ),
                child: const Icon(Icons.edit, size: 14, color: AppColors.textSecondary),
              ),
            ),
          ],
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

  Widget _buildInfoSection({required String title, required List<_InfoRow> rows}) {
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
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
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
          ),
          _buildDivider(),
          _buildSettingItem(
            icon: Icons.language,
            iconColor: AppColors.success,
            label: 'Ngôn ngữ',
            valueText: 'Tiếng Việt',
          ),
          _buildDivider(),
          _buildSettingItem(
            icon: Icons.dark_mode_outlined,
            iconColor: AppColors.textSecondary,
            label: 'Chế độ tối',
            valueText: 'Tắt',
          ),
          _buildDivider(),
          _buildSettingItem(
            icon: Icons.help_outline,
            iconColor: AppColors.warning,
            label: 'Trợ giúp',
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
                style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
              ),
            ),
            if (valueText != null)
              Text(
                valueText,
                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: onTap != null ? AppColors.textSecondary : AppColors.border,
            ),
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
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
                      'Đăng xuất',
                      style: TextStyle(
                        color: Colors.white,
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
