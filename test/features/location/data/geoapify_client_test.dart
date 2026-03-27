import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:birdle/features/location/data/geoapify_client.dart';

void main() {
  group('GeoapifyClient', () {
    test('searchPlaces parses and normalizes response', () async {
      final client = GeoapifyClient(
        apiKey: 'test-key',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/v1/geocode/search');
          return http.Response(
            jsonEncode({
              'features': [
                {
                  'properties': {
                    'formatted': '123 Test St, Ho Chi Minh City, Vietnam',
                    'lat': 10.776889,
                    'lon': 106.700806,
                    'country': 'Vietnam',
                    'city': 'Ho Chi Minh City',
                  },
                },
              ],
            }),
            200,
          );
        }),
      );

      final results = await client.searchPlaces('Test');
      expect(results.length, 1);
      expect(results.first.displayName, contains('Test St'));
      expect(results.first.lat, closeTo(10.776889, 0.000001));
      expect(results.first.lng, closeTo(106.700806, 0.000001));
      expect(results.first.country, 'Vietnam');
      expect(results.first.city, 'Ho Chi Minh City');
    });

    test('searchPlaces supports results format payload', () async {
      final client = GeoapifyClient(
        apiKey: 'test-key',
        httpClient: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'results': [
                {
                  'formatted': 'District 1, Ho Chi Minh City, Vietnam',
                  'lat': 10.776889,
                  'lon': 106.700806,
                  'country': 'Vietnam',
                  'city': 'Ho Chi Minh City',
                },
              ],
            }),
            200,
          );
        }),
      );

      final results = await client.searchPlaces('Thành phố');
      expect(results.length, 1);
      expect(results.first.displayName, contains('District 1'));
      expect(results.first.lat, closeTo(10.776889, 0.000001));
      expect(results.first.lng, closeTo(106.700806, 0.000001));
    });

    test('reverseGeocode parses geometry coordinates fallback', () async {
      final client = GeoapifyClient(
        apiKey: 'test-key',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/v1/geocode/reverse');
          return http.Response(
            jsonEncode({
              'features': [
                {
                  'geometry': {
                    'coordinates': [106.700806, 10.776889],
                  },
                  'properties': {
                    'formatted': 'Landmark 81, Ho Chi Minh City, Vietnam',
                    'country': 'Vietnam',
                    'city': 'Ho Chi Minh City',
                  },
                },
              ],
            }),
            200,
          );
        }),
      );

      final place = await client.reverseGeocode(lat: 10.77, lng: 106.70);
      expect(place, isNotNull);
      expect(place!.displayName, contains('Landmark 81'));
      expect(place.lat, closeTo(10.776889, 0.000001));
      expect(place.lng, closeTo(106.700806, 0.000001));
    });

    test('maps 429 to rateLimit error', () async {
      final client = GeoapifyClient(
        apiKey: 'test-key',
        httpClient: MockClient((request) async {
          return http.Response(jsonEncode({'message': 'Too many requests'}), 429);
        }),
      );

      expect(
        () => client.searchPlaces('Ho Chi Minh'),
        throwsA(
          isA<GeoapifyException>().having((e) => e.code, 'code', GeoapifyErrorCode.rateLimit),
        ),
      );
    });

    test('throws invalidKey when api key is missing', () async {
      final client = GeoapifyClient(
        apiKey: '',
        httpClient: MockClient((request) async {
          return http.Response('{}', 200);
        }),
      );

      expect(
        () => client.searchPlaces('Ho Chi Minh'),
        throwsA(
          isA<GeoapifyException>().having((e) => e.code, 'code', GeoapifyErrorCode.invalidKey),
        ),
      );
    });
  });
}
