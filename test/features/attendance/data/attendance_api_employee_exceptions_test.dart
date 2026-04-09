import 'dart:convert';
import 'dart:io';

import 'package:birdle/features/attendance/data/attendance_api.dart';
import 'package:birdle/features/attendance/presentation/employee_exceptions_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _api = AttendanceApi();
const _tok = 'employee-token';

Map<String, dynamic> _exceptionFix({
  int id = 7,
  String status = 'PENDING_EMPLOYEE',
  bool canSubmitExplanation = true,
  String? employeeExplanation,
  String? employeeSubmittedAt,
  String? adminNote,
  String? adminDecidedAt,
}) {
  return {
    'id': id,
    'employee_id': 10,
    'employee_code': 'E010',
    'full_name': 'Nguyen Van A',
    'group_code': 'G01',
    'group_name': 'Group 01',
    'work_date': '2026-04-01',
    'exception_type': 'MISSED_CHECKOUT',
    'status': status,
    'note': 'System detected missing checkout',
    'source_checkin_log_id': 99,
    'source_checkin_time': '2026-04-01T01:00:00Z',
    'detected_at': '2026-04-01T10:00:00Z',
    'expires_at': '2026-04-04T10:00:00Z',
    'employee_explanation': employeeExplanation,
    'employee_submitted_at': employeeSubmittedAt,
    'admin_note': adminNote,
    'admin_decided_at': adminDecidedAt,
    'decided_by_email': adminNote == null ? null : 'admin@example.com',
    'created_at': '2026-04-01T10:00:00Z',
    'can_submit_explanation': canSubmitExplanation,
    'timeline': [
      {
        'id': 1,
        'event_type': 'exception_detected',
        'previous_status': null,
        'next_status': status,
        'actor_type': 'SYSTEM',
        'actor_email': 'SYSTEM',
        'created_at': '2026-04-01T10:00:00Z',
      },
    ],
  };
}

void main() {
  group('AttendanceApi employee exceptions', () {
    test('listMyExceptions parses workflow fields and timeline', () async {
      final client = MockClient((request) async {
        expect(request.url.path, endsWith('/reports/attendance-exceptions/me'));
        expect(request.url.queryParameters['status'], 'PENDING_EMPLOYEE');
        return http.Response(jsonEncode([_exceptionFix()]), 200);
      });

      final result = await http.runWithClient(
        () => _api.listMyExceptions(_tok, status: 'PENDING_EMPLOYEE'),
        () => client,
      );

      expect(result, hasLength(1));
      final item = result.first;
      expect(item.status, 'PENDING_EMPLOYEE');
      expect(item.detectedAt, DateTime.parse('2026-04-01T10:00:00Z'));
      expect(item.expiresAt, DateTime.parse('2026-04-04T10:00:00Z'));
      expect(item.canSubmitExplanation, isTrue);
      expect(item.canEditExplanation, isTrue);
      expect(item.timeline.single.eventType, 'exception_detected');
    });

    test('submitExceptionExplanation sends correct request body', () async {
      Map<String, dynamic>? body;
      final client = MockClient((request) async {
        expect(request.url.path, endsWith('/reports/attendance-exceptions/7/submit-explanation'));
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode(_exceptionFix(
            status: 'PENDING_ADMIN',
            canSubmitExplanation: false,
            employeeExplanation: 'I forgot to checkout.',
            employeeSubmittedAt: '2026-04-02T01:00:00Z',
          )),
          200,
        );
      });

      final result = await http.runWithClient(
        () => _api.submitExceptionExplanation(
          token: _tok,
          exceptionId: 7,
          explanation: 'I forgot to checkout.',
        ),
        () => client,
      );

      expect(body, {'explanation': 'I forgot to checkout.'});
      expect(result.status, 'PENDING_ADMIN');
      expect(result.canEditExplanation, isFalse);
    });

    test('canEditExplanation only allows pending employee status', () async {
      for (final status in [
        'PENDING_ADMIN',
        'APPROVED',
        'REJECTED',
        'EXPIRED',
      ]) {
        final client = MockClient((request) async {
          return http.Response(
            jsonEncode([
              _exceptionFix(
                status: status,
                canSubmitExplanation: false,
                employeeExplanation: 'Already handled',
                employeeSubmittedAt: '2026-04-02T01:00:00Z',
              ),
            ]),
            200,
          );
        });

        final result = await http.runWithClient(
          () => _api.listMyExceptions(_tok, status: status),
          () => client,
        );

        expect(result.single.status, status);
        expect(result.single.canEditExplanation, isFalse);
      }
    });
  });

  group('EmployeeExceptionsScreen', () {
    test('source maps all workflow statuses and gates submit action', () {
      final source = File(
        'lib/features/attendance/presentation/employee_exceptions_screen.dart',
      ).readAsStringSync();

      for (final status in [
        'PENDING_EMPLOYEE',
        'PENDING_ADMIN',
        'APPROVED',
        'REJECTED',
        'EXPIRED',
      ]) {
        expect(source, contains("'$status'"));
      }
      expect(source, contains("item.status == 'PENDING_EMPLOYEE'"));
      expect(source, contains('item.canSubmitExplanation'));
      expect(source, contains('item.employeeSubmittedAt == null'));
      expect(source, contains('_disabledExplanationHint'));
    });

    testWidgets('enables explanation field for PENDING_EMPLOYEE', (tester) async {
      SharedPreferences.setMockInitialValues({'access_token': _tok});
      final client = MockClient((request) async {
        return http.Response(jsonEncode([_exceptionFix()]), 200);
      });

      await http.runWithClient(
        () async {
          await tester.pumpWidget(const MaterialApp(home: EmployeeExceptionsScreen()));
          await tester.pumpAndSettle();
        },
        () => client,
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.enabled, isTrue);
      expect(find.text('Gui giai trinh'), findsOneWidget);
    });

    testWidgets('disables explanation field and shows admin note for final decision', (tester) async {
      SharedPreferences.setMockInitialValues({'access_token': _tok});
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode([
            _exceptionFix(
              status: 'REJECTED',
              canSubmitExplanation: false,
              employeeExplanation: 'I forgot to checkout.',
              employeeSubmittedAt: '2026-04-02T01:00:00Z',
              adminNote: 'Reason rejected',
              adminDecidedAt: '2026-04-03T01:00:00Z',
            ),
          ]),
          200,
        );
      });

      await http.runWithClient(
        () async {
          await tester.pumpWidget(const MaterialApp(home: EmployeeExceptionsScreen()));
          await tester.pumpAndSettle();
        },
        () => client,
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.enabled, isFalse);
      expect(find.text('Reason rejected'), findsOneWidget);
      expect(find.text('Tu choi'), findsWidgets);
    });
  });
}
