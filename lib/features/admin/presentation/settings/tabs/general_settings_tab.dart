import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:birdle/core/config/app_config.dart';
import 'package:birdle/core/storage/token_storage.dart';
import 'package:birdle/core/theme/app_colors.dart';
import 'package:birdle/core/theme/app_dimensions.dart';
import 'package:birdle/core/theme/app_text_styles.dart';

class GeneralSettingsTab extends StatefulWidget {
  const GeneralSettingsTab({super.key});

  @override
  State<GeneralSettingsTab> createState() => _GeneralSettingsTabState();
}

class _GeneralSettingsTabState extends State<GeneralSettingsTab> {
  final _tokenStorage = TokenStorage();

  String? _token;
  int _holidayYear = DateTime.now().year;
  List<Map<String, dynamic>> _holidays = [];
  bool _holidaysLoading = false;
  bool _holidayAdding = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final token = await _tokenStorage.getToken();
    if (!mounted) return;
    setState(() => _token = token);
    await _loadHolidays();
  }

  Future<void> _loadHolidays() async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    setState(() => _holidaysLoading = true);
    try {
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/rules/public-holidays')
          .replace(queryParameters: {'year': _holidayYear.toString()});
      final res = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
      if (res.statusCode == 200 && mounted) {
        final list = jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
        setState(() => _holidays = list.cast<Map<String, dynamic>>());
      }
    } on Exception catch (_) {
      // silent — list stays empty
    } finally {
      if (mounted) setState(() => _holidaysLoading = false);
    }
  }

  Future<void> _deleteHoliday(int id) async {
    final token = _token;
    if (token == null) return;
    try {
      final res = await http.delete(
        Uri.parse('${AppConfig.apiBaseUrl}/rules/public-holidays/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 204 && mounted) {
        setState(() => _holidays.removeWhere((h) => h['id'] == id));
      }
    } on Exception catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể xoá ngày lễ')),
        );
      }
    }
  }

  Future<void> _showAddHolidayDialog() async {
    DateTime? pickedDate;
    final nameCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Thêm ngày lễ'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  pickedDate == null
                      ? 'Chọn ngày'
                      : '${pickedDate!.day.toString().padLeft(2, '0')}/${pickedDate!.month.toString().padLeft(2, '0')}/${pickedDate!.year}',
                  style: AppTextStyles.body,
                ),
                trailing: const Icon(Icons.calendar_today_outlined, size: 18),
                onTap: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime(_holidayYear),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030, 12, 31),
                  );
                  if (d != null) setDlgState(() => pickedDate = d);
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tên ngày lễ',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Huỷ'),
            ),
            ElevatedButton(
              onPressed: _holidayAdding
                  ? null
                  : () async {
                      final d = pickedDate;
                      final name = nameCtrl.text.trim();
                      if (d == null || name.isEmpty) return;
                      final token = _token;
                      if (token == null) return;
                      final messenger = ScaffoldMessenger.of(context);
                      setState(() => _holidayAdding = true);
                      try {
                        final iso =
                            '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                        final res = await http.post(
                          Uri.parse(
                            '${AppConfig.apiBaseUrl}/rules/public-holidays',
                          ),
                          headers: {
                            'Authorization': 'Bearer $token',
                            'Content-Type': 'application/json',
                          },
                          body: jsonEncode({'date': iso, 'name': name}),
                        );
                        if (res.statusCode == 201) {
                          final created =
                              jsonDecode(utf8.decode(res.bodyBytes))
                                  as Map<String, dynamic>;
                          if (mounted) {
                            setState(
                              () => _holidays
                                ..add(created)
                                ..sort(
                                  (a, b) => (a['date'] as String).compareTo(
                                    b['date'] as String,
                                  ),
                                ),
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                          }
                        } else if (res.statusCode == 409) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Ngày lễ đã tồn tại'),
                            ),
                          );
                        }
                      } on Exception catch (_) {
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Có lỗi xảy ra')),
                        );
                      } finally {
                        if (mounted) setState(() => _holidayAdding = false);
                      }
                    },
              child: const Text('Thêm'),
            ),
          ],
        ),
      ),
    );
    nameCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cài đặt chung',
            style: AppTextStyles.headerTitle.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Quản lý ngày lễ toàn hệ thống',
            style: AppTextStyles.chipText.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
        
          _HolidaySection(
            year: _holidayYear,
            holidays: _holidays,
            loading: _holidaysLoading,
            onYearChanged: (int y) {
              setState(() {
                _holidayYear = y;
                _holidays = [];
              });
              _loadHolidays();
            },
            onAdd: _showAddHolidayDialog,
            onDelete: _deleteHoliday,
          ),
        ],
      ),
    );
  }
}

class _HolidaySection extends StatelessWidget {
  const _HolidaySection({
    required this.year,
    required this.holidays,
    required this.loading,
    required this.onYearChanged,
    required this.onAdd,
    required this.onDelete,
  });

  final int year;
  final List<Map<String, dynamic>> holidays;
  final bool loading;
  final void Function(int) onYearChanged;
  final VoidCallback onAdd;
  final void Function(int) onDelete;

  String _formatDate(String iso) {
    final parts = iso.split('-');
    if (parts.length != 3) return iso;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'NGÀY LỄ',
              style: AppTextStyles.sectionLabel.copyWith(
                color: AppColors.primary,
                letterSpacing: 0.08,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Expanded(child: Divider(color: AppColors.border, height: 1)),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            IconButton(
              onPressed: () => onYearChanged(year - 1),
              icon: const Icon(Icons.chevron_left, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            Text(
              '$year',
              style: AppTextStyles.bodyBold.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            IconButton(
              onPressed: () => onYearChanged(year + 1),
              icon: const Icon(Icons.chevron_right, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Thêm ngày lễ'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ],
        ),
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: LinearProgressIndicator(minHeight: 2),
          )
        else if (holidays.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Text(
              'Chưa có ngày lễ nào trong năm $year',
              style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: holidays.length,
            separatorBuilder: (_, _) =>
                Divider(color: AppColors.border.withValues(alpha: 0.5), height: 1),
            itemBuilder: (_, i) {
              final h = holidays[i];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: AppRadius.smallAll,
                      ),
                      child: Text(
                        _formatDate(h['date'] as String),
                        style: AppTextStyles.captionBold.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        h['name'] as String,
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => onDelete(h['id'] as int),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      color: AppColors.error,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        Divider(color: AppColors.border.withValues(alpha: 0.5), height: 1),
      ],
    );
  }
}
