import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';

/// Thrown when the backend returns HTTP 401 (token missing or expired).
/// Catch this to redirect the user to the login screen.
class UnauthorizedException implements Exception {
  const UnauthorizedException();
}

class ActiveRuleResult {
  const ActiveRuleResult({
    required this.latitude,
    required this.longitude,
    required this.radiusM,
    this.startTime,
    this.graceMinutes,
    this.endTime,
    this.checkoutGraceMinutes,
    this.crossDayCutoffMinutes,
  });

  final double latitude;
  final double longitude;
  final int radiusM;
  final String? startTime;
  final int? graceMinutes;
  final String? endTime;
  final int? checkoutGraceMinutes;
  final int? crossDayCutoffMinutes;
}

class ExceptionPolicy {
  const ExceptionPolicy({
    required this.defaultDeadlineHours,
    required this.gracePeriodDays,
    this.autoClosedDeadlineHours,
    this.missedCheckoutDeadlineHours,
    this.locationRiskDeadlineHours,
    this.largeTimeDeviationDeadlineHours,
    this.updatedAt,
    this.updatedByName,
  });

  final int defaultDeadlineHours;
  final int? autoClosedDeadlineHours;
  final int? missedCheckoutDeadlineHours;
  final int? locationRiskDeadlineHours;
  final int? largeTimeDeviationDeadlineHours;
  final int gracePeriodDays;
  final DateTime? updatedAt;
  final String? updatedByName;
}

class PurgeExpiredExceptionsResult {
  const PurgeExpiredExceptionsResult({
    required this.deletedCount,
    required this.expiredCount,
    required this.gracePeriodDays,
  });

  final int deletedCount;
  final int expiredCount;
  final int gracePeriodDays;
}

class EmployeeLite {
  const EmployeeLite({
    required this.id,
    required this.code,
    required this.fullName,
    this.userId,
    this.groupId,
    this.email,
    this.phone,
    this.departmentName,
    this.groupName,
    this.role,
    this.active,
    this.joinedAt,
    this.resignedAt,
  });

  final int id;
  final String code;
  final String fullName;
  final int? userId;
  final int? groupId;
  final String? email;
  final String? phone;
  final String? departmentName;
  final String? groupName;
  final String? role;
  final bool? active;
  final DateTime? joinedAt;
  // Non-null means the employee has resigned (soft-deleted).
  final DateTime? resignedAt;

  bool get isResigned => resignedAt != null;
}

class UserLite {
  const UserLite({
    required this.id,
    required this.email,
    required this.role,
    this.fullName,
    this.phone,
  });

  final int id;
  final String email;
  final String role;
  final String? fullName;
  final String? phone;
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
  const ReportDownloadResult({required this.fileName, required this.bytes});

  final String fileName;
  final Uint8List bytes;
}

class AttendanceExceptionItem {
  const AttendanceExceptionItem({
    required this.id,
    required this.employeeId,
    required this.employeeCode,
    required this.fullName,
    required this.workDate,
    required this.exceptionType,
    required this.status,
    required this.sourceCheckinLogId,
    this.groupCode,
    this.groupName,
    this.note,
    this.sourceCheckinTime,
    this.actualCheckoutTime,
    this.createdAt,
    this.resolvedAt,
    this.resolvedBy,
    this.resolvedByEmail,
    this.detectedAt,
    this.expiresAt,
    this.extendedDeadlineAt,
    this.employeeExplanation,
    this.employeeSubmittedAt,
    this.adminNote,
    this.adminDecidedAt,
    this.decidedByEmail,
    this.canAdminDecide = false,
    this.timeline = const <Map<String, dynamic>>[],
  });

  final int id;
  final int employeeId;
  final String employeeCode;
  final String fullName;
  final String? groupCode;
  final String? groupName;
  final DateTime workDate;
  final String exceptionType;
  final String status;
  final String? note;
  final int sourceCheckinLogId;
  final DateTime? sourceCheckinTime;
  final DateTime? actualCheckoutTime;
  final DateTime? createdAt;
  final DateTime? resolvedAt;
  final int? resolvedBy;
  final String? resolvedByEmail;
  final DateTime? detectedAt;
  final DateTime? expiresAt;
  final DateTime? extendedDeadlineAt;
  final String? employeeExplanation;
  final DateTime? employeeSubmittedAt;
  final String? adminNote;
  final DateTime? adminDecidedAt;
  final String? decidedByEmail;
  final bool canAdminDecide;
  final List<Map<String, dynamic>> timeline;

  DateTime? get effectiveDeadline => extendedDeadlineAt ?? expiresAt;
}

class DashboardSummaryResult {
  const DashboardSummaryResult({
    required this.totalEmployees,
    required this.checkedIn,
    required this.attendanceRatePercent,
    required this.lateCount,
    required this.lateRatePercent,
    required this.outOfRangeCount,
    required this.geofenceCount,
    required this.inactiveGeofenceCount,
    required this.employeeGrowthPercent,
  });

  final int totalEmployees;
  final int checkedIn;
  final double attendanceRatePercent;
  final int lateCount;
  final double lateRatePercent;
  final int outOfRangeCount;
  final int geofenceCount;
  final int inactiveGeofenceCount;
  final double employeeGrowthPercent;
}

class DashboardAttendanceLogItem {
  const DashboardAttendanceLogItem({
    required this.id,
    required this.employeeName,
    required this.employeeCode,
    required this.departmentName,
    required this.workDate,
    required this.checkInTime,
    required this.checkOutTime,
    required this.totalHours,
    required this.locationStatus,
    required this.attendanceStatus,
    this.checkInLat,
    this.checkInLng,
    this.checkOutLat,
    this.checkOutLng,
    this.entryCount,
  });

  final int id;
  final String employeeName;
  final String employeeCode;
  final String departmentName;
  final DateTime? workDate;
  final String checkInTime;
  final String checkOutTime;
  final String totalHours;
  final String locationStatus;
  final String attendanceStatus;
  final double? checkInLat;
  final double? checkInLng;
  final double? checkOutLat;
  final double? checkOutLng;
  final int? entryCount;
}

