part of '../../admin_page.dart';

extension _EmployeeTableX on _AdminPageState {
  Widget _buildEmployeeTableCardExtracted() {
    final rows = _employeesCurrentPageItems;
    final startIndex = (_employeesPage - 1) * _employeesPageSize;

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
              SingleChildScrollView(
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
                    DataColumn(label: Text('PHÒNG BAN')),
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
                                    mainAxisAlignment: MainAxisAlignment.center,
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
                            DataCell(
                              Text(
                                employee.departmentName ??
                                    _employeeGroupName(employee),
                              ),
                            ),
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
                                            offset + Offset(0, box.size.height),
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
              ),
            const SizedBox(height: 12),
            _buildEmployeesPagination(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeTableSkeletonExtracted() {
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
          DataColumn(label: Text('PHÒNG BAN')),
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
              DataCell(_SkeletonCell(width: 140)),
              DataCell(_SkeletonCell(width: 70)),
              DataCell(_SkeletonCell(width: 80)),
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

  Widget _buildEmployeesPaginationExtracted() {
    final total = _employeesTotalCount;
    final totalPages = _employeesTotalPages;
    final start = total == 0
        ? 0
        : ((_employeesPage - 1) * _employeesPageSize) + 1;
    final end = total == 0
        ? 0
        : (_employeesPage * _employeesPageSize).clamp(0, total);
    final pages = <int>{
      1,
      totalPages,
      _employeesPage - 1,
      _employeesPage,
      _employeesPage + 1,
    }.where((p) => p >= 1 && p <= totalPages).toList()..sort();

    return Row(
      children: [
        Text(
          'Hiển thị $start-$end trong $total bản ghi',
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        const Spacer(),
        OutlinedButton(
          onPressed: _employeesPage > 1
              ? () {
                  setState(() {
                    _employeesPage -= 1;
                  });
                }
              : null,
          child: const Text('Trước'),
        ),
        const SizedBox(width: 6),
        ...pages.map((page) {
          final active = page == _employeesPage;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: SizedBox(
              width: 34,
              height: 34,
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: active
                      ? AppColors.primary
                      : Colors.transparent,
                  foregroundColor: active ? Colors.white : AppColors.textMuted,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: AppColors.border),
                  ),
                ),
                onPressed: active
                    ? null
                    : () {
                        setState(() {
                          _employeesPage = page;
                        });
                      },
                child: Text('$page'),
              ),
            ),
          );
        }),
        const SizedBox(width: 6),
        OutlinedButton(
          onPressed: _employeesPage < totalPages
              ? () {
                  setState(() {
                    _employeesPage += 1;
                  });
                }
              : null,
          child: const Text('Sau'),
        ),
        const SizedBox(width: 10),
        DropdownButton<int>(
          value: _employeesPageSize,
          items: const [
            DropdownMenuItem(value: 10, child: Text('10/trang')),
            DropdownMenuItem(value: 20, child: Text('20/trang')),
            DropdownMenuItem(value: 50, child: Text('50/trang')),
          ],
          onChanged: (value) {
            if (value == null) {
              return;
            }
            setState(() {
              _employeesPageSize = value;
              _employeesPage = 1;
            });
          },
        ),
      ],
    );
  }
}
