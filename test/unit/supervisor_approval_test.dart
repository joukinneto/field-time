import 'package:flutter_test/flutter_test.dart';
import 'package:jkdd_field_time_records_production/src/supervisor_center/supervisor_center_controller.dart';
import 'package:jkdd_field_time_records_production/src/supervisor_center/supervisor_center_models.dart';

void main() {
  test('approval records supervisor, timestamp, history and locks entry', () {
    final controller = SupervisorCenterController();
    const entryId = 'entry-carlos';

    controller.approveEntry(entryId, 'Hours reviewed against job log.');

    final entry =
        controller.state.timeEntries.firstWhere((item) => item.id == entryId);
    expect(entry.status, TimeReviewStatus.approved);
    expect(entry.isLocked, isTrue);
    expect(entry.approvedAt, isNotNull);
    expect(entry.approvedBy, 'Joukin');
    expect(controller.state.reviews.single.previousStatus,
        TimeReviewStatus.pending);
    expect(
        controller.state.reviews.single.newStatus, TimeReviewStatus.approved);
    expect(controller.state.reviews.single.reason,
        'Hours reviewed against job log.');
  });

  test('reject requires reason and exposes rejection details', () {
    final controller = SupervisorCenterController();
    const entryId = 'entry-carlos';

    expect(
      () => controller.rejectEntry(entryId, ''),
      throwsA(isA<StateError>()),
    );

    controller.rejectEntry(entryId, 'Clock-out photo is missing.');
    final entry =
        controller.state.timeEntries.firstWhere((item) => item.id == entryId);

    expect(entry.status, TimeReviewStatus.rejected);
    expect(entry.rejectedBy, 'Joukin');
    expect(entry.rejectedAt, isNotNull);
    expect(entry.rejectionReason, 'Clock-out photo is missing.');
    expect(
        controller.state.reviews.single.newStatus, TimeReviewStatus.rejected);
  });

  test('review request keeps data and stores history observation', () {
    final controller = SupervisorCenterController();
    const entryId = 'entry-jose';

    controller.correctionRequestedBySupervisor(
      entryId,
      'Please confirm break minutes.',
      observation: 'Worker can correct and resubmit.',
    );

    final entry =
        controller.state.timeEntries.firstWhere((item) => item.id == entryId);
    expect(entry.status, TimeReviewStatus.underReview);
    expect(entry.reviewRequestedBy, 'Joukin');
    expect(entry.reviewNote, 'Please confirm break minutes.');
    expect(entry.clockIn, '7:10 AM');
    expect(controller.state.reviews.single.observation,
        'Worker can correct and resubmit.');
  });

  test('approved entries cannot be edited by common review form', () {
    final controller = SupervisorCenterController();
    const entryId = 'entry-carlos';

    controller.approveEntry(entryId, 'Approved.');

    expect(
      () => controller.updateTimeEntry(
        entryId: entryId,
        clockIn: '8:00 AM',
        clockOut: '5:00 PM',
        breakMinutes: 30,
        travelBonusHours: 0,
        supervisorNote: 'Change after approval',
        justification: 'Testing lock',
      ),
      throwsA(isA<StateError>()),
    );
  });

  test(
      'worker correction and resubmission use corrected and resubmitted status',
      () {
    final controller = SupervisorCenterController();
    const entryId = 'entry-carlos';
    controller.rejectEntry(entryId, 'Fix required.');
    controller.setRole(PilotRole.employee);

    controller.requestCorrection(entryId, 'Fixed the clock-out note.');
    expect(
      controller.state.timeEntries
          .firstWhere((entry) => entry.id == entryId)
          .status,
      TimeReviewStatus.corrected,
    );

    controller.submitOwnTime(clockOut: '5:00 PM', note: 'Resubmitting.');
    expect(
      controller.state.timeEntries
          .firstWhere((entry) => entry.id == entryId)
          .status,
      TimeReviewStatus.resubmitted,
    );
  });
}
