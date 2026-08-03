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

    expect(find.text('v1.0.0'), findsOneWidget);
    expect(find.textContaining('Good'), findsOneWidget);
    expect(find.text('EWW'), findsOneWidget);
    expect(find.text('Santana'), findsWidgets);
    expect(find.text('Subcontractor'), findsWidgets);
  });
}
