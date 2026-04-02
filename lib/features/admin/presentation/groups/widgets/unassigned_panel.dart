part of '../../admin_page.dart';

extension _UnassignedPanelX on _AdminPageState {
  Widget _buildUnassignedGroupPanelExtracted() {
    final employees = _unassignedGroupEmployees;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_outlined,
                color: AppColors.warning,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Nhân viên chưa được phân công',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${employees.length}',
                  style: const TextStyle(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (employees.isEmpty)
            const Text(
              'Tất cả nhân viên đã được phân công nhóm.',
              style: TextStyle(color: AppColors.textMuted),
            )
          else ...[
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: employees
                  .take(4)
                  .map((employee) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.bgPage,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            employee.fullName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 10),
                          DropdownButtonHideUnderline(
                            child: DropdownButton<int?>(
                              value: employee.groupId,
                              hint: const Text('Chọn nhóm'),
                              items: [
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('Chưa chọn'),
                                ),
                                ..._dashboardGroups.map(
                                  (group) => DropdownMenuItem<int?>(
                                    value: group.id,
                                    child: Text(group.name),
                                  ),
                                ),
                              ],
                              onChanged: (value) =>
                                  _assignEmployeeToGroup(employee, value),
                            ),
                          ),
                        ],
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
            if (employees.length > 4) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  setState(() {
                    _activeNav = _AdminShellNav.employees;
                    _employeesGroupId = null;
                    _employeesStatus = 'all';
                    _employeesPage = 1;
                  });
                },
                child: Text(
                  'Xem thêm ${employees.length - 4} người khác...',
                  style: const TextStyle(color: AppColors.primary),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
