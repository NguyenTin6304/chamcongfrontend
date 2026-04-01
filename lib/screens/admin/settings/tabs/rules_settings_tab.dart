import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../../core/config/app_config.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../../core/theme/app_colors.dart';

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

  Future<void> _loadRules() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      return;
    }
    setState(() => _loading = true);
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/rules'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode != 200) {
        throw Exception('load-rules-failed');
      }
      final payload = jsonDecode(utf8.decode(response.bodyBytes));
      final rows = _extractList(payload);
      final merged = _mergeRules(rows);
      if (!mounted) {
        return;
      }
      setState(() => _rules = merged);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Có lỗi xảy ra. Vui lòng thử lại.')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  List<Map<String, dynamic>> _extractList(dynamic payload) {
    if (payload is List) {
      return payload.whereType<Map<String, dynamic>>().toList(growable: false);
    }
    if (payload is Map<String, dynamic>) {
      final data = payload['data'];
      if (data is List) {
        return data.whereType<Map<String, dynamic>>().toList(growable: false);
      }
      final items = payload['items'];
      if (items is List) {
        return items.whereType<Map<String, dynamic>>().toList(growable: false);
      }
    }
    return const [];
  }

  int? _toInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value.toString());
  }

  double? _toDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString());
  }

  bool _toBool(dynamic value, {bool fallback = false}) {
    if (value == null) {
      return fallback;
    }
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    final lower = value.toString().toLowerCase();
    if (lower == 'true' || lower == '1') {
      return true;
    }
    if (lower == 'false' || lower == '0') {
      return false;
    }
    return fallback;
  }

  List<_RuleItem> _mergeRules(List<Map<String, dynamic>> rows) {
    final defaults = _defaultRules();
    final lookup = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final key = (row['code'] ?? row['name'] ?? '').toString().toLowerCase();
      lookup[key] = row;
    }

    return defaults.map((rule) {
      Map<String, dynamic>? source;
      for (final key in lookup.keys) {
        final matched = key.contains(rule.code) || rule.code.contains(key);
        if (matched) {
          source = lookup[key];
          break;
        }
      }
      if (source == null) {
        return rule;
      }
      final fields = Map<String, dynamic>.from(rule.fields);
      fields.addAll(Map<String, dynamic>.from(source['fields'] ?? const {}));

      for (final entry in source.entries) {
        if (fields.containsKey(entry.key)) {
          fields[entry.key] = entry.value;
        }
      }

      return rule.copyWith(
        id: _toInt(source['id']) ?? rule.id,
        isActive: _toBool(source['is_active'] ?? source['active'], fallback: rule.isActive),
        fields: fields,
      );
    }).toList(growable: false);
  }

  Future<void> _patchRule(_RuleItem item, Map<String, dynamic> payload) async {
    final token = _token;
    if (token == null || token.isEmpty || item.id == null) {
      throw Exception('missing-rule-id');
    }
    final response = await http.patch(
      Uri.parse('${AppConfig.apiBaseUrl}/rules/${item.id}'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );
    if (response.statusCode != 200) {
      throw Exception('patch-rule-failed');
    }
  }

  Future<void> _toggleRule(int index, bool active) async {
    final item = _rules[index];
    final previous = item;
    setState(() {
      _rules[index] = item.copyWith(isActive: active, saving: true);
    });
    try {
      await _patchRule(item, {'isActive': active, 'is_active': active});
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _rules[index] = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Có lỗi xảy ra. Vui lòng thử lại.')),
      );
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _rules[index] = _rules[index].copyWith(saving: false);
    });
  }

  Future<void> _saveRule(int index) async {
    final item = _rules[index];
    setState(() {
      _rules[index] = item.copyWith(saving: true);
    });
    try {
      await _patchRule(item, item.fields);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu cài đặt')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Có lỗi xảy ra. Vui lòng thử lại.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _rules[index] = _rules[index].copyWith(saving: false);
        });
      }
    }
  }

  Future<void> _saveAll() async {
    setState(() => _savingAll = true);
    try {
      for (var i = 0; i < _rules.length; i++) {
        await _saveRule(i);
      }
    } finally {
      if (mounted) {
        setState(() => _savingAll = false);
      }
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
        fields: {'min_accuracy_meters': 50},
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
        return _NumberFieldRow(
          label: 'min_accuracy_meters',
          value: item.fields['min_accuracy_meters'],
          onChanged: (v) => onChangedField('min_accuracy_meters', v),
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
