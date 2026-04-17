import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../../../core/config/app_config.dart';
import '../../../../../core/storage/token_storage.dart';
import '../../../../../core/theme/app_colors.dart';

class RulesSettingsTab extends StatefulWidget {
  const RulesSettingsTab({super.key});

  @override
  State<RulesSettingsTab> createState() => _RulesSettingsTabState();
}

class _RulesSettingsTabState extends State<RulesSettingsTab> {
  final _tokenStorage = TokenStorage();

  String? _token;
  bool _loading = false;
  bool _savingAll = false;
  List<_RuleItem> _rules = _defaultRules();

  // Full active-rule fields — required as base when calling PUT /rules/active
  double _ruleLatitude = 0.0;
  double _ruleLongitude = 0.0;
  int _ruleRadiusM = 200;
  String? _ruleStartTime;
  String? _ruleEndTime;
  int? _ruleCheckoutGrace;
  int? _ruleCrossDayCutoff;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final token = await _tokenStorage.getToken();
    if (!mounted) {
      return;
    }
    setState(() => _token = token);
    await _loadRules();
  }

  int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  Future<void> _loadRules() async {
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
        if (data is Map<String, dynamic> && mounted) {
          setState(() {
            _ruleLatitude = _toDouble(data['latitude']) ?? _ruleLatitude;
            _ruleLongitude = _toDouble(data['longitude']) ?? _ruleLongitude;
            _ruleRadiusM = _toInt(data['radius_m']) ?? _ruleRadiusM;
            _ruleStartTime = data['start_time']?.toString();
            _ruleEndTime = data['end_time']?.toString();
            _ruleCheckoutGrace = _toInt(data['checkout_grace_minutes']);
            _ruleCrossDayCutoff = _toInt(data['cross_day_cutoff_minutes']);
            _rules = _applyActiveRule(data);
          });
        }
      }
      // 404 (no active rule yet) → keep UI defaults silently
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Có lỗi xảy ra. Vui lòng thử lại.')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_RuleItem> _applyActiveRule(Map<String, dynamic> data) {
    return _defaultRules().map((rule) {
      switch (rule.code) {
        case 'late':
          final grace = _toInt(data['grace_minutes']);
          if (grace == null) return rule;
          return rule.copyWith(fields: {...rule.fields, 'grace_minutes': grace});
        case 'auto_checkout':
          final endTime = data['end_time']?.toString();
          final checkoutGrace = _toInt(data['checkout_grace_minutes']) ?? 0;
          final fields = Map<String, dynamic>.from(rule.fields);
          if (endTime != null) fields['auto_checkout_time'] = endTime;
          fields['checkout_grace_minutes'] = checkoutGrace;
          return rule.copyWith(isActive: checkoutGrace > 0, fields: fields);
        case 'gps':
          final radius = _toInt(data['radius_m']);
          final lat = _toDouble(data['latitude']);
          final lng = _toDouble(data['longitude']);
          final fields = Map<String, dynamic>.from(rule.fields);
          if (radius != null) fields['min_accuracy_meters'] = radius;
          if (lat != null) fields['latitude'] = lat;
          if (lng != null) fields['longitude'] = lng;
          return rule.copyWith(fields: fields);
        default:
          return rule;
      }
    }).toList(growable: false);
  }

  Future<void> _putActiveRule(Map<String, dynamic> extra) async {
    final token = _token;
    if (token == null || token.isEmpty) throw Exception('no-token');
    final body = <String, dynamic>{
      'latitude': _ruleLatitude,
      'longitude': _ruleLongitude,
      'radius_m': _ruleRadiusM,
      if (_ruleStartTime != null) 'start_time': _ruleStartTime,
      if (_ruleEndTime != null) 'end_time': _ruleEndTime,
      if (_ruleCheckoutGrace != null) 'checkout_grace_minutes': _ruleCheckoutGrace,
      if (_ruleCrossDayCutoff != null) 'cross_day_cutoff_minutes': _ruleCrossDayCutoff,
      ...extra,
    };
    final response = await http.put(
      Uri.parse('${AppConfig.apiBaseUrl}/rules/active'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) throw Exception('put-rule-failed');
  }

  Future<void> _toggleRule(int index, bool active) async {
    final previous = _rules[index];
    setState(() {
      _rules[index] = previous.copyWith(isActive: active, saving: true);
    });
    try {
      // Only 'late' rule maps to a backend field (grace_minutes = 0 means disabled)
      if (previous.code == 'late') {
        final grace = active ? (_toInt(previous.fields['grace_minutes']) ?? 15) : 0;
        await _putActiveRule({'grace_minutes': grace});
      }
      // Other rule cards are UI-only — no backend per-rule toggle
    } catch (_) {
      if (!mounted) return;
      setState(() => _rules[index] = previous); // revert
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Có lỗi xảy ra. Vui lòng thử lại.')),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      _rules[index] = _rules[index].copyWith(saving: false);
    });
  }

  Future<void> _saveRule(int index) async {
    final item = _rules[index];
    setState(() => _rules[index] = item.copyWith(saving: true));
    try {
      final extra = <String, dynamic>{};
      switch (item.code) {
        case 'late':
          final grace = _toInt(item.fields['grace_minutes']);
          if (grace != null) extra['grace_minutes'] = grace;
        case 'gps':
          final radius = _toInt(item.fields['min_accuracy_meters']);
          if (radius != null) extra['radius_m'] = radius;
          final lat = _toDouble(item.fields['latitude']);
          if (lat != null) extra['latitude'] = lat;
          final lng = _toDouble(item.fields['longitude']);
          if (lng != null) extra['longitude'] = lng;
        default:
          break;
      }
      if (extra.isNotEmpty) await _putActiveRule(extra);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu cài đặt')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Có lỗi xảy ra. Vui lòng thử lại.')),
      );
    } finally {
      if (mounted) setState(() => _rules[index] = _rules[index].copyWith(saving: false));
    }
  }

  Future<void> _saveAll() async {
    setState(() => _savingAll = true);
    try {
      final extra = <String, dynamic>{};
      for (final rule in _rules) {
        switch (rule.code) {
          case 'late':
            final grace = _toInt(rule.fields['grace_minutes']);
            if (grace != null) extra['grace_minutes'] = grace;
          case 'gps':
            final radius = _toInt(rule.fields['min_accuracy_meters']);
            if (radius != null) extra['radius_m'] = radius;
            final lat = _toDouble(rule.fields['latitude']); 
            if (lat != null) extra['latitude'] = lat;
            final lng = _toDouble(rule.fields['longitude']);
            if (lng != null) extra['longitude'] = lng;
          default:
            break;
        }
      }
      if (extra.isNotEmpty) await _putActiveRule(extra);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu cài đặt')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Có lỗi xảy ra. Vui lòng thử lại.')),
      );
    } finally {
      if (mounted) setState(() => _savingAll = false);
    }
  }

  void _resetDefaults() {
    setState(() {
      _rules = _defaultRules();
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
                const Text(
                  'Quy tắc chấm công',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Cấu hình áp dụng toàn hệ thống',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 12),
                if (_loading)
                  const LinearProgressIndicator(minHeight: 2)
                else
                  ..._rules.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return _RuleCard(
                      item: item,
                      onTapExpand: () {
                        setState(() {
                          _rules[index] = item.copyWith(expanded: !item.expanded);
                        });
                      },
                      onToggle: (value) => _toggleRule(index, value),
                      onChangedField: (key, value) {
                        final fields = Map<String, dynamic>.from(item.fields)
                          ..[key] = value;
                        setState(() {
                          _rules[index] = item.copyWith(fields: fields);
                        });
                      },
                      onSave: () => _saveRule(index),
                    );
                  }),
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
                onPressed: _savingAll ? null : _saveAll,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: _savingAll
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
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

  static List<_RuleItem> _defaultRules() {
    return const [
      _RuleItem(
        id: null,
        code: 'late',
        name: 'Quy tắc đi trễ',
        icon: Icons.warning_amber_rounded,
        iconBg: Color(0xFFFEF3C7),
        iconFg: AppColors.warning,
        isActive: true,
        fields: {'grace_minutes': 15},
      ),
      _RuleItem(
        id: null,
        code: 'auto_checkout',
        name: 'Tự động checkout',
        icon: Icons.schedule_outlined,
        iconBg: Color(0xFFEFF6FF),
        iconFg: AppColors.primary,
        isActive: true,
        fields: {'auto_checkout_time': '18:00'},
      ),
      _RuleItem(
        id: null,
        code: 'gps',
        name: 'Xác thực vị trí GPS',
        icon: Icons.my_location_outlined,
        iconBg: Color(0xFFEFF6FF),
        iconFg: AppColors.primary,
        isActive: true,
        fields: {'latitude': 0.0, 'longitude': 0.0, 'min_accuracy_meters': 200},
      ),
      _RuleItem(
        id: null,
        code: 'overtime',
        name: 'Tính giờ tăng ca',
        icon: Icons.bolt_outlined,
        iconBg: Color(0xFFEDE9FE),
        iconFg: AppColors.overtime,
        isActive: true,
        fields: {'ot_after_minutes': 60, 'ot_multiplier': 1.5},
      ),
      _RuleItem(
        id: null,
        code: 'auto_exception',
        name: 'Tạo ngoại lệ tự động',
        icon: Icons.error_outline,
        iconBg: Color(0xFFFEE2E2),
        iconFg: AppColors.danger,
        isActive: true,
        fields: {
          'trigger_conditions': {
            'missing_checkin': true,
            'missing_checkout': true,
            'out_of_range': true,
          },
        },
      ),
    ];
  }
}

class _RuleCard extends StatelessWidget {
  const _RuleCard({
    required this.item,
    required this.onTapExpand,
    required this.onToggle,
    required this.onChangedField,
    required this.onSave,
  });

  final _RuleItem item;
  final VoidCallback onTapExpand;
  final ValueChanged<bool> onToggle;
  final void Function(String key, dynamic value) onChangedField;
  final VoidCallback onSave;

  String _summary() {
    final map = item.fields;
    switch (item.code) {
      case 'late':
        return 'Ân hạn: ${map['grace_minutes'] ?? '--'} phút';
      case 'auto_checkout':
        return 'Giờ checkout: ${map['auto_checkout_time'] ?? '--'}';
      case 'gps':
        return 'Độ chính xác tối thiểu: ${map['min_accuracy_meters'] ?? '--'}m';
      case 'overtime':
        return 'Sau ${map['ot_after_minutes'] ?? '--'} phút, hệ số ${map['ot_multiplier'] ?? '--'}';
      case 'auto_exception':
        return 'Kích hoạt điều kiện tự động';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        border: Border.all(color: AppColors.border, width: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onTapExpand,
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: item.iconBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(item.icon, color: item.iconFg, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        _summary(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: item.isActive,
                  onChanged: item.saving ? null : onToggle,
                ),
              ],
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: item.expanded ? null : 0,
            curve: Curves.easeOut,
            child: item.expanded
                ? Column(
                    children: [
                      const Divider(color: AppColors.border, height: 18),
                      _buildFields(),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          onPressed: item.saving ? null : onSave,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                          child: item.saving
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Lưu'),
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildFields() {
    switch (item.code) {
      case 'late':
        return _NumberFieldRow(
          label: 'grace_minutes',
          value: item.fields['grace_minutes'],
          onChanged: (v) => onChangedField('grace_minutes', v),
        );
      case 'auto_checkout':
        return _TextFieldRow(
          label: 'auto_checkout_time',
          value: item.fields['auto_checkout_time']?.toString() ?? '',
          onChanged: (v) => onChangedField('auto_checkout_time', v),
        );
      case 'gps':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tọa độ SYSTEM RULE',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 6),
            _DoubleFieldRow(
              label: 'Vĩ độ (latitude)',
              value: item.fields['latitude'] ?? 0.0,
              onChanged: (v) => onChangedField('latitude', v),
            ),
            const SizedBox(height: 8),
            _DoubleFieldRow(
              label: 'Kinh độ (longitude)',
              value: item.fields['longitude'] ?? 0.0,
              onChanged: (v) => onChangedField('longitude', v),
            ),
            const SizedBox(height: 8),
            _NumberFieldRow(
              label: 'Bán kính (m)',
              value: item.fields['min_accuracy_meters'],
              onChanged: (v) => onChangedField('min_accuracy_meters', v),
            ),
          ],
        );
      case 'overtime':
        return Column(
          children: [
            _NumberFieldRow(
              label: 'ot_after_minutes',
              value: item.fields['ot_after_minutes'],
              onChanged: (v) => onChangedField('ot_after_minutes', v),
            ),
            const SizedBox(height: 8),
            _DoubleFieldRow(
              label: 'ot_multiplier',
              value: item.fields['ot_multiplier'],
              onChanged: (v) => onChangedField('ot_multiplier', v),
            ),
          ],
        );
      case 'auto_exception':
        final map =
            Map<String, dynamic>.from(item.fields['trigger_conditions'] ?? {});
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ConditionChip(
              label: 'Thiếu checkin',
              value: map['missing_checkin'] == true,
              onChanged: (v) {
                final next = Map<String, dynamic>.from(map)
                  ..['missing_checkin'] = v;
                onChangedField('trigger_conditions', next);
              },
            ),
            _ConditionChip(
              label: 'Thiếu checkout',
              value: map['missing_checkout'] == true,
              onChanged: (v) {
                final next = Map<String, dynamic>.from(map)
                  ..['missing_checkout'] = v;
                onChangedField('trigger_conditions', next);
              },
            ),
            _ConditionChip(
              label: 'Ngoài vùng',
              value: map['out_of_range'] == true,
              onChanged: (v) {
                final next = Map<String, dynamic>.from(map)
                  ..['out_of_range'] = v;
                onChangedField('trigger_conditions', next);
              },
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _NumberFieldRow extends StatefulWidget {
  const _NumberFieldRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final dynamic value;
  final ValueChanged<int?> onChanged;

  @override
  State<_NumberFieldRow> createState() => _NumberFieldRowState();
}

class _NumberFieldRowState extends State<_NumberFieldRow> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: '${widget.value ?? ''}');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _ctrl,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        isDense: true,
        labelText: widget.label,
        border: const OutlineInputBorder(),
      ),
      onChanged: (v) => widget.onChanged(int.tryParse(v.trim())),
    );
  }
}

class _DoubleFieldRow extends StatefulWidget {
  const _DoubleFieldRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final dynamic value;
  final ValueChanged<double?> onChanged;

  @override
  State<_DoubleFieldRow> createState() => _DoubleFieldRowState();
}

class _DoubleFieldRowState extends State<_DoubleFieldRow> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: '${widget.value ?? ''}');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        isDense: true,
        labelText: widget.label,
        border: const OutlineInputBorder(),
      ),
      onChanged: (v) => widget.onChanged(double.tryParse(v.trim())),
    );
  }
}

