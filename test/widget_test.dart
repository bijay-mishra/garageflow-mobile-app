import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garageflow_mobile/core/formatters.dart';
import 'package:garageflow_mobile/models/auth_user.dart';
import 'package:garageflow_mobile/models/job.dart';
import 'package:garageflow_mobile/widgets/status_chip.dart';

/// Coverage for the logic that would otherwise only be exercised by running
/// the whole app against a live server.
///
/// This replaces the counter test `flutter create` writes: it referenced a
/// `MyApp` that no longer exists, and tested nothing this app does.
void main() {
  group('AuthUser', () {
    AuthUser withRole(String role) => AuthUser(
      id: 'USR-002',
      email: 'someone@garageflow.demo',
      name: 'Suresh Lama',
      role: role,
      workshop: 'GarageFlow HQ',
      companyCode: 'DEMO',
    );

    test('routes mechanics and customers to their own shells', () {
      expect(withRole('Mechanic').isMechanic, isTrue);
      expect(withRole('Mechanic').isStaff, isFalse);
      expect(withRole('Customer').isCustomer, isTrue);
      expect(withRole('Customer').isStaff, isFalse);
    });

    test('treats every dashboard role as staff, whom this app rejects', () {
      for (final role in ['Owner', 'Manager', 'Advisor']) {
        expect(withRole(role).isStaff, isTrue, reason: '$role should be staff');
      }
    });

    test('builds initials from the first and last name', () {
      expect(withRole('Mechanic').initials, 'SL');
    });

    test('survives a blank name rather than throwing on substring', () {
      const user = AuthUser(
        id: 'USR-009',
        email: 'nobody@garageflow.demo',
        name: '',
        role: 'Customer',
        workshop: '',
        companyCode: 'DEMO',
      );

      expect(user.initials, 'N');
    });

    test('round-trips through JSON, so a restored session is unchanged', () {
      final original = withRole('Mechanic');
      final restored = AuthUser.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.role, original.role);
      expect(restored.companyCode, original.companyCode);
    });
  });

  group('JobLine', () {
    test('totals quantity times unit price', () {
      const line = JobLine(
        description: 'Brake pads',
        qty: 2,
        unitPrice: 1250,
        kind: 'part',
      );

      expect(line.total, 2500);
      expect(line.isLabour, isFalse);
    });
  });

  group('Fmt.due', () {
    test('reads relative to today, which is what a mechanic needs', () {
      final today = DateTime.now();

      expect(Fmt.due(today), 'Due today');
      expect(Fmt.due(today.add(const Duration(days: 1))), 'Due tomorrow');
      expect(Fmt.due(today.subtract(const Duration(days: 1))), '1 day late');
      expect(Fmt.due(today.subtract(const Duration(days: 3))), '3 days late');
    });
  });

  group('Fmt.isoDate', () {
    test('pads to yyyy-MM-dd, since the server parses a DateOnly', () {
      expect(Fmt.isoDate(DateTime(2026, 8, 5)), '2026-08-05');
      expect(Fmt.isoDate(DateTime(2026, 12, 31)), '2026-12-31');
    });
  });

  group('mechanicSelectableStatuses', () {
    test('omits Delivered — handing keys back is a front-desk act', () {
      expect(mechanicSelectableStatuses, isNot(contains('Delivered')));
      expect(mechanicSelectableStatuses, contains('Completed'));
    });

    test('offers only statuses the server accepts', () {
      for (final status in mechanicSelectableStatuses) {
        expect(jobStatuses, contains(status));
      }
    });
  });

  testWidgets('StatusChip renders its status text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: StatusChip('Awaiting Parts'))),
      ),
    );

    expect(find.text('Awaiting Parts'), findsOneWidget);
  });
}
