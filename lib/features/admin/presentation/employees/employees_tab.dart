import 'package:flutter/material.dart';

import '../../../../core/download/file_downloader.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../widgets/common/kpi_card.dart';
import '../../data/admin_api.dart';
import '../../data/admin_data_cache.dart';

part 'widgets/employee_edit_panel.dart';
part 'widgets/employee_table.dart';

class EmployeesTab extends StatefulWidget {
  const EmployeesTab({super.key});

  @override
  State<EmployeesTab> createState() => _EmployeesTabState();
}

class _EmployeesTabState extends State<EmployeesTab> {
  final _tokenStorage = TokenStorage();
  final _api = const AdminApi();

  String? _token;

  bool _loadingEmployees = false;
  bool _downloadingReport = false;

  List<EmployeeLite> _employees = const [];
  List<UserLite> _users = const [];
  List<GroupLite> _groups = const [];

  final _employeesSearchController = TextEditingController();
  int? _employeesGroupId;
  String _employeesStatus = 'all';

  final _employeesPaginationNotifier =
      ValueNotifier<({int page, int pageSize})>((page: 1, pageSize: 10));

  int get _employeesPage => _employeesPaginationNotifier.value.page;
  int get _employeesPageSize => _employeesPaginationNotifier.value.pageSize;

  final Set<int> _assigningEmployeeIds = {};
  final Set<int> _deletingEmployeeIds = {};
  final Map<int, int?> _selectedUserByEmployee = {};

  List<EmployeeLite>? _cachedEmployeesView;
  List<EmployeeLite>? _cachedEmployeesListRef;
  String _cachedEmployeesFilterKey = '';

  DateTime? _reportFromDate;
  DateTime? _reportToDate;
  int? _reportEmployeeId;
  final bool _reportIncludeEmpty = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _employeesSearchController.dispose();
    _employeesPaginationNotifier.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final token = await _tokenStorage.getToken();
    if (!mounted || token == null || token.isEmpty) {
      return;
    }

    setState(() {
      _token = token;
    });

