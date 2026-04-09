part of '../employees_tab.dart';

extension _EmployeeTableX on _EmployeesTabState {
  Widget _buildEmployeesTableCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_loadingEmployees) _buildEmployeesTableSkeleton(),
            if (!_loadingEmployees && _employeesView.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.people_outline,
                        color: AppColors.textMuted,
                        size: 28,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Chưa có dữ liệu',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
            if (!_loadingEmployees && _employeesView.isNotEmpty)
              ValueListenableBuilder<({int page, int pageSize})>(
                valueListenable: _employeesPaginationNotifier,
                builder: (context, pagination, _) {
                  final allRows = _employeesView;
                  final start = (pagination.page - 1) * pagination.pageSize;
                  final end = (start + pagination.pageSize).clamp(
                    0,
                    allRows.length,
                  );
                  final rows = start < allRows.length
                      ? allRows.sublist(start, end)
                      : const <EmployeeLite>[];
                  final startIndex = start;
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(AppColors.bgPage),
                      headingTextStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                        letterSpacing: 0.04,
                      ),
                      columns: const [
                        DataColumn(label: Text('STT')),
                        DataColumn(label: Text('NHÂN VIÊN')),
                        DataColumn(label: Text('MÃ NV')),
                        DataColumn(label: Text('NHÓM')),
                        DataColumn(label: Text('SỐ ĐIỆN THOẠI')),
                        DataColumn(label: Text('TRẠNG THÁI')),
                        DataColumn(label: Text('THAO TÁC')),
                      ],
                      rows: rows
                          .asMap()
                          .entries
                          .map((entry) {
                            final employee = entry.value;
                            final active = _isEmployeeActive(employee);
                            final stt = startIndex + entry.key + 1;
                            final statusText = active
                                ? 'Hoạt động'
                                : 'Không hoạt động';
                            final statusBg = active
                                ? AppColors.employeeActiveBg
                                : AppColors.employeeInactiveBg;
                            final statusFg = active
                                ? AppColors.employeeActiveText
                                : AppColors.employeeInactiveText;
                            return DataRow(
                              cells: [
                                DataCell(Text('$stt')),
                                DataCell(
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 14,
                                        backgroundColor: AppColors.bgPage,
                                        child: Text(
                                          employee.fullName.trim().isEmpty
                                              ? 'N'
                                              : employee.fullName
                                                    .trim()[0]
                                                    .toUpperCase(),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(employee.fullName),
                                          Text(
                                            employee.email ??
                                                _userEmailById(employee.userId),
                                            style: const TextStyle(
                                              color: AppColors.textMuted,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                DataCell(Text(employee.code)),
                                DataCell(Text(_employeeGroupName(employee))),
                                DataCell(Text(employee.phone ?? '--')),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusBg,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      statusText,
                                      style: TextStyle(
                                        color: statusFg,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    children: [
                                      IconButton(
                                        onPressed: () =>
                                            _showEmployeeEditPanel(employee),
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          color: AppColors.primary,
                                          size: 18,
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () =>
                                            _showEmployeeDetail(employee),
                                        icon: const Icon(
                                          Icons.remove_red_eye_outlined,
                                          color: AppColors.textMuted,
                                          size: 18,
                                        ),
                                      ),
                                      Builder(
                                        builder: (context) {
                                          return IconButton(
                                            onPressed: () async {
                                              final box =
                                                  context.findRenderObject()
                                                      as RenderBox?;
                                              if (box == null) {
                                                return;
                                              }
                                              final offset = box.localToGlobal(
                                                Offset.zero,
                                              );
                                              await _showEmployeesActionMenu(
                                                employee,
                                                offset +
                                                    Offset(0, box.size.height),
                                              );
                                            },
                                            icon: const Icon(
                                              Icons.more_vert,
                                              size: 18,
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          })
                          .toList(growable: false),
                    ),
                  );
                },
              ),
            const SizedBox(height: 12),
            _buildEmployeesPagination(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeesTableSkeleton() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppColors.bgPage),
        headingTextStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textMuted,
          letterSpacing: 0.04,
        ),
        columns: const [
          DataColumn(label: Text('STT')),
          DataColumn(label: Text('NHÂN VIÊN')),
          DataColumn(label: Text('MÃ NV')),
          DataColumn(label: Text('NHÓM')),
          DataColumn(label: Text('SỐ ĐIỆN THOẠI')),
          DataColumn(label: Text('TRẠNG THÁI')),
          DataColumn(label: Text('THAO TÁC')),
        ],
        rows: List.generate(
          5,
          (_) => const DataRow(
            cells: [
              DataCell(_SkeletonCell(width: 20)),
              DataCell(_SkeletonCell(width: 200)),
              DataCell(_SkeletonCell(width: 70)),
              DataCell(_SkeletonCell(width: 80)),
              DataCell(_SkeletonCell(width: 90)),
              DataCell(_SkeletonCell(width: 80)),
              DataCell(_SkeletonCell(width: 70)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeesPagination() {
    return ValueListenableBuilder<({int page, int pageSize})>(
      valueListenable: _employeesPaginationNotifier,
      builder: (context, pagination, _) {
        final page = pagination.page;
        final pageSize = pagination.pageSize;
        final total = _employeesView.length;
        final totalPages = total == 0 ? 1 : ((total - 1) ~/ pageSize) + 1;
        final start = total == 0 ? 0 : ((page - 1) * pageSize) + 1;
        final end = total == 0 ? 0 : (page * pageSize).clamp(0, total);
        final pageNums = <int>{
          1,
          totalPages,
          page - 1,
          page,
          page + 1,
        }.where((p) => p >= 1 && p <= totalPages).toList()..sort();

        void setPage(int p) {
          _employeesPaginationNotifier.value = (page: p, pageSize: pageSize);
        }

        return Row(
          children: [
            Text(
              'Hiển thị $start-$end trong $total bản ghi',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const Spacer(),
            OutlinedButton(
              onPressed: page > 1 ? () => setPage(page - 1) : null,
              child: const Text('Trước'),
            ),
            const SizedBox(width: 6),
            ...pageNums.map((p) {
              final active = p == page;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: SizedBox(
                  width: 34,
                  height: 34,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor:
                          active ? AppColors.primary : Colors.transparent,
                      foregroundColor:
                          active ? Colors.white : AppColors.textMuted,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: AppColors.border),
                      ),
                    ),
                    onPressed: active ? null : () => setPage(p),
                    child: Text('$p'),
                  ),
                ),
              );
            }),
            const SizedBox(width: 6),
            OutlinedButton(
              onPressed: page < totalPages ? () => setPage(page + 1) : null,
              child: const Text('Sau'),
            ),
            const SizedBox(width: 10),
            DropdownButton<int>(
              value: pageSize,
              items: const [
                DropdownMenuItem(value: 10, child: Text('10/trang')),
                DropdownMenuItem(value: 20, child: Text('20/trang')),
                DropdownMenuItem(value: 50, child: Text('50/trang')),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                _employeesPaginationNotifier.value = (page: 1, pageSize: value);
              },
            ),
          ],
        );
      },
    );
  }
}
