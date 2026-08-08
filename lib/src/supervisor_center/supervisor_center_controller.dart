import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jkdd_field_time_records_production/features/employees/data/employee_asset_repository.dart';
import 'package:jkdd_field_time_records_production/features/employees/domain/employee.dart';
import 'package:jkdd_field_time_records_production/features/jobs/data/job_asset_repository.dart';
import 'package:jkdd_field_time_records_production/features/jobs/domain/job.dart'
    as imported_job;
import 'package:jkdd_field_time_records_production/src/supervisor_center/supervisor_center_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

final supervisorCenterProvider =
    StateNotifierProvider<SupervisorCenterController, SupervisorCenterState>((
      ref,
    ) {
      final controller = SupervisorCenterController(
        employeeRepository: ref.watch(employeeAssetRepositoryProvider),
        jobRepository: ref.watch(jobAssetRepositoryProvider),
      );
      controller.initialize();
      return controller;
    });

final class SupervisorCenterController
    extends StateNotifier<SupervisorCenterState> {
  SupervisorCenterController({
    this.employeeRepository,
    this.jobRepository,
    SupervisorCenterState? initialState,
  }) : super(initialState ?? SupervisorCenterState.seeded());

  final EmployeeAssetRepository? employeeRepository;
  final JobAssetRepository? jobRepository;
  static const _storageKey = 'field_time_supervisor_center_state_v1';

  Future<void> initialize() async {
    final employees = await _loadEmployees();
    final jobs = await _loadJobs();
    final base = employees.isEmpty && jobs.isEmpty
        ? state
        : SupervisorCenterState.fromEmployeesAndJobs(
            employees: employees,
            jobs: jobs,
            currentRole: state.currentRole,
            allowSupervisorCreateJobs: state.allowSupervisorCreateJobs,
          );
    state = await _loadPersisted(base);
  }

  void setRole(PilotRole role) {
    state = state.copyWith(
      currentRole: role,
      clearSimulatedUser: true,
      message: 'supervisor.roleChanged',
    );
    unawaited(_save());
  }

  void setSimulation(PilotRole role, {String? userId}) {
    PilotUser? selected;
    if (userId != null) {
      for (final user in state.users) {
        if (user.id == userId) {
          selected = user;
          break;
        }
      }
    }
    final effectiveRole = selected?.role ?? role;
    state = state.copyWith(
      currentRole: effectiveRole,
      simulatedUserId: selected?.id,
      clearSimulatedUser: selected == null,
      message: 'supervisor.roleChanged',
    );
    unawaited(_save());
  }

  void setSupervisorCreateJobs(bool value) {
    _require(PilotPermission.editJob);
    state = state.copyWith(
      allowSupervisorCreateJobs: value,
      message: value
          ? 'supervisor.createJobsAllowed'
          : 'supervisor.createJobsBlocked',
    );
    unawaited(_save());
  }

  void addJob(SupervisorJob job) {
    _require(PilotPermission.createJob);
    state = state.copyWith(
      jobs: [...state.jobs, job],
      message: 'supervisor.jobCreated',
    );
    unawaited(_save());
  }

  Future<List<Employee>> _loadEmployees() async {
    final repository = employeeRepository;
    if (repository == null) return const [];
    try {
      return (await repository.loadCatalog()).employees;
    } on EmployeeAssetRepositoryException {
      return const [];
    }
  }

  Future<List<imported_job.Job>> _loadJobs() async {
    final repository = jobRepository;
    if (repository == null) return const [];
    try {
      return (await repository.loadCatalog()).jobs;
    } on JobAssetRepositoryException {
      return const [];
    }
  }

  void updateJob(SupervisorJob job) {
    _require(PilotPermission.editJob);
    state = state.copyWith(
      jobs: [
        for (final current in state.jobs)
          if (current.id == job.id) job else current,
      ],
      message: 'supervisor.jobUpdated',
    );
    unawaited(_save());
  }

  void submitOwnTime({required String clockOut, required String note}) {
    _require(PilotPermission.clockOwnTime);
    final user = state.currentUser;
    if (!user.isWorker) {
      throw StateError('supervisor.employeeOrContractorOnly');
    }
    final existing = state.timeEntries
        .where((entry) => entry.userId == user.id)
        .cast<TimeEntry?>()
        .firstOrNull;
    final assignment = state.assignments
        .where((assignment) => assignment.userId == user.id)
        .cast<JobAssignment?>()
        .firstOrNull;
    final jobId = existing?.jobId ?? assignment?.jobId;
    if (jobId == null) {
      throw StateError('supervisor.noAssignedJob');
    }
    final resubmitting =
        existing != null &&
        {
          TimeReviewStatus.rejected,
          TimeReviewStatus.underReview,
          TimeReviewStatus.correctionRequested,
          TimeReviewStatus.corrected,
        }.contains(existing.status);
    final entry = existing == null
        ? TimeEntry(
            id: 'entry-${user.id}-${DateTime.now().millisecondsSinceEpoch}',
            userId: user.id,
            jobId: jobId,
            date: DateTime.now(),
            clockIn: '7:00 AM',
            clockOut: clockOut,
            breakMinutes: 30,
            employeeNote: note,
            status: TimeReviewStatus.pending,
          )
        : existing.copyWith(
            clockOut: clockOut,
            status: resubmitting
                ? TimeReviewStatus.resubmitted
                : TimeReviewStatus.pending,
            supervisorNote: note,
            resubmittedAt: resubmitting
                ? DateTime.now()
                : existing.resubmittedAt,
            clearApproval: true,
          );
    state = state.copyWith(
      timeEntries: existing == null
          ? [...state.timeEntries, entry]
          : [
              for (final current in state.timeEntries)
                if (current.id == entry.id) entry else current,
            ],
      message: resubmitting
          ? 'supervisor.hoursCorrectedResubmitted'
          : 'supervisor.hoursSentForApproval',
    );
    unawaited(_save());
  }

  void requestCorrection(String entryId, String justification) {
    _require(PilotPermission.requestCorrection);
    if (justification.trim().isEmpty) {
      throw StateError('supervisor.correctionReasonRequired');
    }
    _mutateEntry(
      entryId,
      status: TimeReviewStatus.corrected,
      note: justification,
      success: 'supervisor.correctionSent',
    );
  }

  void approveEntry(String entryId, [String justification = '']) {
    _review(
      entryId,
      TimeReviewStatus.approved,
      justification,
      'supervisor.entryApproved',
    );
  }

  void rejectEntry(String entryId, String justification) {
    _review(
      entryId,
      TimeReviewStatus.rejected,
      justification,
      'supervisor.entryRejected',
    );
  }

  void correctionRequestedBySupervisor(
    String entryId,
    String justification, {
    String observation = '',
  }) {
    _review(
      entryId,
      TimeReviewStatus.correctionRequested,
      justification,
      'supervisor.entrySentToReview',
      observation: observation,
    );
  }

  void updateTimeEntry({
    required String entryId,
    required String clockIn,
    required String? clockOut,
    required int breakMinutes,
    required double travelBonusHours,
    required double extraBonusHours,
    required double payPremiumPercent,
    required String supervisorNote,
    required String justification,
  }) {
    _require(PilotPermission.approveTime);
    final entry = state.timeEntries.firstWhere((item) => item.id == entryId);
    if (entry.isLocked) {
      throw StateError('supervisor.approvedRecordLocked');
    }
    final updated = entry.copyWith(
      clockIn: clockIn,
      clockOut: clockOut,
      clearClockOut: clockOut == null,
      breakMinutes: breakMinutes,
      travelBonusHours: travelBonusHours,
      extraBonusHours: extraBonusHours,
      payPremiumPercent: payPremiumPercent,
      supervisorNote: supervisorNote,
      status: TimeReviewStatus.underReview,
    );
    final logs = <AuditLog>[];
    void addLog(String field, String original, String next) {
      if (original == next) return;
      logs.add(
        AuditLog(
          id: 'audit-${DateTime.now().microsecondsSinceEpoch}-$field',
          entityId: entryId,
          fieldName: field,
          originalValue: original,
          newValue: next,
          changedBy: state.currentUser.name,
          changedAt: DateTime.now(),
          justification: justification,
        ),
      );
    }

    addLog('clockIn', entry.clockIn, updated.clockIn);
    addLog(
      'clockOut',
      entry.clockOut ?? 'common.open',
      updated.clockOut ?? 'common.open',
    );
    addLog('breakMinutes', '${entry.breakMinutes}', '${updated.breakMinutes}');
    addLog(
      'travelBonusHours',
      entry.travelBonusHours.toStringAsFixed(2),
      updated.travelBonusHours.toStringAsFixed(2),
    );
    addLog(
      'extraBonusHours',
      entry.extraBonusHours.toStringAsFixed(2),
      updated.extraBonusHours.toStringAsFixed(2),
    );
    addLog(
      'payPremiumPercent',
      entry.payPremiumPercent.toStringAsFixed(0),
      updated.payPremiumPercent.toStringAsFixed(0),
    );
    if (logs.isEmpty && supervisorNote.trim().isNotEmpty) {
      addLog('supervisorNote', entry.supervisorNote, supervisorNote.trim());
    }

    state = state.copyWith(
      timeEntries: [
        for (final current in state.timeEntries)
          if (current.id == entryId) updated else current,
      ],
      auditLogs: [...state.auditLogs, ...logs],
      message: 'supervisor.reviewSavedAudit',
    );
    unawaited(_save());
  }

  void approveAllValidForJob(String jobId, [String justification = '']) {
    _require(PilotPermission.approveTime);
    final validIds = state.timeEntries
        .where(
          (entry) =>
              entry.jobId == jobId &&
              entry.clockOut != null &&
              entry.status != TimeReviewStatus.approved,
        )
        .map((entry) => entry.id)
        .toSet();
    final now = DateTime.now();
    final reviewer = state.currentUser;
    state = state.copyWith(
      timeEntries: [
        for (final entry in state.timeEntries)
          if (validIds.contains(entry.id))
            entry.copyWith(
              status: TimeReviewStatus.approved,
              approvedAt: now,
              approvedBy: reviewer.name,
              clearRejection: true,
              clearReviewRequest: true,
            )
          else
            entry,
      ],
      reviews: [
        ...state.reviews,
        for (final id in validIds)
          TimeEntryReview(
            id: 'review-${DateTime.now().microsecondsSinceEpoch}-$id',
            timeEntryId: id,
            reviewerId: state.currentUser.id,
            previousStatus: state.timeEntries
                .firstWhere((entry) => entry.id == id)
                .status,
            newStatus: TimeReviewStatus.approved,
            reason: justification,
            observation: '',
            reviewedAt: now,
          ),
      ],
      message: 'supervisor.validRecordsApproved',
    );
    unawaited(_save());
  }

  void _review(
    String entryId,
    TimeReviewStatus status,
    String justification,
    String success, {
    String observation = '',
  }) {
    _require(PilotPermission.approveTime);
    final entry = state.timeEntries.firstWhere((item) => item.id == entryId);
    if (entry.status == TimeReviewStatus.approved) {
      throw StateError(
        'Registro já aprovado. Não é necessária nova aprovação.',
      );
    }
    if (entry.userId == state.currentUser.id) {
      throw StateError('supervisor.cannotReviewOwnTime');
    }
    final target = state.userById(entry.userId);
    if (status == TimeReviewStatus.approved &&
        state.currentRole == PilotRole.supervisor &&
        !{PilotRole.employee, PilotRole.contractor}.contains(target.role)) {
      throw StateError('Horas de supervisor devem ser aprovadas pelo diretor.');
    }
    if (status != TimeReviewStatus.approved && justification.trim().isEmpty) {
      throw StateError(
        status == TimeReviewStatus.rejected
            ? 'supervisor.rejectionReasonRequired'
            : 'supervisor.reviewJustificationRequired',
      );
    }
    final review = TimeEntryReview(
      id: 'review-${DateTime.now().microsecondsSinceEpoch}',
      timeEntryId: entryId,
      reviewerId: state.currentUser.id,
      previousStatus: entry.status,
      newStatus: status,
      reason: justification.trim(),
      observation: observation.trim(),
      reviewedAt: DateTime.now(),
    );
    _mutateEntry(
      entryId,
      status: status,
      note: justification,
      success: success,
      review: review,
    );
  }

  void _mutateEntry(
    String entryId, {
    required TimeReviewStatus status,
    required String note,
    required String success,
    TimeEntryReview? review,
  }) {
    final now = DateTime.now();
    final reviewer = state.currentUser;
    state = state.copyWith(
      timeEntries: [
        for (final entry in state.timeEntries)
          if (entry.id == entryId)
            entry.copyWith(
              status: status,
              supervisorNote: note.trim().isEmpty
                  ? entry.supervisorNote
                  : note.trim(),
              approvedAt: status == TimeReviewStatus.approved ? now : null,
              approvedBy: status == TimeReviewStatus.approved
                  ? reviewer.name
                  : null,
              rejectedAt: status == TimeReviewStatus.rejected ? now : null,
              rejectedBy: status == TimeReviewStatus.rejected
                  ? reviewer.name
                  : null,
              rejectionReason: status == TimeReviewStatus.rejected
                  ? note.trim()
                  : null,
              reviewRequestedAt: status == TimeReviewStatus.correctionRequested
                  ? now
                  : null,
              reviewRequestedBy: status == TimeReviewStatus.correctionRequested
                  ? reviewer.name
                  : null,
              reviewNote: status == TimeReviewStatus.correctionRequested
                  ? note.trim()
                  : null,
              clearApproval: status != TimeReviewStatus.approved,
              clearRejection: status != TimeReviewStatus.rejected,
              clearReviewRequest:
                  status != TimeReviewStatus.correctionRequested,
            )
          else
            entry,
      ],
      reviews: review == null ? state.reviews : [...state.reviews, review],
      message: success,
    );
    unawaited(_save());
  }

  void questionSupervisor(String entryId, String question) {
    if (!{
      PilotRole.owner,
      PilotRole.administrator,
    }.contains(state.currentRole)) {
      throw StateError('Somente o diretor pode questionar uma aprovação.');
    }
    if (question.trim().isEmpty) {
      throw StateError('Informe a pergunta para o supervisor.');
    }
    final entry = state.timeEntries.firstWhere((item) => item.id == entryId);
    if (entry.status != TimeReviewStatus.approved) {
      throw StateError('Apenas registros já aprovados podem ser questionados.');
    }
    final now = DateTime.now();
    state = state.copyWith(
      reviews: [
        ...state.reviews,
        TimeEntryReview(
          id: 'question-${now.microsecondsSinceEpoch}',
          timeEntryId: entryId,
          reviewerId: state.currentUser.id,
          previousStatus: entry.status,
          newStatus: entry.status,
          reason: 'DIRECTOR_QUESTION',
          observation: question.trim(),
          reviewedAt: now,
        ),
      ],
      message: 'Questionamento enviado ao supervisor.',
    );
    unawaited(_save());
  }

  void respondDirectorQuestion(String entryId, String response) {
    if (state.currentRole != PilotRole.supervisor) {
      throw StateError(
        'Somente o supervisor pode responder ao questionamento.',
      );
    }
    if (response.trim().isEmpty) {
      throw StateError('Informe a resposta ao diretor.');
    }
    final entry = state.timeEntries.firstWhere((item) => item.id == entryId);
    final now = DateTime.now();
    state = state.copyWith(
      reviews: [
        ...state.reviews,
        TimeEntryReview(
          id: 'response-${now.microsecondsSinceEpoch}',
          timeEntryId: entryId,
          reviewerId: state.currentUser.id,
          previousStatus: entry.status,
          newStatus: entry.status,
          reason: 'SUPERVISOR_RESPONSE',
          observation: response.trim(),
          reviewedAt: now,
        ),
      ],
      message: 'Resposta enviada ao diretor.',
    );
    unawaited(_save());
  }

  void _require(PilotPermission permission) {
    if (!state.hasPermission(permission)) {
      throw StateError('supervisor.permissionDenied');
    }
  }

  Future<void> _save() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_storageKey, jsonEncode(_stateToJson(state)));
    } on Object {
      // Unit tests and unsupported platforms can still use in-memory state.
    }
  }

  Future<SupervisorCenterState> _loadPersisted(
    SupervisorCenterState base,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_storageKey);
    if (raw == null || raw.isEmpty) return base;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final persistedJobs = _decodeList(json['jobs'], _jobFromJson);
      return base.copyWith(
        currentRole:
            _roleFromName(json['currentRole'] as String?) ?? base.currentRole,
        simulatedUserId: json['simulatedUserId'] as String?,
        allowSupervisorCreateJobs:
            json['allowSupervisorCreateJobs'] as bool? ??
            base.allowSupervisorCreateJobs,
        jobs: persistedJobs.isEmpty ? base.jobs : persistedJobs,
        assignments: _decodeList(json['assignments'], _assignmentFromJson),
        schedules: _decodeList(json['schedules'], _scheduleFromJson),
        timeEntries: _decodeList(json['timeEntries'], _timeEntryFromJson),
        reviews: _decodeList(json['reviews'], _reviewFromJson),
        auditLogs: _decodeList(json['auditLogs'], _auditFromJson),
        clearFeedback: true,
      );
    } on Object {
      return base;
    }
  }

  Map<String, dynamic> _stateToJson(SupervisorCenterState value) => {
    'currentRole': value.currentRole.name,
    'simulatedUserId': value.simulatedUserId,
    'allowSupervisorCreateJobs': value.allowSupervisorCreateJobs,
    'jobs': value.jobs.map(_jobToJson).toList(),
    'assignments': value.assignments.map(_assignmentToJson).toList(),
    'schedules': value.schedules.map(_scheduleToJson).toList(),
    'timeEntries': value.timeEntries.map(_timeEntryToJson).toList(),
    'reviews': value.reviews.map(_reviewToJson).toList(),
    'auditLogs': value.auditLogs.map(_auditToJson).toList(),
  };
}

