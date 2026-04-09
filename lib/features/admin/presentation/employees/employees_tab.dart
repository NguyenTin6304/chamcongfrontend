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
      AdminDataCache.instance.replaceEmployees(_employees);
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
    await _loadEmployees();
  }

  List<UserLite> _unassignedUsers() {
    final assignedIds = _employees.map((e) => e.userId).whereType<int>().toSet();
    return _users
        .where((user) => !assignedIds.contains(user.id))
        .toList(growable: false);
  }

  Future<void> _assignEmployee(
    EmployeeLite employee, {
    int? overrideUserId,
  }) async {
    final token = _token;
    if (token == null || token.isEmpty) {
      _showSnack('Phiên đăng nhập đã hết hạn.');
      return;
    }

    final selectedUser = overrideUserId ?? _selectedUserByEmployee[employee.id];

    setState(() {
      _assigningEmployeeIds.add(employee.id);
    });

    try {
      final updated = await _api.assignEmployeeUser(
        token: token,
        employeeId: employee.id,
        userId: selectedUser,
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
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnack('Không thể cập nhật liên kết tài khoản.');
    } finally {
      if (mounted) {
        setState(() {
          _assigningEmployeeIds.remove(employee.id);
        });
      }
    }
  }

  Future<void> _confirmDeleteEmployee(EmployeeLite employee) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa nhân viên'),
        content: Text(
          'Bạn có chắc muốn xóa ${employee.code} - ${employee.fullName}?\nHành động này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await _deleteEmployee(employee);
    }
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
      _showSnack('Đã xóa nhân viên ${employee.code}.');
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnack('Không thể xóa nhân viên.');
    } finally {
      if (mounted) {
        setState(() {
          _deletingEmployeeIds.remove(employee.id);
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
    return _isEmployeeActive(employee) ? 'Hoạt động' : 'Không hoạt động';
  }

  Future<void> _showEmployeeDetail(EmployeeLite employee) async {
    await _showEmployeeDetailDialog(employee);
  }

  Future<void> _showEmployeeEditPanel(EmployeeLite employee) async {
    await _showEmployeeEditPanelDialog(employee);
  }

  Future<void> _showEmployeesActionMenu(
    EmployeeLite employee,
    Offset position,
  ) async {
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: const [
        PopupMenuItem<String>(value: 'group', child: Text('Đổi nhóm')),
        PopupMenuItem<String>(value: 'disable', child: Text('Vô hiệu hoá')),
        PopupMenuItem<String>(value: 'delete', child: Text('Xoá')),
      ],
    );
    if (selected == 'group') {
      await _showEmployeeEditPanel(employee);
      return;
    }
    if (selected == 'disable') {
      await _assignEmployee(employee, overrideUserId: null);
      await _refreshEmployeesOnly();
      return;
    }
    if (selected == 'delete') {
      await _confirmDeleteEmployee(employee);
    }
  }

  Future<void> _showCreateEmployeeDialog() async {
    final codeController = TextEditingController();
    final nameController = TextEditingController();
    int? selectedGroupId;
    int? selectedUserId;
    var creating = false;

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
                Navigator.of(context).pop();
              } catch (_) {
                if (!mounted) {
                  return;
                }
                _showSnack('Không thể thêm nhân viên.');
              } finally {
                if (mounted) {
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
                      decoration:
                          _decoration('Mã nhân viên *', Icons.badge_outlined),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: nameController,
                      decoration: _decoration('Họ tên', Icons.person_outline),
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
                        ..._unassignedUsers().map(
                          (user) => DropdownMenuItem<int?>(
                            value: user.id,
                            child: Text('${user.email} (${user.role})'),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          selectedUserId = value;
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
                      : () => Navigator.of(context).pop(),
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
