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

  Future<List<AttendanceLogItem>> getMyLogs(String token) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/attendance/me');
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
}