List<T> _decodeList<T>(Object? raw, T Function(Map<String, dynamic>) decode) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((item) => decode(Map<String, dynamic>.from(item)))
      .toList(growable: false);
}

PilotRole? _roleFromName(String? name) {
  if (name == null) return null;
  for (final role in PilotRole.values) {
    if (role.name == name) return role;
  }
  return null;
}

TimeReviewStatus _reviewStatusFromName(String? name) =>
    TimeReviewStatus.values.firstWhere(
      (item) => item.name == name,
      orElse: () => TimeReviewStatus.pending,
    );

JobStatus _jobStatusFromName(String? name) => JobStatus.values.firstWhere(
  (item) => item.name == name,
  orElse: () => JobStatus.active,
);

AssignmentStatus _assignmentStatusFromName(String? name) =>
    AssignmentStatus.values.firstWhere(
      (item) => item.name == name,
      orElse: () => AssignmentStatus.scheduled,
    );

Map<String, dynamic> _jobToJson(SupervisorJob job) => {
  'id': job.id,
  'registrationNumber': job.registrationNumber,
  'number': job.number,
  'name': job.name,
  'client': job.client,
  'address': job.address,
  'city': job.city,
  'state': job.state,
  'zipCode': job.zipCode,
  'startDate': job.startDate.toIso8601String(),
  'scheduledTime': job.scheduledTime,
  'supervisorId': job.supervisorId,
  'notes': job.notes,
  'status': job.status.name,
  'travelBonusHours': job.travelBonusHours,
  'payPremiumEnabled': job.payPremiumEnabled,
  'payPremiumLabel': job.payPremiumLabel,
};

