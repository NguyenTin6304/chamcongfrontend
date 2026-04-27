// ignore_for_file: prefer_final_fields, unused_element, unused_field

import 'package:flutter/material.dart';

import 'package:birdle/core/storage/token_storage.dart';
import 'package:birdle/core/theme/app_colors.dart';
import 'package:birdle/widgets/common/kpi_card.dart';
import 'package:birdle/features/admin/data/admin_api.dart';
import 'package:birdle/features/admin/data/admin_data_cache.dart';

part 'widgets/group_card.dart';
part 'widgets/group_card_grid.dart';
part 'widgets/group_create_panel.dart';
part 'widgets/unassigned_panel.dart';

class GroupsTab extends StatefulWidget {
  const GroupsTab({required this.onNavigateTo, super.key});

  final void Function(String section) onNavigateTo;

  @override
  State<GroupsTab> createState() => _GroupsTabState();
}

class _GroupsTabState extends State<GroupsTab> {
  final _tokenStorage = TokenStorage();
  final _api = const AdminApi();

  String? _token;

  bool _loadingGroups = false;
  bool _loadingEmployees = false;
  bool _loadingGroupGeofenceCards = false;
  bool _savingGroup = false;
  bool _deletingGroup = false;

  List<GroupLite> _groups = const [];
  List<EmployeeLite> _employees = const [];

  final _groupsSearchController = TextEditingController();
  String _groupsSearch = '';
  String _groupsStatus = 'all';

  final Map<int, List<GroupGeofenceLite>> _groupGeofencesByGroupId = {};

  List<GroupLite>? _cachedGroupsView;
  List<GroupLite>? _cachedGroupsListRef;
  String _cachedGroupsFilterKey = '';

  @override
  void initState() {
    super.initState();
    _resetGroupsFiltersToDefaults();
    _bootstrap();
  }

