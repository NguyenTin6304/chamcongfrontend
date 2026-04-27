import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:birdle/core/config/app_config.dart';

enum GeoapifyErrorCode { network, rateLimit, invalidKey, badRequest, unknown }

class GeoapifyException implements Exception {
  const GeoapifyException({
    required this.code,
    required this.message,
    this.statusCode,
  });

  final GeoapifyErrorCode code;
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class GeoapifyPlace {
  const GeoapifyPlace({
    required this.displayName,
    required this.lat,
    required this.lng,
    required this.country,
    required this.city,
  });

  final String displayName;
  final double lat;
  final double lng;
  final String country;
  final String city;

  bool get hasValidCoordinate {
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }

  factory GeoapifyPlace.fromFeature(Map<String, dynamic> feature) {
    final properties =
        (feature['properties'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};

    var lat = _toDouble(properties['lat']);
    var lng = _toDouble(properties['lon']);

    final geometry = feature['geometry'];
    if ((lat == null || lng == null) && geometry is Map) {
      final geometryMap = geometry.cast<String, dynamic>();
      final coordinates = geometryMap['coordinates'];
      if (coordinates is List && coordinates.length >= 2) {
        lng ??= _toDouble(coordinates[0]);
        lat ??= _toDouble(coordinates[1]);
      }
    }

    final resolvedLat = lat ?? 0;
    final resolvedLng = lng ?? 0;
    final country = _firstNonEmpty([properties['country']?.toString()]) ?? '';
    final city =
        _firstNonEmpty([
          properties['city']?.toString(),
          properties['town']?.toString(),
          properties['village']?.toString(),
          properties['hamlet']?.toString(),
          properties['county']?.toString(),
          properties['state']?.toString(),
        ]) ??
        '';
    final displayName =
        _firstNonEmpty([
          properties['formatted']?.toString(),
          properties['address_line1']?.toString(),
          properties['address_line2']?.toString(),
          properties['name']?.toString(),
        ]) ??
        '${resolvedLat.toStringAsFixed(6)}, ${resolvedLng.toStringAsFixed(6)}';

    return GeoapifyPlace(
      displayName: displayName,
      lat: resolvedLat,
      lng: resolvedLng,
      country: country,
      city: city,
    );
  }

  factory GeoapifyPlace.fromResult(Map<String, dynamic> result) {
    final lat = _toDouble(result['lat']) ?? 0;
    final lng = _toDouble(result['lon']) ?? 0;
    final country = _firstNonEmpty([result['country']?.toString()]) ?? '';
    final city =
        _firstNonEmpty([
          result['city']?.toString(),
          result['town']?.toString(),
          result['village']?.toString(),
          result['hamlet']?.toString(),
          result['county']?.toString(),
          result['state']?.toString(),
        ]) ??
        '';
    final displayName =
        _firstNonEmpty([
          result['formatted']?.toString(),
          result['address_line1']?.toString(),
          result['address_line2']?.toString(),
          result['name']?.toString(),
        ]) ??
        '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';

    return GeoapifyPlace(
      displayName: displayName,
      lat: lat,
      lng: lng,
      country: country,
      city: city,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString());
  }

  static String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      if (value == null) {
        continue;
      }
      final normalized = value.trim();
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
    return null;
  }
}

class GeoapifyClient {
  GeoapifyClient({
    http.Client? httpClient,
    String? apiKey,
    Duration requestTimeout = const Duration(seconds: 10),
    Duration searchDebounce = const Duration(milliseconds: 400),
  }) : _httpClient = httpClient ?? http.Client(),
       _ownsHttpClient = httpClient == null,
       _apiKey = (apiKey ?? AppConfig.geoapifyApiKey).trim(),
       _requestTimeout = requestTimeout,
       _searchDebounce = searchDebounce;

  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final String _apiKey;
  final Duration _requestTimeout;
  final Duration _searchDebounce;

  String? _latestSearchKey;

  void dispose() {
    if (_ownsHttpClient) {
      _httpClient.close();
    }
  }

  Future<List<GeoapifyPlace>> searchPlaces(
    String text, {
    int limit = 8,
    String language = 'vi',
  }) async {
    final query = text.trim();
    if (query.isEmpty) {
      return const <GeoapifyPlace>[];
    }
    _ensureApiKeyConfigured();

    final uri = Uri.https('api.geoapify.com', '/v1/geocode/search', {
      'text': query,
      'format': 'json',
      'limit': limit.toString(),
      'lang': language,
      'apiKey': _apiKey,
    });

    final response = await _safeGet(uri);
    if (response.statusCode != 200) {
      throw _mapError(response);
    }

    final places = _extractPlaces(response.body);
    return places
        .where((place) => place.hasValidCoordinate)
        .toList(growable: false);
  }

