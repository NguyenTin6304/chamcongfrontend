import 'dart:convert';

import 'package:birdle/features/admin/presentation/shell/admin_shell_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAdminBackend {
  final Map<String, int> _hits = <String, int>{};

  int hit(String key) => _hits[key] ?? 0;

  MockClient get client => MockClient((request) async {
    final key = _bucket(request.url.path);
    _hits[key] = (_hits[key] ?? 0) + 1;

    switch (key) {
      case 'users':
        return http.Response('[]', 200);
      case 'groups':
        return http.Response('[]', 200);
      case 'group_summary':
        return http.Response(
          jsonEncode({
            '1': [
              {
                'id': 10,
                'group_id': 1,
                'name': 'HQ',
                'latitude': 10.7769,
                'longitude': 106.7009,
                'radius_m': 200,
                'active': true,
              },
            ],
          }),
          200,
        );
      case 'employees':
        return http.Response(
          jsonEncode([
            {
              'id': 1,
              'code': 'EM01',
              'full_name': 'Alice',
              'group_id': 1,
              'active': true,
            },
            {
              'id': 2,
              'code': 'EM02',
              'full_name': 'Bob',
              'group_id': null,
              'active': true,
            },
          ]),
          200,
        );
      case 'dashboard':
        return http.Response(
          jsonEncode({
            'total_employees': 2,
            'checked_in': 1,
            'attendance_rate': 50,
            'late_count': 0,
            'late_rate': 0,
            'out_of_range_count': 0,
            'geofence_count': 1,
            'inactive_geofence_count': 0,
            'employee_growth_percent': 0,
          }),
          200,
        );
      case 'attendance_logs':
        return http.Response(
          jsonEncode({'data': <dynamic>[], 'total': 0}),
          200,
        );
      case 'weekly_trends':
        return http.Response('[]', 200);
      case 'geofence_list':
        return http.Response('[]', 200);
      case 'dashboard_exceptions':
        return http.Response('[]', 200);
      default:
        return http.Response('{}', 200);
    }
  });

  String _bucket(String path) {
    if (path.endsWith('/groups/geofences/summary')) return 'group_summary';
    if (path.endsWith('/groups')) return 'groups';
    if (path.endsWith('/employees')) return 'employees';
    if (path.endsWith('/users')) return 'users';
    if (path.endsWith('/reports/dashboard')) return 'dashboard';
    if (path.endsWith('/reports/attendance-logs')) return 'attendance_logs';
    if (path.endsWith('/reports/weekly-trends')) return 'weekly_trends';
    if (path.endsWith('/geofence/list')) return 'geofence_list';
    if (path.endsWith('/reports/exceptions')) return 'dashboard_exceptions';
    return 'other';
  }
}

Future<void> _pumpFrames(WidgetTester tester, {int frames = 24}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    while (tester.takeException() != null) {}
  }
}

Future<void> _setDesktopSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1600, 1000));
}

Finder _sidebarItemByIcon(IconData icon) {
  return find.ancestor(of: find.byIcon(icon), matching: find.byType(InkWell));
}

void main() {
  late void Function(FlutterErrorDetails)? previousOnError;

  setUp(() {
    previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      final message = details.exceptionAsString();
      if (message.contains('A RenderFlex overflowed by')) {
        return;
      }
      if (message.contains(
        "Looking up a deactivated widget's ancestor is unsafe.",
      )) {
        return;
      }
      previousOnError?.call(details);
    };
  });

  tearDown(() {
    FlutterError.onError = previousOnError;
  });

  group('Admin groups route/state wiring', () {
    testWidgets(
      'uses same groups data flow for /admin/groups and /admin -> groups tab',
      (tester) async {
        await _setDesktopSurface(tester);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        SharedPreferences.setMockInitialValues(const {
          'access_token': 'test-token',
        });

        final groupsRouteBackend = _FakeAdminBackend();
        await http.runWithClient(() async {
          await tester.pumpWidget(
            const MaterialApp(home: AdminShellPage(email: 'admin@example.com', initialSection: 'groups')),
          );
          await _pumpFrames(tester);
        }, () => groupsRouteBackend.client);

        final dashboardRouteBackend = _FakeAdminBackend();
        await http.runWithClient(() async {
          await tester.pumpWidget(
            const MaterialApp(
              home: AdminShellPage(email: 'admin@example.com', initialSection: 'dashboard'),
            ),
          );
          await _pumpFrames(tester);

          await tester.tap(_sidebarItemByIcon(Icons.groups_2_outlined).first);
          await _pumpFrames(tester);
        }, () => dashboardRouteBackend.client);

        expect(
          groupsRouteBackend.hit('groups'),
          dashboardRouteBackend.hit('groups'),
        );
        expect(
          groupsRouteBackend.hit('employees'),
          dashboardRouteBackend.hit('employees'),
        );
        expect(
          groupsRouteBackend.hit('group_summary'),
          dashboardRouteBackend.hit('group_summary'),
        );
        expect(groupsRouteBackend.hit('employees'), greaterThanOrEqualTo(1));
      },
    );

    testWidgets(
      'switching tabs repeatedly does not increase groups fetch unexpectedly',
      (tester) async {
        await _setDesktopSurface(tester);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        SharedPreferences.setMockInitialValues(const {
          'access_token': 'test-token',
        });

        final backend = _FakeAdminBackend();

        await http.runWithClient(() async {
          await tester.pumpWidget(
            const MaterialApp(
              home: AdminShellPage(email: 'admin@example.com', initialSection: 'dashboard'),
            ),
          );
          await _pumpFrames(tester);

          await tester.tap(_sidebarItemByIcon(Icons.groups_2_outlined).first);
          await _pumpFrames(tester);

          final groupsAfterFirstOpen = backend.hit('groups');
          final employeesAfterFirstOpen = backend.hit('employees');
          final summaryAfterFirstOpen = backend.hit('group_summary');

          await tester.tap(_sidebarItemByIcon(Icons.dashboard_outlined).first);
          await _pumpFrames(tester, frames: 10);
          await tester.tap(_sidebarItemByIcon(Icons.groups_2_outlined).first);
          await _pumpFrames(tester);

          expect(backend.hit('groups'), groupsAfterFirstOpen);
          expect(backend.hit('employees'), employeesAfterFirstOpen);
          expect(backend.hit('group_summary'), summaryAfterFirstOpen);

          await tester.pumpWidget(
            const MaterialApp(
              home: AdminShellPage(email: 'admin@example.com', initialSection: 'dashboard'),
            ),
          );
          await _pumpFrames(tester);
          await tester.tap(_sidebarItemByIcon(Icons.groups_2_outlined).first);
          await _pumpFrames(tester);

          expect(
            backend.hit('groups'),
            inInclusiveRange(groupsAfterFirstOpen, groupsAfterFirstOpen + 1),
          );
          expect(
            backend.hit('employees'),
            inInclusiveRange(
              employeesAfterFirstOpen,
              employeesAfterFirstOpen + 1,
            ),
          );
          expect(
            backend.hit('group_summary'),
            inInclusiveRange(summaryAfterFirstOpen, summaryAfterFirstOpen + 1),
          );
        }, () => backend.client);
      },
    );
  });
}