SupervisorJob _jobFromJson(Map<String, dynamic> json) => SupervisorJob(
  id: json['id'] as String? ?? '',
  registrationNumber: json['registrationNumber'] as String? ?? '',
  number: json['number'] as String? ?? '',
  name: json['name'] as String? ?? '',
  client: json['client'] as String? ?? 'EWW',
  address: json['address'] as String? ?? '',
  city: json['city'] as String? ?? '',
  state: json['state'] as String? ?? '',
  zipCode: json['zipCode'] as String? ?? '',
  startDate:
      DateTime.tryParse(json['startDate'] as String? ?? '') ?? DateTime.now(),
  scheduledTime: json['scheduledTime'] as String? ?? '',
  supervisorId: json['supervisorId'] as String? ?? 'test-supervisor',
  notes: json['notes'] as String? ?? '',
  status: _jobStatusFromName(json['status'] as String?),
  travelBonusHours: (json['travelBonusHours'] as num?)?.toDouble() ?? 0,
  payPremiumEnabled: json['payPremiumEnabled'] as bool? ?? false,
  payPremiumLabel: json['payPremiumLabel'] as String? ?? '',
);

Map<String, dynamic> _assignmentToJson(JobAssignment assignment) => {
  'id': assignment.id,
  'userId': assignment.userId,
  'jobId': assignment.jobId,
  'assignmentDate': assignment.assignmentDate.toIso8601String(),
  'scheduledStart': assignment.scheduledStart,
  'scheduledEnd': assignment.scheduledEnd,
  'assignedBy': assignment.assignedBy,
  'supervisorId': assignment.supervisorId,
  'status': assignment.status.name,
  'notes': assignment.notes,
};