class _TextFieldRow extends StatefulWidget {
  const _TextFieldRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_TextFieldRow> createState() => _TextFieldRowState();
}

class _TextFieldRowState extends State<_TextFieldRow> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _ctrl,
      decoration: InputDecoration(
        isDense: true,
        labelText: widget.label,
        border: const OutlineInputBorder(),
      ),
      onChanged: widget.onChanged,
    );
  }
}

class _ConditionChip extends StatelessWidget {
  const _ConditionChip({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: value,
      label: Text(label),
      selectedColor: AppColors.primary.withValues(alpha: 0.14),
      checkmarkColor: AppColors.primary,
      onSelected: onChanged,
    );
  }
}

class _RuleItem {
  const _RuleItem({
    required this.id,
    required this.code,
    required this.name,
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.isActive,
    required this.fields,
    this.expanded = false,
    this.saving = false,
  });

  final int? id;
  final String code;
  final String name;
  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final bool isActive;
  final Map<String, dynamic> fields;
  final bool expanded;
  final bool saving;

  _RuleItem copyWith({
    int? id,
    bool? isActive,
    Map<String, dynamic>? fields,
    bool? expanded,
    bool? saving,
  }) {
    return _RuleItem(
      id: id ?? this.id,
      code: code,
      name: name,
      icon: icon,
      iconBg: iconBg,
      iconFg: iconFg,
      isActive: isActive ?? this.isActive,
      fields: fields ?? this.fields,
      expanded: expanded ?? this.expanded,
      saving: saving ?? this.saving,
    );
  }
}
