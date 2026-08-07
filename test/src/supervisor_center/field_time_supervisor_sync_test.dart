import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jkdd_field_time_records_production/src/domain/field_time_models.dart';
import 'package:jkdd_field_time_records_production/src/domain/value_objects/geo_point.dart';
import 'package:jkdd_field_time_records_production/src/supervisor_center/field_time_supervisor_sync.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('completed work segment is added once as pending supervisor entry', () async {
    SharedPreferences.setMockInitialValues({});
    final day = _completedDay();

    final first = await syncCompletedWorkDayForSupervisor(
      day: day,
      userId: 'TER-0001',
    );
    final second = await syncCompletedWorkDayForSupervisor(
      day: day,
      userId: 'TER-0001',
    );

    expect(first, isTrue);
    expect(second, isFalse);

    final preferences = await SharedPreferences.getInstance();
    final decoded = jsonDecode(
      preferences.getString(supervisorCenterStorageKey)!,
    ) as Map<String, dynamic>;
    final entries = decoded['timeEntries'] as List<dynamic>;

    expect(entries, hasLength(1));
    final entry = entries.single as Map<String, dynamic>;
    expect(entry['userId'], 'TER-0001');
    expect(entry['jobId'], 'job-630');
    expect(entry['clockIn'], '7:00 AM');
    expect(entry['clockOut'], '5:15 PM');
    expect(entry['status'], 'pending');
    expect(entry['travelBonusHours'], 2.0);
    expect(entry['breakMinutes'], 0);
  });
}

WorkDay _completedDay() {
  final date = DateTime(2026, 8, 6);
  final started = DateTime(2026, 8, 6, 7);
  final ended = DateTime(2026, 8, 6, 17, 15);
  final point = GeoPoint(
    latitude: 26.36,
    longitude: -80.16,
    accuracyMeters: 5,
    capturedAt: started,
  );

  return WorkDay(
    id: 'day-2026-08-06',
    registrationNumber: 'TIM-0001',
    companyId: 'EWW',
    subcontractorCompanyId: 'JKDD',
    workerId: 'worker-1',
    workDate: date,
    status: WorkDayStatus.completed,
    segments: [
      WorkSegment(
        id: 'segment-1',
        companyId: 'EWW',
        subcontractorCompanyId: 'JKDD',
        workerId: 'worker-1',
        jobId: 'job-630',
        jobNumber: '630',
        jobName: 'Golden Beach',
        jobAddress: '630 Golden Beach Dr',
        startedAt: started,
        startedLocation: point,
        endedAt: ended,
        endedLocation: GeoPoint(
          latitude: 26.36,
          longitude: -80.16,
          accuracyMeters: 5,
          capturedAt: ended,
        ),
        laborType: LaborType.subcontractor,
        travelBonusHours: 2,
        travelBonusEnabled: true,
      ),
    ],
    completedAt: ended,
    createdAt: started,
    updatedAt: ended,
  );
}
