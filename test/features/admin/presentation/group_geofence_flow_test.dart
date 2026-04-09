import 'package:birdle/features/admin/data/admin_api.dart';
import 'package:birdle/features/admin/presentation/group_admin_page.dart';
import 'package:birdle/features/admin/presentation/widgets/admin_location_picker.dart';
import 'package:birdle/features/location/data/geoapify_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

class _FakeGeoapifyClient extends GeoapifyClient {
  _FakeGeoapifyClient({
    required this.searchResults,
    this.reverseResult,
  }) : super(
         apiKey: 'fake-key',
         httpClient: MockClient((_) async {
           throw StateError('Network should not be called in fake client.');
         }),
         searchDebounce: const Duration(milliseconds: 1),
       );

  final List<GeoapifyPlace> searchResults;
  final GeoapifyPlace? reverseResult;

  @override
  Future<List<GeoapifyPlace>> searchPlacesDebounced(
    String text, {
    int limit = 8,
    String language = 'vi',
  }) async {
    if (text.trim().isEmpty) {
      return const <GeoapifyPlace>[];
    }
    return searchResults;
  }

  @override
  Future<GeoapifyPlace?> reverseGeocode({
    required double lat,
    required double lng,
    String language = 'vi',
  }) async {
    return reverseResult;
  }
}

class _FakeAdminApi extends AdminApi {
  _FakeAdminApi({
    this.groups = const <GroupLite>[],
  });

  final List<GroupLite> groups;
  final List<EmployeeLite> employees = const [];
  final List<GroupGeofenceLite> geofences = const [];

  int createGeofenceCalls = 0;
  int updateGeofenceCalls = 0;
  int listGeofencesCalls = 0;

  String? lastToken;
  int? lastGroupId;
  String? lastName;
  double? lastLatitude;
  double? lastLongitude;
  int? lastRadiusM;

  @override
  Future<List<GroupLite>> listGroups(
    String token, {
    bool activeOnly = false,
  }) async {
    return groups;
  }

  @override
  Future<List<EmployeeLite>> listEmployees(
    String token, {
    int? groupId,
    String? query,
    String? status,
  }) async {
    return employees;
  }

  @override
  Future<List<GroupGeofenceLite>> listGroupGeofences({
    required String token,
    required int groupId,
    bool activeOnly = false,
  }) async {
    listGeofencesCalls += 1;
    return geofences;
  }

  @override
  Future<GroupGeofenceLite> createGroupGeofence({
    required String token,
    required int groupId,
    required String name,
    required double latitude,
    required double longitude,
    required int radiusM,
    bool active = true,
  }) async {
    createGeofenceCalls += 1;
    lastToken = token;
    lastGroupId = groupId;
    lastName = name;
    lastLatitude = latitude;
    lastLongitude = longitude;
    lastRadiusM = radiusM;
    return GroupGeofenceLite(
      id: 999,
      groupId: groupId,
      name: name,
      latitude: latitude,
      longitude: longitude,
      radiusM: radiusM,
      active: active,
    );
  }

  @override
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
    updateGeofenceCalls += 1;
    return GroupGeofenceLite(
      id: geofenceId,
      groupId: groupId,
      name: name ?? 'updated',
      latitude: latitude ?? 0,
      longitude: longitude ?? 0,
      radiusM: radiusM ?? 0,
      active: active ?? true,
    );
  }
}

Finder _textFieldByLabel(String label) {
  return find.byWidgetPredicate((widget) {
    if (widget is! TextField) {
      return false;
    }
    return widget.decoration?.labelText == label;
  });
}

void main() {
  group('Group geofence flow', () {
    testWidgets(
      'search -> select result -> lat/lng updated',
      (tester) async {
        LocationPickerValue? latestValue;
        final fakeClient = _FakeGeoapifyClient(
          searchResults: const [
            GeoapifyPlace(
              displayName: 'Landmark 81, Ho Chi Minh City',
              lat: 10.795001,
              lng: 106.721839,
              country: 'Vietnam',
              city: 'Ho Chi Minh City',
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AdminLocationPicker(
                geoapifyClient: fakeClient,
                onChanged: (value) {
                  latestValue = value;
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(_textFieldByLabel('Tìm địa điểm (Geoapify)'), 'Landmark');
        await tester.pump(const Duration(milliseconds: 10));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Landmark 81, Ho Chi Minh City'));
        await tester.pumpAndSettle();

        expect(latestValue, isNotNull);
        expect(latestValue!.latitude, closeTo(10.795001, 0.000001));
        expect(latestValue!.longitude, closeTo(106.721839, 0.000001));
      },
    );

    testWidgets(
      'tap map -> reverse geocode -> address updated',
      (tester) async {
        final fakeClient = _FakeGeoapifyClient(
          searchResults: const [],
          reverseResult: const GeoapifyPlace(
            displayName: 'Bitexco Tower, Ho Chi Minh City',
            lat: 10.7716,
            lng: 106.7044,
            country: 'Vietnam',
            city: 'Ho Chi Minh City',
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AdminLocationPicker(
                geoapifyClient: fakeClient,
                onChanged: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(FlutterMap));
        await tester.pumpAndSettle();

        expect(find.textContaining('Bitexco Tower'), findsOneWidget);
      },
    );

    testWidgets(
      'save geofence payload đúng',
      (tester) async {
        final fakeApi = _FakeAdminApi(
          groups: const [
            GroupLite(
              id: 1,
              code: 'G01',
              name: 'Group 01',
              active: true,
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: GroupAdminPage(
              token: 'admin-token',
              adminApi: fakeApi,
              autoLoad: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.textContaining('Advanced'));
        await tester.ensureVisible(find.text('Tạo geofence'));

        await tester.enterText(_textFieldByLabel('Tên geofence'), 'VP HCM');
        await tester.enterText(_textFieldByLabel('Bán kính (m)'), '250');

        await tester.tap(find.textContaining('Advanced'));
        await tester.pumpAndSettle();

        await tester.enterText(_textFieldByLabel('Vĩ độ'), '10.776889');
        await tester.enterText(_textFieldByLabel('Kinh độ'), '106.700806');
        await tester.tap(find.text('Áp dụng'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Tạo geofence'));
        await tester.pumpAndSettle();

        expect(fakeApi.createGeofenceCalls, 1);
        expect(fakeApi.lastToken, 'admin-token');
        expect(fakeApi.lastGroupId, 1);
        expect(fakeApi.lastName, 'VP HCM');
        expect(fakeApi.lastLatitude, closeTo(10.776889, 0.000001));
        expect(fakeApi.lastLongitude, closeTo(106.700806, 0.000001));
        expect(fakeApi.lastRadiusM, 250);
      },
    );
  });
}