  @override
  void dispose() {
    _groupsSearchController.dispose();
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
      _loadEmployees(token),
    ]);
    await _loadGroupGeofenceCards();
  }

  void _resetGroupsFiltersToDefaults() {
    _groupsSearch = '';
    _groupsStatus = 'all';
    _groupsSearchController.text = '';
  }

  Future<void> _loadGroups(String token) async {
    setState(() {
      _loadingGroups = true;
    });
    try {
      final groups = await AdminDataCache.instance.fetchGroups(token, _api);
      AdminDataCache.instance.replaceGroups(groups);
      if (!mounted) {
        return;
      }
      setState(() {
        _groups = groups;
      });
    } on Object catch (_) {
      if (!mounted) {
        return;
      }
      _showSnack('Không thể tải danh sách nhóm.');
    } finally {
      if (mounted) {
        setState(() {
          _loadingGroups = false;
        });
      }
    }
  }

  Future<void> _loadEmployees(String token) async {
    setState(() {
      _loadingEmployees = true;
    });
    try {
      final employees = await AdminDataCache.instance.fetchEmployees(token, _api);
      if (!mounted) {
        return;
      }
      setState(() {
        _employees = employees;
      });
    } on Object catch (_) {
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


  List<GroupLite> get _groupsView {
    final filterKey = '$_groupsSearch|$_groupsStatus';
    if (_cachedGroupsView != null &&
        identical(_cachedGroupsListRef, _groups) &&
        _cachedGroupsFilterKey == filterKey) {
      return _cachedGroupsView!;
    }

    var list = _groups.toList(growable: false);
    final query = _groupsSearch.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list
          .where((group) {
            final name = group.name.toLowerCase();
            final code = group.code.toLowerCase();
            return name.contains(query) || code.contains(query);
          })
          .toList(growable: false);
    }
    if (_groupsStatus == 'active') {
      list = list.where((group) => group.active).toList(growable: false);
    } else if (_groupsStatus == 'inactive') {
      list = list.where((group) => !group.active).toList(growable: false);
    }

    _cachedGroupsListRef = _groups;
    _cachedGroupsFilterKey = filterKey;
    _cachedGroupsView = list;
    return list;
  }

  List<EmployeeLite> get _unassignedGroupEmployees {
    return _employees.where((employee) => employee.groupId == null).toList(
      growable: false,
    );
  }

  int get _unassignedGroupCount => _unassignedGroupEmployees.length;

  Future<void> _refreshGroupsOnly() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      return;
    }
    await _loadGroups(token);
    await _loadGroupGeofenceCards();
    await _loadEmployees(token);
  }

  Future<void> _loadGroupGeofenceCards() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      return;
    }
    final groups = _groups;
    if (groups.isEmpty) {
      setState(() {
        _groupGeofencesByGroupId.clear();
      });
      return;
    }

    setState(() {
      _loadingGroupGeofenceCards = true;
    });
    try {
      final summary = await _api.listGroupGeofencesSummary(token: token);
      if (!mounted) {
        return;
      }
      setState(() {
        _groupGeofencesByGroupId.clear();
        for (final group in groups) {
          _groupGeofencesByGroupId[group.id] =
              summary[group.id] ?? const <GroupGeofenceLite>[];
        }
      });
    } on Object catch (_) {
      try {
        final entries = await Future.wait(
          groups.map((group) async {
            try {
              final items = await _api.listGroupGeofences(
                token: token,
                groupId: group.id,
              );
              return MapEntry(group.id, items);
            } on Object catch (_) {
              return MapEntry(group.id, const <GroupGeofenceLite>[]);
            }
          }),
        );
        if (!mounted) {
          return;
        }
        setState(() {
          _groupGeofencesByGroupId
            ..clear()
            ..addEntries(entries);
        });
      } on Object catch (_) {
        // Leave existing data untouched if both strategies fail.
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingGroupGeofenceCards = false;
        });
      }
    }
  }

  Future<void> _assignEmployeeToGroup(EmployeeLite employee, int? groupId) async {
    final token = _token;
    if (token == null || token.isEmpty) {
      _showSnack('Phiên đăng nhập đã hết hạn.');
      return;
    }
    try {
      final updated = await _api.assignEmployeeGroup(
        token: token,
        employeeId: employee.id,
        groupId: groupId,
      );
      if (!mounted) {
        return;
      }
      AdminDataCache.instance.upsertEmployee(updated);
      setState(() {
        _employees = _employees
            .map((item) => item.id == updated.id ? updated : item)
            .toList(growable: false);
      });
      _showSnack('Đã cập nhật nhóm cho nhân viên.');
    } on Object catch (_) {
      if (!mounted) {
        return;
      }
      _showSnack('Không thể cập nhật nhóm cho nhân viên.');
    }
  }

  Future<void> _deleteGroupItem(GroupLite group) async {
    final token = _token;
    if (token == null || token.isEmpty) {
      _showSnack('Phiên đăng nhập đã hết hạn.');
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa nhóm'),
        content: Text('Bạn có chắc muốn xóa nhóm "${group.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: AppColors.bgCard,
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirm != true) {
      return;
    }

    setState(() {
      _deletingGroup = true;
    });
    try {
      await _api.deleteGroup(token: token, groupId: group.id);
      if (!mounted) {
        return;
      }
      AdminDataCache.instance.removeGroup(group.id);
      setState(() {
        _groups = _groups
            .where((item) => item.id != group.id)
            .toList(growable: false);
      });
      await _loadGroupGeofenceCards();
      await _loadEmployees(token);
      _showSnack('Đã xoá nhóm.');
    } on Object catch (_) {
      if (!mounted) {
        return;
      }
      _showSnack('Không thể xoá nhóm.');
    } finally {
      if (mounted) {
        setState(() {
          _deletingGroup = false;
        });
      }
    }
  }

  Future<void> _showGroupActionsMenu(GroupLite group, Offset position) async {
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: const [
        PopupMenuItem<String>(value: 'edit', child: Text('Chỉnh sửa')),
        PopupMenuItem<String>(value: 'delete', child: Text('Xóa')),
      ],
    );
    if (selected == 'edit') {
      await _showGroupEditorPanel(group: group);
      return;
    }
    if (selected == 'delete') {
      await _deleteGroupItem(group);
    }
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
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

  Future<void> _showGroupEditorPanel({GroupLite? group}) async {
    await _showGroupEditorPanelExtracted(group: group);
  }

  void _showSnack(String text) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Widget _buildGroupsPage() => _buildGroupsPageExtracted();

  Widget _buildGroupsToolbarCard() => _buildGroupsToolbarCardExtracted();

  Widget _buildGroupsGridCard() => _buildGroupsGridCardExtracted();

  Widget _buildGroupCard(GroupLite group, int index) =>
      _buildGroupCardExtracted(group, index);

  Widget _buildGroupMiniStat(String label, String value) =>
      _buildGroupMiniStatExtracted(label, value);

  Widget _buildUnassignedGroupPanel() => _buildUnassignedGroupPanelExtracted();

  @override
  Widget build(BuildContext context) {
    return _buildGroupsPage();
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
          color: AppColors.border,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