    await Future.wait<void>([
      _loadGroups(token),
      _loadUsers(token),
      _loadEmployees(),
    ]);
  }

  Future<void> _loadGroups(String token) async {
    final groups = await AdminDataCache.instance.fetchGroups(token, _api);
    if (!mounted) {
      return;
    }
    setState(() {
      _groups = groups;
    });
  }

  Future<void> _loadUsers(String token) async {
    final users = await AdminDataCache.instance.fetchUsers(token, _api);
    if (!mounted) {
      return;
    }
    setState(() {
      _users = users;
    });
  }

  void _showSnack(String text) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _friendlyError(Object error, {required String fallback}) {
    var message = error.toString().trim();
    if (message.startsWith('Exception: ')) {
      message = message.substring('Exception: '.length).trim();
    }
    return message.isEmpty ? fallback : message;
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  void _syncSelectedUsers(List<EmployeeLite> employees) {
    final ids = employees.map((e) => e.id).toSet();
    final removed = _selectedUserByEmployee.keys
        .where((id) => !ids.contains(id))
        .toList();
    for (final id in removed) {
      _selectedUserByEmployee.remove(id);
    }
    for (final employee in employees) {
      _selectedUserByEmployee[employee.id] = employee.userId;
    }
  }

  Future<void> _loadEmployees({
    String? query,
    int? groupId,
    String? status,
  }) async {
    final token = _token;
    if (token == null || token.isEmpty) {
      return;
    }

    setState(() {
      _loadingEmployees = true;
    });

    try {
      final useCache =
          (query == null || query.trim().isEmpty) &&
          groupId == null &&
          (status == null || status.isEmpty || status == 'all');

      final employees = useCache
          ? await AdminDataCache.instance.fetchEmployees(token, _api)
          : await _api.listEmployees(
              token,
              query: query,
              groupId: groupId,
              status: status,
            );

      if (!mounted) {
        return;
      }

      setState(() {
        _employees = employees;
        _syncSelectedUsers(employees);
        if (_reportEmployeeId != null &&
            !_employees.any((e) => e.id == _reportEmployeeId)) {
          _reportEmployeeId = null;
        }
      });

      final pages = _employeesTotalPages;
      if (_employeesPage > pages) {
        _employeesPaginationNotifier.value = (
          page: pages,
          pageSize: _employeesPageSize,
        );
      }
      // Don't replace cache when browsing resigned employees — it would evict active ones.
      if (status != 'resigned') {
        AdminDataCache.instance.replaceEmployees(_employees);
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnack('Không thể tải danh sách nhân viên.');
    } finally {
      if (mounted) {
        setState(() {
          _loadingEmployees = false;
        });
      }
    }
  }

  Future<void> _refreshEmployeesOnly() async {
    await _loadEmployees(
      query: _employeesSearchController.text.trim().isEmpty
          ? null
          : _employeesSearchController.text.trim(),
      groupId: _employeesGroupId,
      status: _employeesStatus == 'all' ? null : _employeesStatus,
    );
  }

  List<UserLite> _unassignedUsers() {
    final assignedIds = _employees
        .map((e) => e.userId)
        .whereType<int>()
        .toSet();
    return _users
        .where((user) => !assignedIds.contains(user.id))
        .toList(growable: false);
  }

  String _userOptionLabel(UserLite user) {
    final fullName = user.fullName?.trim() ?? '';
    if (fullName.isEmpty) {
      return '${user.email} (${user.role})';
    }
    return '$fullName - ${user.email} (${user.role})';
  }

  UserLite? _findUser(int? userId) {
    if (userId == null) {
      return null;
    }
    for (final user in _users) {
      if (user.id == userId) {
        return user;
      }
    }
    return null;
  }

  Future<void> _deleteEmployee(EmployeeLite employee) async {
    final token = _token;
    if (token == null || token.isEmpty) {
      _showSnack('Phiên đăng nhập đã hết hạn.');
      return;
    }

    setState(() {
      _deletingEmployeeIds.add(employee.id);
    });

    try {
      await _api.deleteEmployee(token: token, employeeId: employee.id);

      if (!mounted) {
        return;
      }

      // Remove from current view in both stages (stage 1: employee moves to
      // resigned list; stage 2: permanently deleted — neither case stays here).
      AdminDataCache.instance.removeEmployee(employee.id);
      setState(() {
        _employees = _employees
            .where((item) => item.id != employee.id)
            .toList(growable: false);
        _selectedUserByEmployee.remove(employee.id);
        if (_reportEmployeeId == employee.id) {
          _reportEmployeeId = null;
        }
      });

      if (employee.isResigned) {
        _showSnack('Đã xóa vĩnh viễn nhân viên ${employee.code}.');
      } else {
        _showSnack(
          '${employee.code} - ${employee.fullName} đã chuyển sang nghỉ việc.',
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(
        _friendlyError(error, fallback: 'Không thể xóa nhân viên.'),
      );
    } finally {
      if (mounted) {
        setState(() {
          _deletingEmployeeIds.remove(employee.id);
        });
      }
    }
  }

  Future<void> _restoreEmployee(EmployeeLite employee) async {
    final token = _token;
    if (token == null || token.isEmpty) {
      _showSnack('Phiên đăng nhập đã hết hạn.');
      return;
    }

    setState(() {
      _assigningEmployeeIds.add(employee.id);
    });

    try {
      final restored = await _api.restoreEmployee(
        token: token,
        employeeId: employee.id,
      );

      if (!mounted) {
        return;
      }

      // Remove from resigned view (now active again) and update cache.
      AdminDataCache.instance.upsertEmployee(restored);
      setState(() {
        _employees = _employees
            .where((item) => item.id != employee.id)
            .toList(growable: false);
        _selectedUserByEmployee.remove(employee.id);
      });
      _showSnack('Đã khôi phục nhân viên ${employee.code}.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(
        _friendlyError(error, fallback: 'Không thể khôi phục nhân viên.'),
      );
    } finally {
      if (mounted) {
        setState(() {
          _assigningEmployeeIds.remove(employee.id);
        });
      }
    }
  }

  Future<void> _downloadReport() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      _showSnack('Phiên đăng nhập đã hết hạn.');
      return;
    }

    if (_reportFromDate != null &&
        _reportToDate != null &&
        _reportFromDate!.isAfter(_reportToDate!)) {
      _showSnack('Khoảng ngày không hợp lệ: from phải <= to.');
      return;
    }

    setState(() {
      _downloadingReport = true;
    });

    try {
      final report = await _api.downloadAttendanceReport(
        token: token,
        fromDate: _reportFromDate,
        toDate: _reportToDate,
        employeeId: _reportEmployeeId,
        includeEmpty: _reportIncludeEmpty,
      );

      await saveBytesAsFile(bytes: report.bytes, fileName: report.fileName);

      if (!mounted) {
        return;
      }
      _showSnack('Đã tải file: ${report.fileName}.');
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnack('Xuất Excel thất bại.');
    } finally {
      if (mounted) {
        setState(() {
          _downloadingReport = false;
        });
      }
    }
  }

  String _userEmailById(int? userId) {
    if (userId == null) {
      return '--';
    }
    for (final user in _users) {
      if (user.id == userId) {
        return user.email;
      }
    }
    return '--';
  }

  String _employeeStatusLabel(EmployeeLite employee) {
    if (employee.isResigned) return 'Đã nghỉ việc';
    return _isEmployeeActive(employee) ? 'Hoạt động' : 'Không hoạt động';
  }

  Future<void> _showEmployeeDetail(EmployeeLite employee) async {
    await _showEmployeeDetailDialog(employee);
  }

  Future<void> _showEmployeeEditPanel(EmployeeLite employee) async {
    await _showEmployeeEditPanelDialog(employee);
  }

  Future<void> _setEmployeeActive(EmployeeLite employee, bool active) async {
    final token = _token;
    if (token == null || token.isEmpty) {
      _showSnack('Phiên đăng nhập đã hết hạn.');
      return;
    }

    setState(() {
      _assigningEmployeeIds.add(employee.id);
    });

    try {
      final updated = await _api.patchEmployee(
        token: token,
        employeeId: employee.id,
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
      });
      _showSnack(
        active ? 'Đã kích hoạt nhân viên.' : 'Đã vô hiệu hoá nhân viên.',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnack('Không thể cập nhật trạng thái nhân viên.');
    } finally {
      if (mounted) {
        setState(() {
          _assigningEmployeeIds.remove(employee.id);
        });
      }
    }
  }

  Future<void> _showEmployeesActionMenu(
    EmployeeLite employee,
    Offset position,
  ) async {
    final rect = RelativeRect.fromLTRB(
      position.dx,
      position.dy,
      position.dx,
      position.dy,
    );

    if (employee.isResigned) {
      final selected = await showMenu<String>(
        context: context,
        position: rect,
        items: const [
          PopupMenuItem<String>(
            value: 'restore',
            child: Text('Khôi phục'),
          ),
          PopupMenuItem<String>(
            value: 'delete',
            child: Text('Xoá vĩnh viễn'),
          ),
        ],
      );
      if (selected == 'restore') {
        await _restoreEmployee(employee);
      } else if (selected == 'delete') {
        await _deleteEmployee(employee);
      }
    } else {
      final selected = await showMenu<String>(
        context: context,
        position: rect,
        items: [
          const PopupMenuItem<String>(value: 'edit', child: Text('Chỉnh sửa')),
          PopupMenuItem<String>(
            value: 'toggle',
            child: Text(
              _isEmployeeActive(employee) ? 'Vô hiệu hoá' : 'Kích hoạt',
            ),
          ),
          const PopupMenuItem<String>(value: 'delete', child: Text('Xoá')),
        ],
      );
      if (selected == 'edit') {
        await _showEmployeeEditPanel(employee);
      } else if (selected == 'toggle') {
        await _setEmployeeActive(employee, !_isEmployeeActive(employee));
      } else if (selected == 'delete') {
        await _deleteEmployee(employee);
      }
    }
  }

  Future<void> _showCreateEmployeeDialog() async {
    final codeController = TextEditingController();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    int? selectedGroupId;
    int? selectedUserId;
    var creating = false;
    var dialogOpen = true;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> onCreate() async {
              final token = _token;
              if (token == null || token.isEmpty) {
                _showSnack('Phiên đăng nhập đã hết hạn.');
                return;
              }
              final code = codeController.text.trim();
              final fullName = nameController.text.trim();
              final phone = phoneController.text.trim();
              if (code.isEmpty || fullName.isEmpty) {
                _showSnack('Vui lòng nhập mã nhân viên và họ tên.');
                return;
              }
              setDialogState(() {
                creating = true;
              });
              try {
                final created = await _api.createEmployee(
                  token: token,
                  code: code,
                  fullName: fullName,
                  phone: phone.isEmpty ? null : phone,
                  userId: selectedUserId,
                  groupId: selectedGroupId,
                );
                if (!mounted) {
                  return;
                }
                AdminDataCache.instance.upsertEmployee(created);
                setState(() {
                  _employees = [
                    created,
                    ..._employees.where((e) => e.id != created.id),
                  ];
                  _selectedUserByEmployee[created.id] = created.userId;
                });
                await _refreshEmployeesOnly();
                _showSnack('Đã thêm nhân viên mới.');
                if (!context.mounted) {
                  return;
                }
                dialogOpen = false;
                Navigator.of(context).pop();
              } catch (error) {
                if (!mounted) {
                  return;
                }
                _showSnack(
                  _friendlyError(error, fallback: 'Không thể thêm nhân viên.'),
                );
              } finally {
                if (dialogOpen && context.mounted) {
                  setDialogState(() {
                    creating = false;
                  });
                }
              }
            }

            return AlertDialog(
              title: const Text('Thêm nhân viên'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: codeController,
                      decoration: _decoration(
                        'Mã nhân viên *',
                        Icons.badge_outlined,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: nameController,
                      decoration: _decoration('Họ tên', Icons.person_outline),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: _decoration(
                        'Số điện thoại',
                        Icons.phone_outlined,
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int?>(
                      initialValue: selectedGroupId,
                      decoration: _decoration('Nhóm', Icons.groups_2_outlined),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Chưa phân nhóm'),
                        ),
                        ..._groups.map(
                          (group) => DropdownMenuItem<int?>(
                            value: group.id,
                            child: Text(group.name),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          selectedGroupId = value;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int?>(
                      initialValue: selectedUserId,
                      decoration: _decoration(
                        'Liên kết tài khoản',
                        Icons.link_outlined,
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Không liên kết'),
                        ),
                        ..._unassignedUsers().map((user) {
                          return DropdownMenuItem<int?>(
                            value: user.id,
                            child: Text(_userOptionLabel(user)),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        final selectedUser = _findUser(value);
                        setDialogState(() {
                          selectedUserId = value;
                          if (selectedUser != null) {
                            final fullName = selectedUser.fullName?.trim();
                            final phone = selectedUser.phone?.trim();
                            if (fullName != null && fullName.isNotEmpty) {
                              nameController.text = fullName;
                            }
                            if (phone != null && phone.isNotEmpty) {
                              phoneController.text = phone;
                            }
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: creating
                      ? null
                      : () {
                          dialogOpen = false;
                          Navigator.of(context).pop();
                        },
                  child: const Text('Huỷ'),
                ),
                ElevatedButton(
                  onPressed: creating ? null : onCreate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: creating
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Thêm'),
                ),
              ],
            );
          },
        );
      },
    );

    codeController.dispose();
    nameController.dispose();
    phoneController.dispose();
  }

  bool _isEmployeeActive(EmployeeLite employee) {
    if (employee.active != null) {
      return employee.active!;
    }
    return employee.userId != null;
  }

  String _employeeGroupName(EmployeeLite employee) {
    if (employee.groupId == null) {
      return 'Chưa phân nhóm';
    }
    // Always prefer live _groups data so renames are reflected immediately
    for (final group in _groups) {
      if (group.id == employee.groupId) {
        return group.name;
      }
    }
    // Fallback to cached name from server response if group not found locally
    if (employee.groupName != null && employee.groupName!.trim().isNotEmpty) {
      return employee.groupName!;
    }
    return 'Nhóm #${employee.groupId}';
  }

  List<EmployeeLite> get _employeesView {
    final filterKey =
        '${_employeesSearchController.text.trim()}|$_employeesGroupId|$_employeesStatus';
    if (_cachedEmployeesView != null &&
        identical(_cachedEmployeesListRef, _employees) &&
        _cachedEmployeesFilterKey == filterKey) {
      return _cachedEmployeesView!;
    }

    var list = _employees.toList(growable: false);
    final q = _employeesSearchController.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where(
            (e) =>
                e.code.toLowerCase().contains(q) ||
                e.fullName.toLowerCase().contains(q) ||
                (e.email?.toLowerCase().contains(q) ?? false),
          )
          .toList(growable: false);
    }
    if (_employeesGroupId != null) {
      list = list
          .where((e) => e.groupId == _employeesGroupId)
          .toList(growable: false);
    }
    if (_employeesStatus == 'active') {
      list = list.where(_isEmployeeActive).toList(growable: false);
    } else if (_employeesStatus == 'inactive') {
      list = list.where((e) => !_isEmployeeActive(e)).toList(growable: false);
    }

    _cachedEmployeesListRef = _employees;
    _cachedEmployeesFilterKey = filterKey;
    _cachedEmployeesView = list;
    return list;
  }

  int get _employeesTotalCount => _employeesView.length;

  int get _employeesTotalPages {
    if (_employeesTotalCount == 0) {
      return 1;
    }
    return ((_employeesTotalCount - 1) ~/ _employeesPageSize) + 1;
  }

  String _formatThousands(int value) {
    final chars = value.toString().split('');
    final out = <String>[];
    for (var i = 0; i < chars.length; i++) {
      out.add(chars[i]);
      final remain = chars.length - i - 1;
      if (remain > 0 && remain % 3 == 0) {
        out.add('.');
      }
    }
    return out.join();
  }

  Widget _buildEmployeesPage() {
    final total = _employees.length;
    final active = _employees.where(_isEmployeeActive).length;
    final inactive = total - active;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 250,
              child: KpiCard(
                label: 'Tổng nhân viên',
                value: _loadingEmployees ? '--' : _formatThousands(total),
                icon: Icons.groups_outlined,
                iconColor: AppColors.primary,
                valueColor: AppColors.primary,
                loading: _loadingEmployees,
              ),
            ),
            SizedBox(
              width: 250,
              child: KpiCard(
                label: 'Đang hoạt động',
                value: _loadingEmployees ? '--' : _formatThousands(active),
                icon: Icons.check_circle_outline,
                iconColor: AppColors.success,
                valueColor: AppColors.success,
                loading: _loadingEmployees,
              ),
            ),
            SizedBox(
              width: 250,
              child: KpiCard(
                label: 'Không hoạt động',
                value: _loadingEmployees ? '--' : _formatThousands(inactive),
                icon: Icons.pause_circle_outline,
                iconColor: AppColors.textMuted,
                valueColor: AppColors.textMuted,
                loading: _loadingEmployees,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildEmployeesToolbarCard(),
        const SizedBox(height: 16),
        _buildEmployeesTableCard(),
      ],
    );
  }

  Widget _buildEmployeesToolbarCard() {
    return Container(
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
          SizedBox(
            width: 320,
            child: TextField(
              controller: _employeesSearchController,
              onChanged: (_) {
                _employeesPaginationNotifier.value = (
                  page: 1,
                  pageSize: _employeesPageSize,
                );
              },
              onSubmitted: (_) {
                _employeesPaginationNotifier.value = (
                  page: 1,
                  pageSize: _employeesPageSize,
                );
                _refreshEmployeesOnly();
              },
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Tìm nhân viên...',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: IconButton(
                  onPressed: _loadingEmployees
                      ? null
                      : () {
                          _employeesPaginationNotifier.value = (
                            page: 1,
                            pageSize: _employeesPageSize,
                          );
                          _refreshEmployeesOnly();
                        },
                  icon: const Icon(Icons.search),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 250,
            child: DropdownButtonFormField<int?>(
              initialValue: _employeesGroupId,
              decoration: _decoration('Nhóm', Icons.groups_2_outlined),
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
              onChanged: (value) {
                setState(() {
                  _employeesGroupId = value;
                });
                _employeesPaginationNotifier.value = (
                  page: 1,
                  pageSize: _employeesPageSize,
                );
                _refreshEmployeesOnly();
              },
            ),
          ),
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<String>(
              initialValue: _employeesStatus,
              decoration: _decoration('Trạng thái', Icons.rule_outlined),
              items: const [
                DropdownMenuItem<String>(value: 'all', child: Text('Tất cả')),
                DropdownMenuItem<String>(
                  value: 'active',
                  child: Text('Hoạt động'),
                ),
                DropdownMenuItem<String>(
                  value: 'inactive',
                  child: Text('Không hoạt động'),
                ),
                DropdownMenuItem<String>(
                  value: 'resigned',
                  child: Text('Đã nghỉ việc'),
                ),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _employeesStatus = value;
                });
                _employeesPaginationNotifier.value = (
                  page: 1,
                  pageSize: _employeesPageSize,
                );
                _refreshEmployeesOnly();
              },
            ),
          ),
          OutlinedButton.icon(
            onPressed: _downloadingReport ? null : _downloadReport,
            icon: _downloadingReport
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_download_outlined),
            label: const Text('Xuất danh sách'),
          ),
          ElevatedButton.icon(
            onPressed: _showCreateEmployeeDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Thêm nhân viên'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildEmployeesPage();
  }
}

class _SkeletonCell extends StatefulWidget {
  const _SkeletonCell({required this.width});

  final double width;

  @override
  State<_SkeletonCell> createState() => _SkeletonCellState();
}

class _SkeletonCellState extends State<_SkeletonCell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(_controller),
      child: Container(
        width: widget.width,
        height: 12,
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
