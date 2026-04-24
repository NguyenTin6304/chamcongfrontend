import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../../../core/config/app_config.dart';
import '../../../../../core/storage/token_storage.dart';
import '../../../../../core/theme/app_colors.dart';
import 'package:birdle/core/theme/app_text_styles.dart';

class GeneralSettingsTab extends StatefulWidget {
  const GeneralSettingsTab({super.key});

  @override
  State<GeneralSettingsTab> createState() => _GeneralSettingsTabState();
}

class _GeneralSettingsTabState extends State<GeneralSettingsTab> {
  final _tokenStorage = TokenStorage();
  final _systemNameCtrl = TextEditingController();
  final _lateGraceCtrl = TextEditingController();
  final _autoCheckoutCtrl = TextEditingController();
  final _defaultRadiusCtrl = TextEditingController();
  final _otAfterCtrl = TextEditingController();

  String? _token;
  bool _loading = false;
  bool _saving = false;
  bool _autoCheckoutEnabled = false;
  String _language = 'vi';
  String _timeFormat = '24h';
  String _theme = 'light';
  String _density = 'comfortable';
  String _timeZone = 'Asia/Ho_Chi_Minh';
  int _selectedPrimaryIndex = 0;
  String? _logoUrl;

  // Stored from /rules/active — required when calling PUT /rules/active
  double _ruleLatitude = 0.0;
  double _ruleLongitude = 0.0;
  int _ruleRadiusM = 200;

  static const _timezones = <String>[
    'Asia/Ho_Chi_Minh',
    'Asia/Bangkok',
    'Asia/Jakarta',
    'UTC',
  ];

  static const _primaryOptions = <Color>[
    Color(0xFF1A56DB),
    AppColors.success,
    AppColors.warning,
    AppColors.error,
    Color(0xFF7C3AED),
    Color(0xFF0D9488),
  ];

  @override
  void initState() {
    super.initState();
    _systemNameCtrl.text = 'Chấm công GPIT';
    _lateGraceCtrl.text = '15';
    _autoCheckoutCtrl.text = '18:00';
    _defaultRadiusCtrl.text = '200';
    _otAfterCtrl.text = '60';
    _bootstrap();
  }

