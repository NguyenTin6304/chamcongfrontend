import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:birdle/core/storage/token_storage.dart';
import 'package:birdle/core/theme/app_colors.dart';
import 'package:birdle/core/theme/app_dimensions.dart';
import 'package:birdle/core/theme/app_text_styles.dart';
import 'package:birdle/features/admin/data/admin_api.dart';

class ExplanationPolicySettingsTab extends StatefulWidget {
  const ExplanationPolicySettingsTab({super.key});

  @override
  State<ExplanationPolicySettingsTab> createState() =>
      _ExplanationPolicySettingsTabState();
}

class _ExplanationPolicySettingsTabState
    extends State<ExplanationPolicySettingsTab> {
  final _tokenStorage = TokenStorage();
  final _api = const AdminApi();
  final _defaultDeadlineCtrl = TextEditingController();
  final _autoClosedCtrl = TextEditingController();
  final _missedCheckoutCtrl = TextEditingController();
  final _locationRiskCtrl = TextEditingController();
  final _largeDeviationCtrl = TextEditingController();
  final _gracePeriodCtrl = TextEditingController();

  String? _token;
  bool _loading = false;
  bool _saving = false;
  bool _purging = false;
  DateTime? _updatedAt;
  String? _updatedByName;

  @override
  void initState() {
    super.initState();
    _defaultDeadlineCtrl.text = '72';
    _gracePeriodCtrl.text = '30';
    _bootstrap();
  }

  @override
  void dispose() {
    _defaultDeadlineCtrl.dispose();
    _autoClosedCtrl.dispose();
    _missedCheckoutCtrl.dispose();
    _locationRiskCtrl.dispose();
    _largeDeviationCtrl.dispose();
    _gracePeriodCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final token = await _tokenStorage.getToken();
    if (!mounted) {
      return;
    }
    setState(() {
      _token = token;
    });
    await _loadPolicy();
  }

  Future<void> _loadPolicy() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      return;
    }
    setState(() {
      _loading = true;
    });
    try {
      final policy = await _api.getExceptionPolicy(token);
      if (!mounted) {
        return;
      }
      setState(() {
        _applyPolicy(policy);
      });
    } on UnauthorizedException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phiên đăng nhập đã hết hạn.')),
      );
    } on Exception catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể tải chính sách giải trình.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _applyPolicy(ExceptionPolicy policy) {
    _defaultDeadlineCtrl.text = policy.defaultDeadlineHours.toString();
    _autoClosedCtrl.text = _optionalText(policy.autoClosedDeadlineHours);
    _missedCheckoutCtrl.text = _optionalText(
      policy.missedCheckoutDeadlineHours,
    );
    _locationRiskCtrl.text = _optionalText(policy.locationRiskDeadlineHours);
    _largeDeviationCtrl.text = _optionalText(
      policy.largeTimeDeviationDeadlineHours,
    );
    _gracePeriodCtrl.text = policy.gracePeriodDays.toString();
    _updatedAt = policy.updatedAt;
    _updatedByName = policy.updatedByName;
  }

  String _optionalText(int? value) {
    return value == null ? '' : value.toString();
  }

  int? _parseRequiredHours(TextEditingController controller, String label) {
    final value = int.tryParse(controller.text.trim());
    if (value == null || value <= 0) {
      _showError('$label phải lớn hơn 0.');
      return null;
    }
    return value;
  }

  int? _parseOptionalHours(TextEditingController controller, String label) {
    final text = controller.text.trim();
    if (text.isEmpty) {
      return null;
    }
    final value = int.tryParse(text);
    if (value == null || value <= 0) {
      _showError('$label phải lớn hơn 0 hoặc để trống.');
      return null;
    }
    return value;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _savePolicy() async {
    final token = _token;
    if (token == null || token.isEmpty || _saving) {
      return;
    }
    final defaultHours = _parseRequiredHours(
      _defaultDeadlineCtrl,
      'Deadline mặc định',
    );
    if (defaultHours == null) {
      return;
    }
    final graceDays = _parseRequiredHours(_gracePeriodCtrl, 'Grace period');
    if (graceDays == null) {
      return;
    }
    final autoClosed = _parseOptionalHours(_autoClosedCtrl, 'Đóng ngoài giờ');
    if (_autoClosedCtrl.text.trim().isNotEmpty && autoClosed == null) {
      return;
    }
    final missedCheckout = _parseOptionalHours(
      _missedCheckoutCtrl,
      'Quên checkout',
    );
    if (_missedCheckoutCtrl.text.trim().isNotEmpty && missedCheckout == null) {
      return;
    }
    final locationRisk = _parseOptionalHours(
      _locationRiskCtrl,
      'Rủi ro vị trí',
    );
    if (_locationRiskCtrl.text.trim().isNotEmpty && locationRisk == null) {
      return;
    }
    final largeDeviation = _parseOptionalHours(
      _largeDeviationCtrl,
      'Lệch giờ lớn',
    );
    if (_largeDeviationCtrl.text.trim().isNotEmpty && largeDeviation == null) {
      return;
    }

    setState(() {
      _saving = true;
    });
    try {
      final policy = await _api.patchExceptionPolicy(
        token: token,
        defaultDeadlineHours: defaultHours,
        autoClosedDeadlineHours: autoClosed,
        missedCheckoutDeadlineHours: missedCheckout,
        locationRiskDeadlineHours: locationRisk,
        largeTimeDeviationDeadlineHours: largeDeviation,
        gracePeriodDays: graceDays,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _applyPolicy(policy);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu chính sách giải trình.')),
      );
    } on UnauthorizedException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phiên đăng nhập đã hết hạn.')),
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể lưu chính sách: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _confirmPurgeExpired() async {
    final token = _token;
    if (token == null || token.isEmpty || _purging) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Xoá hồ sơ hết hạn'),
          content: Text(
            'Hệ thống sẽ xoá vĩnh viễn các ngoại lệ đã quá hạn lưu trữ '
            'theo grace period ${_gracePeriodCtrl.text.trim()} ngày. '
            'Thao tác này không thể hoàn tác.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Huỷ'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: AppColors.bgCard,
              ),
              child: const Text('Xoá hồ sơ'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }

    setState(() {
      _purging = true;
    });
    try {
      final result = await _api.purgeExpiredExceptions(token: token);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đã xoá ${result.deletedCount} hồ sơ hết hạn. '
            'Đã chuyển quá hạn ${result.expiredCount} hồ sơ trước khi xoá.',
          ),
        ),
      );
    } on UnauthorizedException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phiên đăng nhập đã hết hạn.')),
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể xoá hồ sơ hết hạn: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _purging = false;
        });
      }
    }
  }

  String get _updatedText {
    final updatedAt = _updatedAt;
    final by = _updatedByName?.trim();
    if (updatedAt == null) {
      return 'Chưa có thông tin cập nhật.';
    }
    final formatted = DateFormat(
      'dd/MM/yyyy HH:mm',
    ).format(updatedAt.toLocal());
    if (by == null || by.isEmpty) {
      return 'Cập nhật lần cuối: $formatted';
    }
    return 'Cập nhật lần cuối: $formatted';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chính sách giải trình',
                  style: AppTextStyles.headerTitle.copyWith(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Cấu hình hạn xử lý cho ngoại lệ chấm công',
                  style: AppTextStyles.chipText.copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.border),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                const SizedBox(height: 12),
                const _SectionHeader('DEADLINE MẶC ĐỊNH'),
                const SizedBox(height: 8),
                _PolicyFieldRow(
                  label: 'Deadline mặc định',
                  controller: _defaultDeadlineCtrl,
                  suffix: 'giờ',
                  helper: _daysHint(_defaultDeadlineCtrl.text),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                const _SectionHeader('OVERRIDE THEO LOẠI NGOẠI LỆ'),
                const SizedBox(height: 8),
                _PolicyFieldRow(
                  label: 'Auto checkout ngoài giờ',
                  controller: _autoClosedCtrl,
                  suffix: 'giờ',
                  hintText: 'Mặc định',
                ),
                _PolicyFieldRow(
                  label: 'Quên checkout',
                  controller: _missedCheckoutCtrl,
                  suffix: 'giờ',
                  hintText: 'Mặc định',
                ),
                _PolicyFieldRow(
                  label: 'Rủi ro vị trí',
                  controller: _locationRiskCtrl,
                  suffix: 'giờ',
                  hintText: 'Mặc định',
                ),
                _PolicyFieldRow(
                  label: 'Lệch giờ lớn',
                  controller: _largeDeviationCtrl,
                  suffix: 'giờ',
                  hintText: 'Mặc định',
                ),
                const SizedBox(height: 12),
                const _SectionHeader('LƯU TRỮ'),
                const SizedBox(height: 8),
                _PolicyFieldRow(
                  label: 'Thời gian gia hạn',
                  controller: _gracePeriodCtrl,
                  suffix: 'ngày',
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.bgPage,
                    borderRadius: AppRadius.iconBoxAll,
                    border: Border.all(color: AppColors.border, width: 0.5),
                  ),
                  child: Text(
                    'Hồ sơ hết hạn sẽ được giữ đến hết thời gian gia hạn rồi mới đủ điều kiện xoá.',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _updatedText,
                  style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: AppColors.border, width: 0.5),
            ),
          ),
          child: Row(
            children: [
        
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _loading || _saving || _purging
                    ? null
                    : _confirmPurgeExpired,
                icon: _purging
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_outline, size: 16),
                label: const Text('Xoá hồ sơ hết hạn'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger),
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _saving || _loading || _purging ? null : _savePolicy,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.bgCard,
                ),
                child: _saving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.bgCard,
                        ),
                      )
                    : const Text('Lưu cài đặt'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _daysHint(String text) {
    final hours = int.tryParse(text.trim());
    if (hours == null || hours <= 0) {
      return '';
    }
    final days = hours / 24;
    if (days == days.roundToDouble()) {
      return '≈ ${days.toInt()} ngày';
    }
    return '≈ ${days.toStringAsFixed(1)} ngày';
  }
}

class _PolicyFieldRow extends StatelessWidget {
  const _PolicyFieldRow({
    required this.label,
    required this.controller,
    required this.suffix,
    this.helper,
    this.hintText,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String suffix;
  final String? helper;
  final String? hintText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final helperText = helper;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 190,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                label,
                style: AppTextStyles.chipText.copyWith(color: AppColors.textMuted),
              ),
            ),
          ),
          SizedBox(
            width: 140,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                isDense: true,
                hintText: hintText,
                border: const OutlineInputBorder(),
              ),
              onChanged: onChanged,
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              suffix,
              style: AppTextStyles.chipText.copyWith(color: AppColors.textMuted),
            ),
          ),
          if (helperText != null && helperText.isNotEmpty) ...[
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                helperText,
                style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: AppTextStyles.sectionLabel.copyWith(color: AppColors.primary, letterSpacing: 0.08),
        ),
        const SizedBox(width: 8),
        const Expanded(child: Divider(color: AppColors.border, height: 1)),
      ],
    );
  }
}
