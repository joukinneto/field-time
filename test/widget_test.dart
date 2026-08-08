import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jkdd_field_time_records_production/main.dart';
import 'package:jkdd_field_time_records_production/src/auth/auth_session.dart';
import 'package:jkdd_field_time_records_production/time_records.dart';

void main() {
  testWidgets('renders homologation login first', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(
            (ref) => AuthSessionController.test(),
          ),
          fieldTimeRepositoryProvider
              .overrideWithValue(InMemoryFieldTimeRepository()),
        ],
        child: const FieldTimeApp(),
      ),
    );
    await tester.pump();

    expect(find.text('AMBIENTE DE TESTE'), findsOneWidget);
    expect(find.byKey(const ValueKey('login-username')), findsOneWidget);
    expect(find.byKey(const ValueKey('login-password')), findsOneWidget);
    expect(find.byKey(const ValueKey('forgot-password')), findsOneWidget);
  });

  testWidgets('authenticated session renders Field Time home', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(
            (ref) => AuthSessionController.test(
              user: AuthSessionController.testWorker,
            ),
          ),
          fieldTimeRepositoryProvider
              .overrideWithValue(InMemoryFieldTimeRepository()),
        ],
        child: const FieldTimeApp(),
      ),
    );
    await tester.pump();

    expect(find.text('v1.1.0-test4'), findsOneWidget);
    expect(find.text('EWW'), findsNothing);
    expect(find.textContaining('Santana'), findsWidgets);
    expect(find.textContaining('JKDD Finish & Remodeling Corp'), findsNothing);
    expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text && RegExp(r'Bo(m|a)').hasMatch(widget.data ?? ''),
        ),
        findsWidgets);
  });
}