class DashboardWeeklyTrendItem {
  const DashboardWeeklyTrendItem({
    required this.day,
    required this.onTime,
    required this.late,
    required this.outOfRange,
  });

  final String day;
  final int onTime;
  final int late;
  final int outOfRange;
}

class DashboardGeofenceItem {
  const DashboardGeofenceItem({
    required this.id,
    required this.name,
    required this.memberCount,
    required this.active,
    this.latitude,
    this.longitude,
    this.radiusMeters,
    this.presentCount,
    this.groupId,
    this.groupName,
    this.startTime,
    this.endTime,
    this.overtimeEnabled,
    this.overtimeStartTime,
    this.address,
  });

  final int id;
  final String name;
  final int memberCount;
  final bool active;
  final double? latitude;
  final double? longitude;
  final int? radiusMeters;
  final int? presentCount;
  final int? groupId;
  final String? groupName;
  final String? startTime;
  final String? endTime;
  final bool? overtimeEnabled;
  final String? overtimeStartTime;
  final String? address;
}

class GeoPlaceSuggestion {
  const GeoPlaceSuggestion({
    required this.formatted,
    required this.latitude,
    required this.longitude,
  });

  final String formatted;
  final double latitude;
  final double longitude;
}

class DashboardExceptionItem {
  const DashboardExceptionItem({
    required this.id,
    required this.initials,
    required this.name,
    required this.reason,
    required this.timeLabel,
    required this.status,
  });

  final int id;
  final String initials;
  final String name;
  final String reason;
  final String timeLabel;
  final String status;
}

class AdminApi {
  const AdminApi();

  Future<ActiveRuleResult?> getActiveRule(String token) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/rules/active');
    final response = await http.get(uri, headers: _authHeaders(token));
    final data = _parseResponse(response);

    if (response.statusCode == 200) {
      return ActiveRuleResult(
        latitude: _toDouble(data['latitude']) ?? 0,
        longitude: _toDouble(data['longitude']) ?? 0,
        radiusM: (data['radius_m'] as num?)?.toInt() ?? 0,
        startTime: data['start_time'] as String?,
        graceMinutes: (data['grace_minutes'] as num?)?.toInt(),
        endTime: data['end_time'] as String?,
        checkoutGraceMinutes: (data['checkout_grace_minutes'] as num?)?.toInt(),
        crossDayCutoffMinutes: (data['cross_day_cutoff_minutes'] as num?)
            ?.toInt(),
      );
    }

    if (response.statusCode == 404) {
      return null;
    }

    throw Exception(
      _extractErrorMessage(
        data,
        'Load active rule failed (${response.statusCode})',
      ),
    );
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
    int? crossDayCutoffMinutes,
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
    if (crossDayCutoffMinutes != null) {
      body['cross_day_cutoff_minutes'] = crossDayCutoffMinutes;
    }

    final response = await http.put(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode(body),
    );

    final data = _parseResponse(response);

    if (response.statusCode == 200) {
      return ActiveRuleResult(
        latitude: _toDouble(data['latitude']) ?? 0,
        longitude: _toDouble(data['longitude']) ?? 0,
        radiusM: (data['radius_m'] as num?)?.toInt() ?? 0,
        startTime: data['start_time'] as String?,
        graceMinutes: (data['grace_minutes'] as num?)?.toInt(),
        endTime: data['end_time'] as String?,
        checkoutGraceMinutes: (data['checkout_grace_minutes'] as num?)?.toInt(),
        crossDayCutoffMinutes: (data['cross_day_cutoff_minutes'] as num?)
            ?.toInt(),
      );
    }

