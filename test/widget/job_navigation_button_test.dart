import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jkdd_field_time_records_production/shared/widgets/jkdd_job_navigation_button.dart';

void main() {
  testWidgets('map chooser shows apps without technical URLs', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: JkddJobNavigationButton(
              address: '217 Test Street, Boca Raton, FL',
              compact: false,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Rota para a obra'));
    await tester.pumpAndSettle();

    expect(find.text('Waze'), findsOneWidget);
    expect(find.text('Google Maps'), findsOneWidget);
    expect(find.text('Apple Maps'), findsOneWidget);
    expect(find.textContaining('https://'), findsNothing);
    expect(find.textContaining('query='), findsNothing);
  });
}
