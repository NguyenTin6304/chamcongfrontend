import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../../core/config/app_config.dart';
import '../../../core/download/file_downloader.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../../features/admin/data/admin_api.dart';
import '../../../widgets/common/kpi_card.dart';
import 'widgets/exception_history_table.dart';
import 'widgets/pending_exception_card.dart';

class ExceptionsScreen extends StatefulWidget {
  const ExceptionsScreen({super.key});

  @override
  State<ExceptionsScreen> createState() => _ExceptionsScreenState();
}

class _ExceptionsScreenState extends State<ExceptionsScreen> {
  final _tokenStorage = TokenStorage();
  final _api = const AdminApi();
  final _searchController = TextEditingController();

  String? _token;
  bool _loading = false;
  bool _exporting = false;

  String _selectedTab = 'all';
  DateRange _dateRange = DateRange(from: DateTime.now(), to: DateTime.now());
  int? _selectedGroupId;
  String _selectedExceptionType = 'all';

  final Set<int> _actioningIds = {};
  List<GroupLite> _groups = const [];
  List<ExceptionModel> _pendingItems = const [];

  int _pendingCount = 0;
  int _todayCount = 0;
  int _approvedCount = 0;
  int _rejectedCount = 0;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _searchController.dispose();
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
    await _refreshData();
  }

  Future<void> _refreshData() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      return;
    }
    setState(() {
      _loading = true;
    });
    try {
      final results = await Future.wait<dynamic>([
        _api.listGroups(token, activeOnly: false),
        _fetchPendingExceptions(token: token),
        _fetchStats(token: token),
      ]);
      if (!mounted) {
        return;
      }
      final groups = results[0] as List<GroupLite>;
      final pending = results[1] as List<ExceptionModel>;
      final stats = results[2] as Map<String, int>;
      setState(() {
        _groups = groups;
        _pendingItems = pending;
        _pendingCount = stats['pending'] ?? pending.length;
        _todayCount = stats['today'] ?? 0;
        _approvedCount = stats['approved'] ?? 0;
        _rejectedCount = stats['rejected'] ?? 0;
      });
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
          _loading = false;
        });
      }
    }
  }

  Future<List<ExceptionModel>> _fetchPendingExceptions({
    required String token,
  }) async {
    final query = <String, String>{'status': 'pending'};
    if (_selectedGroupId != null) {
      query['group_id'] = _selectedGroupId.toString();
    }
    if (_searchController.text.trim().isNotEmpty) {
      query['q'] = _searchController.text.trim();
    }
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/attendance/exceptions',
    ).replace(queryParameters: query);

    try {
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode != 200) {
        throw Exception('pending-fetch-failed');
      }
      final payload = jsonDecode(utf8.decode(response.bodyBytes));
      final rows = _extractList(payload);
      return rows.map(_mapExceptionModel).toList(growable: false);
    } catch (_) {
      final fallback = await _api.listDashboardExceptions(
        token: token,
        status: 'pending',
      );
      return fallback
          .map(
            (item) => ExceptionModel(
              id: item.id,
              employeeName: item.name,
              employeeCode: '--',
              departmentName: '--',
              exceptionType: item.reason,
              status: item.status,
              workDate: DateTime.now(),
              checkInTime: '--',
              checkOutTime: '--',
              locationLabel: '--',
              reason: item.reason,
              reviewerName: '--',
              createdAt: DateTime.now(),
            ),
          )
          .toList(growable: false);
    }
  }

  Future<Map<String, int>> _fetchStats({required String token}) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/attendance/exceptions/stats');
    try {
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode != 200) {
        throw Exception('stats-fetch-failed');
      }
      final payload = jsonDecode(utf8.decode(response.bodyBytes));
      final map = _extractMap(payload);
      return {
        'pending': _toInt(
              map['pending'] ?? map['pending_count'] ?? map['open_count'],
            ) ??
            0,
        'today': _toInt(map['today'] ?? map['today_count']) ?? 0,
        'approved': _toInt(
              map['approved'] ??
                  map['approved_count'] ??
                  map['resolved_count'],
            ) ??
            0,
        'rejected': _toInt(
              map['rejected'] ?? map['rejected_count'] ?? map['deny_count'],
            ) ??
            0,
      };
    } catch (_) {
      final history = await _api.listAttendanceExceptions(
        token: token,
        fromDate: _dateRange.from,
        toDate: _dateRange.to,
        groupId: _selectedGroupId,
        exceptionType: 'MISSED_CHECKOUT',
      );
      var pending = 0;
      var approved = 0;
      var rejected = 0;
      var today = 0;
      final now = DateTime.now();
      for (final item in history) {
        final status = item.status.toLowerCase();
        if (status.contains('open') || status.contains('pending')) {
          pending += 1;
        } else if (status.contains('reject')) {
          rejected += 1;
        } else {
          approved += 1;
        }
        final date = item.workDate;
        if (date.year == now.year &&
            date.month == now.month &&
            date.day == now.day) {
          today += 1;
        }
      }
      return {
        'pending': pending,
        'today': today,
        'approved': approved,
        'rejected': rejected,
      };
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

  Map<String, dynamic> _extractMap(dynamic payload) {
    if (payload is Map<String, dynamic>) {
      final data = payload['data'];
      if (data is Map<String, dynamic>) {
        return data;
      }
      return payload;
    }
    return <String, dynamic>{};
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

  String _toTime(dynamic value) {
    if (value == null) {
      return '--';
    }
    final raw = value.toString().trim();
    if (raw.isEmpty) {
      return '--';
    }
    if (RegExp(r'^\d{2}:\d{2}$').hasMatch(raw)) {
      return raw;
    }
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return raw;
    }
    return DateFormat('HH:mm').format(parsed.toLocal());
  }

  DateTime? _toDate(dynamic value) {
    if (value == null) {
      return null;
    }
    return DateTime.tryParse(value.toString());
  }

  ExceptionModel _mapExceptionModel(Map<String, dynamic> row) {
    final fullName =
        row['name'] as String? ??
        row['employee_name'] as String? ??
        row['full_name'] as String? ??
        '--';
    final code = row['employee_code'] as String? ?? '--';
    final department =
        row['department_name'] as String? ??
        row['group_name'] as String? ??
        '--';
    final type =
        row['exception_type'] as String? ?? row['type'] as String? ?? '--';
    return ExceptionModel(
      id: _toInt(row['id']) ?? 0,
      employeeName: fullName,
      employeeCode: code,
      departmentName: department,
      exceptionType: type,
      status: (row['status'] as String? ?? 'pending').toLowerCase(),
      workDate: _toDate(row['work_date'] ?? row['date']),
      checkInTime: _toTime(row['check_in'] ?? row['check_in_time']),
      checkOutTime: _toTime(row['check_out'] ?? row['check_out_time']),
      locationLabel:
          row['location'] as String? ??
          row['location_status'] as String? ??
          '--',
      reason: row['reason'] as String? ?? type,
      reviewerName:
          row['reviewer_name'] as String? ??
          row['resolved_by_email'] as String? ??
          '--',
      createdAt: _toDate(row['created_at'] ?? row['time']),
    );
  }

  Future<void> _approve(ExceptionModel item) async {
    await _handleAction(item: item, approve: true);
  }

  Future<void> _reject(ExceptionModel item) async {
    await _handleAction(item: item, approve: false);
  }

  Future<void> _handleAction({
    required ExceptionModel item,
    required bool approve,
  }) async {
    final token = _token;
    if (token == null || token.isEmpty || _actioningIds.contains(item.id)) {
      return;
    }
    final previous = _pendingItems;
    setState(() {
      _actioningIds.add(item.id);
      _pendingItems = _pendingItems.where((e) => e.id != item.id).toList();
      _pendingCount = (_pendingCount - 1).clamp(0, 1 << 30);
      if (approve) {
        _approvedCount += 1;
      } else {
        _rejectedCount += 1;
      }
    });
    try {
      if (approve) {
        await _api.approveDashboardException(token: token, exceptionId: item.id);
      } else {
        await _api.rejectDashboardException(token: token, exceptionId: item.id);
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _pendingItems = previous;
        _pendingCount += 1;
        if (approve) {
          _approvedCount = (_approvedCount - 1).clamp(0, 1 << 30);
        } else {
          _rejectedCount = (_rejectedCount - 1).clamp(0, 1 << 30);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Có lỗi xảy ra. Vui lòng thử lại.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _actioningIds.remove(item.id);
        });
      }
    }
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(
        start: _dateRange.from,
        end: _dateRange.to,
      ),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _dateRange = DateRange(from: picked.start, to: picked.end);
    });
    await _refreshData();
  }

  Future<void> _exportExcel() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      return;
    }
    setState(() {
      _exporting = true;
    });
    try {
      final report = await _api.exportDashboardExcel(
        token: token,
        fromDate: _dateRange.from,
        toDate: _dateRange.to,
        groupId: _selectedGroupId,
        status: _selectedTab == 'all' ? null : _selectedTab,
      );
      await saveBytesAsFile(bytes: report.bytes, fileName: report.fileName);
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
          _exporting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <_TabItem>[
      const _TabItem(id: 'all', label: 'Tất cả'),
      _TabItem(id: 'pending', label: 'Chờ duyệt ($_pendingCount)'),
      const _TabItem(id: 'approved', label: 'Đã duyệt'),
      const _TabItem(id: 'rejected', label: 'Từ chối'),
    ];
    final pendingVisible = _selectedTab == 'pending' || _pendingCount > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 240,
              child: KpiCard(
                label: 'Chờ duyệt',
                value: '$_pendingCount',
                valueColor: AppColors.warning,
                icon: Icons.warning_amber_rounded,
                iconColor: AppColors.warning,
                loading: _loading,
              ),
            ),
            SizedBox(
              width: 240,
              child: KpiCard(
                label: 'Hôm nay',
                value: '$_todayCount',
                icon: Icons.calendar_today_outlined,
                iconColor: AppColors.primary,
                loading: _loading,
              ),
            ),
            SizedBox(
              width: 240,
              child: KpiCard(
                label: 'Đã duyệt',
                value: '$_approvedCount',
                valueColor: AppColors.success,
                icon: Icons.check_circle_outline,
                iconColor: AppColors.success,
                loading: _loading,
              ),
            ),
            SizedBox(
              width: 240,
              child: KpiCard(
                label: 'Từ chối',
                value: '$_rejectedCount',
                valueColor: AppColors.danger,
                icon: Icons.cancel_outlined,
                iconColor: AppColors.danger,
                loading: _loading,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tabs.map((tab) {
            final isActive = _selectedTab == tab.id;
            final isPending = tab.id == 'pending';
            return InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () async {
                setState(() {
                  _selectedTab = tab.id;
                });
                await _refreshData();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive && isPending
                      ? AppColors.warning.withValues(alpha: 0.15)
                      : (isActive ? AppColors.bgPage : Colors.transparent),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isActive && isPending
                        ? AppColors.warning
                        : AppColors.border,
                  ),
                ),
                child: Text(
                  tab.label,
                  style: TextStyle(
                    color: isActive && isPending
                        ? AppColors.warning
                        : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }).toList(growable: false),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _pickRange,
                icon: const Icon(Icons.date_range_outlined),
                label: Text(
                  '${DateFormat('dd/MM/yyyy').format(_dateRange.from)} → ${DateFormat('dd/MM/yyyy').format(_dateRange.to)}',
                ),
              ),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<int?>(
                  initialValue: _selectedGroupId,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Nhóm',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Tất cả nhóm'),
                    ),
                    ..._groups.map(
                      (group) => DropdownMenuItem<int?>(
                        value: group.id,
                        child: Text(group.name),
                      ),
                    ),
                  ],
                  onChanged: (value) async {
                    setState(() {
                      _selectedGroupId = value;
                    });
                    await _refreshData();
                  },
                ),
              ),
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedExceptionType,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Loại ngoại lệ',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Tất cả')),
                    DropdownMenuItem(
                      value: 'MISSED_CHECKOUT',
                      child: Text('Quên checkout'),
                    ),
                    DropdownMenuItem(
                      value: 'SUSPECTED_LOCATION_SPOOF',
                      child: Text('Sai vị trí'),
                    ),
                  ],
                  onChanged: (value) async {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _selectedExceptionType = value;
                    });
                    await _refreshData();
                  },
                ),
              ),
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Tìm nhân viên...',
                    prefixIcon: Icon(Icons.search, size: 18),
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _refreshData(),
                ),
              ),
              OutlinedButton(
                onPressed: _refreshData,
                child: const Text('Làm mới'),
              ),
              ElevatedButton(
                onPressed: _exporting ? null : _exportExcel,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: _exporting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Xuất danh sách'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (pendingVisible) ...[
          Row(
            children: [
              const Icon(Icons.circle, size: 10, color: AppColors.warning),
              const SizedBox(width: 8),
              const Text(
                'Yêu cầu cần xử lý',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$_pendingCount',
                  style: const TextStyle(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_pendingItems.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'Không có ngoại lệ chờ xử lý.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _pendingItems.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: PendingExceptionCard(
                      exception: item,
                      isProcessing: _actioningIds.contains(item.id),
                      onApprove: () => _approve(item),
                      onReject: () => _reject(item),
                      onViewDetail: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Tính năng chi tiết sẽ bổ sung sau.'),
                          ),
                        );
                      },
                    ),
                  );
                }).toList(growable: false),
              ),
            ),
          const SizedBox(height: 16),
        ],
        Row(
          children: [
            const Expanded(
              child: Text(
                'Lịch sử xử lý ngoại lệ',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                setState(() {
                  _selectedTab = 'all';
                });
                await _refreshData();
              },
              child: const Text('Xem tất cả lịch sử →'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ExceptionHistoryTable(
          statusFilter: _selectedTab,
          dateRange: _dateRange,
          groupId: _selectedGroupId?.toString(),
        ),
      ],
    );
  }
}

class _TabItem {
  const _TabItem({required this.id, required this.label});

  final String id;
  final String label;
}
