import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';

class ActiveRuleResult {
  const ActiveRuleResult({
    required this.latitude,
    required this.longitude,
    required this.radiusM,
    this.startTime,
    this.graceMinutes,
    this.endTime,
    this.checkoutGraceMinutes,
  });

  final double latitude;
  final double longitude;
  final int radiusM;
  final String? startTime;
  final int? graceMinutes;
  final String? endTime;
  final int? checkoutGraceMinutes;
}

class EmployeeLite {
  const EmployeeLite({
    required this.id,
    required this.code,
    required this.fullName,
    this.userId,
    this.groupId,
  });

  final int id;
  final String code;
  final String fullName;
  final int? userId;
  final int? groupId;
}

class UserLite {
  const UserLite({
    required this.id,
    required this.email,
    required this.role,
  });

  final int id;
  final String email;
  final String role;
}

class GroupLite {
  const GroupLite({
    required this.id,
    required this.code,
    required this.name,
    required this.active,
    this.startTime,
    this.graceMinutes,
    this.endTime,
    this.checkoutGraceMinutes,
  });

  final int id;
  final String code;
  final String name;
  final bool active;
  final String? startTime;
  final int? graceMinutes;
  final String? endTime;
  final int? checkoutGraceMinutes;
}

class GroupGeofenceLite {
  const GroupGeofenceLite({
    required this.id,
    required this.groupId,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusM,
    required this.active,
  });

  final int id;
  final int groupId;
  final String name;
  final double latitude;
  final double longitude;
  final int radiusM;
  final bool active;
}

class ReportDownloadResult {
  const ReportDownloadResult({
    required this.fileName,
    required this.bytes,
  });

  final String fileName;
  final Uint8List bytes;
}

class AdminApi {
  const AdminApi();

  Future<ActiveRuleResult?> getActiveRule(String token) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/rules/active');
    final response = await http.get(uri, headers: _authHeaders(token));
    final data = _parseJsonMap(response.body);

    if (response.statusCode == 200) {
      return ActiveRuleResult(
        latitude: _toDouble(data['latitude']) ?? 0,
        longitude: _toDouble(data['longitude']) ?? 0,
        radiusM: (data['radius_m'] as num?)?.toInt() ?? 0,
        startTime: data['start_time'] as String?,
        graceMinutes: (data['grace_minutes'] as num?)?.toInt(),
        endTime: data['end_time'] as String?,
        checkoutGraceMinutes: (data['checkout_grace_minutes'] as num?)?.toInt(),
      );
    }

    if (response.statusCode == 404) {
      return null;
    }