JobAssignment _assignmentFromJson(Map<String, dynamic> json) => JobAssignment(
  id: json['id'] as String? ?? '',
  userId: json['userId'] as String? ?? '',
  jobId: json['jobId'] as String? ?? '',
  assignmentDate:
      DateTime.tryParse(json['assignmentDate'] as String? ?? '') ??
      DateTime.now(),
  scheduledStart: json['scheduledStart'] as String? ?? '',
  scheduledEnd: json['scheduledEnd'] as String? ?? '',
  assignedBy: json['assignedBy'] as String? ?? '',
  supervisorId: json['supervisorId'] as String? ?? '',
  status: _assignmentStatusFromName(json['status'] as String?),
  notes: json['notes'] as String? ?? '',
);

Map<String, dynamic> _scheduleToJson(SupervisorSchedule schedule) => {
  'id': schedule.id,
  'supervisorId': schedule.supervisorId,
  'jobId': schedule.jobId,
  'date': schedule.date.toIso8601String(),
  'time': schedule.time,
  'note': schedule.note,
};

SupervisorSchedule _scheduleFromJson(Map<String, dynamic> json) =>
    SupervisorSchedule(
      id: json['id'] as String? ?? '',
      supervisorId: json['supervisorId'] as String? ?? '',
      jobId: json['jobId'] as String? ?? '',
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      time: json['time'] as String? ?? '',
      note: json['note'] as String? ?? '',
    );

