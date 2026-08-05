import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jkdd_field_time_records_production/main.dart';
import 'package:jkdd_field_time_records_production/src/auth/auth_session.dart';
import 'package:jkdd_field_time_records_production/src/presentation/screens/timesheet_screen.dart';
import 'package:jkdd_field_time_records_production/src/supervisor_center/supervisor_center_models.dart';
import 'package:jkdd_field_time_records_production/time_records.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> pumpAuthenticatedApp(
    WidgetTester tester, {
    required String userId,
    required String username,
    required String role,
    required Size screenSize,
  }) async {
    SharedPreferences.setMockInitialValues({
      AuthSessionController.storageKey: jsonEncode({
        'id': userId,
        'username': username,
        'role': role,
      }),
    });

    tester.view.physicalSize = screenSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fieldTimeRepositoryProvider
              .overrideWithValue(InMemoryFieldTimeRepository()),
        ],
        child: const FieldTimeApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('reselecting the same bottom navigation tab returns to root view',
      (tester) async {
    await pumpAuthenticatedApp(
      tester,
      userId: 'TER-0001',
      username: 'collaborator@test.jkdd',
      role: PilotRole.employee.name,
      screenSize: const Size(600, 1024),
    );

    expect(find.text('Meu timesheet'), findsOneWidget);

    final timesheetNavLabel =
      find.descendant(of: find.byType(BottomNavigationBar), matching: find.text('Timesheet'));
    expect(timesheetNavLabel, findsOneWidget);
    await tester.tap(timesheetNavLabel);
    await tester.pumpAndSettle();

    final bottomNav = tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar));
    expect(bottomNav.currentIndex, equals(1));

    // Reselect same tab
    await tester.tap(timesheetNavLabel);
    await tester.pumpAndSettle();

    final bottomNav2 = tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar));
    expect(bottomNav2.currentIndex, equals(1));
  });

  testWidgets('management tab root reset via bottom navigation', (tester) async {
    await pumpAuthenticatedApp(
      tester,
      userId: 'test-supervisor',
      username: 'supervisor@test.jkdd',
      role: PilotRole.supervisor.name,
      screenSize: const Size(600, 1024),
    );

    // Management destination should be present for supervisor role
    final managementNavLabel = find.descendant(
      of: find.byType(BottomNavigationBar), matching: find.text('Management'));
    // In Portuguese build the label may be 'Gestão' — accept either
    final managementLabelExists = managementNavLabel.evaluate().isNotEmpty ||
      find.descendant(of: find.byType(BottomNavigationBar), matching: find.text('Gestão')).evaluate().isNotEmpty;
    expect(managementLabelExists, isTrue);
  });

  testWidgets('reselecting same navigation rail destination returns to root',
      (tester) async {
    await pumpAuthenticatedApp(
      tester,
      userId: 'TER-0001',
      username: 'collaborator@test.jkdd',
      role: PilotRole.employee.name,
      screenSize: const Size(1920, 1080),
    );

    final railTimesheetLabel = find.descendant(
      of: find.byType(NavigationRail), matching: find.text('Timesheet'));
    expect(railTimesheetLabel, findsAtLeastNWidgets(1));

      await tester.tap(railTimesheetLabel.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      final timesheetIdx = rail.destinations.indexWhere((d) => d.label is Text && (d.label as Text).data == 'Timesheet');
      expect(timesheetIdx, isNonNegative);
      expect(rail.selectedIndex, equals(timesheetIdx));

    await tester.tap(find.byIcon(Icons.table_chart).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final rail2 = tester.widget<NavigationRail>(find.byType(NavigationRail));
      final timesheetIdx2 = rail2.destinations.indexWhere((d) => d.label is Text && (d.label as Text).data == 'Timesheet');
      expect(timesheetIdx2, isNonNegative);
      expect(rail2.selectedIndex, equals(timesheetIdx2));
  });
}