  @override
  void dispose() {
    _systemNameCtrl.dispose();
    _lateGraceCtrl.dispose();
    _autoCheckoutCtrl.dispose();
    _defaultRadiusCtrl.dispose();
    _otAfterCtrl.dispose();
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
    await _loadSettings();
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  Future<void> _loadSettings() async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    setState(() => _loading = true);
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/rules/active'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data is Map && mounted) {
          setState(() {
            _ruleLatitude = _toDouble(data['latitude']) ?? _ruleLatitude;
            _ruleLongitude = _toDouble(data['longitude']) ?? _ruleLongitude;
            _ruleRadiusM = _toInt(data['radius_m']) ?? _ruleRadiusM;
            _lateGraceCtrl.text = (_toInt(data['grace_minutes']) ?? 15).toString();
            _defaultRadiusCtrl.text = _ruleRadiusM.toString();
            final endTime = data['end_time']?.toString();
            if (endTime != null && endTime.isNotEmpty) {
              _autoCheckoutCtrl.text = endTime;
            }
            final checkoutGrace = _toInt(data['checkout_grace_minutes']) ?? 0;
            _autoCheckoutEnabled = checkoutGrace > 0;
          });
        }
      }
      // 404 (no active rule yet) or any other status → silently keep defaults
    } on Exception catch (_) {
      // Network error: silently keep defaults, do not show snackbar
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveSettings() async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    setState(() => _saving = true);
    try {
      final graceMinutes = int.tryParse(_lateGraceCtrl.text.trim()) ?? 15;
      final radiusM = int.tryParse(_defaultRadiusCtrl.text.trim()) ?? _ruleRadiusM;
      final body = <String, dynamic>{
        'latitude': _ruleLatitude,
        'longitude': _ruleLongitude,
        'radius_m': radiusM,
        'grace_minutes': graceMinutes,
        if (_autoCheckoutCtrl.text.trim().isNotEmpty)
          'end_time': _autoCheckoutCtrl.text.trim(),
      };
      final response = await http.put(
        Uri.parse('${AppConfig.apiBaseUrl}/rules/active'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      if (response.statusCode != 200) throw Exception('save-failed');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu cài đặt')),
      );
    } on Exception catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Có lỗi xảy ra. Vui lòng thử lại.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _resetDefaults() {
    setState(() {
      _systemNameCtrl.text = 'Chấm công GPIT';
      _lateGraceCtrl.text = '15';
      _autoCheckoutEnabled = false;
      _autoCheckoutCtrl.text = '17:30';
      _defaultRadiusCtrl.text = '200';
      _ruleRadiusM = 200;
      _otAfterCtrl.text = '60';
      _language = 'vi';
      _timeFormat = '24h';
      _theme = 'light';
      _density = 'comfortable';
      _timeZone = _timezones.first;
      _selectedPrimaryIndex = 0;
      _logoUrl = null;
    });
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
                  'Cài đặt chung',
                  style: AppTextStyles.headerTitle.copyWith(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Cấu hình thông tin cơ bản',
                  style: AppTextStyles.chipText.copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 12),
                const _SectionHeader('THÔNG TIN HỆ THỐNG'),
                const SizedBox(height: 8),
                _SettingRow(
                  label: 'Tên hệ thống',
                  input: TextFormField(
                    controller: _systemNameCtrl,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                _SettingRow(
                  label: 'Logo hệ thống',
                  input: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DottedBorderBox(
                        child: Row(
                          children: [
                            const Icon(Icons.upload_outlined, size: 18),
                            const SizedBox(width: 8),
                            const Text('Tải logo hệ thống'),
                            const Spacer(),
                            TextButton(
                              onPressed: () {},
                              child: const Text('Chọn tệp'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _logoUrl == null || _logoUrl!.isEmpty
                            ? 'Chưa có logo'
                            : 'Đã có logo',
                        style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                _SettingRow(
                  label: 'Múi giờ',
                  input: DropdownButtonFormField<String>(
                    initialValue: _timeZone,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: _timezones
                        .map(
                          (timezone) => DropdownMenuItem<String>(
                            value: timezone,
                            child: Text(timezone),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() => _timeZone = value);
                    },
                  ),
                ),
                _SettingRow(
                  label: 'Ngôn ngữ',
                  input: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'vi', label: Text('Tiếng Việt')),
                      ButtonSegment(value: 'en', label: Text('English')),
                    ],
                    selected: {_language},
                    onSelectionChanged: (values) {
                      setState(() => _language = values.first);
                    },
                  ),
                ),
                _SettingRow(
                  label: 'Định dạng giờ',
                  input: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: '24h', label: Text('24h')),
                      ButtonSegment(value: '12h', label: Text('12h')),
                    ],
                    selected: {_timeFormat},
                    onSelectionChanged: (values) {
                      setState(() => _timeFormat = values.first);
                    },
                  ),
                ),
                const SizedBox(height: 12),
                const _SectionHeader('QUY TẮC ĐIỂM DANH'),
                const SizedBox(height: 8),
                _SettingRow(
                  label: 'Thời gian ân hạn đi trễ',
                  input: Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: TextFormField(
                          controller: _lateGraceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('phút'),
                    ],
                  ),
                ),
                _SettingRow(
                  label: 'Tự động checkout',
                  input: Row(
                    children: [
                      Switch(
                        value: _autoCheckoutEnabled,
                        onChanged: (value) {
                          setState(() => _autoCheckoutEnabled = value);
                        },
                      ),
                      const SizedBox(width: 8),
                      AnimatedOpacity(
                        opacity: _autoCheckoutEnabled ? 1 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: SizedBox(
                          width: 120,
                          child: TextFormField(
                            controller: _autoCheckoutCtrl,
                            enabled: _autoCheckoutEnabled,
                            decoration: const InputDecoration(
                              isDense: true,
                              hintText: 'HH:mm',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _SettingRow(
                  label: 'Bán kính mặc định',
                  input: Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: TextFormField(
                          controller: _defaultRadiusCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('mét (GPS Radius)'),
                    ],
                  ),
                ),
                _SettingRow(
                  label: 'Tính tăng ca sau',
                  input: Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: TextFormField(
                          controller: _otAfterCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('phút làm việc thêm'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const _SectionHeader('GIAO DIỆN'),
                const SizedBox(height: 8),
                _SettingRow(
                  label: 'Màu chủ đạo',
                  input: Row(
                    children: List.generate(_primaryOptions.length, (index) {
                      final selected = _selectedPrimaryIndex == index;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedPrimaryIndex = index),
                        child: Container(
                          width: 28,
                          height: 28,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            color: _primaryOptions[index],
                            shape: BoxShape.circle,
                            border: selected
                                ? Border.all(
                                    color: AppColors.textPrimary,
                                    width: 2,
                                  )
                                : null,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                _SettingRow(
                  label: 'Chủ đề',
                  input: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'light', label: Text('Sáng')),
                      ButtonSegment(value: 'dark', label: Text('Tối')),
                      ButtonSegment(value: 'auto', label: Text('Tự động')),
                    ],
                    selected: {_theme},
                    onSelectionChanged: (values) {
                      setState(() => _theme = values.first);
                    },
                  ),
                ),
                _SettingRow(
                  label: 'Mật độ hiển thị',
                  input: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'comfortable',
                        label: Text('Thoải mái'),
                      ),
                      ButtonSegment(value: 'normal', label: Text('Vừa')),
                      ButtonSegment(value: 'compact', label: Text('Gọn')),
                    ],
                    selected: {_density},
                    onSelectionChanged: (values) {
                      setState(() => _density = values.first);
                    },
                  ),
                ),
                if (_loading)
                  Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: LinearProgressIndicator(minHeight: 2),
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
              TextButton(
                onPressed: _resetDefaults,
                child: const Text('Đặt lại mặc định'),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _saving ? null : _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.surface,
                ),
                child: _saving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.surface,
                        ),
                      )
                    : const Text('Lưu thay đổi'),
              ),
            ],
          ),
        ),
      ],
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

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.label, required this.input});

  final String label;
  final Widget input;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(width: 2),
              SizedBox(
                width: 200,
                child: Text(
                  label,
                  style: AppTextStyles.chipText.copyWith(color: AppColors.textMuted),
                ),
              ),
              Expanded(child: input),
            ],
          ),
        ),
        Divider(color: AppColors.border.withValues(alpha: 0.5), height: 1),
      ],
    );
  }
}

class _DottedBorderBox extends StatelessWidget {
  const _DottedBorderBox({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DottedPainter(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: child,
      ),
    );
  }
}

class _DottedPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const dashWidth = 4.0;
    const dashSpace = 3.0;
    final paint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(8),
        ),
      );
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
