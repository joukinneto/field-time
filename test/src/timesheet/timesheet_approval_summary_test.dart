import 'package:flutter_test/flutter_test.dart';
import 'package:jkdd_field_time_records_production/src/domain/field_time_models.dart';
import 'package:jkdd_field_time_records_production/src/domain/value_objects/geo_point.dart';
import 'package:jkdd_field_time_records_production/src/timesheet/timesheet_approval_service.dart';
import 'package:jkdd_field_time_records_production/src/timesheet/timesheet_approval_summary.dart';

void main() {
  test('summary reports fully approved when every closed segment is approved', () {
    final day = _day();
    final stamps = {
      approvalEntryId(day.id, day.segments.first.id): const TimesheetApprovalStamp(
        entryId: 'field-day-1-segment-1',
        status: 'approved',
        approvedBy: 'Supervisor Test',
      ),
    };

    final summary = summarizeApprovals(days: [day], stamps: stamps);

    expect(summary.total, 1);
    expect(summary.approved, 1);
    expect(summary.fullyApproved, isTrue);
    expect(summary.formalStatus, 'Fully Approved');
  });

  test('summary keeps missing approval records pending', () {
    final summary = summarizeApprovals(days: [_day()], stamps: const {});

    expect(summary.total, 1);
    expect(summary.pending, 1);
    expect(summary.formalStatus, 'Pending Approval');
  });
}

WorkDay _day() {
  final started = DateTime(2026, 8, 6, 7);
  final ended = DateTime(2026, 8, 6, 17);
  final point = GeoPoint(
    latitude: 26.36,
    longitude: -80.16,
    accuracyMeters: 5,
    capturedAt: started,
  );
  return WorkDay(
    id: 'day-1',
    companyId: 'EWW',
    subcontractorCompanyId: 'JKDD',
    workerId: 'TER-0001',
    workDate: DateTime(2026, 8, 6),
    status: WorkDayStatus.completed,
    segments: [
      WorkSegment(
        id: 'segment-1',
        companyId: 'EWW',
        subcontractorCompanyId: 'JKDD',
        workerId: 'TER-0001',
        jobId: 'job-630',
        jobNumber: '630',
        jobName: 'Golden Beach',
        jobAddress: '630 Golden Beach Dr',
        startedAt: started,
        startedLocation: point,
        endedAt: ended,
        endedLocation: point,
        laborType: LaborType.subcontractor,
      ),
    ],
    completedAt: ended,
    createdAt: started,
    updatedAt: ended,
  );
}
