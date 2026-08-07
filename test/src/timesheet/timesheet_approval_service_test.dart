import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jkdd_field_time_records_production/src/timesheet/timesheet_approval_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads approved supervisor entry as a formal timesheet stamp', () async {
    SharedPreferences.setMockInitialValues({
      supervisorCenterStorageKey: jsonEncode({
        'timeEntries': [
          {
            'id': 'field-day-1-segment-1',
            'status': 'approved',
            'approvedBy': 'Supervisor Test',
            'approvedAt': '2026-08-06T18:30:00.000',
          },
        ],
      }),
    });

    final stamps = await const TimesheetApprovalService().load();
    final stamp = stamps['field-day-1-segment-1'];

    expect(stamp, isNotNull);
    expect(stamp!.approved, isTrue);
    expect(stamp.displayStatus, 'Approved');
    expect(stamp.approvedBy, 'Supervisor Test');
    expect(stamp.approvedAt, DateTime(2026, 8, 6, 18, 30));
  });

  test('loads rejected and correction-requested states safely', () async {
    SharedPreferences.setMockInitialValues({
      supervisorCenterStorageKey: jsonEncode({
        'timeEntries': [
          {
            'id': 'field-day-2-segment-1',
            'status': 'rejected',
            'rejectedBy': 'Supervisor Test',
            'rejectedAt': '2026-08-06T19:00:00.000',
            'rejectionReason': 'Clock out needs correction',
          },
          {
            'id': 'field-day-2-segment-2',
            'status': 'correctionRequested',
            'reviewRequestedBy': 'Director Test',
            'reviewRequestedAt': '2026-08-06T19:05:00.000',
            'reviewNote': 'Verify travel time',
          },
        ],
      }),
    });

    final stamps = await const TimesheetApprovalService().load();

    expect(stamps['field-day-2-segment-1']!.displayStatus, 'Rejected');
    expect(stamps['field-day-2-segment-1']!.rejectionReason,
        'Clock out needs correction');
    expect(stamps['field-day-2-segment-2']!.displayStatus,
        'Correction Requested');
    expect(stamps['field-day-2-segment-2']!.reviewNote, 'Verify travel time');
  });

  test('approvalEntryId matches Field Time to Supervisor sync identifier', () {
    expect(
      approvalEntryId('day-2026-08-06', 'segment-1'),
      'field-day-2026-08-06-segment-1',
    );
  });
}
