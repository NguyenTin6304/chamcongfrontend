import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/storage/token_storage.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../data/admin_api.dart';
import 'exception_ui_helpers.dart';

class DateRange {
  const DateRange({required this.from, required this.to});

  final DateTime from;
  final DateTime to;
}

class ExceptionHistoryTable extends StatefulWidget {
  const ExceptionHistoryTable({
    required this.statusFilter,
    required this.dateRange,
    required this.groupId,
    required this.employeeId,
    required this.exceptionTypeFilter,
    required this.searchQuery,
    required this.reloadToken,
    super.key,
    this.onViewDetail,
  });

  final String? statusFilter;
  final DateRange? dateRange;
  final String? groupId;
  final int? employeeId;
  final String? exceptionTypeFilter;
  final String searchQuery;
  final int reloadToken;
  final ValueChanged<AttendanceExceptionItem>? onViewDetail;

  @override
  State<ExceptionHistoryTable> createState() => _ExceptionHistoryTableState();
}

class _ExceptionHistoryTableState extends State<ExceptionHistoryTable> {
  final _tokenStorage = TokenStorage();
  final _api = const AdminApi();

  bool _loading = false;
  String? _token;
  List<AttendanceExceptionItem> _allRows = const [];

  int _page = 1;
  int _pageSize = 10;

  static const List<String> _allTypes = <String>[
    'SUSPECTED_LOCATION_SPOOF',
    'OUT_OF_RANGE',
    'AUTO_CLOSED',
    'AUTO_CHECKOUT',
    'MISSED_CHECKOUT',
    'FORGOT_CHECKOUT',
    'UNUSUAL_HOURS',
  ];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void didUpdateWidget(covariant ExceptionHistoryTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    final needsRefetch =
        oldWidget.groupId != widget.groupId ||
        oldWidget.employeeId != widget.employeeId ||
        oldWidget.statusFilter != widget.statusFilter ||
        oldWidget.exceptionTypeFilter != widget.exceptionTypeFilter ||
        oldWidget.reloadToken != widget.reloadToken ||
        oldWidget.dateRange?.from != widget.dateRange?.from ||
        oldWidget.dateRange?.to != widget.dateRange?.to;
    final needsPageReset = needsRefetch ||
        oldWidget.searchQuery != widget.searchQuery;
    if (needsRefetch) {
      _page = 1;
      _loadRows();
    } else if (needsPageReset) {
      setState(() {
        _page = 1;
      });
    }
  }

  Future<void> _bootstrap() async {
    final token = await _tokenStorage.getToken();
    if (!mounted) {
      return;
    }
    setState(() {
      _token = token;
    });
    await _loadRows();
  }