    throw Exception(_extractErrorMessage(data, 'Load active rule failed (${response.statusCode})'));
  }

  Future<ActiveRuleResult> updateActiveRule({
    required String token,
    required double latitude,
    required double longitude,
    required int radius,
    String? startTime,
    int? graceMinutes,
    String? endTime,
    int? checkoutGraceMinutes,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/rules/active');
    final body = <String, dynamic>{
      'latitude': latitude,
      'longitude': longitude,
      'radius_m': radius,
    };
    if (startTime != null && startTime.isNotEmpty) {
      body['start_time'] = startTime;
    }
    if (graceMinutes != null) {
      body['grace_minutes'] = graceMinutes;
    }
    if (endTime != null && endTime.isNotEmpty) {
      body['end_time'] = endTime;
    }
    if (checkoutGraceMinutes != null) {
      body['checkout_grace_minutes'] = checkoutGraceMinutes;
    }

    final response = await http.put(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode(body),
    );

    final data = _parseJsonMap(response.body);

    if (response.statusCode == 200) {
      return ActiveRuleResult(
        latitude: _toDouble(data['latitude']) ?? 0,
        longitude: _toDouble(data['longitude']) ?? 0,
        radiusM: (data['radius_m'] as num?)?.toInt() ?? 0,
        startTime: data['start_time'] as String?,
        graceMinutes: (data['grace_minutes'] as num?)?.toInt(),
        endTime: data['end_time'] as String?,
        checkoutGraceMinutes: (data['checkout_grace_minutes'] as num?)?.toInt(),
      );
    }

    throw Exception(_extractErrorMessage(data, 'Update rule failed (${response.statusCode})'));
  }

  Future<List<EmployeeLite>> listEmployees(String token) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/employees');
    final response = await http.get(uri, headers: _authHeaders(token));

    if (response.statusCode == 200) {
      final data = _parseJsonList(response.body);
      return data.whereType<Map<String, dynamic>>().map(_employeeFromMap).toList();
    }

    final data = _parseJsonMap(response.body);
    throw Exception(_extractErrorMessage(data, 'Load employees failed (${response.statusCode})'));
  }

  Future<EmployeeLite> createEmployee({
    required String token,
    required String code,
    required String fullName,
    int? userId,
    int? groupId,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/employees');
    final response = await http.post(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode({
        'code': code,
        'full_name': fullName,
        'user_id': userId,
        'group_id': groupId,
      }),
    );

    final data = _parseJsonMap(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return _employeeFromMap(data);
    }

    throw Exception(_extractErrorMessage(data, 'Create employee failed (${response.statusCode})'));
  }

  Future<List<UserLite>> listUsers(String token, {int limit = 300}) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/users?limit=$limit');
    final response = await http.get(uri, headers: _authHeaders(token));

    if (response.statusCode == 200) {
      final data = _parseJsonList(response.body);
      return data.whereType<Map<String, dynamic>>().map(
        (e) {
          return UserLite(
            id: (e['id'] as num?)?.toInt() ?? 0,
            email: e['email'] as String? ?? '-',
            role: e['role'] as String? ?? 'USER',
          );
        },
      ).toList();
    }

    final data = _parseJsonMap(response.body);
    throw Exception(_extractErrorMessage(data, 'Load users failed (${response.statusCode})'));
  }

  Future<EmployeeLite> assignEmployeeUser({
    required String token,
    required int employeeId,
    required int? userId,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/employees/$employeeId/assign-user');
    final response = await http.put(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode({'user_id': userId}),
    );

    final data = _parseJsonMap(response.body);

    if (response.statusCode == 200) {
      return _employeeFromMap(data);
    }

    throw Exception(_extractErrorMessage(data, 'Assign user failed (${response.statusCode})'));
  }

  Future<EmployeeLite> assignEmployeeGroup({
    required String token,
    required int employeeId,
    required int? groupId,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/employees/$employeeId/assign-group');
    final response = await http.put(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode({'group_id': groupId}),
    );

    final data = _parseJsonMap(response.body);

    if (response.statusCode == 200) {
      return _employeeFromMap(data);
    }

    throw Exception(_extractErrorMessage(data, 'Assign group failed (${response.statusCode})'));
  }
  Future<void> deleteEmployee({
    required String token,
    required int employeeId,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/employees/$employeeId');
    final response = await http.delete(uri, headers: _authHeaders(token));

    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    }

    final data = _parseJsonMap(response.body);
    throw Exception(_extractErrorMessage(data, 'Delete employee failed (${response.statusCode})'));
  }

  Future<List<GroupLite>> listGroups(String token, {bool activeOnly = false}) async {
    final query = activeOnly ? '?active_only=true' : '';
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/groups$query');
    final response = await http.get(uri, headers: _authHeaders(token));

    if (response.statusCode == 200) {
      final data = _parseJsonList(response.body);
      return data.whereType<Map<String, dynamic>>().map(_groupFromMap).toList();
    }

    final data = _parseJsonMap(response.body);
    throw Exception(_extractErrorMessage(data, 'Load groups failed (${response.statusCode})'));
  }

  Future<GroupLite> createGroup({
    required String token,
    required String code,
    required String name,
    bool active = true,
    String? startTime,
    int? graceMinutes,
    String? endTime,
    int? checkoutGraceMinutes,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/groups');
    final body = <String, dynamic>{
      'code': code,
      'name': name,
      'active': active,
    };
    if (startTime != null && startTime.isNotEmpty) {
      body['start_time'] = startTime;
    }
    if (graceMinutes != null) {
      body['grace_minutes'] = graceMinutes;
    }
    if (endTime != null && endTime.isNotEmpty) {
      body['end_time'] = endTime;
    }
    if (checkoutGraceMinutes != null) {
      body['checkout_grace_minutes'] = checkoutGraceMinutes;
    }

    final response = await http.post(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode(body),
    );

    final data = _parseJsonMap(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return _groupFromMap(data);
    }

    throw Exception(_extractErrorMessage(data, 'Create group failed (${response.statusCode})'));
  }

  Future<GroupLite> updateGroup({
    required String token,
    required int groupId,
    String? code,
    String? name,
    bool? active,
    String? startTime,
    int? graceMinutes,
    String? endTime,
    int? checkoutGraceMinutes,
    bool clearStartTime = false,
    bool clearGraceMinutes = false,
    bool clearEndTime = false,
    bool clearCheckoutGraceMinutes = false,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/groups/$groupId');
    final body = <String, dynamic>{};
    if (code != null) {
      body['code'] = code;
    }
    if (name != null) {
      body['name'] = name;
    }
    if (active != null) {
      body['active'] = active;
    }

    if (clearStartTime) {
      body['start_time'] = null;
    } else if (startTime != null && startTime.isNotEmpty) {
      body['start_time'] = startTime;
    }

    if (clearGraceMinutes) {
      body['grace_minutes'] = null;
    } else if (graceMinutes != null) {
      body['grace_minutes'] = graceMinutes;
    }

    if (clearEndTime) {
      body['end_time'] = null;
    } else if (endTime != null && endTime.isNotEmpty) {
      body['end_time'] = endTime;
    }

    if (clearCheckoutGraceMinutes) {
      body['checkout_grace_minutes'] = null;
    } else if (checkoutGraceMinutes != null) {
      body['checkout_grace_minutes'] = checkoutGraceMinutes;
    }

    final response = await http.put(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode(body),
    );

    final data = _parseJsonMap(response.body);

    if (response.statusCode == 200) {
      return _groupFromMap(data);
    }

    throw Exception(_extractErrorMessage(data, 'Update group failed (${response.statusCode})'));
  }
  Future<void> deleteGroup({
    required String token,
    required int groupId,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/groups/$groupId');
    final response = await http.delete(uri, headers: _authHeaders(token));

    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    }

    final data = _parseJsonMap(response.body);
    throw Exception(_extractErrorMessage(data, 'Delete group failed (${response.statusCode})'));
  }
  Future<List<GroupGeofenceLite>> listGroupGeofences({
    required String token,
    required int groupId,
    bool activeOnly = false,
  }) async {
    final query = activeOnly ? '?active_only=true' : '';
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/groups/$groupId/geofences$query');
    final response = await http.get(uri, headers: _authHeaders(token));

    if (response.statusCode == 200) {
      final data = _parseJsonList(response.body);
      return data.whereType<Map<String, dynamic>>().map(_groupGeofenceFromMap).toList();
    }

    final data = _parseJsonMap(response.body);
    throw Exception(_extractErrorMessage(data, 'Load geofences failed (${response.statusCode})'));
  }

  Future<GroupGeofenceLite> createGroupGeofence({
    required String token,
    required int groupId,
    required String name,
    required double latitude,
    required double longitude,
    required int radiusM,
    bool active = true,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/groups/$groupId/geofences');
    final response = await http.post(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode({
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'radius_m': radiusM,
        'active': active,
      }),
    );

    final data = _parseJsonMap(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return _groupGeofenceFromMap(data);
    }

    throw Exception(_extractErrorMessage(data, 'Create geofence failed (${response.statusCode})'));
  }

  Future<GroupGeofenceLite> updateGroupGeofence({
    required String token,
    required int groupId,
    required int geofenceId,
    String? name,
    double? latitude,
    double? longitude,
    int? radiusM,
    bool? active,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/groups/$groupId/geofences/$geofenceId');
    final body = <String, dynamic>{};
    if (name != null) {
      body['name'] = name;
    }
    if (latitude != null) {
      body['latitude'] = latitude;
    }
    if (longitude != null) {
      body['longitude'] = longitude;
    }
    if (radiusM != null) {
      body['radius_m'] = radiusM;
    }
    if (active != null) {
      body['active'] = active;
    }

    final response = await http.put(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode(body),
    );

    final data = _parseJsonMap(response.body);

    if (response.statusCode == 200) {
      return _groupGeofenceFromMap(data);
    }

    throw Exception(_extractErrorMessage(data, 'Update geofence failed (${response.statusCode})'));
  }

  Future<void> deleteGroupGeofence({
    required String token,
    required int groupId,
    required int geofenceId,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/groups/$groupId/geofences/$geofenceId');
    final response = await http.delete(uri, headers: _authHeaders(token));

    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    }

    final data = _parseJsonMap(response.body);
    throw Exception(_extractErrorMessage(data, 'Delete geofence failed (${response.statusCode})'));
  }

  Future<ReportDownloadResult> downloadAttendanceReport({
    required String token,
    DateTime? fromDate,
    DateTime? toDate,
    int? employeeId,
    int? groupId,
    bool includeEmpty = false,
  }) async {
    final query = <String, String>{};
    if (fromDate != null) {
      query['from'] = _formatDateOnly(fromDate);
    }
    if (toDate != null) {
      query['to'] = _formatDateOnly(toDate);
    }
    if (employeeId != null) {
      query['employee_id'] = employeeId.toString();
    }
    if (groupId != null) {
      query['group_id'] = groupId.toString();
    }
    if (includeEmpty) {
      query['include_empty'] = 'true';
    }

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/reports/attendance.xlsx')
        .replace(queryParameters: query.isEmpty ? null : query);
    final response = await http.get(uri, headers: _authHeaders(token));

    if (response.statusCode == 200) {
      final disposition = response.headers['content-disposition'];
      final fileName = _extractFilenameFromDisposition(disposition) ?? 'attendance_report.xlsx';
      return ReportDownloadResult(fileName: fileName, bytes: response.bodyBytes);
    }

    final bodyText = utf8.decode(response.bodyBytes, allowMalformed: true);
    final data = _parseJsonMap(bodyText);
    throw Exception(_extractErrorMessage(data, 'Export report failed (${response.statusCode})'));
  }

  EmployeeLite _employeeFromMap(Map<String, dynamic> e) {
    return EmployeeLite(
      id: (e['id'] as num?)?.toInt() ?? 0,
      code: e['code'] as String? ?? '-',
      fullName: e['full_name'] as String? ?? '-',
      userId: (e['user_id'] as num?)?.toInt(),
      groupId: (e['group_id'] as num?)?.toInt(),
    );
  }

  GroupLite _groupFromMap(Map<String, dynamic> e) {
    return GroupLite(
      id: (e['id'] as num?)?.toInt() ?? 0,
      code: e['code'] as String? ?? '-',
      name: e['name'] as String? ?? '-',
      active: e['active'] as bool? ?? true,
      startTime: e['start_time'] as String?,
      graceMinutes: (e['grace_minutes'] as num?)?.toInt(),
      endTime: e['end_time'] as String?,
      checkoutGraceMinutes: (e['checkout_grace_minutes'] as num?)?.toInt(),
    );
  }

  GroupGeofenceLite _groupGeofenceFromMap(Map<String, dynamic> e) {
    return GroupGeofenceLite(
      id: (e['id'] as num?)?.toInt() ?? 0,
      groupId: (e['group_id'] as num?)?.toInt() ?? 0,
      name: e['name'] as String? ?? '-',
      latitude: _toDouble(e['latitude']) ?? 0,
      longitude: _toDouble(e['longitude']) ?? 0,
      radiusM: (e['radius_m'] as num?)?.toInt() ?? 0,
      active: e['active'] as bool? ?? true,
    );
  }

  Map<String, String> _authHeaders(String token) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  String _formatDateOnly(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String? _extractFilenameFromDisposition(String? disposition) {
    if (disposition == null || disposition.isEmpty) {
      return null;
    }

    final utf8Match = RegExp(r"filename\*=UTF-8''([^;]+)", caseSensitive: false)
        .firstMatch(disposition);
    if (utf8Match != null) {
      return Uri.decodeComponent(utf8Match.group(1)!);
    }

    final normalMatch = RegExp(r'filename="?([^";]+)"?', caseSensitive: false)
        .firstMatch(disposition);
    if (normalMatch != null) {
      return normalMatch.group(1);
    }

    return null;
  }

  Map<String, dynamic> _parseJsonMap(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}
    return <String, dynamic>{};
  }

  List<dynamic> _parseJsonList(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is List<dynamic>) {
        return decoded;
      }
    } catch (_) {}
    return <dynamic>[];
  }

  String _extractErrorMessage(Map<String, dynamic> data, String fallback) {
    final error = data['error'];
    if (error is Map<String, dynamic>) {
      final message = error['message'] as String?;
      if (message != null && message.isNotEmpty) {
        return message;
      }
    }

    final detail = data['detail'];
    if (detail is String && detail.isNotEmpty) {
      return detail;
    }

    return fallback;
  }

  double? _toDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString());
  }
}












