import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jkdd_field_time_records_production/main.dart';
import 'package:jkdd_field_time_records_production/time_records.dart';

void main() {
  testWidgets('shows real actions and contains no pause action',
      (tester) async {
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

    expect(find.text('CLOCK IN'), findsOneWidget);
    expect(find.text('Switch Job'), findsOneWidget);
    expect(find.text('Attach Receipt'), findsOneWidget);
    expect(find.text('Request Reimbursement'), findsOneWidget);
    expect(find.text('My Timesheet'), findsOneWidget);
    expect(find.textContaining('Pause'), findsNothing);
    expect(find.textContaining('Pausa'), findsNothing);
  });
}
