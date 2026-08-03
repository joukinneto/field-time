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

  test('pay premium supports percentage fixed hourly and double time', () {
    final base = _premiumSegment(
      type: PayPremiumType.percentage,
      value: 0.25,
    );
    final fixed = _premiumSegment(
      type: PayPremiumType.fixedHourly,
      value: 5,
    );
    final doubleTime = _premiumSegment(
      type: PayPremiumType.doubleTime,
      value: 1,
    );

    expect(base.payPremiumAmount(40), 80);
    expect(fixed.payPremiumAmount(40), 40);
    expect(doubleTime.payPremiumAmount(40), 320);
  });

  test('travel bonus remains separate from pay premium', () {
    final segment = _premiumSegment(
      type: PayPremiumType.percentage,
      value: 0.25,
      travelBonusHours: 1,
    );

    expect(segment.regularHours(), 8);
    expect(segment.travelBonusHours, 1);
    expect(segment.totalHours(), 9);
    expect(segment.payPremiumAmount(40), 80);
  });
}

WorkSegment _premiumSegment({
  required PayPremiumType type,
  required double value,
  double travelBonusHours = 0,
}) =>
    WorkSegment(
      id: 'segment-$type-$value',
      companyId: FieldTimeSnapshot.companyIdEww,
      subcontractorCompanyId: FieldTimeSnapshot.subcontractorIdJkdd,
      workerId: FieldTimeSnapshot.workerTechnicalIdPilot,
      jobId: 'job-217',
      jobNumber: '217',
      jobName: 'Obra 217',
      jobAddress: '217 Gregory Rd',
      startedAt: DateTime.utc(2026, 8, 1, 8),
      endedAt: DateTime.utc(2026, 8, 1, 16),
      startedLocation: GeoPoint(
        latitude: 26.3683,
        longitude: -80.1289,
        accuracyMeters: 8,
        capturedAt: DateTime.utc(2026, 8, 1, 8),
      ),
      laborType: LaborType.subcontractor,
      travelBonusEnabled: travelBonusHours > 0,
      travelBonusHours: travelBonusHours,
      payPremiumEnabled: true,
      payPremiumType: type,
      payPremiumValue: value,
    );
