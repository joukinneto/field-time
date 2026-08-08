import 'package:flutter_test/flutter_test.dart';
import 'package:jkdd_field_time_records_production/src/data/remote/supabase_time_entry_sync.dart';
import 'package:jkdd_field_time_records_production/src/domain/field_time_models.dart';
import 'package:jkdd_field_time_records_production/src/domain/value_objects/geo_point.dart';

void main() {
  const location = GeoPoint(
    latitude: 26.3683,
    longitude: -80.1289,
    accuracyMeters: 8,
    capturedAt: DateTime.utc(2026, 8, 8, 12),
  );

  WorkSegment segment({DateTime? endedAt}) => WorkSegment(
        id: '018f3f4a-8a10-7c91-8000-000000000001',
        companyId: 'local-company',
        subcontractorCompanyId: 'local-subcontractor',
        workerId: 'local-worker',
        jobId: '315',
        jobNumber: '315',
        jobName: 'Obra 315',
        jobAddress: '315 Ellamar Rd',
        startedAt: DateTime.utc(2026, 8, 8, 12),
        startedLocation: location,
        endedAt: endedAt,
        endedLocation: endedAt == null ? null : location,
        laborType: LaborType.subcontractor,
      );

  test('open segment maps to active sync entry', () {
    final payload = SupabaseTimeEntrySync.buildPayload(
      segment: segment(),
      companyId: '11111111-1111-1111-1111-111111111111',
      workerId: '22222222-2222-2222-2222-222222222222',
      jobId: '33333333-3333-3333-3333-333333333333',
    );

    expect(payload['source'], 'sync');
    expect(payload['status'], 'active');
    expect(payload['clock_out_at'], isNull);
    expect(payload['company_id'], '11111111-1111-1111-1111-111111111111');
    expect(payload['job_id'], '33333333-3333-3333-3333-333333333333');
  });

  test('closed segment maps to submitted sync entry', () {
    final payload = SupabaseTimeEntrySync.buildPayload(
      segment: segment(endedAt: DateTime.utc(2026, 8, 8, 20)),
      companyId: '11111111-1111-1111-1111-111111111111',
      workerId: '22222222-2222-2222-2222-222222222222',
      jobId: '33333333-3333-3333-3333-333333333333',
    );

    expect(payload['source'], 'sync');
    expect(payload['status'], 'submitted');
    expect(payload['clock_out_at'], isNotNull);
  });
}
