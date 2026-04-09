import 'admin_api.dart';

/// In-memory cache for shared admin list data.
/// Prevents redundant API calls when multiple self-contained tabs need the
/// same reference data (groups, employees, users).
///
/// Usage:
///   final groups = await AdminDataCache.instance.fetchGroups(token, api);
///   AdminDataCache.instance.invalidate(); // on logout / hard refresh
class AdminDataCache {
  AdminDataCache._();
  static final instance = AdminDataCache._();

  List<GroupLite>? _groups;
  List<EmployeeLite>? _employees;
  List<UserLite>? _users;
  Future<List<GroupLite>>? _groupsFuture;
  Future<List<EmployeeLite>>? _employeesFuture;
  Future<List<UserLite>>? _usersFuture;

  Future<List<GroupLite>> fetchGroups(String token, AdminApi api) async {
    final cached = _groups;
    if (cached != null) {
      return cached;
    }
    final pending = _groupsFuture;
    if (pending != null) {
      return pending;
    }
    final future = api.listGroups(token);
    _groupsFuture = future;
    try {
      final groups = await future;
      _groups = groups;
      return groups;
    } finally {
      _groupsFuture = null;
    }
  }

  void replaceGroups(List<GroupLite> groups) {
    _groups = List<GroupLite>.unmodifiable(groups);
  }

  void upsertGroup(GroupLite group) {
    final current = _groups;
    if (current == null) {
      return;
    }
    final next = current
        .map((item) => item.id == group.id ? group : item)
        .toList(growable: true);
    if (!next.any((item) => item.id == group.id)) {
      next.insert(0, group);
    }
    _groups = List<GroupLite>.unmodifiable(next);
  }

  void removeGroup(int groupId) {
    final current = _groups;
    if (current == null) {
      return;
    }
    _groups = List<GroupLite>.unmodifiable(
      current.where((item) => item.id != groupId),
    );
  }

  Future<List<EmployeeLite>> fetchEmployees(String token, AdminApi api) async {
    final cached = _employees;
    if (cached != null) {
      return cached;
    }
    final pending = _employeesFuture;
    if (pending != null) {
      return pending;
    }
    final future = api.listEmployees(token);
    _employeesFuture = future;
    try {
      final employees = await future;
      _employees = employees;
      return employees;
    } finally {
      _employeesFuture = null;
    }
  }

  Future<List<UserLite>> fetchUsers(String token, AdminApi api) async {
    final cached = _users;
    if (cached != null) {
      return cached;
    }
    final pending = _usersFuture;
    if (pending != null) {
      return pending;
    }
    final future = api.listUsers(token);
    _usersFuture = future;
    try {
      final users = await future;
      _users = users;
      return users;
    } finally {
      _usersFuture = null;
    }
  }

  void replaceEmployees(List<EmployeeLite> employees) {
    _employees = List<EmployeeLite>.unmodifiable(employees);
  }

  void upsertEmployee(EmployeeLite employee) {
    final current = _employees;
    if (current == null) {
      return;
    }
    final next = current
        .map((item) => item.id == employee.id ? employee : item)
        .toList(growable: true);
    if (!next.any((item) => item.id == employee.id)) {
      next.insert(0, employee);
    }
    _employees = List<EmployeeLite>.unmodifiable(next);
  }

  void removeEmployee(int employeeId) {
    final current = _employees;
    if (current == null) {
      return;
    }
    _employees = List<EmployeeLite>.unmodifiable(
      current.where((item) => item.id != employeeId),
    );
  }

  /// Clears all cached data. Call on logout or when a hard refresh is needed.
  void invalidate() {
    _groups = null;
    _employees = null;
    _users = null;
    _groupsFuture = null;
    _employeesFuture = null;
    _usersFuture = null;
  }
}