Map<String, dynamic> _timeEntryToJson(TimeEntry entry) => {
  'id': entry.id,
  'userId': entry.userId,
  'jobId': entry.jobId,
  'date': entry.date.toIso8601String(),
  'clockIn': entry.clockIn,
  'clockOut': entry.clockOut,
  'breakMinutes': entry.breakMinutes,
  'employeeNote': entry.employeeNote,
  'status': entry.status.name,
  'travelBonusHours': entry.travelBonusHours,
  'supervisorNote': entry.supervisorNote,
  'approvedAt': entry.approvedAt?.toIso8601String(),
  'approvedBy': entry.approvedBy,
  'rejectedAt': entry.rejectedAt?.toIso8601String(),
  'rejectedBy': entry.rejectedBy,
  'rejectionReason': entry.rejectionReason,
  'reviewRequestedAt': entry.reviewRequestedAt?.toIso8601String(),
  'reviewRequestedBy': entry.reviewRequestedBy,
  'reviewNote': entry.reviewNote,
  'resubmittedAt': entry.resubmittedAt?.toIso8601String(),
};

TimeEntry _timeEntryFromJson(Map<String, dynamic> json) => TimeEntry(
  id: json['id'] as String? ?? '',
  userId: json['userId'] as String? ?? '',
  jobId: json['jobId'] as String? ?? '',
  date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
  clockIn: json['clockIn'] as String? ?? '',
  clockOut: json['clockOut'] as String?,
  breakMinutes: json['breakMinutes'] as int? ?? 0,
  employeeNote: json['employeeNote'] as String? ?? '',
  status: _reviewStatusFromName(json['status'] as String?),
  travelBonusHours: (json['travelBonusHours'] as num?)?.toDouble() ?? 0,
  supervisorNote: json['supervisorNote'] as String? ?? '',
  approvedAt: DateTime.tryParse(json['approvedAt'] as String? ?? ''),
  approvedBy: json['approvedBy'] as String?,
  rejectedAt: DateTime.tryParse(json['rejectedAt'] as String? ?? ''),
  rejectedBy: json['rejectedBy'] as String?,
  rejectionReason: json['rejectionReason'] as String?,
  reviewRequestedAt: DateTime.tryParse(
    json['reviewRequestedAt'] as String? ?? '',
  ),
  reviewRequestedBy: json['reviewRequestedBy'] as String?,
  reviewNote: json['reviewNote'] as String?,
  resubmittedAt: DateTime.tryParse(json['resubmittedAt'] as String? ?? ''),
);