    throw Exception(
      _extractErrorMessage(data, 'Update rule failed (${response.statusCode})'),
    );
  }

  Future<ExceptionPolicy> getExceptionPolicy(String token) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/rules/exception-policy');
    final response = await http.get(uri, headers: _authHeaders(token));
    final data = _parseResponseBytes(response);

    if (response.statusCode == 200) {
      return _exceptionPolicyFromMap(_extractPayloadMap(data));
    }

    throw Exception(
      _extractErrorMessage(
        data,
        'Load exception policy failed (${response.statusCode})',
      ),
    );
  }

  Future<ExceptionPolicy> patchExceptionPolicy({
    required String token,
    required int defaultDeadlineHours,
    required int gracePeriodDays,
    int? autoClosedDeadlineHours,
    int? missedCheckoutDeadlineHours,
    int? locationRiskDeadlineHours,
    int? largeTimeDeviationDeadlineHours,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/rules/exception-policy');
    final response = await http.patch(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode(<String, dynamic>{
        'default_deadline_hours': defaultDeadlineHours,
        'auto_closed_deadline_hours': autoClosedDeadlineHours,
        'missed_checkout_deadline_hours': missedCheckoutDeadlineHours,
        'location_risk_deadline_hours': locationRiskDeadlineHours,
        'large_time_deviation_deadline_hours': largeTimeDeviationDeadlineHours,
        'grace_period_days': gracePeriodDays,
      }),
    );
    final data = _parseResponseBytes(response);

    if (response.statusCode == 200) {
      return _exceptionPolicyFromMap(_extractPayloadMap(data));
    }

    throw Exception(
      _extractErrorMessage(
        data,
        'Update exception policy failed (${response.statusCode})',
      ),
    );
  }

  Future<PurgeExpiredExceptionsResult> purgeExpiredExceptions({
    required String token,
  }) async {
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/reports/attendance-exceptions/purge-expired',
    );
    final response = await http.post(uri, headers: _authHeaders(token));
    final data = _parseResponseBytes(response);

    if (response.statusCode == 200) {
      return PurgeExpiredExceptionsResult(
        deletedCount: _toInt(data['deleted_count']) ?? 0,
        expiredCount: _toInt(data['expired_count']) ?? 0,
        gracePeriodDays: _toInt(data['grace_period_days']) ?? 30,
      );
    }

    throw Exception(
      _extractErrorMessage(
        data,
        'Purge expired exceptions failed (${response.statusCode})',
      ),
    );
  }

  Future<List<EmployeeLite>> listEmployees(
    String token, {
    String? query,
    int? groupId,
    String? status,
  }) async {
    final queryMap = <String, String>{};
    if (query != null && query.trim().isNotEmpty) {
      queryMap['q'] = query.trim();
    }
    if (groupId != null) {
      queryMap['group_id'] = groupId.toString();
    }
    if (status != null && status.isNotEmpty && status != 'all') {
      queryMap['status'] = status;
    }
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/employees',
    ).replace(queryParameters: queryMap.isEmpty ? null : queryMap);
    final response = await http.get(uri, headers: _authHeaders(token));

    if (response.statusCode == 200) {
      final data = _parseJsonList(response.body);
      return data
          .whereType<Map<String, dynamic>>()
          .map(_employeeFromMap)
          .toList();
    }

    final data = _parseResponse(response);
    throw Exception(
      _extractErrorMessage(
        data,
        'Load employees failed (${response.statusCode})',
      ),
    );
  }

  Future<EmployeeLite> createEmployee({
    required String token,
    required String code,
    required String fullName,
    String? phone,
    int? userId,
    int? groupId,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/employees');
    final body = <String, dynamic>{
      'code': code,
      'full_name': fullName,
      'user_id': userId,
      'group_id': groupId,
    };
    if (phone != null && phone.trim().isNotEmpty) {
      body['phone'] = phone.trim();
    }

    final response = await http.post(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode(body),
    );

    final data = _parseResponse(response);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return _employeeFromMap(data);
    }

    throw Exception(
      _extractErrorMessage(
        data,
        'Create employee failed (${response.statusCode})',
      ),
    );
  }

  Future<List<UserLite>> listUsers(String token, {int limit = 300}) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/users?limit=$limit');
    final response = await http.get(uri, headers: _authHeaders(token));

    if (response.statusCode == 200) {
      final data = _parseJsonList(response.body);
      return data.whereType<Map<String, dynamic>>().map((e) {
        return UserLite(
          id: (e['id'] as num?)?.toInt() ?? 0,
          email: e['email'] as String? ?? '-',
          role: e['role'] as String? ?? 'USER',
          fullName: e['full_name'] as String?,
          phone: e['phone'] as String?,
        );
      }).toList();
    }

    final data = _parseResponse(response);
    throw Exception(
      _extractErrorMessage(data, 'Load users failed (${response.statusCode})'),
    );
  }

  Future<EmployeeLite> assignEmployeeUser({
    required String token,
    required int employeeId,
    required int? userId,
  }) async {
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/employees/$employeeId/assign-user',
    );
    final response = await http.put(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode({'user_id': userId}),
    );

    final data = _parseResponse(response);

    if (response.statusCode == 200) {
      return _employeeFromMap(data);
    }

    throw Exception(
      _extractErrorMessage(data, 'Assign user failed (${response.statusCode})'),
    );
  }

  Future<EmployeeLite> assignEmployeeGroup({
    required String token,
    required int employeeId,
    required int? groupId,
  }) async {
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/employees/$employeeId/assign-group',
    );
    final response = await http.put(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode({'group_id': groupId}),
    );

    final data = _parseResponse(response);

    if (response.statusCode == 200) {
      return _employeeFromMap(data);
    }

    throw Exception(
      _extractErrorMessage(
        data,
        'Assign group failed (${response.statusCode})',
      ),
    );
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

    final data = _parseResponse(response);
    throw Exception(
      _extractErrorMessage(
        data,
        'Delete employee failed (${response.statusCode})',
      ),
    );
  }

  Future<EmployeeLite> restoreEmployee({
    required String token,
    required int employeeId,
  }) async {
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/employees/$employeeId/restore',
    );
    final response = await http.put(uri, headers: _authHeaders(token));
    final data = _parseResponse(response);
    if (response.statusCode == 200) {
      return _employeeFromMap(data);
    }
    throw Exception(
      _extractErrorMessage(
        data,
        'Restore employee failed (${response.statusCode})',
      ),
    );
  }

  Future<List<GroupLite>> listGroups(
    String token, {
    bool activeOnly = false,
  }) async {
    final query = activeOnly ? '?active_only=true' : '';
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/groups$query');
    final response = await http.get(uri, headers: _authHeaders(token));

    if (response.statusCode == 200) {
      final data = _parseJsonList(response.body);
      return data.whereType<Map<String, dynamic>>().map(_groupFromMap).toList();
    }

    final data = _parseResponse(response);
    throw Exception(
      _extractErrorMessage(data, 'Load groups failed (${response.statusCode})'),
    );
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

    final data = _parseResponse(response);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return _groupFromMap(data);
    }

    throw Exception(
      _extractErrorMessage(
        data,
        'Create group failed (${response.statusCode})',
      ),
    );
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

    final data = _parseResponse(response);

    if (response.statusCode == 200) {
      return _groupFromMap(data);
    }

    throw Exception(
      _extractErrorMessage(
        data,
        'Update group failed (${response.statusCode})',
      ),
    );
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

    final data = _parseResponse(response);
    throw Exception(
      _extractErrorMessage(
        data,
        'Delete group failed (${response.statusCode})',
      ),
    );
  }

  Future<List<GroupGeofenceLite>> listGroupGeofences({
    required String token,
    required int groupId,
    bool activeOnly = false,
  }) async {
    final query = activeOnly ? '?active_only=true' : '';
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/groups/$groupId/geofences$query',
    );
    final response = await http.get(uri, headers: _authHeaders(token));

    if (response.statusCode == 200) {
      final data = _parseJsonList(response.body);
      return data
          .whereType<Map<String, dynamic>>()
          .map(_groupGeofenceFromMap)
          .toList();
    }

    final data = _parseResponse(response);
    throw Exception(
      _extractErrorMessage(
        data,
        'Load geofences failed (${response.statusCode})',
      ),
    );
  }

  /// Aggregate endpoint — fetches all group geofences in a single request.
  /// Returns a map of groupId -> list of geofences.
  /// Groups with no geofences are absent from the map (treat as empty list).
  Future<Map<int, List<GroupGeofenceLite>>> listGroupGeofencesSummary({
    required String token,
    List<int>? groupIds,
    bool activeOnly = false,
  }) async {
    final params = <String, String>{};
    if (groupIds != null && groupIds.isNotEmpty) {
      params['group_ids'] = groupIds.join(',');
    }
    if (activeOnly) params['active_only'] = 'true';
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/groups/geofences/summary',
    ).replace(queryParameters: params.isEmpty ? null : params);
    final response = await http.get(uri, headers: _authHeaders(token));
    if (response.statusCode == 200) {
      final raw = _parseJsonMap(
        utf8.decode(response.bodyBytes, allowMalformed: true),
      );
      final result = <int, List<GroupGeofenceLite>>{};
      raw.forEach((key, value) {
        final groupId = int.tryParse(key.toString());
        if (groupId == null) return;
        final list = value is List ? value : <dynamic>[];
        result[groupId] = list
            .whereType<Map<String, dynamic>>()
            .map(_groupGeofenceFromMap)
            .toList(growable: false);
      });
      return result;
    }
    final data = _parseResponse(response);
    throw Exception(
      _extractErrorMessage(
        data,
        'Load geofences summary failed (${response.statusCode})',
      ),
    );
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

    final data = _parseResponse(response);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return _groupGeofenceFromMap(data);
    }

    throw Exception(
      _extractErrorMessage(
        data,
        'Create geofence failed (${response.statusCode})',
      ),
    );
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
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/groups/$groupId/geofences/$geofenceId',
    );
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

    final data = _parseResponse(response);

    if (response.statusCode == 200) {
      return _groupGeofenceFromMap(data);
    }

    throw Exception(
      _extractErrorMessage(
        data,
        'Update geofence failed (${response.statusCode})',
      ),
    );
  }

  Future<void> deleteGroupGeofence({
    required String token,
    required int groupId,
    required int geofenceId,
  }) async {
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/groups/$groupId/geofences/$geofenceId',
    );
    final response = await http.delete(uri, headers: _authHeaders(token));

    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    }

    final data = _parseResponse(response);
    throw Exception(
      _extractErrorMessage(
        data,
        'Delete geofence failed (${response.statusCode})',
      ),
    );
  }

  Future<ReportDownloadResult> downloadAttendanceReport({
    required String token,
    DateTime? fromDate,
    DateTime? toDate,
    int? employeeId,
    int? groupId,
    String? status,
    String? search,
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
    if (status != null && status.isNotEmpty && status != 'all') {
      query['status'] = status;
    }
    if (search != null && search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }
    if (includeEmpty) {
      query['include_empty'] = 'true';
    }

    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/reports/attendance.xlsx',
    ).replace(queryParameters: query.isEmpty ? null : query);
    final response = await http.get(uri, headers: _authHeaders(token));

    if (response.statusCode == 200) {
      final disposition = response.headers['content-disposition'];
      final fileName =
          _extractFilenameFromDisposition(disposition) ??
          'attendance_report.xlsx';
      return ReportDownloadResult(
        fileName: fileName,
        bytes: response.bodyBytes,
      );
    }

    if (response.statusCode == 401) throw const UnauthorizedException();
    final bodyText = utf8.decode(response.bodyBytes, allowMalformed: true);
    final data = _parseJsonMap(bodyText);
    throw Exception(
      _extractErrorMessage(
        data,
        'Export report failed (${response.statusCode})',
      ),
    );
  }

  Future<List<AttendanceExceptionItem>> listAttendanceExceptions({
    required String token,
    DateTime? fromDate,
    DateTime? toDate,
    int? employeeId,
    int? groupId,
    String? exceptionType,
    String? statusFilter,
  }) async {
    final query = <String, String>{};
    if (exceptionType != null && exceptionType.isNotEmpty) {
      query['exception_type'] = exceptionType;
    }
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
    if (statusFilter != null && statusFilter.isNotEmpty) {
      query['status'] = statusFilter;
    }

    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/reports/attendance-exceptions',
    ).replace(queryParameters: query);
    final response = await http.get(uri, headers: _authHeaders(token));

    if (response.statusCode == 200) {
      final data = _parseJsonListAny(
        utf8.decode(response.bodyBytes, allowMalformed: true),
      );
      return data
          .whereType<Map<String, dynamic>>()
          .map(_attendanceExceptionFromMap)
          .toList(growable: false);
    }

    final data = _parseResponse(response);
    throw Exception(
      _extractErrorMessage(
        data,
        'Load attendance exceptions failed (${response.statusCode})',
      ),
    );
  }

  Future<AttendanceExceptionItem> getAttendanceExceptionDetail({
    required String token,
    required int exceptionId,
  }) async {
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/reports/attendance-exceptions/$exceptionId',
    );
    final response = await http.get(uri, headers: _authHeaders(token));
    final data = _parseResponseBytes(response);

    if (response.statusCode == 200) {
      return _attendanceExceptionFromMap(_extractPayloadMap(data));
    }

    throw Exception(
      _extractErrorMessage(
        data,
        'Load attendance exception detail failed (${response.statusCode})',
      ),
    );
  }

  Future<AttendanceExceptionItem> approveAttendanceException({
    required String token,
    required int exceptionId,
    String? adminNote,
    DateTime? actualCheckoutTime,
  }) async {
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/reports/attendance-exceptions/$exceptionId/approve',
    );
    final body = <String, dynamic>{};
    final note = adminNote?.trim();
    if (note != null && note.isNotEmpty) {
      body['admin_note'] = note;
    }
    if (actualCheckoutTime != null) {
      body['actual_checkout_time'] = actualCheckoutTime
          .toUtc()
          .toIso8601String();
    }

    final response = await http.post(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode(body),
    );
    if (response.statusCode == 204) {
      return getAttendanceExceptionDetail(
        token: token,
        exceptionId: exceptionId,
      );
    }

    final data = _parseResponseBytes(response);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return _attendanceExceptionFromMap(_extractPayloadMap(data));
    }

    throw Exception(
      _extractErrorMessage(
        data,
        'Approve attendance exception failed (${response.statusCode})',
      ),
    );
  }

  Future<AttendanceExceptionItem> rejectAttendanceException({
    required String token,
    required int exceptionId,
    required String adminNote,
  }) async {
    final note = adminNote.trim();
    if (note.isEmpty) {
      throw ArgumentError('admin_note is required to reject exception');
    }

    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/reports/attendance-exceptions/$exceptionId/reject',
    );
    final response = await http.post(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode(<String, dynamic>{'admin_note': note}),
    );
    if (response.statusCode == 204) {
      return getAttendanceExceptionDetail(
        token: token,
        exceptionId: exceptionId,
      );
    }

    final data = _parseResponseBytes(response);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return _attendanceExceptionFromMap(_extractPayloadMap(data));
    }

    throw Exception(
      _extractErrorMessage(
        data,
        'Reject attendance exception failed (${response.statusCode})',
      ),
    );
  }

  Future<AttendanceExceptionItem> extendExceptionDeadline({
    required String token,
    required int exceptionId,
    required int extendHours,
  }) async {
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/reports/attendance-exceptions/$exceptionId/extend-deadline',
    );
    final response = await http.patch(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode(<String, dynamic>{'extend_hours': extendHours}),
    );
    if (response.statusCode == 204) {
      return getAttendanceExceptionDetail(
        token: token,
        exceptionId: exceptionId,
      );
    }

    final data = _parseResponseBytes(response);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return _attendanceExceptionFromMap(_extractPayloadMap(data));
    }

    throw Exception(
      _extractErrorMessage(
        data,
        'Extend attendance exception deadline failed (${response.statusCode})',
      ),
    );
  }

  Future<AttendanceExceptionItem> resolveAttendanceException({
    required String token,
    required int exceptionId,
    String? note,
    DateTime? actualCheckoutTime,
  }) async {
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/reports/attendance-exceptions/$exceptionId/resolve',
    );
    final body = <String, dynamic>{};
    if (note != null && note.trim().isNotEmpty) {
      body['note'] = note.trim();
    }
    if (actualCheckoutTime != null) {
      body['actual_checkout_time'] = actualCheckoutTime.toIso8601String();
    }

    final response = await http.patch(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode(body),
    );

    final data = _parseResponse(response);
    if (response.statusCode == 200) {
      return _attendanceExceptionFromMap(data);
    }

    throw Exception(
      _extractErrorMessage(
        data,
        'Resolve attendance exception failed (${response.statusCode})',
      ),
    );
  }

  Future<AttendanceExceptionItem> reopenAttendanceException({
    required String token,
    required int exceptionId,
    String? note,
  }) async {
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/reports/attendance-exceptions/$exceptionId/reopen',
    );
    final body = <String, dynamic>{};
    if (note != null && note.trim().isNotEmpty) {
      body['note'] = note.trim();
    }

    final response = await http.patch(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode(body),
    );

    final data = _parseResponse(response);
    if (response.statusCode == 200) {
      return _attendanceExceptionFromMap(data);
    }

    throw Exception(
      _extractErrorMessage(
        data,
        'Reopen attendance exception failed (${response.statusCode})',
      ),
    );
  }

  Future<EmployeeLite> patchEmployee({
    required String token,
    required int employeeId,
    String? fullName,
    int? groupId,
    bool setGroupId =
        false, // pass true to send group_id (even when null = unassign)
    int? userId,
    bool setUserId =
        false, // pass true to send user_id (even when null = unassign)
    String? email,
    String? phone,
    String? departmentName,
    String? role,
    bool? active,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/employees/$employeeId');
    final body = <String, dynamic>{};
    if (fullName != null) {
      body['full_name'] = fullName;
    }
    if (phone != null) {
      body['phone'] = phone;
    }
    // Only include group_id / user_id when the caller explicitly opts in,
    // so callers that only change `active` don't accidentally unlink the account.
    if (setGroupId) {
      body['group_id'] = groupId;
    }
    if (setUserId) {
      body['user_id'] = userId;
    }
    if (active != null) {
      body['active'] = active;
    }

    final response = await http.put(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode(body),
    );
    final data = _parseResponse(response);
    if (response.statusCode == 200) {
      return _employeeFromMap(data);
    }
    throw Exception(
      _extractErrorMessage(
        data,
        'Update employee failed (${response.statusCode})',
      ),
    );
  }

  Future<DashboardSummaryResult> getDashboardSummary({
    required String token,
    required DateTime date,
    int? groupId,
    String? status,
  }) async {
    final query = <String, String>{'date': _formatDateOnly(date)};
    if (groupId != null) {
      query['group_id'] = groupId.toString();
    }
    if (status != null && status.isNotEmpty && status != 'all') {
      query['status'] = status;
    }

    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/reports/dashboard',
    ).replace(queryParameters: query);
    final response = await http.get(uri, headers: _authHeaders(token));
    final data = _parseResponseBytes(response);
    if (response.statusCode == 200) {
      final payload = _extractPayloadMap(data);
      return DashboardSummaryResult(
        totalEmployees: _toInt(payload['total_employees']) ?? 0,
        checkedIn: _toInt(payload['checked_in']) ?? 0,
        attendanceRatePercent: _toDouble(payload['attendance_rate']) ?? 0,
        lateCount: _toInt(payload['late_count']) ?? 0,
        lateRatePercent: _toDouble(payload['late_rate']) ?? 0,
        outOfRangeCount: _toInt(payload['out_of_range_count']) ?? 0,
        geofenceCount: _toInt(payload['geofence_count']) ?? 0,
        inactiveGeofenceCount: _toInt(payload['inactive_geofence_count']) ?? 0,
        employeeGrowthPercent:
            _toDouble(payload['employee_growth_percent']) ?? 0,
      );
    }
    throw Exception(
      _extractErrorMessage(
        data,
        'Load dashboard summary failed (${response.statusCode})',
      ),
    );
  }

  Future<({List<DashboardAttendanceLogItem> items, int total})>
  listDashboardAttendanceLogs({
    required String token,
    DateTime? date,
    DateTime? fromDate,
    DateTime? toDate,
    int? groupId,
    String? status,
    String? search,
    String? sort,
    int? page,
    int? limit,
  }) async {
    final query = <String, String>{};
    if (date != null) {
      query['date'] = _formatDateOnly(date);
    }
    if (fromDate != null) {
      query['from'] = _formatDateOnly(fromDate);
    }
    if (toDate != null) {
      query['to'] = _formatDateOnly(toDate);
    }
    if (groupId != null) {
      query['group_id'] = groupId.toString();
    }
    if (status != null && status.isNotEmpty && status != 'all') {
      query['status'] = status;
    }
    if (search != null && search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }
    if (sort != null && sort.trim().isNotEmpty) {
      query['sort'] = sort.trim();
    }
    if (page != null && page > 0) {
      query['page'] = page.toString();
    }
    if (limit != null && limit > 0) {
      query['limit'] = limit.toString();
    }
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/reports/attendance-logs',
    ).replace(queryParameters: query);
    final response = await http.get(uri, headers: _authHeaders(token));
    if (response.statusCode == 200) {
      final envelope = _parseJsonMap(
        utf8.decode(response.bodyBytes, allowMalformed: true),
      );
      final dataRaw = envelope['data'];
      final rows = dataRaw is List ? dataRaw : <dynamic>[];
      final total = _toInt(envelope['total']) ?? 0;
      final items = rows
          .whereType<Map<String, dynamic>>()
          .map((e) {
            return DashboardAttendanceLogItem(
              id: _toInt(e['id']) ?? 0,
              employeeName:
                  e['employee_name'] as String? ??
                  e['full_name'] as String? ??
                  '-',
              employeeCode:
                  e['employee_code'] as String? ?? e['code'] as String? ?? '-',
              departmentName:
                  e['department_name'] as String? ??
                  e['group_name'] as String? ??
                  '-',
              workDate:
                  _toDateTime(e['work_date']) ??
                  _toDateTime(e['date']) ??
                  _toDateTime(e['log_date']),
              checkInTime: _toClockLabel(
                e['check_in_time'] ?? e['checkin_time'],
              ),
              checkOutTime: _toClockLabel(
                e['check_out_time'] ?? e['checkout_time'],
              ),
              totalHours:
                  e['total_hours']?.toString() ??
                  e['work_hours']?.toString() ??
                  '--',
              locationStatus: (e['location_status'] as String? ?? 'inside')
                  .toLowerCase(),
              attendanceStatus:
                  (e['status'] as String? ??
                          e['attendance_status'] as String? ??
                          'on_time')
                      .toLowerCase(),
              checkInLat: _toDouble(e['checkin_lat']),
              checkInLng: _toDouble(e['checkin_lng']),
              checkOutLat: _toDouble(e['checkout_lat']),
              checkOutLng: _toDouble(e['checkout_lng']),
              entryCount: _toInt(e['count']) ?? _toInt(e['entry_count']),
            );
          })
          .toList(growable: false);
      return (items: items, total: total);
    }
    final data = _parseResponseBytes(response);
    throw Exception(
      _extractErrorMessage(
        data,
        'Load attendance logs failed (${response.statusCode})',
      ),
    );
  }

  Future<List<DashboardWeeklyTrendItem>> getDashboardWeeklyTrends({
    required String token,
    required DateTime date,
    int? groupId,
    String? status,
    String? period,
  }) async {
    final query = <String, String>{'date': _formatDateOnly(date)};
    if (groupId != null) {
      query['group_id'] = groupId.toString();
    }
    if (status != null && status.isNotEmpty && status != 'all') {
      query['status'] = status;
    }
    if (period != null && period.trim().isNotEmpty) {
      query['period'] = period.trim();
    }

    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/reports/weekly-trends',
    ).replace(queryParameters: query);
    final response = await http.get(uri, headers: _authHeaders(token));
    if (response.statusCode == 200) {
      final rows = _parseJsonListAny(
        utf8.decode(response.bodyBytes, allowMalformed: true),
      );
      return rows
          .whereType<Map<String, dynamic>>()
          .map((e) {
            return DashboardWeeklyTrendItem(
              day: e['day'] as String? ?? e['day_label'] as String? ?? '-',
              onTime: _toInt(e['on_time']) ?? _toInt(e['on_time_count']) ?? 0,
              late: _toInt(e['late']) ?? 0,
              outOfRange: _toInt(e['out_of_range']) ?? _toInt(e['oor']) ?? 0,
            );
          })
          .toList(growable: false);
    }
    final data = _parseResponseBytes(response);
    throw Exception(
      _extractErrorMessage(
        data,
        'Load weekly trends failed (${response.statusCode})',
      ),
    );
  }

  Future<List<DashboardGeofenceItem>> listDashboardGeofences({
    required String token,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/geofence/list');
    final response = await http.get(uri, headers: _authHeaders(token));
    if (response.statusCode == 200) {
      final rows = _parseJsonListAny(
        utf8.decode(response.bodyBytes, allowMalformed: true),
      );
      return rows
          .whereType<Map<String, dynamic>>()
          .map(_dashboardGeofenceFromMap)
          .toList(growable: false);
    }
    final data = _parseResponseBytes(response);
    throw Exception(
      _extractErrorMessage(
        data,
        'Load geofence list failed (${response.statusCode})',
      ),
    );
  }

  Future<List<GeoPlaceSuggestion>> searchGeoapifyPlaces({
    required String query,
    int limit = 6,
  }) async {
    final text = query.trim();
    if (text.isEmpty || AppConfig.geoapifyApiKey.trim().isEmpty) {
      return const [];
    }
    final uri = Uri.https('api.geoapify.com', '/v1/geocode/autocomplete', {
      'text': text,
      'limit': '$limit',
      'lang': 'vi',
      'apiKey': AppConfig.geoapifyApiKey,
    });
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final data = _parseJsonMap(
        utf8.decode(response.bodyBytes, allowMalformed: true),
      );
      final features = data['features'];
      if (features is List) {
        return features
            .whereType<Map<String, dynamic>>()
            .map((feature) {
              final properties = feature['properties'];
              final geometry = feature['geometry'];
              final coordinates = geometry is Map<String, dynamic>
                  ? geometry['coordinates']
                  : null;
              final lon = coordinates is List && coordinates.isNotEmpty
                  ? _toDouble(coordinates[0])
                  : null;
              final lat = coordinates is List && coordinates.length > 1
                  ? _toDouble(coordinates[1])
                  : null;
              final formatted = properties is Map<String, dynamic>
                  ? properties['formatted'] as String?
                  : null;
              if (lat == null ||
                  lon == null ||
                  formatted == null ||
                  formatted.isEmpty) {
                return null;
              }
              return GeoPlaceSuggestion(
                formatted: formatted,
                latitude: lat,
                longitude: lon,
              );
            })
            .whereType<GeoPlaceSuggestion>()
            .toList(growable: false);
      }
      return const [];
    }
    return const [];
  }

  Future<String?> reverseGeocodeAddress({
    required String token,
    required double latitude,
    required double longitude,
  }) async {
    if (AppConfig.geoapifyApiKey.trim().isEmpty) {
      return null;
    }
    final uri = Uri.https('api.geoapify.com', '/v1/geocode/reverse', {
      'lat': latitude.toString(),
      'lon': longitude.toString(),
      'apiKey': AppConfig.geoapifyApiKey,
    });
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      return null;
    }
    final data = _parseResponseBytes(response);
    final features = data['features'];
    if (features is List && features.isNotEmpty) {
      final first = features.first;
      if (first is Map<String, dynamic>) {
        final properties = first['properties'];
        if (properties is Map<String, dynamic>) {
          final formatted = properties['formatted'] as String?;
          if (formatted != null && formatted.trim().isNotEmpty) {
            return formatted.trim();
          }
        }
      }
    }
    return null;
  }

  Future<List<DashboardExceptionItem>> listDashboardExceptions({
    required String token,
    String status = 'PENDING_ADMIN',
  }) async {
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/reports/exceptions',
    ).replace(queryParameters: {'status': status});
    final response = await http.get(uri, headers: _authHeaders(token));
    if (response.statusCode == 200) {
      final rows = _parseJsonListAny(
        utf8.decode(response.bodyBytes, allowMalformed: true),
      );
      return rows
          .whereType<Map<String, dynamic>>()
          .map((e) {
            final name =
                e['name'] as String? ??
                e['employee_name'] as String? ??
                e['full_name'] as String? ??
                '-';
            final initials = _nameToInitials(name);
            return DashboardExceptionItem(
              id: _toInt(e['id']) ?? 0,
              initials: initials,
              name: name,
              reason:
                  e['reason'] as String? ??
                  e['exception_type'] as String? ??
                  '-',
              timeLabel: _toClockLabel(e['time'] ?? e['created_at']),
              status: e['status']?.toString() ?? status,
            );
          })
          .toList(growable: false);
    }
    final data = _parseResponseBytes(response);
    throw Exception(
      _extractErrorMessage(
        data,
        'Load dashboard exceptions failed (${response.statusCode})',
      ),
    );
  }

  Future<ReportDownloadResult> exportDashboardExcel({
    required String token,
    required DateTime fromDate,
    required DateTime toDate,
    int? groupId,
    String? status,
  }) async {
    final body = <String, dynamic>{
      'from': _formatDateOnly(fromDate),
      'to': _formatDateOnly(toDate),
    };
    if (groupId != null) {
      body['group_id'] = groupId;
    }
    if (status != null && status.isNotEmpty && status != 'all') {
      body['status'] = status;
    }
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/reports/export-excel');
    final response = await http.post(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode(body),
    );
    if (response.statusCode == 200) {
      final disposition = response.headers['content-disposition'];
      final fileName =
          _extractFilenameFromDisposition(disposition) ??
          'attendance_report.xlsx';
      return ReportDownloadResult(
        fileName: fileName,
        bytes: response.bodyBytes,
      );
    }
    final data = _parseResponseBytes(response);
    throw Exception(
      _extractErrorMessage(
        data,
        'Export dashboard report failed (${response.statusCode})',
      ),
    );
  }

  EmployeeLite _employeeFromMap(Map<String, dynamic> e) {
    return EmployeeLite(
      id: (e['id'] as num?)?.toInt() ?? 0,
      code: e['code'] as String? ?? '-',
      fullName: e['full_name'] as String? ?? '-',
      userId: (e['user_id'] as num?)?.toInt(),
      groupId: (e['group_id'] as num?)?.toInt(),
      email: e['email'] as String?,
      phone: e['phone'] as String? ?? e['phone_number'] as String?,
      departmentName: e['department_name'] as String?,
      groupName: e['group_name'] as String?,
      role: e['role'] as String?,
      active: _toBool(e['active'] ?? e['is_active']),
      joinedAt:
          _toDateTime(e['joined_at']) ??
          _toDateTime(e['created_at']) ??
          _toDateTime(e['start_date']),
      resignedAt: _toDateTime(e['resigned_at']),
    );
  }

  DashboardGeofenceItem _dashboardGeofenceFromMap(Map<String, dynamic> e) {
    return DashboardGeofenceItem(
      id: _toInt(e['id']) ?? 0,
      name: e['name'] as String? ?? e['zone_name'] as String? ?? '-',
      memberCount:
          _toInt(e['member_count']) ??
          _toInt(e['members']) ??
          _toInt(e['employee_count']) ??
          0,
      active: _toBool(e['active'] ?? e['is_active']) ?? false,
      latitude:
          _toDouble(e['latitude']) ??
          _toDouble(e['lat']) ??
          _toDouble(e['center_lat']),
      longitude:
          _toDouble(e['longitude']) ??
          _toDouble(e['lng']) ??
          _toDouble(e['center_lng']),
      radiusMeters:
          _toInt(e['radius_meters']) ??
          _toInt(e['radius_meter']) ??
          _toInt(e['radius_m']),
      presentCount: _toInt(e['present_count']) ?? _toInt(e['present']),
      groupId: _toInt(e['group_id']),
      groupName: e['group_name'] as String?,
      startTime: e['start_time'] as String?,
      endTime: e['end_time'] as String?,
      overtimeEnabled: _toBool(e['overtime_enabled']),
      overtimeStartTime: e['overtime_start_time'] as String?,
      address: e['address'] as String? ?? e['formatted_address'] as String?,
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

  ExceptionPolicy _exceptionPolicyFromMap(Map<String, dynamic> e) {
    return ExceptionPolicy(
      defaultDeadlineHours: _toInt(e['default_deadline_hours']) ?? 72,
      autoClosedDeadlineHours: _toInt(e['auto_closed_deadline_hours']),
      missedCheckoutDeadlineHours: _toInt(e['missed_checkout_deadline_hours']),
      locationRiskDeadlineHours: _toInt(e['location_risk_deadline_hours']),
      largeTimeDeviationDeadlineHours: _toInt(
        e['large_time_deviation_deadline_hours'],
      ),
      gracePeriodDays: _toInt(e['grace_period_days']) ?? 30,
      updatedAt: _toDateTime(e['updated_at']),
      updatedByName:
          e['updated_by_name'] as String? ??
          e['updated_by_email'] as String? ??
          e['updated_by'] as String?,
    );
  }

  AttendanceExceptionItem _attendanceExceptionFromMap(Map<String, dynamic> e) {
    final workDateRaw = e['work_date']?.toString() ?? '';
    final workDate = DateTime.tryParse(workDateRaw) ?? DateTime(1970, 1, 1);
    final decidedByEmail = e['decided_by_email'] as String?;
    final resolvedByEmail = e['resolved_by_email'] as String?;
    return AttendanceExceptionItem(
      id: _toInt(e['id']) ?? 0,
      employeeId: _toInt(e['employee_id']) ?? 0,
      employeeCode: e['employee_code'] as String? ?? '-',
      fullName: e['full_name'] as String? ?? '-',
      groupCode: e['group_code'] as String?,
      groupName: e['group_name'] as String?,
      workDate: workDate,
      exceptionType: e['exception_type'] as String? ?? '-',
      status: e['status']?.toString() ?? '-',
      note: e['note'] as String?,
      sourceCheckinLogId: _toInt(e['source_checkin_log_id']) ?? 0,
      sourceCheckinTime: _toDateTime(e['source_checkin_time']),
      actualCheckoutTime: _toDateTime(e['actual_checkout_time']),
      createdAt: _toDateTime(e['created_at']),
      resolvedAt: _toDateTime(e['resolved_at'] ?? e['admin_decided_at']),
      resolvedBy: _toInt(e['resolved_by']),
      resolvedByEmail: resolvedByEmail ?? decidedByEmail,
      detectedAt: _toDateTime(e['detected_at']),
      expiresAt: _toDateTime(e['expires_at']),
      extendedDeadlineAt: _toDateTime(e['extended_deadline_at']),
      employeeExplanation: e['employee_explanation'] as String?,
      employeeSubmittedAt: _toDateTime(e['employee_submitted_at']),
      adminNote: e['admin_note'] as String?,
      adminDecidedAt: _toDateTime(e['admin_decided_at']),
      decidedByEmail: decidedByEmail,
      canAdminDecide: _toBool(e['can_admin_decide']) ?? false,
      timeline: _toMapList(e['timeline']),
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

    final utf8Match = RegExp(
      r"filename\*=UTF-8''([^;]+)",
      caseSensitive: false,
    ).firstMatch(disposition);
    if (utf8Match != null) {
      return Uri.decodeComponent(utf8Match.group(1)!);
    }

    final normalMatch = RegExp(
      r'filename="?([^";]+)"?',
      caseSensitive: false,
    ).firstMatch(disposition);
    if (normalMatch != null) {
      return normalMatch.group(1);
    }

    return null;
  }

  /// Parses [response.body] as a JSON map.
  /// Throws [UnauthorizedException] if the response status is 401.
  Map<String, dynamic> _parseResponse(http.Response response) {
    if (response.statusCode == 401) throw const UnauthorizedException();
    return _parseJsonMap(response.body);
  }

  /// Like [_parseResponse] but decodes bodyBytes with UTF-8 before parsing.
  Map<String, dynamic> _parseResponseBytes(http.Response response) {
    if (response.statusCode == 401) throw const UnauthorizedException();
    return _parseJsonMap(utf8.decode(response.bodyBytes, allowMalformed: true));
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

  List<dynamic> _parseJsonListAny(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is List<dynamic>) {
        return decoded;
      }
      if (decoded is Map<String, dynamic>) {
        final directData = decoded['data'];
        if (directData is List<dynamic>) {
          return directData;
        }
        final payload = _extractPayloadMap(decoded);
        final candidate =
            payload['items'] ?? payload['rows'] ?? payload['data'];
        if (candidate is List<dynamic>) {
          return candidate;
        }
      }
    } catch (_) {}
    return <dynamic>[];
  }

  Map<String, dynamic> _extractPayloadMap(Map<String, dynamic> data) {
    final payload = data['data'];
    if (payload is Map<String, dynamic>) {
      return payload;
    }
    return data;
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
    if (detail is List && detail.isNotEmpty) {
      final first = detail.first;
      if (first is Map<String, dynamic>) {
        final message = first['msg'] as String?;
        if (message != null && message.isNotEmpty) {
          return message;
        }
      }
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

  int? _toInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value.toString());
  }

  DateTime? _toDateTime(dynamic value) {
    if (value == null) {
      return null;
    }
    return DateTime.tryParse(value.toString());
  }

  List<Map<String, dynamic>> _toMapList(dynamic value) {
    if (value is! List) {
      return const <Map<String, dynamic>>[];
    }
    return value
        .whereType<Map>()
        .map(
          (item) => item.map((key, value) => MapEntry(key.toString(), value)),
        )
        .toList(growable: false);
  }

  bool? _toBool(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    final normalized = value.toString().trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') {
      return true;
    }
    if (normalized == 'false' || normalized == '0') {
      return false;
    }
    return null;
  }

  String _toClockLabel(dynamic value) {
    if (value == null) {
      return '--';
    }
    final raw = value.toString();
    if (raw.isEmpty) {
      return '--';
    }
    if (RegExp(r'^\d{2}:\d{2}$').hasMatch(raw)) {
      return raw;
    }
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return raw;
    }
    final local = parsed.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _nameToInitials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) {
      return '--';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    final first = parts.first.substring(0, 1).toUpperCase();
    final last = parts.last.substring(0, 1).toUpperCase();
    return '$first$last';
  }
}
