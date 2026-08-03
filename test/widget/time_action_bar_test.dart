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
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('REGISTRAR ENTRADA'), findsOneWidget);
    expect(find.text('Trocar obra'), findsOneWidget);
    expect(find.text('Anexar recibo'), findsOneWidget);
    expect(find.text('Pedir reembolso'), findsNothing);
    expect(find.text('Meu timesheet'), findsOneWidget);
    expect(find.textContaining('Pause'), findsNothing);
    expect(find.textContaining('Pausa'), findsNothing);
  });
}
