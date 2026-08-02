import 'package:flutter_test/flutter_test.dart';
import 'package:jkdd_field_time_records_production/time_records.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('offline snapshot persists work segments and sync queue', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = SharedPreferencesFieldTimeRepository();
    const service = FieldTimeApplicationService();
    var snapshot = await repository.load();
    final offline = GeoPoint(
      latitude: 0,
      longitude: 0,
      accuracyMeters: 9999,
      capturedAt: DateTime.utc(2026, 8, 1, 8),
      isOfflineFallback: true,
    );
    snapshot = service.clockIn(
      snapshot: snapshot,
      job: snapshot.jobs.first,
      at: DateTime.utc(2026, 8, 1, 8),
      location: offline,
    );
    await repository.save(snapshot);

    final restored = await repository.load();
    expect(restored.activeWorkDay, isNotNull);
    expect(
        restored.activeWorkDay!.openSegment!.startedLocation.isOfflineFallback,
        isTrue);
    expect(restored.syncQueue, isNotEmpty);
  });
}
