import 'dart:convert';
import 'dart:io';

import 'package:birdle/features/attendance/data/attendance_api.dart';
import 'package:birdle/features/attendance/presentation/employee_exceptions_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _tok = 'test-token';

// ── Fixture helpers ────────────────────────────────────────────────────────

EmployeeExceptionItem _item({
  int id = 1,
  String status = 'PENDING_EMPLOYEE',
  String exceptionType = 'MISSED_CHECKOUT',
  bool canSubmitExplanation = true,
  String? employeeExplanation,
  DateTime? employeeSubmittedAt,
  String? adminNote,
  DateTime? expiresAt,
}) {
  return EmployeeExceptionItem(
    id: id,
    employeeId: 10,
    workDate: '2026-04-01',
    exceptionType: exceptionType,
    status: status,
    sourceCheckinLogId: 99,
    canSubmitExplanation: canSubmitExplanation,
    employeeExplanation: employeeExplanation,
    employeeSubmittedAt: employeeSubmittedAt,
    adminNote: adminNote,
    expiresAt: expiresAt ?? DateTime.now().add(const Duration(hours: 48)),
  );
}

Map<String, dynamic> _itemJson({
  int id = 1,
  String status = 'PENDING_EMPLOYEE',
  String exceptionType = 'MISSED_CHECKOUT',
  bool canSubmitExplanation = true,
  String? employeeExplanation,
  String? adminNote,
  String? adminDecidedAt,
}) =>
    {
      'id': id,
      'employee_id': 10,
      'employee_code': 'E010',
      'full_name': 'Nguyen Van A',
      'group_code': 'G01',
      'group_name': 'Group 01',
      'work_date': '2026-04-01',
      'exception_type': exceptionType,
      'status': status,
      'note': 'System reason',
      'source_checkin_log_id': 99,
      'source_checkin_time': '2026-04-01T08:00:00Z',
      'detected_at': '2026-04-01T10:00:00Z',
      'expires_at': '2026-04-04T10:00:00Z',
      'employee_explanation': employeeExplanation,
      'employee_submitted_at': null,
      'admin_note': adminNote,
      'admin_decided_at': adminDecidedAt,
      'decided_by_email': adminDecidedAt != null ? 'admin@example.com' : null,
      'created_at': '2026-04-01T10:00:00Z',
      'can_submit_explanation': canSubmitExplanation,
      'timeline': <Map<String, dynamic>>[],
    };

// Wraps child with a MaterialApp that registers /login so redirects don't throw.
Widget _wrap(Widget child) => MaterialApp(
      routes: {'/login': (_) => const Scaffold(body: Text('login'))},
      home: child,
    );

// MockClient that always fails — used so _loadDetail falls back to widget.item.
final _failClient = MockClient((_) async => http.Response('fail', 500));

// ── ExceptionDetailPage tests (no auth needed) ─────────────────────────────