  Future<void> _loadRows() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      return;
    }
    setState(() {
      _loading = true;
    });
    try {
      final groupId = int.tryParse(widget.groupId ?? '');
      final range = widget.dateRange;
      final typeFilter = widget.exceptionTypeFilter;
      final typesToLoad = typeFilter == null ? _allTypes : <String>[typeFilter];

      final requests = typesToLoad
          .map(
            (type) => _loadByTypeSafe(
              token: token,
              fromDate: range?.from,
              toDate: range?.to,
              groupId: groupId,
              employeeId: widget.employeeId,
              exceptionType: type,
            ),
          )
          .toList(growable: false);

      final results = await Future.wait<List<AttendanceExceptionItem>>(requests);
      final merged = <int, AttendanceExceptionItem>{};
      for (final list in results) {
        for (final row in list) {
          merged[row.id] = row;
        }
      }
      final sorted = merged.values.toList(growable: false)
        ..sort((a, b) {
          final aTime = a.createdAt ?? a.workDate;
          final bTime = b.createdAt ?? b.workDate;
          return bTime.compareTo(aTime);
        });
      if (!mounted) {
        return;
      }
      setState(() {
        _allRows = sorted;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _allRows = const [];
      });
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

  Future<List<AttendanceExceptionItem>> _loadByTypeSafe({
    required String token,
    DateTime? fromDate,
    DateTime? toDate,
    int? groupId,
    int? employeeId,
    required String exceptionType,
  }) async {
    try {
      return await _api.listAttendanceExceptions(
        token: token,
        fromDate: fromDate,
        toDate: toDate,
        groupId: groupId,
        employeeId: employeeId,
        exceptionType: exceptionType,
        statusFilter: widget.statusFilter,
      );
    } catch (_) {
      return const [];
    }
  }

  List<AttendanceExceptionItem> get _filteredRows {
    final status = widget.statusFilter?.toUpperCase();
    final keyword = widget.searchQuery.trim().toLowerCase();
    return _allRows.where((row) {
      if (status != null &&
          status.isNotEmpty &&
          row.status.toUpperCase() != status) {
        return false;
      }
      if (keyword.isEmpty) {
        return true;
      }
      final haystack = [
        row.fullName,
        row.employeeCode,
        row.groupName ?? '',
        row.note ?? '',
        row.exceptionType,
      ].join(' ').toLowerCase();
      return haystack.contains(keyword);
    }).toList(growable: false);
  }

  int get _totalPages {
    final total = _filteredRows.length;
    if (total == 0) {
      return 1;
    }
    return (total / _pageSize).ceil();
  }

  List<AttendanceExceptionItem> get _pageRows {
    final rows = _filteredRows;
    final start = ((_page - 1) * _pageSize).clamp(0, rows.length);
    final end = (_page * _pageSize).clamp(0, rows.length);
    return rows.sublist(start, end);
  }

  List<Widget> _buildPageButtons() {
    final totalPages = _totalPages;
    final widgets = <Widget>[];
    final pages = <int>{1, totalPages, _page - 1, _page, _page + 1}
      ..removeWhere((value) => value < 1 || value > totalPages);
    final ordered = pages.toList(growable: false)..sort();
    var previous = 0;
    for (final page in ordered) {
      if (previous != 0 && page - previous > 1) {
        widgets.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text('...'),
          ),
        );
      }
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(left: 6),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              setState(() {
                _page = page;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _page == page ? AppColors.primary : AppColors.bgCard,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: Text(
                '$page',
                style: TextStyle(
                  fontSize: 12,
                  color: _page == page ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      );
      previous = page;
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final total = _filteredRows.length;
    final start = total == 0 ? 0 : ((_page - 1) * _pageSize) + 1;
    final end = total == 0 ? 0 : (_page * _pageSize).clamp(0, total);
    final rows = _pageRows;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border, width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            if (_loading)
              _buildSkeletonTable()
            else if (rows.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 30),
                color: AppColors.bgCard,
                child: const Column(
                  children: [
                    Icon(
                      Icons.assignment_outlined,
                      size: 48,
                      color: AppColors.border,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Chưa có ngoại lệ',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ],
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(AppColors.bgPage),
                  headingTextStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.06,
                    color: AppColors.textMuted,
                  ),
                  dataRowMinHeight: 56,
                  dataRowMaxHeight: 56,
                  dividerThickness: 0.5,
                  columns: const [
                    DataColumn(label: Text('STT')),
                    DataColumn(label: Text('NHÂN VIÊN')),
                    DataColumn(label: Text('LOẠI NGOẠI LỆ')),
                    DataColumn(label: Text('NGÀY')),
                    DataColumn(label: Text('GIỜ VÀO')),
                    DataColumn(label: Text('GIỜ RA')),
                    DataColumn(label: Text('LÝ DO')),
                    DataColumn(label: Text('TRẠNG THÁI')),
                    DataColumn(label: Text('NGƯỜI DUYỆT')),
                    DataColumn(label: Text('CHI TIẾT')),
                  ],
                  rows: rows.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final stt = (start + index).toString().padLeft(2, '0');
                    final initials = _initials(item.fullName);
                    final typeText = exceptionTypeLabel(item.exceptionType);
                    final typeColor = exceptionTypeColor(item.exceptionType);
                    final dateText = DateFormat('dd/MM/yyyy').format(item.workDate);
                    final checkInText = item.sourceCheckinTime == null
                        ? '—'
                        : DateFormat('HH:mm').format(item.sourceCheckinTime!.toLocal());
                    final checkOutText = item.actualCheckoutTime == null
                        ? '—'
                        : DateFormat('HH:mm').format(item.actualCheckoutTime!.toLocal());
                    final reason = (item.note ?? '').trim().isEmpty
                        ? typeText
                        : item.note!.trim();

                    return DataRow(
                      cells: [
                        DataCell(Text(stt)),
                        DataCell(
                          SizedBox(
                            width: 220,
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: AppColors.bgPage,
                                  child: Text(
                                    initials,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.fullName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        '${item.employeeCode} - ${item.groupName ?? item.groupCode ?? '--'}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: typeColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              typeText,
                              style: TextStyle(
                                fontSize: 11,
                                color: typeColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        DataCell(Text(dateText)),
                        DataCell(Text(checkInText)),
                        DataCell(
                          Text(
                            checkOutText,
                            style: TextStyle(
                              color: checkOutText == '—'
                                  ? AppColors.textMuted
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 220,
                            child: Text(
                              reason,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(_ReviewStatusBadge(status: item.status)),
                        DataCell(
                          Text(item.decidedByEmail ?? item.resolvedByEmail ?? '—'),
                        ),
                        DataCell(
                          TextButton(
                            onPressed: widget.onViewDetail == null
                                ? null
                                : () => widget.onViewDetail!(item),
                            child: const Text('Xem'),
                          ),
                        ),
                      ],
                    );
                  }).toList(growable: false),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.border, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    'Hiển thị $start–$end trong $total ngoại lệ',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: _page > 1
                        ? () {
                            setState(() {
                              _page -= 1;
                            });
                          }
                        : null,
                    child: const Text('Trước'),
                  ),
                  ..._buildPageButtons(),
                  const SizedBox(width: 6),
                  OutlinedButton(
                    onPressed: _page < _totalPages
                        ? () {
                            setState(() {
                              _page += 1;
                            });
                          }
                        : null,
                    child: const Text('Sau'),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<int>(
                    value: _pageSize,
                    borderRadius: BorderRadius.circular(8),
                    items: const [
                      DropdownMenuItem(value: 10, child: Text('10/trang')),
                      DropdownMenuItem(value: 25, child: Text('25/trang')),
                      DropdownMenuItem(value: 50, child: Text('50/trang')),
                    ],
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _pageSize = value;
                        _page = 1;
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppColors.bgPage),
        headingTextStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.06,
          color: AppColors.textMuted,
        ),
        columns: const [
          DataColumn(label: Text('STT')),
          DataColumn(label: Text('NHÂN VIÊN')),
          DataColumn(label: Text('LOẠI NGOẠI LỆ')),
          DataColumn(label: Text('NGÀY')),
          DataColumn(label: Text('GIỜ VÀO')),
          DataColumn(label: Text('GIỜ RA')),
          DataColumn(label: Text('LÝ DO')),
          DataColumn(label: Text('TRẠNG THÁI')),
          DataColumn(label: Text('NGƯỜI DUYỆT')),
          DataColumn(label: Text('CHI TIẾT')),
        ],
        rows: List.generate(
          3,
          (_) => const DataRow(
            cells: [
              DataCell(_ShimmerCell(width: 24)),
              DataCell(_ShimmerCell(width: 180)),
              DataCell(_ShimmerCell(width: 120)),
              DataCell(_ShimmerCell(width: 80)),
              DataCell(_ShimmerCell(width: 56)),
              DataCell(_ShimmerCell(width: 56)),
              DataCell(_ShimmerCell(width: 170)),
              DataCell(_ShimmerCell(width: 90)),
              DataCell(_ShimmerCell(width: 120)),
              DataCell(_ShimmerCell(width: 60)),
            ],
          ),
        ),
      ),
    );
  }

  String _initials(String fullName) {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) {
      return 'NA';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }
}

class _ReviewStatusBadge extends StatelessWidget {
  const _ReviewStatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toUpperCase();
    final label = exceptionStatusLabel(normalized);
    final palette = exceptionStatusPalette(normalized);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: palette.text,
        ),
      ),
    );
  }
}

class _ShimmerCell extends StatelessWidget {
  const _ShimmerCell({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.45, end: 0.9),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Container(
          width: width,
          height: 12,
          decoration: BoxDecoration(
            color: AppColors.border.withValues(alpha: value),
            borderRadius: BorderRadius.circular(99),
          ),
        );
      },
      onEnd: () {},
    );
  }
}
