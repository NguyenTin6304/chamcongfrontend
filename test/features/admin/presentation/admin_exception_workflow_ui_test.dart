import 'dart:io';

import 'package:birdle/core/theme/app_colors.dart';
import 'package:birdle/features/admin/presentation/exceptions/widgets/exception_ui_helpers.dart';
import 'package:birdle/features/admin/presentation/exceptions/widgets/pending_exception_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ExceptionModel _model({
  String status = 'PENDING_ADMIN',
  bool canAdminDecide = true,
}) {
  return ExceptionModel(
    id: 1,
    employeeName: 'Employee 01',
    employeeCode: 'E001',
    departmentName: 'Group 01',
    exceptionType: 'MISSED_CHECKOUT',
    status: status,
    workDate: DateTime(2026, 4, 7),
    checkInTime: '08:00',
    checkOutTime: '--',
    locationLabel: '--',
    reason: 'System reason',
    reviewerName: '--',
    createdAt: DateTime(2026, 4, 7, 9),
    canAdminDecide: canAdminDecide,
  );
}

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  group('admin exception status UX', () {
    test('maps all new statuses to labels and colors', () {
      expect(
        exceptionStatusLabel('PENDING_EMPLOYEE'),
        isNot('PENDING_EMPLOYEE'),
      );
      expect(exceptionStatusLabel('PENDING_ADMIN'), isNot('PENDING_ADMIN'));
      expect(exceptionStatusLabel('APPROVED'), isNot('APPROVED'));
      expect(exceptionStatusLabel('REJECTED'), isNot('REJECTED'));
      expect(exceptionStatusLabel('EXPIRED'), isNot('EXPIRED'));

      expect(
        exceptionStatusPalette('PENDING_EMPLOYEE').text,
        AppColors.badgeTextLate,
      );
      expect(
        exceptionStatusPalette('PENDING_ADMIN').text,
        AppColors.exceptionTabAllText,
      );
      expect(
        exceptionStatusPalette('APPROVED').text,
        AppColors.badgeTextOnTime,
      );
      expect(
        exceptionStatusPalette('REJECTED').text,
        AppColors.badgeTextOutOfRange,
      );
      expect(exceptionStatusPalette('EXPIRED').text, AppColors.textMuted);
    });
  });

  group('PendingExceptionCard actions', () {
    testWidgets('disables approve/reject when canDecide is false', (
      tester,
    ) async {
      var approveCount = 0;
      var rejectCount = 0;

      await tester.pumpWidget(
        _wrap(
          PendingExceptionCard(
            exception: _model(
              status: 'PENDING_EMPLOYEE',
              canAdminDecide: false,
            ),
            canDecide: false,
            onApprove: () => approveCount++,
            onReject: () => rejectCount++,
            onViewDetail: () {},
          ),
        ),
      );

      await tester.tap(find.byType(OutlinedButton));
      await tester.tap(find.byType(ElevatedButton));
      expect(approveCount, 0);
      expect(rejectCount, 0);
    });

    testWidgets('enables approve/reject when canDecide is true', (
      tester,
    ) async {
      var approveCount = 0;
      var rejectCount = 0;

      await tester.pumpWidget(
        _wrap(
          PendingExceptionCard(
            exception: _model(),
            canDecide: true,
            onApprove: () => approveCount++,
            onReject: () => rejectCount++,
            onViewDetail: () {},
          ),
        ),
      );

      await tester.tap(find.byType(OutlinedButton));
      await tester.tap(find.byType(ElevatedButton));
      expect(rejectCount, 1);
      expect(approveCount, 1);
    });
  });

  test('dashboard source does not mutate exception status directly', () {
    final source = File(
      'lib/features/admin/presentation/dashboard/dashboard_tab.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('_handleExceptionAction')));
    expect(source, isNot(contains('approveDashboardException')));
    expect(source, isNot(contains('rejectDashboardException')));
  });

  test('exceptions source exports history with Phase 6 filters', () {
    final source = File(
      'lib/features/admin/presentation/exceptions/exceptions_screen.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('exportDashboardExcel')));
    expect(source, contains('_loadExceptionRowsByTypeForExport'));
    expect(source, contains('statusFilter: _selectedStatus'));
    expect(source, contains('employeeId: _selectedEmployeeId'));
    expect(source, contains('exceptionType: exceptionType'));
    expect(source, contains('fromDate: _dateRange.from'));
    expect(source, contains('toDate: _dateRange.to'));
  });

  test(
    'exceptions source shows Phase 6 detail fields and read-only history detail',
    () {
      final source = File(
        'lib/features/admin/presentation/exceptions/exceptions_screen.dart',
      ).readAsStringSync();
      final historySource = File(
        'lib/features/admin/presentation/exceptions/widgets/exception_history_table.dart',
      ).readAsStringSync();

      expect(source, contains('adminNote'));
      expect(source, contains('adminDecidedAt'));
      expect(source, contains('decidedByEmail'));
      expect(source, contains('Không có timeline.'));
      expect(source, contains('readOnly: !_canAdminDecide(model)'));
      expect(historySource, isNot(contains('approveAttendanceException')));
      expect(historySource, isNot(contains('rejectAttendanceException')));
    },
  );

  test('exceptions source gates admin action and requires reject note', () {
    final source = File(
      'lib/features/admin/presentation/exceptions/exceptions_screen.dart',
    ).readAsStringSync();

    expect(source, contains("detail.status.toUpperCase() == 'PENDING_ADMIN'"));
    expect(source, contains('detail.canAdminDecide'));
    expect(source, contains('!readOnly'));
    expect(source, contains('Vui lòng nhập admin_note khi từ chối.'));
    expect(source, contains('rejectAttendanceException'));
    expect(source, contains('approveAttendanceException'));
  });
}
