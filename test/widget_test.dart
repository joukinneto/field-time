import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jkdd_field_time_records_production/main.dart';
import 'package:jkdd_field_time_records_production/time_records.dart';

void main() {
  testWidgets('renders Field Time pilot identity', (tester) async {
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
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('v1.1.0-test'), findsOneWidget);
    expect(find.text('EWW'), findsOneWidget);
    expect(find.textContaining('Santana'), findsWidgets);
    expect(find.textContaining('JKDD Finish & Remodeling Corp'), findsWidgets);
    expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text && RegExp(r'Bo(m|a)').hasMatch(widget.data ?? ''),
        ),
        findsWidgets);
  });
}
