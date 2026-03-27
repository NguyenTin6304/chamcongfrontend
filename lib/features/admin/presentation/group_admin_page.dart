
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/download/file_downloader.dart';
import '../data/admin_api.dart';
import 'widgets/admin_location_picker.dart';

class GroupAdminPage extends StatefulWidget {
  const GroupAdminPage({
    required this.token,
    this.adminApi,
    this.autoLoad = true,
    super.key,
  });

  final String token;
  final AdminApi? adminApi;
  final bool autoLoad;

  @override
  State<GroupAdminPage> createState() => _GroupAdminPageState();
}

class _GroupAdminPageState extends State<GroupAdminPage> {
  late final AdminApi _adminApi;
  final _scrollController = ScrollController();

  final _groupCodeController = TextEditingController();
  final _groupNameController = TextEditingController();
  final _groupStartTimeController = TextEditingController(text: '08:00');
  final _groupGraceMinutesController = TextEditingController(text: '30');
  final _groupEndTimeController = TextEditingController(text: '17:30');
  final _groupCheckoutGraceController = TextEditingController(text: '0');

  final _selectedStartTimeController = TextEditingController();
  final _selectedGraceMinutesController = TextEditingController();
  final _selectedEndTimeController = TextEditingController();
  final _selectedCheckoutGraceController = TextEditingController();

  final _geofenceNameController = TextEditingController();
  final _geofenceLatController = TextEditingController();
  final _geofenceLngController = TextEditingController();
  final _geofenceRadiusController = TextEditingController(text: '200');

  final Map<int, int?> _selectedGroupByEmployee = {};
  final Set<int> _assigningEmployeeIds = {};
  final Set<int> _deletingGeofenceIds = {};
  final Set<int> _deletingGroupIds = {};

  List<GroupLite> _groups = const [];
  List<GroupGeofenceLite> _geofences = const [];
  List<EmployeeLite> _employees = const [];

  int? _selectedGroupId;
  int? _editingGeofenceId;
  int _locationPickerVersion = 0;
  String? _selectedGeofenceAddress;

  bool _loadingGroups = false;
  bool _loadingGeofences = false;
  bool _loadingEmployees = false;
  bool _creatingGroup = false;
  bool _savingGroupTimeRule = false;
  bool _savingGeofence = false;
  bool _downloadingReport = false;

  String? _error;
  String? _info;

