import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';

class AttendanceStatusResult {
  const AttendanceStatusResult({
    required this.employeeAssigned,
    required this.currentState,
    required this.canCheckin,
    required this.canCheckout,
    required this.message,
    this.lastAction,
    this.lastActionTime,
    this.warningCode,
    this.warningDate,
  });

  final bool employeeAssigned;
  final String currentState;
  final bool canCheckin;
  final bool canCheckout;
  final String message;
  final String? lastAction;
  final String? lastActionTime;
  final String? warningCode;
  final String? warningDate;
}

class AttendanceActionResult {
  const AttendanceActionResult({
    required this.type,
    required this.time,
    required this.distanceM,
    required this.nearestDistanceM,
    required this.isOutOfRange,
    required this.message,
    this.matchedGeofence,
    this.geofenceSource,
    this.fallbackReason,
    this.punctualityStatus,
    this.checkoutStatus,
    this.riskScore,
    this.riskLevel,
    this.riskFlags = const [],
    this.decision,
  });

  final String type;
  final String time;
  final double? distanceM;
  final double? nearestDistanceM;
  final bool isOutOfRange;
  final String message;
  final String? matchedGeofence;
  final String? geofenceSource;
  final String? fallbackReason;
  final String? punctualityStatus;
  final String? checkoutStatus;
  final int? riskScore;
  final String? riskLevel;
  final List<String> riskFlags;
  final String? decision;
}

class AttendanceLogItem {
  const AttendanceLogItem({
    required this.id,
    required this.type,
    required this.time,
    required this.lat,
    required this.lng,
    required this.isOutOfRange,
    this.distanceM,
    this.nearestDistanceM,
    this.matchedGeofence,
    this.geofenceSource,
    this.fallbackReason,
    this.punctualityStatus,
    this.checkoutStatus,
    this.riskScore,
    this.riskLevel,
    this.riskFlags = const [],
  });

  final int id;
  final String type;
  final String time;
  final double lat;
  final double lng;
  final double? distanceM;
  final double? nearestDistanceM;
  final bool isOutOfRange;
  final String? matchedGeofence;
  final String? geofenceSource;
  final String? fallbackReason;
  final String? punctualityStatus;
  final String? checkoutStatus;
  final int? riskScore;
  final String? riskLevel;
  final List<String> riskFlags;
}

class EmployeeExceptionTimelineItem {
  const EmployeeExceptionTimelineItem({
    required this.id,
    required this.eventType,
    required this.nextStatus,
    required this.actorType,
    required this.createdAt,
    this.previousStatus,
    this.actorEmail,
  });

  final int id;
  final String eventType;
  final String? previousStatus;
  final String nextStatus;
  final String actorType;
  final String? actorEmail;
  final DateTime? createdAt;
}

class EmployeeExceptionItem {
  const EmployeeExceptionItem({
    required this.id,
    required this.employeeId,
    required this.workDate,
    required this.exceptionType,
    required this.status,
    required this.sourceCheckinLogId,
    required this.canSubmitExplanation,
    this.employeeCode,
    this.fullName,
    this.groupCode,
    this.groupName,
    this.note,
    this.sourceCheckinTime,
    this.detectedAt,
    this.expiresAt,
    this.employeeExplanation,
    this.employeeSubmittedAt,
    this.adminNote,
    this.adminDecidedAt,
    this.decidedByEmail,
    this.createdAt,
    this.timeline = const [],
  });

  final int id;
  final int employeeId;
  final String? employeeCode;
  final String? fullName;
  final String? groupCode;
  final String? groupName;
  final String workDate;
  final String exceptionType;
  final String status;
  final String? note;
  final int sourceCheckinLogId;
  final DateTime? sourceCheckinTime;
  final DateTime? detectedAt;
  final DateTime? expiresAt;
  final String? employeeExplanation;
  final DateTime? employeeSubmittedAt;
  final String? adminNote;
  final DateTime? adminDecidedAt;
  final String? decidedByEmail;
  final DateTime? createdAt;
  final bool canSubmitExplanation;
  final List<EmployeeExceptionTimelineItem> timeline;

