// Regression + unit tests cho groups/geofences API sau tối ưu hiệu năng.
//
// Bao phủ:
//  1. listGroupGeofencesSummary — N+1 fix: string key → int key, multi-group parsing
//  2. listGroups — null-safety cho mọi optional field
//  3. createGroup / updateGroup — serialise body đúng, bao gồm null clear
//  4. assignEmployeeGroup — unassign (null) và assign (int)
//  5. deleteGroup — trả về thành công không throw
//
// Chạy: flutter test test/features/admin/data/admin_api_groups_regression_test.dart

import 'dart:convert';

import 'package:birdle/features/admin/data/admin_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _api = AdminApi();
const _tok = 'test-token';

/// Geofence JSON fixture with all required fields.
Map<String, dynamic> _geoFix({
  int id = 10,
  int groupId = 1,
  String name = 'Zone A',
  double lat = 10.5,
  double lng = 106.7,
  int radiusM = 200,
  bool active = true,
}) =>
    {
      'id': id,
      'group_id': groupId,
      'name': name,
      'latitude': lat,
      'longitude': lng,
      'radius_m': radiusM,
      'active': active,
    };

/// Group JSON fixture.
Map<String, dynamic> _groupFix({
  int id = 1,
  String code = 'G01',
  String name = 'Group 01',
  bool active = true,
  String? startTime,
  String? endTime,
  int? graceMinutes,
  int? checkoutGraceMinutes,
}) {
  final m = <String, dynamic>{
    'id': id,
    'code': code,
    'name': name,
    'active': active,
  };
  if (startTime != null) m['start_time'] = startTime;
  if (endTime != null) m['end_time'] = endTime;
  if (graceMinutes != null) m['grace_minutes'] = graceMinutes;
  if (checkoutGraceMinutes != null) m['checkout_grace_minutes'] = checkoutGraceMinutes;
  return m;
}

/// Employee JSON fixture.
Map<String, dynamic> _empFix({
  int id = 100,
  String code = 'E001',
  String fullName = 'Nguyễn Văn A',
  bool active = true,
  int? groupId,
}) {
  final m = <String, dynamic>{
    'id': id,
    'code': code,
    'full_name': fullName,
    'active': active,
  };
  if (groupId != null) m['group_id'] = groupId;
  return m;
}

// ---------------------------------------------------------------------------
// 1. listGroupGeofencesSummary — N+1 fix
// ---------------------------------------------------------------------------