  bool get _isAnyLoading =>
      _loadingGroups ||
      _loadingGeofences ||
      _loadingEmployees ||
      _creatingGroup ||
      _savingGroupTimeRule ||
      _savingGeofence ||
      _downloadingReport ||
      _assigningEmployeeIds.isNotEmpty ||
      _deletingGeofenceIds.isNotEmpty ||
      _deletingGroupIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _adminApi = widget.adminApi ?? const AdminApi();
    if (widget.autoLoad) {
      _loadAll();
    }
  }

  @override
  void dispose() {
    _groupCodeController.dispose();
    _groupNameController.dispose();
    _groupStartTimeController.dispose();
    _groupGraceMinutesController.dispose();
    _groupEndTimeController.dispose();
    _groupCheckoutGraceController.dispose();

    _selectedStartTimeController.dispose();
    _selectedGraceMinutesController.dispose();
    _selectedEndTimeController.dispose();
    _selectedCheckoutGraceController.dispose();

    _geofenceNameController.dispose();
    _geofenceLatController.dispose();
    _geofenceLngController.dispose();
    _geofenceRadiusController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await _loadGroups();
    await _loadEmployees();
    await _loadGeofences();
  }

  GroupLite? _findGroupById(int? groupId) {
    if (groupId == null) {
      return null;
    }
    for (final g in _groups) {
      if (g.id == groupId) {
        return g;
      }
    }
    return null;
  }

  GroupLite? get _selectedGroup => _findGroupById(_selectedGroupId);

  void _syncSelectedGroupRuleForm() {
    final selected = _selectedGroup;
    _selectedStartTimeController.text = selected?.startTime ?? '';
    _selectedGraceMinutesController.text = selected?.graceMinutes?.toString() ?? '';
    _selectedEndTimeController.text = selected?.endTime ?? '';
    _selectedCheckoutGraceController.text = selected?.checkoutGraceMinutes?.toString() ?? '';
  }

  String? _normalizeOptionalTime(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      return null;
    }

    final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(value);
    if (match == null) {
      return null;
    }

    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return null;
    }

    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  int? _parseOptionalNonNegativeInt(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      return null;
    }

    final parsed = int.tryParse(value);
    if (parsed == null || parsed < 0) {
      return null;
    }
    return parsed;
  }

  String _groupTimeSummary(GroupLite group) {
    final checkin = '${group.startTime ?? '-'} (+${group.graceMinutes?.toString() ?? '-'}m)';
    final checkout = '${group.endTime ?? '-'} (+${group.checkoutGraceMinutes?.toString() ?? '-'}m)';
    return 'IN $checkin • OUT $checkout';
  }

  bool _isValidCoordinate(double value, {required bool isLatitude}) {
    if (isLatitude) {
      return value >= -90 && value <= 90;
    }
    return value >= -180 && value <= 180;
  }

  bool get _hasValidGeofenceCoordinates {
    final lat = double.tryParse(_geofenceLatController.text.trim());
    final lng = double.tryParse(_geofenceLngController.text.trim());
    if (lat == null || lng == null) {
      return false;
    }
    return _isValidCoordinate(lat, isLatitude: true) && _isValidCoordinate(lng, isLatitude: false);
  }

  void _onLocationPickerChanged(LocationPickerValue value) {
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedGeofenceAddress = value.displayName;
      if (value.latitude == null || value.longitude == null || !value.hasValidCoordinates) {
        _geofenceLatController.clear();
        _geofenceLngController.clear();
        return;
      }
      _geofenceLatController.text = value.latitude!.toStringAsFixed(6);
      _geofenceLngController.text = value.longitude!.toStringAsFixed(6);
    });
  }

  Future<void> _onSelectGroup(int? groupId) async {
    setState(() {
      _selectedGroupId = groupId;
      _syncSelectedGroupRuleForm();
    });
    await _loadGeofences();
  }

  Future<void> _loadGroups() async {
    setState(() {
      _loadingGroups = true;
      _error = null;
    });

    try {
      final groups = await _adminApi.listGroups(widget.token);
      if (!mounted) {
        return;
      }

      setState(() {
        _groups = groups;
        if (_selectedGroupId != null && !_groups.any((g) => g.id == _selectedGroupId)) {
          _selectedGroupId = null;
        }
        if (_selectedGroupId == null && _groups.isNotEmpty) {
          _selectedGroupId = _groups.first.id;
        }
        _syncSelectedGroupRuleForm();
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Tải group thất bại: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingGroups = false;
        });
      }
    }
  }

  Future<void> _loadEmployees() async {
    setState(() {
      _loadingEmployees = true;
      _error = null;
    });

    try {
      final employees = await _adminApi.listEmployees(widget.token);
      if (!mounted) {
        return;
      }

      setState(() {
        _employees = employees;
        _selectedGroupByEmployee.clear();
        for (final e in employees) {
          _selectedGroupByEmployee[e.id] = e.groupId;
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Tải employee thất bại: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingEmployees = false;
        });
      }
    }
  }

  Future<void> _loadGeofences() async {
    final groupId = _selectedGroupId;
    if (groupId == null) {
      setState(() {
        _geofences = const [];
      });
      return;
    }

    setState(() {
      _loadingGeofences = true;
      _error = null;
    });

    try {
      final geofences = await _adminApi.listGroupGeofences(token: widget.token, groupId: groupId);
      if (!mounted) {
        return;
      }

      setState(() {
        _geofences = geofences;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Tải geofence thất bại: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingGeofences = false;
        });
      }
    }
  }

  Future<void> _createGroup() async {
    final code = _groupCodeController.text.trim().toUpperCase();
    final name = _groupNameController.text.trim();

    if (code.isEmpty || name.isEmpty) {
      setState(() {
        _error = 'Nhập code và tên group.';
      });
      return;
    }

    final startRaw = _groupStartTimeController.text.trim();
    final endRaw = _groupEndTimeController.text.trim();
    final startTime = _normalizeOptionalTime(startRaw);
    final endTime = _normalizeOptionalTime(endRaw);
    final graceMinutes = _parseOptionalNonNegativeInt(_groupGraceMinutesController.text);
    final checkoutGraceMinutes = _parseOptionalNonNegativeInt(_groupCheckoutGraceController.text);

    if (startRaw.isNotEmpty && startTime == null) {
      setState(() {
        _error = 'Thời gian vào (check-in) không hợp lệ. Định dạng đúng HH:mm.';
      });
      return;
    }

    if (endRaw.isNotEmpty && endTime == null) {
      setState(() {
        _error = 'Thời gian ra (check-out) không hợp lệ. Định dạng đúng HH:mm.';
      });
      return;
    }

    if (_groupGraceMinutesController.text.trim().isNotEmpty && graceMinutes == null) {
      setState(() {
        _error = 'Thời gian gia hạn vào (check-in) phút phải là số >= 0.';
      });
      return;
    }

    if (_groupCheckoutGraceController.text.trim().isNotEmpty && checkoutGraceMinutes == null) {
      setState(() {
        _error = 'Thời gian gia hạn ra (check-out) phút phải là số >= 0.';
      });
      return;
    }

    setState(() {
      _creatingGroup = true;
      _error = null;
      _info = null;
    });

    try {
      final created = await _adminApi.createGroup(
        token: widget.token,
        code: code,
        name: name,
        startTime: startTime,
        graceMinutes: graceMinutes,
        endTime: endTime,
        checkoutGraceMinutes: checkoutGraceMinutes,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _groupCodeController.clear();
        _groupNameController.clear();
        _selectedGroupId = created.id;
        _info = 'Đã tạo group ${created.code}.';
      });

      await _loadGroups();
      await _loadGeofences();
      await _loadEmployees();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Tạo group thất bại: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _creatingGroup = false;
        });
      }
    }
  }

  Future<void> _saveSelectedGroupTimeRule() async {
    final selected = _selectedGroup;
    if (selected == null) {
      setState(() {
        _error = 'Hãy chọn group để cập nhật rule thời gian.';
      });
      return;
    }

    final startRaw = _selectedStartTimeController.text.trim();
    final endRaw = _selectedEndTimeController.text.trim();

    final startTime = _normalizeOptionalTime(startRaw);
    final endTime = _normalizeOptionalTime(endRaw);
    final graceMinutes = _parseOptionalNonNegativeInt(_selectedGraceMinutesController.text);
    final checkoutGraceMinutes = _parseOptionalNonNegativeInt(_selectedCheckoutGraceController.text);

    if (startRaw.isNotEmpty && startTime == null) {
      setState(() {
        _error = 'Thời gian vào (check-in) group không hợp lệ. Định dạng đúng HH:mm.';
      });
      return;
    }

    if (endRaw.isNotEmpty && endTime == null) {
      setState(() {
        _error = 'Thời gian ra (check-out) group không hợp lệ. Định dạng đúng HH:mm.';
      });
      return;
    }

    if (_selectedGraceMinutesController.text.trim().isNotEmpty && graceMinutes == null) {
      setState(() {
        _error = 'Thời gian gia hạn vào (check-in) phút phải là số >= 0.';
      });
      return;
    }

    if (_selectedCheckoutGraceController.text.trim().isNotEmpty && checkoutGraceMinutes == null) {
      setState(() {
        _error = 'Thời gian gia hạn ra (check-out) phút phải là số >= 0.';
      });
      return;
    }

    final clearStartTime = startRaw.isEmpty && selected.startTime != null;
    final clearGraceMinutes =
        _selectedGraceMinutesController.text.trim().isEmpty && selected.graceMinutes != null;
    final clearEndTime = endRaw.isEmpty && selected.endTime != null;
    final clearCheckoutGraceMinutes =
        _selectedCheckoutGraceController.text.trim().isEmpty && selected.checkoutGraceMinutes != null;

    final hasAnyUpdate =
        startTime != null ||
        endTime != null ||
        graceMinutes != null ||
        checkoutGraceMinutes != null ||
        clearStartTime ||
        clearGraceMinutes ||
        clearEndTime ||
        clearCheckoutGraceMinutes;

    if (!hasAnyUpdate) {
      setState(() {
        _error = 'Không có thay đổi để lưu.';
      });
      return;
    }

    setState(() {
      _savingGroupTimeRule = true;
      _error = null;
      _info = null;
    });

    try {
      final updated = await _adminApi.updateGroup(
        token: widget.token,
        groupId: selected.id,
        startTime: startTime,
        graceMinutes: graceMinutes,
        endTime: endTime,
        checkoutGraceMinutes: checkoutGraceMinutes,
        clearStartTime: clearStartTime,
        clearGraceMinutes: clearGraceMinutes,
        clearEndTime: clearEndTime,
        clearCheckoutGraceMinutes: clearCheckoutGraceMinutes,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _groups = _groups.map((g) => g.id == updated.id ? updated : g).toList(growable: false);
        _syncSelectedGroupRuleForm();
        _info = 'Đã cập nhật rule thời gian cho ${updated.code}.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Cập nhật rule thời gian group thất bại: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _savingGroupTimeRule = false;
        });
      }
    }
  }

  Future<void> _clearSelectedGroupTimeRule() async {
    final selected = _selectedGroup;
    if (selected == null) {
      setState(() {
        _error = 'Hãy chọn group để xóa rule thời gian.';
      });
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Xóa rule giờ của group'),
          content: Text(
            'Xóa toàn bộ start/end/grace của group ${selected.code}?\nSau khi xóa, group sẽ fallback về system rule.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Xóa rule giờ'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _savingGroupTimeRule = true;
      _error = null;
      _info = null;
    });

    try {
      final updated = await _adminApi.updateGroup(
        token: widget.token,
        groupId: selected.id,
        clearStartTime: true,
        clearGraceMinutes: true,
        clearEndTime: true,
        clearCheckoutGraceMinutes: true,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _groups = _groups.map((g) => g.id == updated.id ? updated : g).toList(growable: false);
        _syncSelectedGroupRuleForm();
        _info = 'Đã xóa rule giờ của ${updated.code}. Hệ thống sẽ fallback system rule.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Xóa rule giờ group thất bại: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _savingGroupTimeRule = false;
        });
      }
    }
  }
  Future<void> _toggleGroupActive(GroupLite group) async {
    try {
      final updated = await _adminApi.updateGroup(
        token: widget.token,
        groupId: group.id,
        active: !group.active,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _groups = _groups.map((g) => g.id == updated.id ? updated : g).toList(growable: false);
        _syncSelectedGroupRuleForm();
        _info = updated.active ? 'Đã bật ${updated.code}' : 'Đã tắt ${updated.code}';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Đổi trạng thái group thất bại: $error';
      });
    }
  }

  Future<void> _confirmDeleteGroup(GroupLite group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Xóa group'),
          content: Text(
            'Xóa group ${group.code}?\nHệ thống sẽ bỏ gán group khỏi employee và xóa geofence thuộc group này.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await _deleteGroup(group);
  }

  Future<void> _deleteGroup(GroupLite group) async {
    setState(() {
      _deletingGroupIds.add(group.id);
      _error = null;
      _info = null;
    });

    try {
      await _adminApi.deleteGroup(token: widget.token, groupId: group.id);

      if (!mounted) {
        return;
      }

      if (_selectedGroupId == group.id) {
        _selectedGroupId = null;
      }

      setState(() {
        _info = 'Đã xóa group ${group.code}';
      });

      await _loadGroups();
      await _loadGeofences();
      await _loadEmployees();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Xóa group thất bại: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _deletingGroupIds.remove(group.id);
        });
      }
    }
  }

  Future<void> _toggleGeofenceActive(GroupGeofenceLite geofence) async {
    final groupId = _selectedGroupId;
    if (groupId == null) {
      return;
    }

    try {
      await _adminApi.updateGroupGeofence(
        token: widget.token,
        groupId: groupId,
        geofenceId: geofence.id,
        active: !geofence.active,
      );

      await _loadGeofences();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Đổi trạng thái geofence thất bại: $error';
      });
    }
  }

  Future<void> _saveGeofence() async {
    final groupId = _selectedGroupId;
    if (groupId == null) {
      setState(() {
        _error = 'Hãy chọn group trước.';
      });
      return;
    }

    final name = _geofenceNameController.text.trim();
    final lat = double.tryParse(_geofenceLatController.text.trim());
    final lng = double.tryParse(_geofenceLngController.text.trim());
    final radius = int.tryParse(_geofenceRadiusController.text.trim());

    if (name.isEmpty || lat == null || lng == null || radius == null || radius <= 0) {
      setState(() {
        _error = 'Geofence không hợp lệ. Kiểm tra tên/vĩ độ/kinh độ/bán kính.';
      });
      return;
    }
    if (!_isValidCoordinate(lat, isLatitude: true) || !_isValidCoordinate(lng, isLatitude: false)) {
      setState(() {
        _error = 'Tọa độ không hợp lệ. Lat phải trong [-90,90], Lng trong [-180,180].';
      });
      return;
    }

    setState(() {
      _savingGeofence = true;
      _error = null;
      _info = null;
    });

    try {
      if (_editingGeofenceId == null) {
        await _adminApi.createGroupGeofence(
          token: widget.token,
          groupId: groupId,
          name: name,
          latitude: lat,
          longitude: lng,
          radiusM: radius,
        );
      } else {
        await _adminApi.updateGroupGeofence(
          token: widget.token,
          groupId: groupId,
          geofenceId: _editingGeofenceId!,
          name: name,
          latitude: lat,
          longitude: lng,
          radiusM: radius,
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _editingGeofenceId = null;
        _geofenceNameController.clear();
        _geofenceLatController.clear();
        _geofenceLngController.clear();
        _geofenceRadiusController.text = '200';
        _selectedGeofenceAddress = null;
        _locationPickerVersion++;
        _info = 'Đã lưu geofence.';
      });

      await _loadGeofences();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Lưu geofence thất bại: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _savingGeofence = false;
        });
      }
    }
  }

  Future<void> _deleteGeofence(GroupGeofenceLite geofence) async {
    final groupId = _selectedGroupId;
    if (groupId == null) {
      return;
    }

    setState(() {
      _deletingGeofenceIds.add(geofence.id);
      _error = null;
    });

    try {
      await _adminApi.deleteGroupGeofence(
        token: widget.token,
        groupId: groupId,
        geofenceId: geofence.id,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _info = 'Đã xóa geofence ${geofence.name}';
      });

      await _loadGeofences();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Xóa geofence thất bại: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _deletingGeofenceIds.remove(geofence.id);
        });
      }
    }
  }

  Future<void> _assignGroup(EmployeeLite employee) async {
    final groupId = _selectedGroupByEmployee[employee.id];

    setState(() {
      _assigningEmployeeIds.add(employee.id);
      _error = null;
    });

    try {
      final updated = await _adminApi.assignEmployeeGroup(
        token: widget.token,
        employeeId: employee.id,
        groupId: groupId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _employees = _employees.map((e) => e.id == updated.id ? updated : e).toList(growable: false);
        _selectedGroupByEmployee[updated.id] = updated.groupId;
        _info = 'Đã gán group cho ${updated.code}';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Gán group thất bại: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _assigningEmployeeIds.remove(employee.id);
        });
      }
    }
  }

  Future<void> _exportGroupReport() async {
    final groupId = _selectedGroupId;
    if (groupId == null) {
      setState(() {
        _error = 'Hãy chọn group trước khi export.';
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
        token: widget.token,
        groupId: groupId,
      );

      final savedPath = await saveBytesAsFile(
        bytes: report.bytes,
        fileName: report.fileName,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _info = 'Đã tải file theo group. Vị trí: $savedPath';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Export theo group thất bại: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _downloadingReport = false;
        });
      }
    }
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _banner(String text, {required bool error}) {
    final color = error ? Colors.red : Colors.blue;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
    );
  }

  List<DropdownMenuItem<int?>> _groupItems({String noneLabel = 'Không gán group'}) {
    final items = <DropdownMenuItem<int?>>[
      DropdownMenuItem<int?>(value: null, child: Text(noneLabel)),
    ];
    for (final g in _groups) {
      items.add(DropdownMenuItem<int?>(value: g.id, child: Text('${g.code} - ${g.name}')));
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Group/Geofence Admin')),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _loadAll,
            notificationPredicate: (_) => !kIsWeb,
            child: ListView(
              controller: _scrollController,
              primary: false,
              physics: const ClampingScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null) _banner(_error!, error: true),
                if (_info != null) _banner(_info!, error: false),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Tạo Group', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _groupCodeController,
                          decoration: _decoration('Group code', Icons.qr_code_2),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _groupNameController,
                          decoration: _decoration('Group name', Icons.badge_outlined),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _groupStartTimeController,
                          keyboardType: TextInputType.datetime,
                          decoration: _decoration('Thời gian vào (HH:mm)', Icons.schedule),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _groupGraceMinutesController,
                          keyboardType: TextInputType.number,
                          decoration: _decoration('Thời gian gia hạn vào (check-in) phút', Icons.timer_outlined),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _groupEndTimeController,
                          keyboardType: TextInputType.datetime,
                          decoration: _decoration('Thời gian ra (HH:mm)', Icons.access_time_filled_outlined),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _groupCheckoutGraceController,
                          keyboardType: TextInputType.number,
                          decoration: _decoration('Thời gian gia hạn ra (check-out) phút', Icons.timer_off_outlined),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _creatingGroup ? null : _createGroup,
                            icon: const Icon(Icons.add_business_outlined),
                            label: Text(_creatingGroup ? 'Đang tạo...' : 'Tạo group'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ..._groups.map(
                          (g) {
                            final deletingGroup = _deletingGroupIds.contains(g.id);
                            return ListTile(
                              selected: _selectedGroupId == g.id,
                              contentPadding: EdgeInsets.zero,
                              title: Text('${g.code} - ${g.name}'),
                              subtitle: Text('${g.active ? 'ACTIVE' : 'INACTIVE'} • ${_groupTimeSummary(g)}'),
                              trailing: Wrap(
                                spacing: 8,
                                children: [
                                  OutlinedButton(
                                    onPressed: deletingGroup ? null : () => _onSelectGroup(g.id),
                                    child: const Text('Chọn'),
                                  ),
                                  OutlinedButton(
                                    onPressed: deletingGroup ? null : () => _toggleGroupActive(g),
                                    child: Text(g.active ? 'Tắt' : 'Bật'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: deletingGroup ? null : () => _confirmDeleteGroup(g),
                                    icon: deletingGroup
                                        ? const SizedBox(
                                            width: 12,
                                            height: 12,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : const Icon(Icons.delete_outline, size: 16),
                                    label: const Text('Xóa'),
                                  ),
                                ],
                              ),
                            );
                          },
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
                        const Text('Rule thời gian group đang chọn', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int?>(
                          initialValue: _selectedGroupId,
                          items: _groupItems(noneLabel: 'Chọn group để set rule giờ'),
                          onChanged: (value) => _onSelectGroup(value),
                          decoration: _decoration('Group', Icons.groups_2_outlined),
                        ),
                        const SizedBox(height: 10),
                        if (_selectedGroup == null)
                          const Text('Chưa chọn group.')
                        else ...[
                          Text(
                            'Áp dụng cho: ${_selectedGroup!.code} - ${_selectedGroup!.name}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _selectedStartTimeController,
                            keyboardType: TextInputType.datetime,
                            decoration: _decoration('Thời gian vào (HH:mm)', Icons.schedule),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _selectedGraceMinutesController,
                            keyboardType: TextInputType.number,
                            decoration: _decoration('Thời gian gia hạn vào (check-in) phút', Icons.timer_outlined),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _selectedEndTimeController,
                            keyboardType: TextInputType.datetime,
                            decoration: _decoration('Thời gian ra (HH:mm)', Icons.access_time_filled_outlined),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _selectedCheckoutGraceController,
                            keyboardType: TextInputType.number,
                            decoration: _decoration('Thời gian gia hạn ra (check-out) phút', Icons.timer_off_outlined),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: _savingGroupTimeRule ? null : _saveSelectedGroupTimeRule,
                                  icon: _savingGroupTimeRule
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : const Icon(Icons.save),
                                  label: Text(_savingGroupTimeRule ? 'Đang lưu...' : 'Lưu rule thời gian group'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _savingGroupTimeRule ? null : _clearSelectedGroupTimeRule,
                                  icon: const Icon(Icons.auto_fix_high_outlined),
                                  label: const Text('Clear về system'),
                                ),
                              ),
                            ],
                          ),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('CRUD Geofence', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int?>(
                          initialValue: _selectedGroupId,
                          items: _groupItems(noneLabel: 'Chọn group'),
                          onChanged: (value) => _onSelectGroup(value),
                          decoration: _decoration('Group', Icons.groups_2_outlined),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _downloadingReport ? null : _exportGroupReport,
                            icon: _downloadingReport
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.download),
                            label: Text(
                              _downloadingReport
                                  ? 'Đang export...'
                                  : 'Export Excel theo group đang chọn',
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _geofenceNameController,
                          decoration: _decoration('Tên geofence', Icons.location_on_outlined),
                        ),
                        const SizedBox(height: 10),
                        AdminLocationPicker(
                          key: ValueKey(_locationPickerVersion),
                          initialLatitude: double.tryParse(_geofenceLatController.text.trim()),
                          initialLongitude: double.tryParse(_geofenceLngController.text.trim()),
                          initialDisplayName: _selectedGeofenceAddress,
                          onChanged: _onLocationPickerChanged,
                        ),
                        const SizedBox(height: 10),
                        if (_selectedGeofenceAddress != null &&
                            _selectedGeofenceAddress!.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              'Địa chỉ đã chọn: ${_selectedGeofenceAddress!}',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        TextField(
                          controller: _geofenceRadiusController,
                          decoration: _decoration('Bán kính (m)', Icons.straighten),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: (_savingGeofence || !_hasValidGeofenceCoordinates)
                                    ? null
                                    : _saveGeofence,
                                icon: const Icon(Icons.save),
                                label: Text(_editingGeofenceId == null ? 'Tạo geofence' : 'Lưu geofence'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _editingGeofenceId = null;
                                  _geofenceNameController.clear();
                                  _geofenceLatController.clear();
                                  _geofenceLngController.clear();
                                  _geofenceRadiusController.text = '200';
                                  _selectedGeofenceAddress = null;
                                  _locationPickerVersion++;
                                });
                              },
                              child: const Text('Reset'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ..._geofences.map(
                          (geo) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('${geo.name} (${geo.radiusM}m)'),
                            subtitle: Text(
                              'lat=${geo.latitude.toStringAsFixed(6)}, lng=${geo.longitude.toStringAsFixed(6)}',
                            ),
                            trailing: Wrap(
                              spacing: 6,
                              children: [
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _editingGeofenceId = geo.id;
                                      _geofenceNameController.text = geo.name;
                                      _geofenceLatController.text = geo.latitude.toStringAsFixed(6);
                                      _geofenceLngController.text = geo.longitude.toStringAsFixed(6);
                                      _geofenceRadiusController.text = geo.radiusM.toString();
                                      _selectedGeofenceAddress =
                                          'lat=${geo.latitude.toStringAsFixed(6)}, lng=${geo.longitude.toStringAsFixed(6)}';
                                      _locationPickerVersion++;
                                    });
                                  },
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  onPressed: () => _toggleGeofenceActive(geo),
                                  icon: Icon(geo.active ? Icons.visibility_off : Icons.visibility),
                                ),
                                IconButton(
                                  onPressed: _deletingGeofenceIds.contains(geo.id)
                                      ? null
                                      : () => _deleteGeofence(geo),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
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
                        const Text('Gán group cho employee', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 10),
                        ..._employees.map(
                          (e) {
                            final assigning = _assigningEmployeeIds.contains(e.id);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${e.code} - ${e.fullName}'),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<int?>(
                                    initialValue: _selectedGroupByEmployee[e.id],
                                    items: _groupItems(),
                                    onChanged: assigning
                                        ? null
                                        : (value) {
                                            setState(() {
                                              _selectedGroupByEmployee[e.id] = value;
                                            });
                                          },
                                    decoration: _decoration('Group', Icons.groups_2_outlined),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton(
                                      onPressed: assigning ? null : () => _assignGroup(e),
                                      child: Text(assigning ? 'Đang lưu...' : 'Lưu gán group'),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
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
