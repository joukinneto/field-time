import 'package:flutter_test/flutter_test.dart';
import 'package:jkdd_field_time_records_production/src/supervisor_center/supervisor_center_controller.dart';
import 'package:jkdd_field_time_records_production/src/supervisor_center/supervisor_center_models.dart';

void main() {
  test('three sprint roles expose expected permissions', () {
    final collaborator = SupervisorCenterState.seeded();
    expect(collaborator.currentRole, PilotRole.employee);
    expect(collaborator.hasPermission(PilotPermission.viewManagement), isFalse);

    final supervisor = collaborator.copyWith(currentRole: PilotRole.supervisor);
    expect(supervisor.hasPermission(PilotPermission.viewManagement), isTrue);
    expect(supervisor.hasPermission(PilotPermission.approveTime), isTrue);

    final director = collaborator.copyWith(currentRole: PilotRole.owner);
    expect(director.hasPermission(PilotPermission.viewManagement), isTrue);
    expect(director.hasPermission(PilotPermission.editJob), isTrue);
    expect(director.hasPermission(PilotPermission.approveTime), isTrue);
  });

  test('approval records supervisor, timestamp, history and locks entry', () {
    final controller = _controllerWithEntries();
    const entryId = 'entry-ter-0002';

    controller.approveEntry(entryId, 'Hours reviewed against job log.');

    final entry =
        controller.state.timeEntries.firstWhere((item) => item.id == entryId);
    expect(entry.status, TimeReviewStatus.approved);
    expect(entry.isLocked, isTrue);
    expect(entry.approvedAt, isNotNull);
    expect(entry.approvedBy, 'Santana');
    expect(controller.state.reviews.single.previousStatus,
        TimeReviewStatus.pending);
    expect(
        controller.state.reviews.single.newStatus, TimeReviewStatus.approved);
    expect(controller.state.reviews.single.reason,
        'Hours reviewed against job log.');
  });

  test('reject requires reason and exposes rejection details', () {
    final controller = _controllerWithEntries();
    const entryId = 'entry-ter-0002';

    expect(
      () => controller.rejectEntry(entryId, ''),
      throwsA(isA<StateError>()),
    );

    controller.rejectEntry(entryId, 'Clock-out photo is missing.');
    final entry =
        controller.state.timeEntries.firstWhere((item) => item.id == entryId);

    expect(entry.status, TimeReviewStatus.rejected);
    expect(entry.rejectedBy, 'Santana');
    expect(entry.rejectedAt, isNotNull);
    expect(entry.rejectionReason, 'Clock-out photo is missing.');
    expect(
        controller.state.reviews.single.newStatus, TimeReviewStatus.rejected);
  });

  test('review request keeps data and stores history observation', () {
    final controller = _controllerWithEntries();
    const entryId = 'entry-ter-0002';

    controller.correctionRequestedBySupervisor(
      entryId,
      'Please confirm break minutes.',
      observation: 'Worker can correct and resubmit.',
    );

    final entry =
        controller.state.timeEntries.firstWhere((item) => item.id == entryId);
    expect(entry.status, TimeReviewStatus.correctionRequested);
    expect(entry.reviewRequestedBy, 'Santana');
    expect(entry.reviewNote, 'Please confirm break minutes.');
    expect(entry.clockIn, '7:10 AM');
    expect(controller.state.reviews.single.observation,
        'Worker can correct and resubmit.');
  });

  test('approved entries cannot be edited by common review form', () {
    final controller = _controllerWithEntries();
    const entryId = 'entry-ter-0002';

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

  test('reviewer cannot approve own time record', () {
    final controller =
        _controllerWithEntries(currentRole: PilotRole.supervisor);

    expect(
      () => controller.approveEntry('entry-ter-0001', 'Approving myself.'),
      throwsA(isA<StateError>()),
    );
  });

  test(
      'worker correction and resubmission use corrected and resubmitted status',
      () {
    final controller = _controllerWithEntries(currentRole: PilotRole.employee);
    const entryId = 'entry-ter-0002';
    controller.setRole(PilotRole.supervisor);
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

SupervisorCenterController _controllerWithEntries({
  PilotRole currentRole = PilotRole.supervisor,
}) {
  final date = DateTime(2026, 8, 3);
  final state = SupervisorCenterState(
    currentRole: currentRole,
    users: const [
      PilotUser(
        id: 'TER-0001',
        name: 'Santana',
        role: PilotRole.supervisor,
        company: 'JKDD Finish & Remodeling Corp.',
      ),
      PilotUser(
        id: 'TER-0002',
        name: 'Employee Under Review',
        role: PilotRole.employee,
        company: 'JKDD Finish & Remodeling Corp.',
      ),
    ],
    jobs: [
      SupervisorJob(
        id: 'job-real',
        number: '1001',
        name: 'Imported Job',
        client: 'EWW',
        address: 'Boca Raton, FL',
        city: 'Boca Raton',
        state: 'FL',
        zipCode: '33428',
        startDate: date,
        scheduledTime: '7:00 AM',
        supervisorId: 'TER-0001',
        notes: '',
        status: JobStatus.active,
      ),
    ],
    assignments: [
      JobAssignment(
        id: 'assign-ter-0002',
        userId: 'TER-0002',
        jobId: 'job-real',
        assignmentDate: date,
        scheduledStart: '7:00 AM',
        scheduledEnd: '5:00 PM',
        assignedBy: 'TER-0001',
        supervisorId: 'TER-0001',
        status: AssignmentStatus.finished,
        notes: '',
      ),
    ],
    schedules: const [],
    timeEntries: [
      TimeEntry(
        id: 'entry-ter-0001',
        userId: 'TER-0001',
        jobId: 'job-real',
        date: date,
        clockIn: '7:00 AM',
        clockOut: '4:00 PM',
        breakMinutes: 30,
        employeeNote: 'Supervisor own time.',
        status: TimeReviewStatus.pending,
      ),
      TimeEntry(
        id: 'entry-ter-0002',
        userId: 'TER-0002',
        jobId: 'job-real',
        date: date,
        clockIn: '7:10 AM',
        clockOut: '4:30 PM',
        breakMinutes: 30,
        employeeNote: 'Imported employee time.',
        status: TimeReviewStatus.pending,
      ),
    ],
    reviews: const [],
    auditLogs: const [],
  );
  return SupervisorCenterController(initialState: state);
}
