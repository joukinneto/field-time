import 'package:flutter_test/flutter_test.dart';
import 'package:jkdd_field_time_records_production/time_records.dart';

void main() {
  test('pilot worker is classified as an EWW subcontractor', () {
    final snapshot = FieldTimeSnapshot.seeded();

    expect(snapshot.companyName, 'EWW');
    expect(snapshot.worker.id, FieldTimeSnapshot.workerTechnicalIdPilot);
    expect(snapshot.worker.registrationNumber, 'TER-0001');
    expect(snapshot.worker.displayName, 'Santana');
    expect(snapshot.worker.isSubcontractor, isTrue);
    expect(snapshot.worker.subcontractorCompanyId,
        FieldTimeSnapshot.subcontractorIdJkdd);
  });

  test('geo point calculates distance and quality', () {
    final a = GeoPoint(
      latitude: 26.3683,
      longitude: -80.1289,
      accuracyMeters: 8,
      capturedAt: DateTime.utc(2026),
    );
    final b = GeoPoint(
      latitude: 26.3684,
      longitude: -80.1290,
      accuracyMeters: 8,
      capturedAt: DateTime.utc(2026),
    );

    expect(a.distanceToMeters(b), greaterThan(0));
    expect(a.quality, LocationQuality.high);
  });
}