void main() {
  group('listGroupGeofencesSummary – N+1 fix', () {
    test('parses multi-group response, string keys → int keys', () async {
      final client = MockClient((req) async {
        expect(req.url.path, endsWith('/groups/geofences/summary'));
        expect(req.headers['Authorization'], contains(_tok));
        return http.Response(
          jsonEncode({
            '1': [_geoFix(id: 10, groupId: 1, name: 'Zone A', radiusM: 200)],
            '2': [
              _geoFix(id: 20, groupId: 2, name: 'Zone B', radiusM: 150, active: false),
              _geoFix(id: 21, groupId: 2, name: 'Zone C', radiusM: 300),
            ],
          }),
          200,
        );
      });

      final result = await http.runWithClient(
        () => _api.listGroupGeofencesSummary(token: _tok),
        () => client,
      );

      expect(result.length, 2);
      expect(result.containsKey(1), isTrue);
      expect(result.containsKey(2), isTrue);

      final z1 = result[1]!.first;
      expect(z1.id, 10);
      expect(z1.name, 'Zone A');
      expect(z1.radiusM, 200);
      expect(z1.latitude, closeTo(10.5, 0.001));
      expect(z1.active, isTrue);

      expect(result[2]!.length, 2);
      expect(result[2]![0].active, isFalse);
      expect(result[2]![1].radiusM, 300);
    });

    test('skips non-numeric string keys', () async {
      final client = MockClient((_) async {
        return http.Response(
          jsonEncode({
            '1': [_geoFix()],
            'invalid_key': [_geoFix(id: 99, groupId: 0, name: 'Ghost')],
            'null': [_geoFix(id: 98)],
          }),
          200,
        );
      });

      final result = await http.runWithClient(
        () => _api.listGroupGeofencesSummary(token: _tok),
        () => client,
      );

      expect(result.length, 1);
      expect(result.containsKey(1), isTrue);
      expect(result.containsKey(0), isFalse);
    });

    test('returns empty map when response is {}', () async {
      final client = MockClient((_) async {
        return http.Response(jsonEncode(<String, dynamic>{}), 200);
      });

      final result = await http.runWithClient(
        () => _api.listGroupGeofencesSummary(token: _tok),
        () => client,
      );

      expect(result, isEmpty);
    });

    test('appends group_ids param when provided', () async {
      final client = MockClient((req) async {
        expect(req.url.queryParameters['group_ids'], '1,2,3');
        return http.Response(jsonEncode(<String, dynamic>{}), 200);
      });

      await http.runWithClient(
        () => _api.listGroupGeofencesSummary(token: _tok, groupIds: [1, 2, 3]),
        () => client,
      );
    });

    test('does NOT append group_ids when list is empty', () async {
      final client = MockClient((req) async {
        expect(req.url.queryParameters.containsKey('group_ids'), isFalse);
        return http.Response(jsonEncode(<String, dynamic>{}), 200);
      });

      await http.runWithClient(
        () => _api.listGroupGeofencesSummary(token: _tok, groupIds: []),
        () => client,
      );
    });

    test('throws on non-200 status', () async {
      final client = MockClient((_) async {
        return http.Response(jsonEncode({'detail': 'Forbidden'}), 403);
      });

      await expectLater(
        http.runWithClient(
          () => _api.listGroupGeofencesSummary(token: _tok),
          () => client,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('handles non-list value for a group key gracefully', () async {
      // If backend sends {"1": null}, it should not crash.
      final client = MockClient((_) async {
        return http.Response(
          jsonEncode({'1': null, '2': [_geoFix(groupId: 2)]}),
          200,
        );
      });

      final result = await http.runWithClient(
        () => _api.listGroupGeofencesSummary(token: _tok),
        () => client,
      );

      // null value treated as empty list → key 1 maps to []
      expect(result.containsKey(1), isTrue);
      expect(result[1]!, isEmpty);
      expect(result[2]!.length, 1);
    });
  });

  // -------------------------------------------------------------------------
  // 2. listGroups — null-safety
  // -------------------------------------------------------------------------

  group('listGroups – null-safety', () {
    test('maps all optional fields when present', () async {
      final client = MockClient((_) async {
        return http.Response(
          jsonEncode([
            _groupFix(
              id: 1,
              code: 'G01',
              name: 'Nhóm sáng',
              startTime: '08:00',
              endTime: '17:30',
              graceMinutes: 15,
              checkoutGraceMinutes: 1080,
            ),
          ]),
          200,
        );
      });

      final groups = await http.runWithClient(
        () => _api.listGroups(_tok),
        () => client,
      );

      expect(groups.length, 1);
      final g = groups.first;
      expect(g.id, 1);
      expect(g.code, 'G01');
      expect(g.name, 'Nhóm sáng');
      expect(g.startTime, '08:00');
      expect(g.endTime, '17:30');
      expect(g.graceMinutes, 15);
      expect(g.checkoutGraceMinutes, 1080);
      expect(g.active, isTrue);
    });

    test('handles all-null optional fields without crash', () async {
      final client = MockClient((_) async {
        return http.Response(
          jsonEncode([
            {'id': 2, 'code': 'G02', 'name': 'Nhóm chiều', 'active': false},
          ]),
          200,
        );
      });

      final groups = await http.runWithClient(
        () => _api.listGroups(_tok),
        () => client,
      );

      expect(groups.length, 1);
      final g = groups.first;
      expect(g.startTime, isNull);
      expect(g.endTime, isNull);
      expect(g.graceMinutes, isNull);
      expect(g.checkoutGraceMinutes, isNull);
      expect(g.active, isFalse);
    });

    test('returns empty list when API returns []', () async {
      final client = MockClient((_) async {
        return http.Response(jsonEncode(<dynamic>[]), 200);
      });

      final groups = await http.runWithClient(
        () => _api.listGroups(_tok),
        () => client,
      );

      expect(groups, isEmpty);
    });

    test('throws on error response', () async {
      final client = MockClient((_) async {
        return http.Response(jsonEncode({'detail': 'Unauthorized'}), 401);
      });

      await expectLater(
        http.runWithClient(() => _api.listGroups(_tok), () => client),
        throwsA(isA<Exception>()),
      );
    });
  });

  // -------------------------------------------------------------------------
  // 3. createGroup — body serialisation
  // -------------------------------------------------------------------------

  group('createGroup – body serialisation', () {
    test('sends required fields + optional when provided', () async {
      Map<String, dynamic>? sentBody;
      final client = MockClient((req) async {
        sentBody = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode(_groupFix(
            id: 99,
            code: 'G99',
            name: 'New Group',
            startTime: '08:00',
            endTime: '17:30',
            graceMinutes: 10,
          )),
          201,
        );
      });

      await http.runWithClient(
        () => _api.createGroup(
          token: _tok,
          code: 'G99',
          name: 'New Group',
          active: true,
          startTime: '08:00',
          endTime: '17:30',
          graceMinutes: 10,
        ),
        () => client,
      );

      expect(sentBody!['code'], 'G99');
      expect(sentBody!['name'], 'New Group');
      expect(sentBody!['active'], isTrue);
      expect(sentBody!['start_time'], '08:00');
      expect(sentBody!['end_time'], '17:30');
      expect(sentBody!['grace_minutes'], 10);
    });

    test('omits optional fields when null/empty', () async {
      Map<String, dynamic>? sentBody;
      final client = MockClient((req) async {
        sentBody = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response(jsonEncode(_groupFix(code: 'G88', name: 'Min')), 201);
      });

      await http.runWithClient(
        () => _api.createGroup(token: _tok, code: 'G88', name: 'Min'),
        () => client,
      );

      expect(sentBody!.containsKey('start_time'), isFalse);
      expect(sentBody!.containsKey('end_time'), isFalse);
      expect(sentBody!.containsKey('grace_minutes'), isFalse);
      expect(sentBody!.containsKey('checkout_grace_minutes'), isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // 4. updateGroup — null clear
  // -------------------------------------------------------------------------

  group('updateGroup – clearCheckoutGraceMinutes', () {
    test('sends null when clearCheckoutGraceMinutes=true', () async {
      Map<String, dynamic>? sentBody;
      final client = MockClient((req) async {
        sentBody = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response(jsonEncode(_groupFix(id: 1)), 200);
      });

      await http.runWithClient(
        () => _api.updateGroup(
          token: _tok,
          groupId: 1,
          name: 'Updated',
          clearCheckoutGraceMinutes: true,
        ),
        () => client,
      );

      expect(sentBody!.containsKey('checkout_grace_minutes'), isTrue);
      expect(sentBody!['checkout_grace_minutes'], isNull);
    });

    test('sends value when autoCheckout enabled', () async {
      Map<String, dynamic>? sentBody;
      final client = MockClient((req) async {
        sentBody = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode(_groupFix(id: 1, checkoutGraceMinutes: 1080)),
          200,
        );
      });

      await http.runWithClient(
        () => _api.updateGroup(
          token: _tok,
          groupId: 1,
          checkoutGraceMinutes: 1080,
        ),
        () => client,
      );

      expect(sentBody!['checkout_grace_minutes'], 1080);
    });
  });

  // -------------------------------------------------------------------------
  // 5. assignEmployeeGroup — assign & unassign
  // -------------------------------------------------------------------------

  group('assignEmployeeGroup – assign/unassign', () {
    test('sends groupId=null to unassign', () async {
      Map<String, dynamic>? sentBody;
      String? calledPath;
      final client = MockClient((req) async {
        sentBody = jsonDecode(req.body) as Map<String, dynamic>;
        calledPath = req.url.path;
        return http.Response(
          jsonEncode(_empFix(id: 100, groupId: null)),
          200,
        );
      });

      await http.runWithClient(
        () => _api.assignEmployeeGroup(
          token: _tok,
          employeeId: 100,
          groupId: null,
        ),
        () => client,
      );

      expect(calledPath, endsWith('/employees/100/assign-group'));
      expect(sentBody!.containsKey('group_id'), isTrue);
      expect(sentBody!['group_id'], isNull);
    });

    test('sends groupId=int to assign', () async {
      Map<String, dynamic>? sentBody;
      final client = MockClient((req) async {
        sentBody = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode(_empFix(id: 100, groupId: 3)),
          200,
        );
      });

      await http.runWithClient(
        () => _api.assignEmployeeGroup(
          token: _tok,
          employeeId: 100,
          groupId: 3,
        ),
        () => client,
      );

      expect(sentBody!['group_id'], 3);
    });

    test('returns updated EmployeeLite with new groupId', () async {
      final client = MockClient((_) async {
        return http.Response(
          jsonEncode(_empFix(id: 100, groupId: 5, fullName: 'Trần Thị B')),
          200,
        );
      });

      final emp = await http.runWithClient(
        () => _api.assignEmployeeGroup(
          token: _tok,
          employeeId: 100,
          groupId: 5,
        ),
        () => client,
      );

      expect(emp.id, 100);
      expect(emp.groupId, 5);
      expect(emp.fullName, 'Trần Thị B');
    });
  });

  // -------------------------------------------------------------------------
  // 6. deleteGroup — thành công không throw
  // -------------------------------------------------------------------------

  group('deleteGroup', () {
    test('completes without throwing on 200', () async {
      final client = MockClient((_) async {
        return http.Response(
          jsonEncode({'ok': true, 'deleted_group_id': 1}),
          200,
        );
      });

      await expectLater(
        http.runWithClient(
          () => _api.deleteGroup(token: _tok, groupId: 1),
          () => client,
        ),
        completes,
      );
    });

    test('throws on 404', () async {
      final client = MockClient((_) async {
        return http.Response(jsonEncode({'detail': 'Group not found'}), 404);
      });

      await expectLater(
        http.runWithClient(
          () => _api.deleteGroup(token: _tok, groupId: 999),
          () => client,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  // -------------------------------------------------------------------------
  // 7. _groupGeofenceFromMap — null-safety trực tiếp qua listGroupGeofences
  // -------------------------------------------------------------------------

  group('GroupGeofenceLite mapping – null-safety', () {
    test('uses fallback 0 when radius_m missing', () async {
      final client = MockClient((_) async {
        return http.Response(
          jsonEncode([
            {
              'id': 5,
              'group_id': 1,
              'name': 'No Radius',
              'latitude': 10.0,
              'longitude': 106.0,
              // radius_m intentionally omitted
              'active': true,
            },
          ]),
          200,
        );
      });

      final items = await http.runWithClient(
        () => _api.listGroupGeofences(token: _tok, groupId: 1),
        () => client,
      );

      expect(items.first.radiusM, 0); // fallback
    });

    test('active defaults to true when field missing', () async {
      final client = MockClient((_) async {
        return http.Response(
          jsonEncode([
            {
              'id': 6,
              'group_id': 1,
              'name': 'No Active',
              'latitude': 10.0,
              'longitude': 106.0,
              'radius_m': 100,
              // active intentionally omitted
            },
          ]),
          200,
        );
      });

      final items = await http.runWithClient(
        () => _api.listGroupGeofences(token: _tok, groupId: 1),
        () => client,
      );

      expect(items.first.active, isTrue); // default true
    });
  });
}