  bool get canEditExplanation =>
      status == 'PENDING_EMPLOYEE' && canSubmitExplanation && employeeSubmittedAt == null;
}

class EmployeeProfile {
  const EmployeeProfile({
    required this.id,
    required this.code,
    required this.fullName,
    this.userId,
    this.groupId,
    this.groupName,
    this.joinedAt,
  });

  final int id;
  final String code;
  final String fullName;
  final int? userId;
  final int? groupId;
  final String? groupName;
  final DateTime? joinedAt;
}

class AttendanceActionException implements Exception {
  const AttendanceActionException({
    required this.message,
    this.riskScore,
    this.riskLevel,
    this.riskFlags = const [],
    this.decision,
  });

  final String message;
  final int? riskScore;
  final String? riskLevel;
  final List<String> riskFlags;
  final String? decision;

  @override
  String toString() => message;
}

class AttendanceApi {
  const AttendanceApi();

  Future<AttendanceStatusResult> getStatus(String token) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/attendance/status');
    final response = await http.get(
      uri,
      headers: _authHeaders(token),
    );

    final data = _parseJsonMap(response.body);

    if (response.statusCode == 200) {
      return AttendanceStatusResult(
        employeeAssigned: data['employee_assigned'] as bool? ?? false,
        currentState: data['current_state'] as String? ?? 'UNKNOWN',
        canCheckin: data['can_checkin'] as bool? ?? false,
        canCheckout: data['can_checkout'] as bool? ?? false,
        message: data['message'] as String? ?? '',
        lastAction: data['last_action'] as String?,
        lastActionTime: data['last_action_time'] as String?,
        warningCode: data['warning_code'] as String?,
        warningDate: data['warning_date'] as String?,
      );
    }