Map<String, dynamic> _reviewToJson(TimeEntryReview review) => {
  'id': review.id,
  'timeEntryId': review.timeEntryId,
  'reviewerId': review.reviewerId,
  'previousStatus': review.previousStatus.name,
  'newStatus': review.newStatus.name,
  'reason': review.reason,
  'observation': review.observation,
  'reviewedAt': review.reviewedAt.toIso8601String(),
};

TimeEntryReview _reviewFromJson(Map<String, dynamic> json) => TimeEntryReview(
  id: json['id'] as String? ?? '',
  timeEntryId: json['timeEntryId'] as String? ?? '',
  reviewerId: json['reviewerId'] as String? ?? '',
  previousStatus: _reviewStatusFromName(json['previousStatus'] as String?),
  newStatus: _reviewStatusFromName(json['newStatus'] as String?),
  reason: json['reason'] as String? ?? '',
  observation: json['observation'] as String? ?? '',
  reviewedAt:
      DateTime.tryParse(json['reviewedAt'] as String? ?? '') ?? DateTime.now(),
);

Map<String, dynamic> _auditToJson(AuditLog log) => {
  'id': log.id,
  'entityId': log.entityId,
  'fieldName': log.fieldName,
  'originalValue': log.originalValue,
  'newValue': log.newValue,
  'changedBy': log.changedBy,
  'changedAt': log.changedAt.toIso8601String(),
  'justification': log.justification,
};

AuditLog _auditFromJson(Map<String, dynamic> json) => AuditLog(
  id: json['id'] as String? ?? '',
  entityId: json['entityId'] as String? ?? '',
  fieldName: json['fieldName'] as String? ?? '',
  originalValue: json['originalValue'] as String? ?? '',
  newValue: json['newValue'] as String? ?? '',
  changedBy: json['changedBy'] as String? ?? '',
  changedAt:
      DateTime.tryParse(json['changedAt'] as String? ?? '') ?? DateTime.now(),
  justification: json['justification'] as String? ?? '',
);
