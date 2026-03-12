import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/download/file_downloader.dart';
import '../../../core/storage/token_storage.dart';
import '../data/admin_api.dart';
import 'group_admin_page.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({
    required this.email,
    super.key,
  });

  final String email;

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final _tokenStorage = TokenStorage();
  final _adminApi = const AdminApi();
  final _dateFormat = DateFormat('yyyy-MM-dd');
  final _scrollController = ScrollController();

  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _radiusController = TextEditingController();
  final _startTimeController = TextEditingController();
  final _graceMinutesController = TextEditingController();
  final _endTimeController = TextEditingController();
  final _checkoutGraceMinutesController = TextEditingController();

  final _employeeCodeController = TextEditingController();
  final _employeeNameController = TextEditingController();

  final Set<int> _assigningEmployeeIds = {};
  final Set<int> _deletingEmployeeIds = {};
  final Map<int, int?> _selectedUserByEmployee = {};

  String? _token;

  bool _loadingRule = false;
  bool _savingRule = false;
  bool _loadingEmployees = false;
  bool _loadingUsers = false;
  bool _creatingEmployee = false;
  bool _downloadingReport = false;

  ActiveRuleResult? _activeRule;
  List<EmployeeLite> _employees = const [];
  List<UserLite> _users = const [];

  int? _newEmployeeUserId;
  int? _expandedEmployeeId;
  DateTime? _reportFromDate;
  DateTime? _reportToDate;
  int? _reportEmployeeId;
  bool _reportIncludeEmpty = false;

  String? _error;
  String? _info;

  bool get _isAnyLoading =>
      _loadingRule ||
      _savingRule ||
      _loadingEmployees ||
      _loadingUsers ||
      _creatingEmployee ||
      _downloadingReport ||
      _assigningEmployeeIds.isNotEmpty ||
      _deletingEmployeeIds.isNotEmpty;


  @override
  void initState() {
    super.initState();
    _startTimeController.text = '08:00';
    _graceMinutesController.text = '30';
    _endTimeController.text = '17:30';
    _checkoutGraceMinutesController.text = '0';
    _bootstrap();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _radiusController.dispose();
    _startTimeController.dispose();
    _graceMinutesController.dispose();
    _endTimeController.dispose();
    _checkoutGraceMinutesController.dispose();
    _employeeCodeController.dispose();
    _employeeNameController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final token = await _tokenStorage.getToken();
    if (!mounted) {
      return;
    }

    if (token == null || token.isEmpty) {
      setState(() {
        _error = 'Thiếu token đăng nhập. Hãy đăng nhập lại.';
      });
      return;
    }

    setState(() {
      _token = token;
    });

    await _refreshAll();
  }

  Future<void> _refreshAll() async {
    await _loadActiveRule();
    await _loadUsers();
    await _loadEmployees();
  }

  Future<void> _loadActiveRule() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      return;
    }

    setState(() {
      _loadingRule = true;
      _error = null;
      _info = null;
    });

    try {
      final rule = await _adminApi.getActiveRule(token);
      if (!mounted) {
        return;
      }

      setState(() {
        _activeRule = rule;
        if (rule != null) {
          _latController.text = rule.latitude.toStringAsFixed(6);
          _lngController.text = rule.longitude.toStringAsFixed(6);
          _radiusController.text = rule.radiusM.toString();
          _startTimeController.text = (rule.startTime ?? '08:00');
          _graceMinutesController.text = (rule.graceMinutes ?? 30).toString();
          _endTimeController.text = (rule.endTime ?? '17:30');
          _checkoutGraceMinutesController.text = (rule.checkoutGraceMinutes ?? 0).toString();
        } else {
          _startTimeController.text = '08:00';
          _graceMinutesController.text = '30';
          _endTimeController.text = '17:30';
          _checkoutGraceMinutesController.text = '0';
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Tải rule thất bại: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingRule = false;
        });
      }
    }
  }

  Future<void> _loadUsers() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      return;
    }

    setState(() {
      _loadingUsers = true;
      _error = null;
    });

    try {
      final users = await _adminApi.listUsers(token);
      if (!mounted) {
        return;
      }

      setState(() {
        _users = users;
        if (_newEmployeeUserId != null && !_users.any((u) => u.id == _newEmployeeUserId)) {
          _newEmployeeUserId = null;
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Tải danh sách user thất bại: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingUsers = false;
        });
      }
    }
  }

  void _syncSelectedUsers(List<EmployeeLite> employees) {
    final ids = employees.map((e) => e.id).toSet();
    final removed = _selectedUserByEmployee.keys.where((id) => !ids.contains(id)).toList();
    for (final id in removed) {
      _selectedUserByEmployee.remove(id);
    }

    for (final emp in employees) {
      _selectedUserByEmployee[emp.id] = emp.userId;
    }
  }

  Future<void> _loadEmployees() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      return;
    }

    setState(() {
      _loadingEmployees = true;
      _error = null;
    });

    try {
      final employees = await _adminApi.listEmployees(token);
      if (!mounted) {
        return;
      }
      setState(() {
        _employees = employees;
        _syncSelectedUsers(employees);
        if (_reportEmployeeId != null && !_employees.any((e) => e.id == _reportEmployeeId)) {
          _reportEmployeeId = null;
        }
        if (_expandedEmployeeId != null && !_employees.any((e) => e.id == _expandedEmployeeId)) {
          _expandedEmployeeId = null;
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Tải danh sách nhân viên thất bại: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingEmployees = false;
        });
      }
    }
  }

  Future<void> _saveRule() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      setState(() {
        _error = 'Thiếu token đăng nhập. Hãy đăng nhập lại.';
      });
      return;
    }

    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());
    final radius = int.tryParse(_radiusController.text.trim());
    final startTimeRaw = _startTimeController.text.trim();
    final graceMinutes = int.tryParse(_graceMinutesController.text.trim());
    final endTimeRaw = _endTimeController.text.trim();
    final checkoutGraceMinutes = int.tryParse(_checkoutGraceMinutesController.text.trim());

    final startMatch = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(startTimeRaw);
    final startHour = startMatch == null ? null : int.tryParse(startMatch.group(1)!);
    final startMinute = startMatch == null ? null : int.tryParse(startMatch.group(2)!);
    final validStartTime =
        startHour != null &&
        startMinute != null &&
        startHour >= 0 &&
        startHour <= 23 &&
        startMinute >= 0 &&
        startMinute <= 59;

    final endMatch = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(endTimeRaw);
    final endHour = endMatch == null ? null : int.tryParse(endMatch.group(1)!);
    final endMinute = endMatch == null ? null : int.tryParse(endMatch.group(2)!);
    final validEndTime =
        endHour != null &&
        endMinute != null &&
        endHour >= 0 &&
        endHour <= 23 &&
        endMinute >= 0 &&
        endMinute <= 59;

    if (lat == null ||
        lng == null ||
        radius == null ||
        radius <= 0 ||
        !validStartTime ||
        graceMinutes == null ||
        graceMinutes < 0 ||
        !validEndTime ||
        checkoutGraceMinutes == null ||
        checkoutGraceMinutes < 0) {
      setState(() {
        _error = 'Dữ liệu rule không hợp lệ. Kiểm tra lat/lng/radius/start_time/end_time (HH:mm) và grace_minutes/checkout_grace_minutes.';
      });
      return;
    }

    setState(() {
      _savingRule = true;
      _error = null;
      _info = null;
    });

    try {
      final updated = await _adminApi.updateActiveRule(
        token: token,
        latitude: lat,
        longitude: lng,
        radius: radius,
        startTime: startTimeRaw,
        graceMinutes: graceMinutes,
        endTime: endTimeRaw,
        checkoutGraceMinutes: checkoutGraceMinutes,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _activeRule = updated;
        _latController.text = updated.latitude.toStringAsFixed(6);
        _lngController.text = updated.longitude.toStringAsFixed(6);
        _radiusController.text = updated.radiusM.toString();
        _startTimeController.text = updated.startTime ?? startTimeRaw;
        _graceMinutesController.text = (updated.graceMinutes ?? graceMinutes).toString();
        _endTimeController.text = updated.endTime ?? endTimeRaw;
        _checkoutGraceMinutesController.text =
            (updated.checkoutGraceMinutes ?? checkoutGraceMinutes).toString();
        _info = 'Đã cập nhật rule thành công.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Cập nhật rule thất bại: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _savingRule = false;
        });
      }
    }
  }

  List<UserLite> _unassignedUsers() {
    final assignedIds = _employees.map((e) => e.userId).whereType<int>().toSet();
    return _users.where((u) => !assignedIds.contains(u.id)).toList(growable: false);
  }

  List<DropdownMenuItem<int?>> _createEmployeeUserItems() {
    final items = <DropdownMenuItem<int?>>[
      const DropdownMenuItem<int?>(
        value: null,
        child: Text('Tạo employee chưa gán user'),
      ),
    ];

    for (final u in _unassignedUsers()) {
      items.add(
        DropdownMenuItem<int?>(
          value: u.id,
          child: Text('${u.email} (id=${u.id}, ${u.role})'),
        ),
      );
    }

    final selected = _newEmployeeUserId;
    if (selected != null && !items.any((x) => x.value == selected)) {
      UserLite? fallback;
      for (final u in _users) {
        if (u.id == selected) {
          fallback = u;
          break;
        }
      }

      items.add(
        DropdownMenuItem<int?>(
          value: selected,
          child: Text(
            fallback == null
                ? 'user_id=$selected (không có trong list)'
                : '${fallback.email} (id=${fallback.id}, ${fallback.role})',
          ),
        ),
      );
    }

    return items;
  }

  Future<void> _createEmployee() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      setState(() {
        _error = 'Thiếu token đăng nhập. Hãy đăng nhập lại.';
      });
      return;
    }

    final code = _employeeCodeController.text.trim();
    final fullName = _employeeNameController.text.trim();

    if (code.isEmpty || fullName.isEmpty) {
      setState(() {
        _error = 'Vui lòng nhập đầy đủ mã nhân viên và họ tên.';
      });
      return;
    }

    setState(() {
      _creatingEmployee = true;
      _error = null;
      _info = null;
    });

    try {
      final created = await _adminApi.createEmployee(
        token: token,
        code: code,
        fullName: fullName,
        userId: _newEmployeeUserId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _employeeCodeController.clear();
        _employeeNameController.clear();
        _newEmployeeUserId = null;

        _employees = [created, ..._employees.where((e) => e.id != created.id)];
        _selectedUserByEmployee[created.id] = created.userId;
        _expandedEmployeeId = created.id;
        _info = created.userId == null
            ? 'Đã tạo employee ${created.code}.'
            : 'Đã tạo employee ${created.code} và gán user_id=${created.userId}.';
      });
      
      await _loadUsers();
      await _loadEmployees();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Tạo employee thất bại: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _creatingEmployee = false;
        });
      }
    }
  }

  Future<void> _assignEmployee(EmployeeLite employee, {int? overrideUserId}) async {
    final token = _token;
    if (token == null || token.isEmpty) {
      setState(() {
        _error = 'Thiếu token đăng nhập. Hãy đăng nhập lại.';
      });
      return;
    }

    final selectedUser = overrideUserId ?? _selectedUserByEmployee[employee.id];

    setState(() {
      _assigningEmployeeIds.add(employee.id);
      _error = null;
      _info = null;
    });

    try {
      final updated = await _adminApi.assignEmployeeUser(
        token: token,
        employeeId: employee.id,
        userId: selectedUser,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _employees = _employees.map((e) => e.id == updated.id ? updated : e).toList(growable: false);
        _selectedUserByEmployee[updated.id] = updated.userId;
        _info = updated.userId == null
            ? 'Đã bỏ gán user khỏi ${updated.code}.'
            : 'Đã gán user_id=${updated.userId} cho ${updated.code}.';
      });
      
      await _loadUsers();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Gán user thất bại: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _assigningEmployeeIds.remove(employee.id);
        });
      }
    }
  }

  Future<void> _clearAssign(EmployeeLite employee) async {
    await _assignEmployee(employee, overrideUserId: null);
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
      setState(() {
        _error = 'Thiếu token đăng nhập. Hãy đăng nhập lại.';
      });
      return;
    }

    setState(() {
      _deletingEmployeeIds.add(employee.id);
      _error = null;
      _info = null;
    });

    try {
      await _adminApi.deleteEmployee(token: token, employeeId: employee.id);

      if (!mounted) {
        return;
      }

      setState(() {
        _employees = _employees.where((x) => x.id != employee.id).toList(growable: false);
        _selectedUserByEmployee.remove(employee.id);
        if (_reportEmployeeId == employee.id) {
          _reportEmployeeId = null;
        }
        if (_expandedEmployeeId == employee.id) {
          _expandedEmployeeId = null;
        }
        _info = 'Đã xóa employee ${employee.code}.';
      });
      _showSnack('Đã xóa employee ${employee.code}.');

      await _loadUsers();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Xóa employee thất bại: $error';
      });
      _showSnack('Xóa employee thất bại: $error');
    } finally {
      if (mounted) {
        setState(() {
          _deletingEmployeeIds.remove(employee.id);
        });
      }
    }
  }

  String _dateLabel(DateTime? value) {
    if (value == null) {
      return 'Tất cả';
    }
    return _dateFormat.format(value);
  }

  Future<void> _pickReportDate({required bool isFrom}) async {
    final initial = isFrom ? (_reportFromDate ?? DateTime.now()) : (_reportToDate ?? DateTime.now());

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      if (isFrom) {
        _reportFromDate = picked;
      } else {
        _reportToDate = picked;
      }
    });
  }

  Future<void> _downloadReport() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      setState(() {
        _error = 'Thiếu token đăng nhập. Hãy đăng nhập lại.';
      });
      return;
    }

    if (_reportFromDate != null && _reportToDate != null && _reportFromDate!.isAfter(_reportToDate!)) {
      setState(() {
        _error = 'Khoảng ngày không hợp lệ: from phải <= to.';
      });
      return;
    }

    setState(() {
      _downloadingReport = true;
      _error = null;
      _info = null;
    });

    try {
      final report = await _adminApi.downloadAttendanceReport(
        token: token,
        fromDate: _reportFromDate,
        toDate: _reportToDate,
        employeeId: _reportEmployeeId,
        includeEmpty: _reportIncludeEmpty,
      );

      final savedPath = await saveBytesAsFile(bytes: report.bytes, fileName: report.fileName);

      if (!mounted) {
        return;
      }

      setState(() {
        _info = 'Đã tải file: ${report.fileName}. Vị trí: $savedPath';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Xuất Excel thất bại: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _downloadingReport = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    await _tokenStorage.clearToken();
    if (!mounted) {
      return;
    }

    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }
  void _showSnack(String text) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
  Future<void> _openGroupAdmin() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      setState(() {
        _error = 'Thiếu token đăng nhập. Hãy đăng nhập lại.';
      });
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GroupAdminPage(token: token)),
    );

    if (!mounted) {
      return;
    }

    await _loadEmployees();
    await _loadUsers();
  }
  Widget _buildBanner({required String text, required bool isError}) {
    final color = isError ? Colors.red : Colors.blue;
    final icon = isError ? Icons.error_outline : Icons.info_outline;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  List<DropdownMenuItem<int?>> _employeeReportItems() {
    final items = <DropdownMenuItem<int?>>[
      const DropdownMenuItem<int?>(
        value: null,
        child: Text('Tất cả nhân viên'),
      ),
    ];

    for (final e in _employees) {
      items.add(
        DropdownMenuItem<int?>(
          value: e.id,
          child: Text('${e.code} - ${e.fullName} (id=${e.id})'),
        ),
      );
    }

    return items;
  }

  List<DropdownMenuItem<int?>> _userItemsForEmployee(EmployeeLite employee) {
    final items = <DropdownMenuItem<int?>>[
      const DropdownMenuItem<int?>(
        value: null,
        child: Text('Không gán user'),
      ),
    ];

    for (final u in _users) {
      items.add(
        DropdownMenuItem<int?>(
          value: u.id,
          child: Text('${u.email} (id=${u.id}, ${u.role})'),
        ),
      );
    }

    final selected = _selectedUserByEmployee[employee.id];
    if (selected != null && !_users.any((u) => u.id == selected)) {
      items.add(
        DropdownMenuItem<int?>(
          value: selected,
          child: Text('user_id=$selected (khong co trong list)'),
        ),
      );
    }

    return items;
  }

  Widget _buildEmployeeRow(EmployeeLite e) {
    final assigning = _assigningEmployeeIds.contains(e.id);
    final deleting = _deletingEmployeeIds.contains(e.id);
    final busy = assigning || deleting;
    final selected = _selectedUserByEmployee[e.id];
    final expanded = _expandedEmployeeId == e.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              setState(() {
                _expandedEmployeeId = expanded ? null : e.id;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  CircleAvatar(child: Text('${e.id}')),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${e.code} - ${e.fullName}'),
                        Text(
                          e.userId == null ? 'Chưa gán user' : 'user_id hiện tại=${e.userId}',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<int?>(
              initialValue: selected,
              isExpanded: true,
              decoration: _decoration('Chọn user để gán', Icons.person_outline),
              items: _userItemsForEmployee(e),
              onChanged: busy
                  ? null
                  : (value) {
                      setState(() {
                        _selectedUserByEmployee[e.id] = value;
                      });
                    },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: busy ? null : () => _assignEmployee(e),
                    icon: assigning
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.link),
                    label: const Text('Lưu gán'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : () => _clearAssign(e),
                    icon: const Icon(Icons.link_off),
                    label: const Text('Bỏ gán'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : () => _confirmDeleteEmployee(e),
                    icon: deleting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_outline),
                    label: const Text('Xóa'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Demo'),
        actions: [
          IconButton(
            onPressed: _isAnyLoading ? null : _refreshAll,
            icon: const Icon(Icons.refresh),
            tooltip: 'Tải lại',
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: 'Đăng xuất',
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _refreshAll,
            notificationPredicate: (_) => !kIsWeb,
            child: ListView(
              controller: _scrollController,
              primary: false,
              physics: const ClampingScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Xin chào Admin: ${widget.email}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                if (_error != null) _buildBanner(text: _error!, isError: true),
                if (_info != null) _buildBanner(text: _info!, isError: false),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Quản lý Group/Geofence + gán group cho employee',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: _openGroupAdmin,
                          icon: const Icon(Icons.map_outlined),
                          label: const Text('Mở'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Rule hiện tại',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        if (_activeRule == null)
                          const Text('Chưa có active rule')
                        else ...[
                          Text('Latitude: ${_activeRule!.latitude.toStringAsFixed(6)}'),
                          Text('Longitude: ${_activeRule!.longitude.toStringAsFixed(6)}'),
                          Text('Radius: ${_activeRule!.radiusM} m'),
                          Text('Start time: ${_activeRule!.startTime ?? '-'}'),
                          Text('Grace vào: ${_activeRule!.graceMinutes ?? '-'} phút'),
                          Text('End time: ${_activeRule!.endTime ?? '-'}'),
                          Text('Grace về: ${_activeRule!.checkoutGraceMinutes ?? '-'} phút'),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        TextField(
                          controller: _latController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          decoration: _decoration('Latitude', Icons.place),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _lngController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          decoration: _decoration('Longitude', Icons.place_outlined),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _radiusController,
                          keyboardType: TextInputType.number,
                          decoration: _decoration('Radius (m)', Icons.straighten),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _startTimeController,
                          keyboardType: TextInputType.datetime,
                          decoration: _decoration('Start time (HH:mm)', Icons.schedule),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _graceMinutesController,
                          keyboardType: TextInputType.number,
                          decoration: _decoration('Grace minutes (check-in)', Icons.timer_outlined),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _endTimeController,
                          keyboardType: TextInputType.datetime,
                          decoration: _decoration('End time (HH:mm)', Icons.access_time_filled_outlined),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _checkoutGraceMinutesController,
                          keyboardType: TextInputType.number,
                          decoration: _decoration('Grace minutes (check-out)', Icons.timer_off_outlined),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: FilledButton.icon(
                            onPressed: _savingRule ? null : _saveRule,
                            icon: _savingRule
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.save),
                            label: Text(_savingRule ? 'Đang lưu...' : 'Cập nhật Rule'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Xuất Excel chấm công',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _downloadingReport ? null : () => _pickReportDate(isFrom: true),
                              icon: const Icon(Icons.event),
                              label: Text('Từ ngày: ${_dateLabel(_reportFromDate)}'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _downloadingReport ? null : () => _pickReportDate(isFrom: false),
                              icon: const Icon(Icons.event_available),
                              label: Text('Đến ngày: ${_dateLabel(_reportToDate)}'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _downloadingReport
                                  ? null
                                  : () {
                                      setState(() {
                                        _reportFromDate = null;
                                        _reportToDate = null;
                                      });
                                    },
                              icon: const Icon(Icons.clear),
                              label: const Text('Bỏ lọc ngày'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<int?>(
                          initialValue: _reportEmployeeId,
                          isExpanded: true,
                          decoration: _decoration('Lọc theo nhân viên (optional)', Icons.groups_2_outlined),
                          items: _employeeReportItems(),
                          onChanged: _downloadingReport
                              ? null
                              : (value) {
                                  setState(() {
                                    _reportEmployeeId = value;
                                  });
                                },
                        ),
                        const SizedBox(height: 8),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _reportIncludeEmpty,
                          onChanged: _downloadingReport
                              ? null
                              : (value) {
                                  setState(() {
                                    _reportIncludeEmpty = value ?? false;
                                  });
                                },
                          title: const Text('include_empty (xuất file dù không có dữ liệu)'),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: FilledButton.icon(
                            onPressed: _downloadingReport ? null : _downloadReport,
                            icon: _downloadingReport
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.download),
                            label: Text(_downloadingReport ? 'Đang tải file...' : 'Tải Excel'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Nhân viên',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                            ),
                            Text('${_employees.length} bản ghi'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: Text('Users khả dụng: ${_users.length}')),
                            TextButton.icon(
                              onPressed: _loadingUsers ? null : _loadUsers,
                              icon: _loadingUsers
                                  ? const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.refresh, size: 16),
                              label: const Text('Tải users'),
                            ),
                          ],
                        ),
                        if (_loadingUsers)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 6),
                            child: LinearProgressIndicator(minHeight: 2),
                          ),
                        const SizedBox(height: 2),
                        const Text(
                          'Nếu vừa tạo user mới, bấm "Tải users" để cập nhật danh sách rồi gán employee.',
                        ),
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 8),
                        const Text(
                          'Tạo employee + gán user',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _employeeCodeController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: _decoration('Mã nhân viên (VD: NV006)', Icons.badge_outlined),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _employeeNameController,
                          decoration: _decoration('Họ tên nhân viên', Icons.person),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<int?>(
                          initialValue: _newEmployeeUserId,
                          isExpanded: true,
                          decoration: _decoration('Chọn user để gán ngay (optional)', Icons.link),
                          items: _createEmployeeUserItems(),
                          onChanged: _creatingEmployee
                              ? null
                              : (value) {
                                  setState(() {
                                    _newEmployeeUserId = value;
                                  });
                                },
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: FilledButton.icon(
                            onPressed: _creatingEmployee ? null : _createEmployee,
                            icon: _creatingEmployee
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.person_add_alt_1),
                            label: Text(_creatingEmployee ? 'Đang tạo...' : 'Tạo employee'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 8),
                        if (_employees.isEmpty)
                          const Text('Chưa có dữ liệu nhân viên.')
                        else
                          ..._employees.take(50).map(_buildEmployeeRow),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isAnyLoading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
      ),
    );
  }
}




























