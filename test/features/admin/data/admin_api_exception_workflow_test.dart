import 'dart:convert';

import 'package:birdle/features/admin/data/admin_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _api = AdminApi();
const _tok = 'test-token';

Map<String, dynamic> _exceptionFix({
  int id = 7,
  String status = 'PENDING_ADMIN',
  bool canAdminDecide = true,
}) {
  return {
    'id': id,
    'employee_id': 10,
    'employee_code': 'E010',
    'full_name': 'Employee 10',
    'group_code': 'G01',
    'group_name': 'Group 01',
    'work_date': '2026-04-07',
    'exception_type': 'MISSED_CHECKOUT',
    'status': status,
    'note': 'System reason',
    'source_checkin_log_id': 99,
    'source_checkin_time': '2026-04-07T08:00:00Z',
    'actual_checkout_time': null,
    'created_at': '2026-04-07T09:00:00Z',
    'detected_at': '2026-04-07T09:01:00Z',
    'expires_at': '2026-04-09T00:00:00Z',
    'employee_explanation': 'Forgot to checkout',
    'employee_submitted_at': '2026-04-07T10:00:00Z',
    'admin_note': 'Looks valid',
    'admin_decided_at': '2026-04-07T11:00:00Z',
    'decided_by_email': 'admin@example.com',
    'can_admin_decide': canAdminDecide,
    'timeline': [
      {
        'action': 'CREATED',
        'actor_email': 'system@example.com',
        'created_at': '2026-04-07T09:01:00Z',
        'note': 'Detected by scheduler',
      },
    ],
  };
}

void main() {
  group('AdminApi exception workflow', () {
    test('lists exceptions with new status filter and parses new fields', () async {
      final client = MockClient((req) async {
        expect(req.method, 'GET');
        expect(req.url.path, endsWith('/reports/attendance-exceptions'));
        expect(req.url.queryParameters['status'], 'PENDING_ADMIN');
        expect(req.url.queryParameters.containsKey('exception_type'), isFalse);
        expect(req.headers['Authorization'], contains(_tok));
        return http.Response(jsonEncode([_exceptionFix()]), 200);
      });

      final result = await http.runWithClient(
        () => _api.listAttendanceExceptions(
          token: _tok,
          statusFilter: 'PENDING_ADMIN',
        ),
        () => client,
      );

      final item = result.single;
      expect(item.status, 'PENDING_ADMIN');
      expect(item.detectedAt, isNotNull);
      expect(item.expiresAt, isNotNull);
      expect(item.employeeExplanation, 'Forgot to checkout');
      expect(item.employeeSubmittedAt, isNotNull);
      expect(item.adminNote, 'Looks valid');
      expect(item.adminDecidedAt, isNotNull);
      expect(item.decidedByEmail, 'admin@example.com');
      expect(item.resolvedByEmail, 'admin@example.com');
      expect(item.canAdminDecide, isTrue);
      expect(item.timeline.single['action'], 'CREATED');
      expect(item.timeline.single['actor_email'], 'system@example.com');
      expect(item.timeline.single['created_at'], '2026-04-07T09:01:00Z');
      expect(item.timeline.single['note'], 'Detected by scheduler');
    });

    test('list sends Phase 6 history filters to backend query', () async {
      final client = MockClient((req) async {
        expect(req.method, 'GET');
        expect(req.url.path, endsWith('/reports/attendance-exceptions'));
        expect(req.url.queryParameters['status'], 'APPROVED');
        expect(req.url.queryParameters['exception_type'], 'MISSED_CHECKOUT');
        expect(req.url.queryParameters['group_id'], '2');
        expect(req.url.queryParameters['employee_id'], '10');
        expect(req.url.queryParameters['from'], '2026-04-01');
        expect(req.url.queryParameters['to'], '2026-04-30');
        return http.Response(jsonEncode([_exceptionFix(status: 'APPROVED')]), 200);
      });

      final result = await http.runWithClient(
        () => _api.listAttendanceExceptions(
          token: _tok,
          statusFilter: 'APPROVED',
          exceptionType: 'MISSED_CHECKOUT',
          groupId: 2,
          employeeId: 10,
          fromDate: DateTime(2026, 4),
          toDate: DateTime(2026, 4, 30),
        ),
        () => client,
      );

      expect(result.single.status, 'APPROVED');
    });

    test('approve sends optional admin_note to new endpoint', () async {
      final client = MockClient((req) async {
        expect(req.method, 'POST');
        expect(req.url.path, endsWith('/reports/attendance-exceptions/7/approve'));
        expect(jsonDecode(req.body), {'admin_note': 'ok'});
        return http.Response(jsonEncode(_exceptionFix(status: 'APPROVED')), 200);
      });

      final result = await http.runWithClient(
        () => _api.approveAttendanceException(
          token: _tok,
          exceptionId: 7,
          adminNote: ' ok ',
        ),
        () => client,
      );

      expect(result.status, 'APPROVED');
    });

    test('reject requires non-empty admin_note and sends new request body', () async {
      await expectLater(
        _api.rejectAttendanceException(
          token: _tok,
          exceptionId: 7,
          adminNote: '   ',
        ),
        throwsArgumentError,
      );

      final client = MockClient((req) async {
        expect(req.method, 'POST');
        expect(req.url.path, endsWith('/reports/attendance-exceptions/7/reject'));
        expect(jsonDecode(req.body), {'admin_note': 'invalid explanation'});
        return http.Response(jsonEncode(_exceptionFix(status: 'REJECTED')), 200);
      });

      final result = await http.runWithClient(
        () => _api.rejectAttendanceException(
          token: _tok,
          exceptionId: 7,
          adminNote: ' invalid explanation ',
        ),
        () => client,
      );

      expect(result.status, 'REJECTED');
    });
  });
}
