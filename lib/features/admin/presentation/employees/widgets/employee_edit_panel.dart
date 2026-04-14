// ignore_for_file: invalid_use_of_protected_member

part of '../employees_tab.dart';

extension _EmployeeEditPanelX on _EmployeesTabState {
  Future<void> _showEmployeeDetailDialog(EmployeeLite employee) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Chi tiết nhân viên'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employee.fullName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text('Mã nhân viên: ${employee.code}'),
                Text(
                  'Email: ${employee.email ?? _userEmailById(employee.userId)}',
                ),
                Text('Số điện thoại: ${employee.phone ?? '--'}'),
                Text('Nhóm: ${_employeeGroupName(employee)}'),
                Text('Vai trò: ${employee.role ?? '--'}'),
                Text('Trạng thái: ${_employeeStatusLabel(employee)}'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Đóng'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEmployeeEditPanelDialog(EmployeeLite employee) async {
    final fullNameController = TextEditingController(text: employee.fullName);
    final codeController = TextEditingController(text: employee.code);
    final emailController = TextEditingController(
      text: employee.email ?? _userEmailById(employee.userId),
    );
    final phoneController = TextEditingController(text: employee.phone ?? '');
    // departmentName is read-only: not included in patchEmployee body
    final users = _users;
    final groups = _groups;

    var selectedGroupId = employee.groupId;
    if (selectedGroupId != null &&
        !groups.any((g) => g.id == selectedGroupId)) {
      selectedGroupId = null;
    }
    var selectedRole = (employee.role ?? 'EMPLOYEE').toUpperCase();
    if (selectedRole != 'EMPLOYEE' && selectedRole != 'ADMIN') {
      selectedRole = 'EMPLOYEE';
    }
    var selectedUserId = employee.userId;
    if (selectedUserId != null && !users.any((u) => u.id == selectedUserId)) {
      selectedUserId = null;
    }
    var active = _isEmployeeActive(employee);
    var saving = false;

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'employee-editor',
      barrierColor: Colors.black.withValues(alpha: 0.25),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerRight,
          child: StatefulBuilder(
            builder: (context, setPanelState) {
              Future<void> onSave() async {
                if (saving) {
                  return;
                }
                final token = _token;
                if (token == null || token.isEmpty) {
                  _showSnack('Phiên đăng nhập đã hết hạn.');
                  return;
                }
                if (fullNameController.text.trim().isEmpty) {
                  _showSnack('Vui lòng nhập họ tên.');
                  return;
                }
                setPanelState(() {
                  saving = true;
                });
                final nav = Navigator.of(context);
                try {
                  final updated = await _api.patchEmployee(
                    token: token,
                    employeeId: employee.id,
                    fullName: fullNameController.text.trim(),
                    groupId: selectedGroupId,
                    setGroupId: true,
                    userId: selectedUserId,
                    setUserId: true,
                    phone: phoneController.text.trim(),
                    active: active,
                  );
                  if (!mounted) {
                    return;
                  }
                  AdminDataCache.instance.upsertEmployee(updated);
                  setState(() {
                    _employees = _employees
                        .map((e) => e.id == updated.id ? updated : e)
                        .toList(growable: false);
                    _selectedUserByEmployee[updated.id] = updated.userId;
                  });
                  nav.pop();
                  _showSnack('Đã lưu thay đổi nhân viên.');
                } catch (error) {
                  if (!mounted) {
                    return;
                  }
                  _showSnack(
                    _friendlyError(
                      error,
                      fallback: 'Không thể lưu thay đổi nhân viên.',
                    ),
                  );
                  if (context.mounted) {
                    setPanelState(() {
                      saving = false;
                    });
                  }
                }
              }

              return Material(
                color: Colors.transparent,
                child: Container(
                  width: 420,
                  height: double.infinity,
                  color: AppColors.bgCard,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: AppColors.border,
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Chỉnh sửa nhân viên',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: saving
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: CircleAvatar(
                                  radius: 28,
                                  backgroundColor: AppColors.bgPage,
                                  child: Text(
                                    employee.fullName.trim().isEmpty
                                        ? 'N'
                                        : employee.fullName
                                              .trim()[0]
                                              .toUpperCase(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Center(
                                child: TextButton.icon(
                                  onPressed: () => _showSnack(
                                    'Tải ảnh đại diện sẽ cập nhật ở bước sau.',
                                  ),
                                  icon: const Icon(Icons.upload_outlined),
                                  label: const Text('Tải ảnh đại diện'),
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: fullNameController,
                                decoration: _decoration(
                                  'Họ và tên',
                                  Icons.person_outline,
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: codeController,
                                readOnly: true,
                                decoration: _decoration(
                                  'Mã nhân viên',
                                  Icons.badge_outlined,
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: emailController,
                                readOnly: true,
                                decoration: _decoration(
                                  'Email',
                                  Icons.email_outlined,
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: phoneController,
                                decoration: _decoration(
                                  'Số điện thoại',
                                  Icons.phone_outlined,
                                ),
                              ),
                              const SizedBox(height: 10),
                              DropdownButtonFormField<int?>(
                                initialValue: selectedGroupId,
                                decoration: _decoration(
                                  'Nhóm',
                                  Icons.groups_2_outlined,
                                ),
                                items: [
                                  const DropdownMenuItem<int?>(
                                    value: null,
                                    child: Text('Chưa phân nhóm'),
                                  ),
                                  ...groups.map(
                                    (group) => DropdownMenuItem<int?>(
                                      value: group.id,
                                      child: Text(group.name),
                                    ),
                                  ),
                                ],
                                onChanged: (value) {
                                  setPanelState(() {
                                    selectedGroupId = value;
                                  });
                                },
                              ),
                              const SizedBox(height: 10),
                              DropdownButtonFormField<String>(
                                initialValue: selectedRole,
                                decoration: _decoration(
                                  'Vai trò',
                                  Icons.admin_panel_settings_outlined,
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'EMPLOYEE',
                                    child: Text('Nhân viên'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'ADMIN',
                                    child: Text('Quản trị viên'),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value == null) {
                                    return;
                                  }
                                  setPanelState(() {
                                    selectedRole = value;
                                  });
                                },
                              ),
                              const SizedBox(height: 10),
                              SwitchListTile(
                                value: active,
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Trạng thái hoạt động'),
                                subtitle: Text(
                                  active ? 'Hoạt động' : 'Không hoạt động',
                                ),
                                onChanged: (value) {
                                  setPanelState(() {
                                    active = value;
                                  });
                                },
                              ),
                              const SizedBox(height: 80),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: AppColors.border,
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: saving
                                    ? null
                                    : () => Navigator.of(context).pop(),
                                child: const Text('Huỷ'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: saving ? null : onSave,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                ),
                                child: saving
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Lưu thay đổi'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
      transitionBuilder: (context, animation, _, child) {
        final offset =
            Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );
        return SlideTransition(position: offset, child: child);
      },
    );

    fullNameController.dispose();
    codeController.dispose();
    emailController.dispose();
    phoneController.dispose();
  }
}