  Future<List<GeoapifyPlace>> searchPlacesDebounced(
    String text, {
    int limit = 8,
    String language = 'vi',
  }) async {
    final marker = '${DateTime.now().microsecondsSinceEpoch}:${text.trim()}';
    _latestSearchKey = marker;

    await Future<void>.delayed(_searchDebounce);
    if (_latestSearchKey != marker) {
      return const <GeoapifyPlace>[];
    }

    return searchPlaces(text, limit: limit, language: language);
  }

  Future<GeoapifyPlace?> reverseGeocode({
    required double lat,
    required double lng,
    String language = 'vi',
  }) async {
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      throw const GeoapifyException(
        code: GeoapifyErrorCode.badRequest,
        message: 'Tọa độ không hợp lệ.',
      );
    }
    _ensureApiKeyConfigured();

    final uri = Uri.https('api.geoapify.com', '/v1/geocode/reverse', {
      'lat': lat.toStringAsFixed(7),
      'lon': lng.toStringAsFixed(7),
      'format': 'json',
      'lang': language,
      'apiKey': _apiKey,
    });

    final response = await _safeGet(uri);
    if (response.statusCode != 200) {
      throw _mapError(response);
    }

    final places = _extractPlaces(response.body);
    if (places.isEmpty) {
      return null;
    }

    final first = places.first;
    return first.hasValidCoordinate ? first : null;
  }

  Future<http.Response> _safeGet(Uri uri) async {
    try {
      return await _httpClient.get(uri).timeout(_requestTimeout);
    } on TimeoutException {
      throw const GeoapifyException(
        code: GeoapifyErrorCode.network,
        message: 'Yêu cầu bản đồ quá thời gian. Vui lòng thử lại.',
      );
    } on http.ClientException {
      throw const GeoapifyException(
        code: GeoapifyErrorCode.network,
        message: 'Không thể kết nối dịch vụ bản đồ.',
      );
    }
  }

  void _ensureApiKeyConfigured() {
    if (_apiKey.isEmpty) {
      throw const GeoapifyException(
        code: GeoapifyErrorCode.invalidKey,
        message: 'Thiếu cấu hình GEOAPIFY_API_KEY.',
      );
    }
  }

  GeoapifyException _mapError(http.Response response) {
    final statusCode = response.statusCode;
    final data = _parseJsonMap(response.body);
    final rawMessage = _extractMessage(data).toLowerCase();

    if (statusCode == 429) {
      return const GeoapifyException(
        code: GeoapifyErrorCode.rateLimit,
        message: 'Vượt giới hạn truy vấn bản đồ. Vui lòng thử lại sau.',
        statusCode: 429,
      );
    }

    final invalidKeyLike =
        statusCode == 401 ||
        statusCode == 403 ||
        rawMessage.contains('api key') ||
        rawMessage.contains('invalid key') ||
        rawMessage.contains('unauthorized') ||
        rawMessage.contains('forbidden');
    if (invalidKeyLike) {
      return GeoapifyException(
        code: GeoapifyErrorCode.invalidKey,
        message: 'Geoapify API key không hợp lệ hoặc bị từ chối.',
        statusCode: statusCode,
      );
    }

    if (statusCode == 400) {
      return GeoapifyException(
        code: GeoapifyErrorCode.badRequest,
        message: 'Yêu cầu tìm địa điểm không hợp lệ.',
        statusCode: statusCode,
      );
    }

    if (statusCode >= 500) {
      return GeoapifyException(
        code: GeoapifyErrorCode.network,
        message: 'Dịch vụ bản đồ đang lỗi tạm thời. Vui lòng thử lại.',
        statusCode: statusCode,
      );
    }

    return GeoapifyException(
      code: GeoapifyErrorCode.unknown,
      message: 'Không thể xử lý yêu cầu bản đồ (${response.statusCode}).',
      statusCode: statusCode,
    );
  }

  List<GeoapifyPlace> _extractPlaces(String body) {
    final data = _parseJsonMap(body);

    final features = data['features'];
    if (features is List && features.isNotEmpty) {
      return features
          .whereType<Map<dynamic, dynamic>>()
          .map(
            (feature) =>
                GeoapifyPlace.fromFeature(feature.cast<String, dynamic>()),
          )
          .toList(growable: false);
    }

    final results = data['results'];
    if (results is List) {
      return results
          .whereType<Map<dynamic, dynamic>>()
          .map(
            (result) =>
                GeoapifyPlace.fromResult(result.cast<String, dynamic>()),
          )
          .toList(growable: false);
    }

    return const <GeoapifyPlace>[];
  }

  Map<String, dynamic> _parseJsonMap(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } on Object catch (_) {}
    return <String, dynamic>{};
  }

  String _extractMessage(Map<String, dynamic> data) {
    final message = data['message'];
    if (message is String && message.trim().isNotEmpty) {
      return message.trim();
    }

    final error = data['error'];
    if (error is String && error.trim().isNotEmpty) {
      return error.trim();
    }
    if (error is Map) {
      final nested = error['message'];
      if (nested is String && nested.trim().isNotEmpty) {
        return nested.trim();
      }
    }

    return '';
  }
}