    throw Exception(_extractErrorMessage(data, 'Load status failed (${response.statusCode})'));
  }

  Future<List<AttendanceLogItem>> getMyLogs(
    String token, {
    DateTime? from,
    DateTime? to,
  }) async {
    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final params = <String, String>{
      if (from != null) 'from': fmt(from),
      if (to != null) 'to': fmt(to),
    };
    final base = Uri.parse('${AppConfig.apiBaseUrl}/attendance/me');
    final uri = params.isEmpty ? base : base.replace(queryParameters: params);
    final response = await http.get(uri, headers: _authHeaders(token));

    if (response.statusCode == 200) {
      final list = _parseJsonList(response.body);
      return list
          .whereType<Map<String, dynamic>>()
          .map(
            (e) => AttendanceLogItem(
              id: (e['id'] as num?)?.toInt() ?? 0,
              type: e['type'] as String? ?? 'UNKNOWN',
              time: e['time'] as String? ?? '',
              lat: _toDouble(e['lat']) ?? 0,
              lng: _toDouble(e['lng']) ?? 0,
              distanceM: _toDouble(e['distance_m']),
              nearestDistanceM: _toDouble(e['nearest_distance_m']),
              isOutOfRange: e['is_out_of_range'] as bool? ?? false,
              matchedGeofence: e['matched_geofence'] as String?,
              geofenceSource: e['geofence_source'] as String?,
              fallbackReason: e['fallback_reason'] as String?,
              punctualityStatus: e['punctuality_status'] as String?,
              checkoutStatus: e['checkout_status'] as String?,
              riskScore: _toInt(e['risk_score']),
              riskLevel: e['risk_level'] as String?,
              riskFlags: _toStringList(e['risk_flags']),
            ),
          )
          .toList();
    }

    final data = _parseJsonMap(response.body);
    throw Exception(_extractErrorMessage(data, 'Load history failed (${response.statusCode})'));
  }

  Future<List<EmployeeExceptionItem>> listMyExceptions(
    String token, {
    String? status,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/reports/attendance-exceptions/me').replace(
      queryParameters: {
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    final response = await http.get(uri, headers: _authHeaders(token));

    if (response.statusCode == 200) {
      final list = _parseJsonList(response.body);
      return list
          .whereType<Map<String, dynamic>>()
          .map(_employeeExceptionFromMap)
          .toList();
    }

    final data = _parseJsonMap(response.body);
    throw Exception(_extractErrorMessage(data, 'Load exceptions failed (${response.statusCode})'));
  }

  Future<EmployeeExceptionItem> getMyExceptionDetail({
    required String token,
    required int exceptionId,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/reports/attendance-exceptions/me/$exceptionId');
    final response = await http.get(uri, headers: _authHeaders(token));
    final data = _parseJsonMap(response.body);

    if (response.statusCode == 200) {
      return _employeeExceptionFromMap(data);
    }

    throw Exception(_extractErrorMessage(data, 'Load exception detail failed (${response.statusCode})'));
  }

  Future<EmployeeExceptionItem> submitExceptionExplanation({
    required String token,
    required int exceptionId,
    required String explanation,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/reports/attendance-exceptions/$exceptionId/submit-explanation');
    final response = await http.post(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode({'explanation': explanation}),
    );
    final data = _parseJsonMap(response.body);

    if (response.statusCode == 200) {
      return _employeeExceptionFromMap(data);
    }

    throw Exception(_extractErrorMessage(data, 'Submit explanation failed (${response.statusCode})'));
  }

  Future<EmployeeProfile> getMyEmployeeProfile(String token) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/employees/me');
    final response = await http.get(uri, headers: _authHeaders(token));
    final data = _parseJsonMap(response.body);

    if (response.statusCode == 200) {
      return EmployeeProfile(
        id: _toInt(data['id']) ?? 0,
        code: data['code'] as String? ?? '',
        fullName: data['full_name'] as String? ?? '',
        userId: _toInt(data['user_id']),
        groupId: _toInt(data['group_id']),
        groupName: data['group_name'] as String?,
        joinedAt: _toDateTime(data['joined_at']),
      );
    }

    throw Exception(_extractErrorMessage(data, 'Load employee profile failed (${response.statusCode})'));
  }

  Future<AttendanceActionResult> checkin({
    required String token,
    required double lat,
    required double lng,
    double? accuracyM,
    DateTime? timestampClient,
  }) {
    return _doAction(
      path: '/attendance/checkin',
      token: token,
      lat: lat,
      lng: lng,
      accuracyM: accuracyM,
      timestampClient: timestampClient,
    );
  }

  Future<AttendanceActionResult> checkout({
    required String token,
    required double lat,
    required double lng,
    double? accuracyM,
    DateTime? timestampClient,
  }) {
    return _doAction(
      path: '/attendance/checkout',
      token: token,
      lat: lat,
      lng: lng,
      accuracyM: accuracyM,
      timestampClient: timestampClient,
    );
  }

  Future<AttendanceActionResult> _doAction({
    required String path,
    required String token,
    required double lat,
    required double lng,
    double? accuracyM,
    DateTime? timestampClient,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$path');
    final payload = <String, dynamic>{
      'lat': lat,
      'lng': lng,
    };
    if (accuracyM != null) {
      payload['accuracy_m'] = accuracyM;
    }
    if (timestampClient != null) {
      payload['timestamp_client'] = timestampClient.toUtc().toIso8601String();
    }

    final response = await http.post(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode(payload),
    );

    final data = _parseJsonMap(response.body);

    if (response.statusCode == 200) {
      final log = data['log'] as Map<String, dynamic>? ?? <String, dynamic>{};
      final responseFlags = _toStringList(data['risk_flags']);
      return AttendanceActionResult(
        type: log['type'] as String? ?? 'UNKNOWN',
        time: log['time'] as String? ?? '',
        distanceM: _toDouble(log['distance_m']),
        nearestDistanceM: _toDouble(log['nearest_distance_m']),
        isOutOfRange: log['is_out_of_range'] as bool? ?? false,
        matchedGeofence: log['matched_geofence'] as String?,
        geofenceSource: (data['geofence_source'] as String?) ?? (log['geofence_source'] as String?),
        fallbackReason: (data['fallback_reason'] as String?) ?? (log['fallback_reason'] as String?),
        message: data['message'] as String? ?? 'Success',
        punctualityStatus: log['punctuality_status'] as String?,
        checkoutStatus: log['checkout_status'] as String?,
        riskScore: _toInt(data['risk_score']) ?? _toInt(log['risk_score']),
        riskLevel: (data['risk_level'] as String?) ?? (log['risk_level'] as String?),
        riskFlags: responseFlags.isNotEmpty ? responseFlags : _toStringList(log['risk_flags']),
        decision: data['decision'] as String?,
      );
    }

    final details = _extractErrorDetails(data);
    throw AttendanceActionException(
      message: _extractErrorMessage(data, 'Action failed (${response.statusCode})'),
      riskScore: _toInt(details['risk_score']),
      riskLevel: details['risk_level'] as String?,
      riskFlags: _toStringList(details['risk_flags']),
      decision: details['decision'] as String?,
    );
  }

  Map<String, String> _authHeaders(String token) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
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

  Map<String, dynamic> _extractErrorDetails(Map<String, dynamic> data) {
    final error = data['error'];
    if (error is Map<String, dynamic>) {
      final details = error['details'];
      if (details is Map<String, dynamic>) {
        return details;
      }
    }
    return const <String, dynamic>{};
  }

  List<String> _toStringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return const <String>[];
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

  double? _toDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString());
  }

  DateTime? _toDateTime(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is DateTime) {
      return value;
    }
    return DateTime.tryParse(value.toString());
  }

  EmployeeExceptionItem _employeeExceptionFromMap(Map<String, dynamic> data) {
    return EmployeeExceptionItem(
      id: _toInt(data['id']) ?? 0,
      employeeId: _toInt(data['employee_id']) ?? 0,
      employeeCode: data['employee_code'] as String?,
      fullName: data['full_name'] as String?,
      groupCode: data['group_code'] as String?,
      groupName: data['group_name'] as String?,
      workDate: data['work_date']?.toString() ?? '',
      exceptionType: data['exception_type'] as String? ?? 'UNKNOWN',
      status: data['status'] as String? ?? 'PENDING_EMPLOYEE',
      note: data['note'] as String?,
      sourceCheckinLogId: _toInt(data['source_checkin_log_id']) ?? 0,
      sourceCheckinTime: _toDateTime(data['source_checkin_time']),
      detectedAt: _toDateTime(data['detected_at']),
      expiresAt: _toDateTime(data['expires_at']),
      employeeExplanation: data['employee_explanation'] as String?,
      employeeSubmittedAt: _toDateTime(data['employee_submitted_at']),
      adminNote: data['admin_note'] as String?,
      adminDecidedAt: _toDateTime(data['admin_decided_at']),
      decidedByEmail: data['decided_by_email'] as String?,
      createdAt: _toDateTime(data['created_at']),
      canSubmitExplanation: data['can_submit_explanation'] as bool? ?? false,
      timeline: _employeeExceptionTimelineFromList(data['timeline']),
    );
  }

  List<EmployeeExceptionTimelineItem> _employeeExceptionTimelineFromList(dynamic value) {
    if (value is! List) {
      return const [];
    }
    return value.whereType<Map<String, dynamic>>().map((item) {
      return EmployeeExceptionTimelineItem(
        id: _toInt(item['id']) ?? 0,
        eventType: item['event_type'] as String? ?? '',
        previousStatus: item['previous_status'] as String?,
        nextStatus: item['next_status'] as String? ?? '',
        actorType: item['actor_type'] as String? ?? '',
        actorEmail: item['actor_email'] as String?,
        createdAt: _toDateTime(item['created_at']),
      );
    }).toList();
  }
}