void main() {
  group('ExceptionDetailPage', () {
    testWidgets('shows type label and status badge', (tester) async {
      await http.runWithClient(
        () async {
          await tester.pumpWidget(_wrap(ExceptionDetailPage(
            item: _item(
              exceptionType: 'MISSED_CHECKOUT',
              status: 'PENDING_EMPLOYEE',
            ),
            token: _tok,
          )));
          await tester.pumpAndSettle();
        },
        () => _failClient,
      );

      expect(find.text('Quên checkout'), findsWidgets);
      expect(find.text('Chờ giải trình'), findsOneWidget);
    });

    testWidgets('PENDING_EMPLOYEE shows editable TextField and send button',
        (tester) async {
      await http.runWithClient(
        () async {
          await tester.pumpWidget(_wrap(ExceptionDetailPage(
            item: _item(status: 'PENDING_EMPLOYEE', canSubmitExplanation: true),
            token: _tok,
          )));
          await tester.pumpAndSettle();
        },
        () => _failClient,
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Gửi giải trình'), findsOneWidget);
    });

    testWidgets('APPROVED shows submitted explanation and no TextField',
        (tester) async {
      await http.runWithClient(
        () async {
          await tester.pumpWidget(_wrap(ExceptionDetailPage(
            item: _item(
              status: 'APPROVED',
              canSubmitExplanation: false,
              employeeExplanation: 'Tôi quên checkout hôm đó.',
            ),
            token: _tok,
          )));
          await tester.pumpAndSettle();
        },
        () => _failClient,
      );

      expect(find.byType(TextField), findsNothing);
      expect(find.text('Tôi quên checkout hôm đó.'), findsOneWidget);
    });

    testWidgets('urgency banner appears when deadline is within 24h',
        (tester) async {
      await http.runWithClient(
        () async {
          await tester.pumpWidget(_wrap(ExceptionDetailPage(
            item: _item(
              status: 'PENDING_EMPLOYEE',
              expiresAt: DateTime.now().add(const Duration(hours: 6)),
            ),
            token: _tok,
          )));
          await tester.pumpAndSettle();
        },
        () => _failClient,
      );

      expect(find.textContaining('để giải trình'), findsOneWidget);
    });

    testWidgets('no urgency banner when deadline is more than 24h away',
        (tester) async {
      await http.runWithClient(
        () async {
          await tester.pumpWidget(_wrap(ExceptionDetailPage(
            item: _item(
              status: 'PENDING_EMPLOYEE',
              expiresAt: DateTime.now().add(const Duration(hours: 36)),
            ),
            token: _tok,
          )));
          await tester.pumpAndSettle();
        },
        () => _failClient,
      );

      expect(find.textContaining('để giải trình'), findsNothing);
    });
  });

  // ── EmployeeExceptionsScreen tests ────────────────────────────────────────

  group('EmployeeExceptionsScreen', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({'access_token': _tok});
    });

    testWidgets('shows loading indicator before API responds', (tester) async {
      await http.runWithClient(
        () async {
          await tester.pumpWidget(_wrap(const EmployeeExceptionsScreen()));
          // _bootstrap() queued but not yet resolved — loading == true
          expect(find.byType(CircularProgressIndicator), findsOneWidget);
          await tester.pumpAndSettle();
        },
        () => MockClient((_) async => http.Response(jsonEncode([]), 200)),
      );
    });

    testWidgets('shows empty state when API returns no items', (tester) async {
      await http.runWithClient(
        () async {
          await tester.pumpWidget(_wrap(const EmployeeExceptionsScreen()));
          await tester.pumpAndSettle();
        },
        () => MockClient((_) async => http.Response(jsonEncode([]), 200)),
      );

      expect(
        find.text('Không có ngoại lệ nào cần xử lý'),
        findsOneWidget,
      );
    });

    testWidgets('shows exception cards from API response', (tester) async {
      // Use mobile viewport so only the list is rendered (no split-panel),
      // ensuring all 3 cards are in the widget tree without scrolling.
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final items = [
        _itemJson(id: 1, exceptionType: 'MISSED_CHECKOUT'),
        _itemJson(id: 2, exceptionType: 'AUTO_CLOSED'),
        _itemJson(id: 3, exceptionType: 'LOCATION_RISK'),
      ];

      await http.runWithClient(
        () async {
          await tester.pumpWidget(_wrap(const EmployeeExceptionsScreen()));
          await tester.pumpAndSettle();
        },
        () => MockClient((_) async => http.Response(jsonEncode(items), 200)),
      );

      expect(find.text('Quên checkout'), findsOneWidget);
      expect(find.text('Tự động đóng ca'), findsOneWidget);
      expect(find.text('Bất thường vị trí'), findsOneWidget);
    });

    testWidgets('shows friendly error and retry button on API failure',
        (tester) async {
      await http.runWithClient(
        () async {
          await tester.pumpWidget(_wrap(const EmployeeExceptionsScreen()));
          await tester.pumpAndSettle();
        },
        () => MockClient((_) async => http.Response('server error', 500)),
      );

      expect(
        find.text('Có lỗi xảy ra. Vui lòng thử lại.'),
        findsOneWidget,
      );
      expect(find.text('Tải lại'), findsOneWidget);
    });
  });

  // ── Source structure tests ─────────────────────────────────────────────────

  group('source structure', () {
    test('screen implements all Phase 1-5 requirements', () {
      final source = File(
        'lib/features/attendance/presentation/employee_exceptions_screen.dart',
      ).readAsStringSync();

      // Phase 1 — widget extraction
      expect(source, contains('class _ExceptionCard'));
      expect(source, contains('class _ExceptionDetailPanel'));
      expect(source, contains('class _ExplanationSection extends StatefulWidget'));
      expect(source, contains('on Exception catch'));

      // Phase 3 — visual design
      expect(source, contains('_statusBorderColor'));
      expect(source, contains('class _TypeIconBox'));
      expect(source, contains('BoxShadow'));

      // Phase 4 — 3 breakpoints + mobile route
      expect(source, contains('AppBreakpoints.mobile'));
      expect(source, contains('AppBreakpoints.tablet'));
      expect(source, contains('AnimatedSwitcher'));
      expect(source, contains('class ExceptionDetailPage'));
      expect(source, contains("Navigator.push<EmployeeExceptionItem>"));

      // Phase 5 — polish
      expect(source, contains('_urgencyBanner'));
      expect(source, contains('_friendlyError'));
      expect(source, contains('dart:developer'));
    });
  });
}
