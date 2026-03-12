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
  });

  final bool employeeAssigned;
  final String currentState;
  final bool canCheckin;
  final bool canCheckout;
  final String message;
  final String? lastAction;
  final String? lastActionTime;
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
  }) {
    return _doAction(path: '/attendance/checkin', token: token, lat: lat, lng: lng);
  }

  Future<AttendanceActionResult> checkout({
    required String token,
    required double lat,
    required double lng,
  }) {
    return _doAction(path: '/attendance/checkout', token: token, lat: lat, lng: lng);
  }

  Future<AttendanceActionResult> _doAction({
    required String path,
    required String token,
    required double lat,
    required double lng,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$path');
    final response = await http.post(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode({'lat': lat, 'lng': lng}),
    );

    final data = _parseJsonMap(response.body);

    if (response.statusCode == 200) {
      final log = data['log'] as Map<String, dynamic>? ?? <String, dynamic>{};
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
      );
    }

    throw Exception(_extractErrorMessage(data, 'Action failed (${response.statusCode})'));
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
