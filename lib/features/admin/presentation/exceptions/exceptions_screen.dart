import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:birdle/core/download/file_downloader.dart';
import 'package:birdle/core/storage/token_storage.dart';
import 'package:birdle/core/theme/app_colors.dart';
import 'package:birdle/core/theme/app_dimensions.dart';
import 'package:birdle/core/theme/app_text_styles.dart';
import 'package:birdle/features/admin/data/admin_api.dart';
import 'package:birdle/features/admin/data/admin_data_cache.dart';
import 'package:birdle/widgets/common/kpi_card.dart';
import 'package:birdle/features/admin/presentation/exceptions/widgets/exception_history_table.dart';
import 'package:birdle/features/admin/presentation/exceptions/widgets/exception_ui_helpers.dart';
import 'package:birdle/features/admin/presentation/exceptions/widgets/pending_exception_card.dart';

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

  String _selectedStatus = 'PENDING_EMPLOYEE';
  DateRange _dateRange = _currentMonthRange();
  int? _selectedGroupId;
  int? _selectedEmployeeId;
  String? _selectedExceptionType;
  String _searchQuery = '';
  int _reloadToken = 0;

  final Set<int> _actioningIds = <int>{};
  List<GroupLite> _groups = const [];
  List<ExceptionModel> _pendingItems = const [];

  int _pendingEmployeeCount = 0;
  int _pendingCount = 0;
  int _approvedCount = 0;
  int _rejectedCount = 0;
  int _expiredCount = 0;
  int _gracePeriodDays = 30;

  static const List<String> _allExceptionTypes = <String>[
    'SUSPECTED_LOCATION_SPOOF',
    'OUT_OF_RANGE',
    'AUTO_CLOSED',
    'AUTO_CHECKOUT',
    'MISSED_CHECKOUT',
    'FORGOT_CHECKOUT',
    'LARGE_TIME_DEVIATION',
    'UNUSUAL_HOURS',
  ];

  static DateRange _currentMonthRange() {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final lastDay = DateTime(now.year, now.month + 1, 0);
    return DateRange(from: firstDay, to: lastDay);
  }

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
        _fetchGracePeriodDays(token: token),
      ]);

      if (!mounted) {
        return;
      }

      final groups = results[0] as List<GroupLite>;
      final pending = results[1] as List<ExceptionModel>;
      final stats = results[2] as Map<String, int>;
      final gracePeriodDays = results[3] as int;

      setState(() {
        _groups = groups;
        _pendingItems = pending;
        _pendingEmployeeCount = stats['pending_employee'] ?? 0;
        _pendingCount = pending.isNotEmpty
            ? pending.length
            : stats['pending_admin'] ?? 0;
        _approvedCount = stats['approved'] ?? 0;
        _rejectedCount = stats['rejected'] ?? 0;
        _expiredCount = stats['expired'] ?? 0;
        _gracePeriodDays = gracePeriodDays;
        _reloadToken += 1;
      });
    } on UnauthorizedException {
      AdminDataCache.instance.sessionExpired.value = true;
    } on Exception catch (_) {
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
    try {
      final rows = await _loadExceptionRowsByStatus(
        token: token,
        status: 'PENDING_ADMIN',
      );
      return rows.map(_mapExceptionItem).toList(growable: false);
    } on Exception catch (_) {
      final fallback = await _api.listDashboardExceptions(
        token: token,
        status: 'PENDING_ADMIN',
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
              canAdminDecide: item.status.toUpperCase() == 'PENDING_ADMIN',
            ),
          )
          .toList(growable: false);
    }
  }

  Future<int> _fetchGracePeriodDays({required String token}) async {
    try {
      final policy = await _api.getExceptionPolicy(token);
      return policy.gracePeriodDays;
    } on Exception catch (_) {
      return _gracePeriodDays;
    }
  }

  Future<Map<String, int>> _fetchStats({required String token}) async {
    final results = await Future.wait<List<AttendanceExceptionItem>>([
      _loadExceptionRowsByStatus(token: token, status: 'PENDING_EMPLOYEE'),
      _loadExceptionRowsByStatus(token: token, status: 'PENDING_ADMIN'),
      _loadExceptionRowsByStatus(token: token, status: 'APPROVED'),
      _loadExceptionRowsByStatus(token: token, status: 'REJECTED'),
      _loadExceptionRowsByStatus(token: token, status: 'EXPIRED'),
    ]);

    final pendingEmployee = results[0];
    final pendingAdmin = results[1];
    final approved = results[2];
    final rejected = results[3];
    final expired = results[4];
    final merged = <int, AttendanceExceptionItem>{};
    for (final result in results) {
      for (final item in result) {
        merged[item.id] = item;
      }
    }
    var today = 0;
    final now = DateTime.now();
    for (final item in merged.values) {
      final date = item.workDate;
      if (date.year == now.year &&
          date.month == now.month &&
          date.day == now.day) {
        today += 1;
      }
    }

    return {
      'pending_employee': pendingEmployee.length,
      'pending_admin': pendingAdmin.length,
      'today': today,
      'approved': approved.length,
      'rejected': rejected.length,
      'expired': expired.length,
    };
  }

  Future<List<AttendanceExceptionItem>> _loadExceptionRowsByStatus({
    required String token,
    required String status,
  }) async {
    final types = _selectedExceptionType == null
        ? _allExceptionTypes
        : <String>[_selectedExceptionType!];
    final results = await Future.wait<List<AttendanceExceptionItem>>(
      types.map((type) async {
        try {
          return await _api.listAttendanceExceptions(
            token: token,
            fromDate: _dateRange.from,
            toDate: _dateRange.to,
            groupId: _selectedGroupId,
            employeeId: _selectedEmployeeId,
            exceptionType: type,
            statusFilter: status,
          );
        } on Exception catch (_) {
          return const <AttendanceExceptionItem>[];
        }
      }),
    );
    final merged = <int, AttendanceExceptionItem>{};
    for (final result in results) {
      for (final row in result) {
        merged[row.id] = row;
      }
    }
    return merged.values.toList(growable: false);
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

  ExceptionModel _mapExceptionItem(AttendanceExceptionItem item) {
    return ExceptionModel(
      id: item.id,
      employeeName: item.fullName,
      employeeCode: item.employeeCode,
      departmentName: item.groupName ?? item.groupCode ?? '--',
      exceptionType: item.exceptionType,
      status: item.status,
      workDate: item.workDate,
      checkInTime: _toTime(item.sourceCheckinTime),
      checkOutTime: _toTime(item.actualCheckoutTime),
      locationLabel: '--',
      reason: item.note ?? item.exceptionType,
      reviewerName: item.resolvedByEmail ?? item.decidedByEmail ?? '--',
      createdAt: item.createdAt ?? item.detectedAt,
      canAdminDecide: item.canAdminDecide,
    );
  }

  Future<void> _approve(ExceptionModel item) async {
    await _showExceptionReviewDialog(item, initialApprove: true);
  }

  Future<void> _reject(ExceptionModel item) async {
    await _showExceptionReviewDialog(item, initialApprove: false);
  }

  bool _canAdminDecide(ExceptionModel item) {
    return item.status.toUpperCase() == 'PENDING_ADMIN' && item.canAdminDecide;
  }

  String _formatDateOnly(DateTime? value) {
    if (value == null) {
      return '--';
    }
    return DateFormat('dd/MM/yyyy').format(value.toLocal());
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) {
      return '--';
    }
    return DateFormat('dd/MM/yyyy HH:mm').format(value.toLocal());
  }

  String _displayText(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? '--' : text;
  }

  Future<void> _showExceptionReviewDialog(
    ExceptionModel item, {
    bool? initialApprove,
    bool readOnly = false,
  }) async {
    final token = _token;
    if (token == null || token.isEmpty || _actioningIds.contains(item.id)) {
      return;
    }

    setState(() {
      _actioningIds.add(item.id);
    });

    try {
      final detail = await _api.getAttendanceExceptionDetail(
        token: token,
        exceptionId: item.id,
      );
      if (!mounted) {
        return;
      }
      await _openReviewDialog(
        detail,
        initialApprove: initialApprove,
        readOnly: readOnly,
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể tải chi tiết exception: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _actioningIds.remove(item.id);
        });
      }
    }
  }

  Future<void> _openReviewDialog(
    AttendanceExceptionItem detail, {
    bool? initialApprove,
    bool readOnly = false,
  }) async {
    final noteController = TextEditingController(text: detail.adminNote ?? '');
    final canDecide =
        !readOnly &&
        detail.status.toUpperCase() == 'PENDING_ADMIN' &&
        detail.canAdminDecide;
    final isCheckoutType =
        detail.exceptionType.toUpperCase() == 'AUTO_CLOSED' ||
        detail.exceptionType.toUpperCase() == 'MISSED_CHECKOUT';
    DateTime? selectedCheckoutTime;
    var submitting = false;

    Future<void> submit({
      required bool approve,
      required StateSetter setDialogState,
      required BuildContext dialogContext,
      DateTime? checkoutTime,
    }) async {
      final token = _token;
      if (token == null || token.isEmpty || submitting) {
        return;
      }
      final note = noteController.text.trim();
      if (!approve && note.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng nhập admin_note khi từ chối.'),
          ),
        );
        return;
      }
      if (approve && isCheckoutType && checkoutTime != null) {
        final checkinTime = detail.sourceCheckinTime;
        if (checkinTime != null && !checkoutTime.isAfter(checkinTime)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Giờ ra phải sau giờ vào.')),
          );
          return;
        }
      }
      setDialogState(() {
        submitting = true;
      });
      try {
        if (approve) {
          await _api.approveAttendanceException(
            token: token,
            exceptionId: detail.id,
            adminNote: note.isEmpty ? null : note,
            actualCheckoutTime: isCheckoutType ? checkoutTime : null,
          );
        } else {
          await _api.rejectAttendanceException(
            token: token,
            exceptionId: detail.id,
            adminNote: note,
          );
        }
        if (!mounted || !dialogContext.mounted) {
          return;
        }
        Navigator.of(dialogContext).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              approve ? 'Đã duyệt exception.' : 'Đã từ chối exception.',
            ),
            backgroundColor: approve ? AppColors.success : AppColors.danger,
          ),
        );
        await _refreshData();
      } on Object catch (error) {
        if (!mounted) {
          return;
        }
        setDialogState(() {
          submitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backend tu choi transition: $error')),
        );
      }
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final timeline = detail.timeline;
            return AlertDialog(
              title: const Text('Chi tiết exception'),
              content: SizedBox(
                width: 720,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _DialogSectionTitle('Nhân viên'),
                      _DialogInfoRow('Mã nhân viên', detail.employeeCode),
                      _DialogInfoRow('Họ tên', detail.fullName),
                      _DialogInfoRow(
                        'Nhóm',
                        _displayText(detail.groupName ?? detail.groupCode),
                      ),
                      const SizedBox(height: 12),
                      const _DialogSectionTitle('Nội dung exception'),
                      _DialogInfoRow(
                        'Loại',
                        exceptionTypeLabel(detail.exceptionType),
                      ),
                      _DialogInfoRow(
                        'Trạng thái',
                        exceptionStatusLabel(detail.status),
                      ),
                      _DialogInfoRow(
                        'Ngày công',
                        _formatDateOnly(detail.workDate),
                      ),
                      _DialogInfoRow(
                        'Lý do hệ thống',
                        _displayText(detail.note),
                      ),
                      _DialogInfoRow(
                        'Phát hiện lúc',
                        _formatDateTime(detail.detectedAt),
                      ),
                      _DialogInfoRow(
                        'Hết hạn lúc',
                        _formatDateTime(detail.expiresAt),
                      ),
                      if (detail.extendedDeadlineAt != null)
                        _DialogInfoRow(
                          'Gia hạn đến',
                          _formatDateTime(detail.extendedDeadlineAt),
                        ),
                      const SizedBox(height: 12),
                      const _DialogSectionTitle('Giải trình nhân viên'),
                      _DialogInfoRow(
                        'Nội dung',
                        _displayText(detail.employeeExplanation),
                      ),
                      _DialogInfoRow(
                        'Gửi lúc',
                        _formatDateTime(detail.employeeSubmittedAt),
                      ),
                      const SizedBox(height: 12),
                      const _DialogSectionTitle('Quyết định admin'),
                      _DialogInfoRow('Ghi chú', _displayText(detail.adminNote)),
                      _DialogInfoRow(
                        'Quyết định lúc',
                        _formatDateTime(detail.adminDecidedAt),
                      ),
                      _DialogInfoRow(
                        'Người quyết định',
                        _displayText(detail.decidedByEmail),
                      ),
                      const SizedBox(height: 12),
                      const _DialogSectionTitle('Timeline'),
                      if (timeline.isEmpty)
                        Text(
                          'Không có timeline.',
                          style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                        )
                      else
                        ...timeline.map(_buildTimelineRow),
                      if (canDecide) ...[
                        if (isCheckoutType) ...[
                          const SizedBox(height: 16),
                          const _DialogSectionTitle('Giờ ra thực tế'),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  selectedCheckoutTime == null
                                      ? 'Chưa chọn (tuỳ chọn)'
                                      : DateFormat('HH:mm  dd/MM/yyyy').format(
                                          selectedCheckoutTime!.toLocal(),
                                        ),
                                  style: AppTextStyles.chipText,
                                ),
                              ),
                              TextButton.icon(
                                icon: const Icon(Icons.access_time, size: 16),
                                label: Text(
                                  selectedCheckoutTime == null
                                      ? 'Chọn giờ'
                                      : 'Đổi giờ',
                                ),
                                onPressed: submitting
                                    ? null
                                    : () async {
                                        final workDate = detail.workDate;
                                        final initial =
                                            selectedCheckoutTime?.toLocal() ??
                                            DateTime.now();
                                        final picked = await showTimePicker(
                                          context: context,
                                          initialTime: TimeOfDay.fromDateTime(
                                            initial,
                                          ),
                                        );
                                        if (picked != null) {
                                          final candidate = DateTime(
                                            workDate.year,
                                            workDate.month,
                                            workDate.day,
                                            picked.hour,
                                            picked.minute,
                                          );
                                          setDialogState(() {
                                            selectedCheckoutTime = candidate
                                                .toUtc();
                                          });
                                        }
                                      },
                              ),
                              if (selectedCheckoutTime != null)
                                IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  tooltip: 'Xóa giờ ra',
                                  onPressed: submitting
                                      ? null
                                      : () => setDialogState(() {
                                          selectedCheckoutTime = null;
                                        }),
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 16),
                        TextField(
                          controller: noteController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'admin_note',
                            hintText: 'Nhập ghi chú khi cần',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        if (initialApprove == false)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'Bắt buộc nhập note khi từ chối.',
                              style: AppTextStyles.caption.copyWith(color: AppColors.danger),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Đóng'),
                ),
                if (canDecide) ...[
                  OutlinedButton(
                    onPressed: submitting
                        ? null
                        : () => submit(
                            approve: false,
                            setDialogState: setDialogState,
                            dialogContext: dialogContext,
                          ),
                    child: submitting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Từ chối'),
                  ),
                  ElevatedButton(
                    onPressed: submitting
                        ? null
                        : () => submit(
                            approve: true,
                            setDialogState: setDialogState,
                            dialogContext: dialogContext,
                            checkoutTime: selectedCheckoutTime,
                          ),
                    child: submitting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Phê duyệt'),
                  ),
                ],
              ],
            );
          },
        );
      },
    );

    noteController.dispose();
  }

  Widget _buildTimelineRow(Map<String, dynamic> item) {
    final action = _displayText(
      item['action']?.toString() ?? item['status']?.toString(),
    );
    final actor = _displayText(
      item['actor_email']?.toString() ?? item['actor']?.toString(),
    );
    final at = _formatDateTime(
      _toDate(item['created_at'] ?? item['at'] ?? item['time']),
    );
    final note = _displayText(item['note']?.toString());
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text('$at - $action - $actor - $note'),
    );
  }

  Future<void> _showExtendDeadlineDialog(AttendanceExceptionItem item) async {
    final token = _token;
    if (token == null || token.isEmpty || _actioningIds.contains(item.id)) {
      return;
    }

    final hoursController = TextEditingController(text: '24');
    var submitting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final extendHours = int.tryParse(hoursController.text.trim()) ?? 24;
            final currentDeadline = item.effectiveDeadline?.toLocal();
            final previewDeadline = currentDeadline?.add(
              Duration(hours: extendHours),
            );

            Future<void> submit() async {
              final hours = int.tryParse(hoursController.text.trim());
              if (hours == null || hours < 1 || hours > 168) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Số giờ gia hạn phải từ 1 đến 168.'),
                  ),
                );
                return;
              }
              setDialogState(() {
                submitting = true;
              });
              try {
                await _api.extendExceptionDeadline(
                  token: token,
                  exceptionId: item.id,
                  extendHours: hours,
                );
                if (!mounted || !dialogContext.mounted) {
                  return;
                }
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã gia hạn giải trình.')),
                );
                await _refreshData();
              } on Object catch (error) {
                if (!mounted || !dialogContext.mounted) {
                  return;
                }
                setDialogState(() {
                  submitting = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Không thể gia hạn: $error')),
                );
              }
            }

            return AlertDialog(
              title: const Text('Gia hạn giải trình'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DialogInfoRow(
                      'Hạn hiện tại',
                      _formatDateTime(item.effectiveDeadline),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: hoursController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: 'Gia hạn thêm',
                        suffixText: 'giờ',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 12),
                    _DialogInfoRow('Hạn mới', _formatDateTime(previewDeadline)),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: submitting ? null : submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.bgCard,
                  ),
                  child: submitting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.bgCard,
                          ),
                        )
                      : const Text('Xác nhận gia hạn'),
                ),
              ],
            );
          },
        );
      },
    );

    hoursController.dispose();
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
      final rows = await _loadExceptionRowsForCurrentFilters(token);
      if (rows.isEmpty) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Khong co exception de xuat voi filter hien tai.'),
          ),
        );
        return;
      }

      final csv = _buildExceptionCsv(rows);
      final fileName =
          'attendance_exceptions_${DateFormat('yyyyMMdd').format(_dateRange.from)}_${DateFormat('yyyyMMdd').format(_dateRange.to)}.csv';
      await saveBytesAsFile(
        bytes: Uint8List.fromList(utf8.encode(csv)),
        fileName: fileName,
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Khong the xuat exception voi filter hien tai: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _exporting = false;
        });
      }
    }
  }

  Future<List<AttendanceExceptionItem>> _loadExceptionRowsForCurrentFilters(
    String token,
  ) async {
    final types = _selectedExceptionType == null
        ? _allExceptionTypes
        : <String>[_selectedExceptionType!];
    final requests = types.map(
      (type) => _loadExceptionRowsByTypeForExport(
        token: token,
        exceptionType: type,
        ignoreErrors: _selectedExceptionType == null,
      ),
    );
    final results = await Future.wait<List<AttendanceExceptionItem>>(requests);
    final merged = <int, AttendanceExceptionItem>{};
    for (final result in results) {
      for (final row in result) {
        merged[row.id] = row;
      }
    }
    final rows = merged.values.toList(growable: false)
      ..sort((a, b) {
        final aTime = a.createdAt ?? a.detectedAt ?? a.workDate;
        final bTime = b.createdAt ?? b.detectedAt ?? b.workDate;
        return bTime.compareTo(aTime);
      });
    return rows;
  }

  Future<List<AttendanceExceptionItem>> _loadExceptionRowsByTypeForExport({
    required String token,
    required String exceptionType,
    required bool ignoreErrors,
  }) async {
    try {
      return await _api.listAttendanceExceptions(
        token: token,
        fromDate: _dateRange.from,
        toDate: _dateRange.to,
        groupId: _selectedGroupId,
        employeeId: _selectedEmployeeId,
        exceptionType: exceptionType,
        statusFilter: _selectedStatus,
      );
    } on Exception catch (_) {
      if (ignoreErrors) {
        return const [];
      }
      rethrow;
    }
  }

  String _buildExceptionCsv(List<AttendanceExceptionItem> rows) {
    final buffer = StringBuffer()
      ..writeln(
        [
          'id',
          'employee_id',
          'employee_code',
          'employee_name',
          'group',
          'exception_type',
          'status',
          'work_date',
          'detected_at',
          'expires_at',
          'employee_explanation',
          'employee_submitted_at',
          'admin_note',
          'admin_decided_at',
          'decided_by_email',
          'system_note',
        ].map(_csvCell).join(','),
      );

    for (final row in rows) {
      buffer.writeln(
        [
          row.id.toString(),
          row.employeeId.toString(),
          row.employeeCode,
          row.fullName,
          row.groupName ?? row.groupCode ?? '',
          row.exceptionType,
          row.status,
          _formatDateOnly(row.workDate),
          _formatDateTime(row.detectedAt),
          _formatDateTime(row.expiresAt),
          row.employeeExplanation ?? '',
          _formatDateTime(row.employeeSubmittedAt),
          row.adminNote ?? '',
          _formatDateTime(row.adminDecidedAt),
          row.decidedByEmail ?? '',
          row.note ?? '',
        ].map(_csvCell).join(','),
      );
    }

    return buffer.toString();
  }

  String _csvCell(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  // ignore: unused_element
  List<ExceptionModel> get _filteredPendingItems {
    if (_searchQuery.trim().isEmpty) {
      return _pendingItems;
    }
    final keyword = _searchQuery.trim().toLowerCase();
    return _pendingItems
        .where((item) {
          final haystack = [
            item.employeeName,
            item.employeeCode,
            item.departmentName,
            item.reason,
            item.exceptionType,
          ].join(' ').toLowerCase();
          return haystack.contains(keyword);
        })
        .toList(growable: false);
  }

  ({Color bg, Color text, Color border}) _tabPalette(String id, bool active) {
    return exceptionStatusPalette(id, active: active);
  }

  // ignore: unused_element
  Widget _buildPendingCards(List<ExceptionModel> pending) {
    if (pending.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Không có yêu cầu chờ xử lý.',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = pending
            .map(
              (item) => PendingExceptionCard(
                exception: item,
                isProcessing: _actioningIds.contains(item.id),
                canDecide: _canAdminDecide(item),
                onApprove: _canAdminDecide(item) ? () => _approve(item) : null,
                onReject: _canAdminDecide(item) ? () => _reject(item) : null,
                onViewDetail: () => _showExceptionReviewDialog(item),
              ),
            )
            .toList(growable: false);

        if (cards.length == 1) {
          return cards.first;
        }
        if (cards.length == 2) {
          final width = (constraints.maxWidth - 12) / 2;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: width, child: cards[0]),
              const SizedBox(width: 12),
              SizedBox(width: width, child: cards[1]),
            ],
          );
        }

        final cardWidth = constraints.maxWidth > 1200
            ? (constraints.maxWidth - 24) / 3
            : 360.0;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: cards
                .map(
                  (card) => Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: SizedBox(width: cardWidth, child: card),
                  ),
                )
                .toList(growable: false),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <({String id, String label})>[
      (
        id: 'PENDING_EMPLOYEE',
        label:
            '${exceptionStatusLabel('PENDING_EMPLOYEE')} ($_pendingEmployeeCount)',
      ),
      (
        id: 'PENDING_ADMIN',
        label: '${exceptionStatusLabel('PENDING_ADMIN')} ($_pendingCount)',
      ),
      (id: 'APPROVED', label: exceptionStatusLabel('APPROVED')),
      (id: 'REJECTED', label: exceptionStatusLabel('REJECTED')),
      (
        id: 'EXPIRED',
        label: '${exceptionStatusLabel('EXPIRED')} ($_expiredCount)',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 230,
              child: KpiCard(
                label: exceptionStatusLabel('PENDING_EMPLOYEE'),
                value: '$_pendingEmployeeCount',
                valueColor: AppColors.warning,
                icon: Icons.warning_amber_rounded,
                iconColor: AppColors.warning,
                loading: _loading,
              ),
            ),
            SizedBox(
              width: 230,
              child: KpiCard(
                label: exceptionStatusLabel('PENDING_ADMIN'),
                value: '$_pendingCount',
                valueColor: AppColors.overtime,
                icon: Icons.admin_panel_settings_outlined,
                iconColor: AppColors.overtime,
                loading: _loading,
              ),
            ),
            SizedBox(
              width: 230,
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
              width: 230,
              child: KpiCard(
                label: 'Từ chối',
                value: '$_rejectedCount',
                valueColor: AppColors.danger,
                icon: Icons.cancel_outlined,
                iconColor: AppColors.danger,
                loading: _loading,
              ),
            ),
            SizedBox(
              width: 230,
              child: KpiCard(
                label: 'Quá hạn',
                value: '$_expiredCount',
                valueColor: AppColors.textMuted,
                icon: Icons.hourglass_empty_outlined,
                iconColor: AppColors.textMuted,
                loading: _loading,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: AppRadius.cardAll,
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: tabs
                          .map((tab) {
                            final isActive = _selectedStatus == tab.id;
                            final palette = _tabPalette(tab.id, isActive);
                            return InkWell(
                              borderRadius: AppRadius.badgeAll,
                              onTap: () async {
                                if (_selectedStatus == tab.id) {
                                  return;
                                }
                                setState(() {
                                  _selectedStatus = tab.id;
                                });
                                await _refreshData();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: palette.bg,
                                  borderRadius: AppRadius.badgeAll,
                                  border: Border.all(color: palette.border),
                                ),
                                child: Text(
                                  tab.label,
                                  style: TextStyle(
                                    color: palette.text,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            );
                          })
                          .toList(growable: false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
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
                    width: 230,
                    child: DropdownButtonFormField<int?>(
                      initialValue: _selectedGroupId,
                      decoration: const InputDecoration(
                        isDense: true,
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
                    width: 220,
                    child: DropdownButtonFormField<String?>(
                      initialValue: _selectedExceptionType,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Tất cả loại'),
                        ),
                        DropdownMenuItem<String?>(
                          value: 'SUSPECTED_LOCATION_SPOOF',
                          child: Text('Vị trí bất thường'),
                        ),
                        DropdownMenuItem<String?>(
                          value: 'AUTO_CLOSED',
                          child: Text('Tự động checkout'),
                        ),
                        DropdownMenuItem<String?>(
                          value: 'MISSED_CHECKOUT',
                          child: Text('Quên checkout'),
                        ),
                        DropdownMenuItem<String?>(
                          value: 'UNUSUAL_HOURS',
                          child: Text('Giờ bất thường'),
                        ),
                      ],
                      onChanged: (value) async {
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
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _exporting ? null : _exportExcel,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.surface,
                    ),
                    icon: _exporting
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.surface,
                            ),
                          )
                        : const Icon(Icons.download_rounded, size: 16),
                    label: const Text('Xuất danh sách'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                'Lịch sử xử lý ngoại lệ',
                style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ExceptionHistoryTable(
          statusFilter: _selectedStatus,
          dateRange: _dateRange,
          groupId: _selectedGroupId?.toString(),
          employeeId: _selectedEmployeeId,
          exceptionTypeFilter: _selectedExceptionType,
          searchQuery: _searchQuery,
          reloadToken: _reloadToken,
          gracePeriodDays: _gracePeriodDays,
          onViewDetail: (item) {
            final model = _mapExceptionItem(item);
            _showExceptionReviewDialog(
              model,
              readOnly: !_canAdminDecide(model),
            );
          },
          onExtendDeadline: _showExtendDeadlineDialog,
        ),
      ],
    );
  }
}

class _DialogSectionTitle extends StatelessWidget {
  const _DialogSectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: AppTextStyles.chipText.copyWith(color: AppColors.textPrimary),
      ),
    );
  }
}

class _DialogInfoRow extends StatelessWidget {
  const _DialogInfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
