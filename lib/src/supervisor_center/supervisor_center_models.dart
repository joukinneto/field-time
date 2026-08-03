enum PilotRole {
  owner,
  administrator,
  coordinator,
  supervisor,
  employee,
  contractor
}

enum PilotPermission {
  viewManagement,
  approveTime,
  createJob,
  createSchedule,
  viewAllTime,
  editJob,
  clockOwnTime,
  requestCorrection,
}

enum JobStatus { planned, active, paused, completed, cancelled }

enum AssignmentStatus {
  scheduled,
  working,
  breakTime,
  finished,
  noEntry,
  absent
}

enum TimeReviewStatus {
  pending,
  underReview,
  approved,
  rejected,
  correctionRequested,
  corrected,
  resubmitted,
  closed,
  working,
}

enum ScheduleFilter { today, week, calendar }

final class PilotUser {
  const PilotUser({
    required this.id,
    required this.name,
    required this.role,
  });

  final String id;
  final String name;
  final PilotRole role;

  bool get isContractor => role == PilotRole.contractor;
  bool get isWorker =>
      role == PilotRole.employee || role == PilotRole.contractor;
}

final class SupervisorJob {
  const SupervisorJob({
    required this.id,
    required this.number,
    required this.name,
    required this.client,
    required this.address,
    required this.city,
    required this.state,
    required this.zipCode,
    required this.startDate,
    required this.scheduledTime,
    required this.supervisorId,
    required this.notes,
    required this.status,
  });

  final String id;
  final String number;
  final String name;
  final String client;
  final String address;
  final String city;
  final String state;
  final String zipCode;
  final DateTime startDate;
  final String scheduledTime;
  final String supervisorId;
  final String notes;
  final JobStatus status;

  String get displayName => 'Obra $number - $name';

  SupervisorJob copyWith({
    String? id,
    String? number,
    String? name,
    String? client,
    String? address,
    String? city,
    String? state,
    String? zipCode,
    DateTime? startDate,
    String? scheduledTime,
    String? supervisorId,
    String? notes,
    JobStatus? status,
  }) =>
      SupervisorJob(
        id: id ?? this.id,
        number: number ?? this.number,
        name: name ?? this.name,
        client: client ?? this.client,
        address: address ?? this.address,
        city: city ?? this.city,
        state: state ?? this.state,
        zipCode: zipCode ?? this.zipCode,
        startDate: startDate ?? this.startDate,
        scheduledTime: scheduledTime ?? this.scheduledTime,
        supervisorId: supervisorId ?? this.supervisorId,
        notes: notes ?? this.notes,
        status: status ?? this.status,
      );
}

final class JobAssignment {
  const JobAssignment({
    required this.id,
    required this.userId,
    required this.jobId,
    required this.assignmentDate,
    required this.scheduledStart,
    required this.scheduledEnd,
    required this.assignedBy,
    required this.supervisorId,
    required this.status,
    required this.notes,
  });

  final String id;
  final String userId;
  final String jobId;
  final DateTime assignmentDate;
  final String scheduledStart;
  final String scheduledEnd;
  final String assignedBy;
  final String supervisorId;
  final AssignmentStatus status;
  final String notes;
}

final class SupervisorSchedule {
  const SupervisorSchedule({
    required this.id,
    required this.supervisorId,
    required this.jobId,
    required this.date,
    required this.time,
    required this.note,
  });

  final String id;
  final String supervisorId;
  final String jobId;
  final DateTime date;
  final String time;
  final String note;
}

final class TimeEntry {
  const TimeEntry({
    required this.id,
    required this.userId,
    required this.jobId,
    required this.date,
    required this.clockIn,
    required this.clockOut,
    required this.breakMinutes,
    required this.employeeNote,
    required this.status,
    this.travelBonusHours = 0,
    this.supervisorNote = '',
    this.approvedAt,
    this.approvedBy,
    this.rejectedAt,
    this.rejectedBy,
    this.rejectionReason,
    this.reviewRequestedAt,
    this.reviewRequestedBy,
    this.reviewNote,
    this.resubmittedAt,
  });

  final String id;
  final String userId;
  final String jobId;
  final DateTime date;
  final String clockIn;
  final String? clockOut;
  final int breakMinutes;
  final String employeeNote;
  final TimeReviewStatus status;
  final double travelBonusHours;
  final String supervisorNote;
  final DateTime? approvedAt;
  final String? approvedBy;
  final DateTime? rejectedAt;
  final String? rejectedBy;
  final String? rejectionReason;
  final DateTime? reviewRequestedAt;
  final String? reviewRequestedBy;
  final String? reviewNote;
  final DateTime? resubmittedAt;

  bool get isOpen => clockOut == null;
  bool get isLocked => status == TimeReviewStatus.approved;

  TimeEntry copyWith({
    String? clockIn,
    String? clockOut,
    bool clearClockOut = false,
    int? breakMinutes,
    TimeReviewStatus? status,
    double? travelBonusHours,
    String? supervisorNote,
    DateTime? approvedAt,
    String? approvedBy,
    DateTime? rejectedAt,
    String? rejectedBy,
    String? rejectionReason,
    DateTime? reviewRequestedAt,
    String? reviewRequestedBy,
    String? reviewNote,
    DateTime? resubmittedAt,
    bool clearApproval = false,
    bool clearRejection = false,
    bool clearReviewRequest = false,
  }) =>
      TimeEntry(
        id: id,
        userId: userId,
        jobId: jobId,
        date: date,
        clockIn: clockIn ?? this.clockIn,
        clockOut: clearClockOut ? null : clockOut ?? this.clockOut,
        breakMinutes: breakMinutes ?? this.breakMinutes,
        employeeNote: employeeNote,
        status: status ?? this.status,
        travelBonusHours: travelBonusHours ?? this.travelBonusHours,
        supervisorNote: supervisorNote ?? this.supervisorNote,
        approvedAt: clearApproval ? null : approvedAt ?? this.approvedAt,
        approvedBy: clearApproval ? null : approvedBy ?? this.approvedBy,
        rejectedAt: clearRejection ? null : rejectedAt ?? this.rejectedAt,
        rejectedBy: clearRejection ? null : rejectedBy ?? this.rejectedBy,
        rejectionReason:
            clearRejection ? null : rejectionReason ?? this.rejectionReason,
        reviewRequestedAt: clearReviewRequest
            ? null
            : reviewRequestedAt ?? this.reviewRequestedAt,
        reviewRequestedBy: clearReviewRequest
            ? null
            : reviewRequestedBy ?? this.reviewRequestedBy,
        reviewNote: clearReviewRequest ? null : reviewNote ?? this.reviewNote,
        resubmittedAt: resubmittedAt ?? this.resubmittedAt,
      );
}

final class TimeEntryReview {
  const TimeEntryReview({
    required this.id,
    required this.timeEntryId,
    required this.reviewerId,
    required this.previousStatus,
    required this.newStatus,
    required this.reason,
    required this.observation,
    required this.reviewedAt,
  });

  final String id;
  final String timeEntryId;
  final String reviewerId;
  final TimeReviewStatus previousStatus;
  final TimeReviewStatus newStatus;
  final String reason;
  final String observation;
  final DateTime reviewedAt;
}

final class AuditLog {
  const AuditLog({
    required this.id,
    required this.entityId,
    required this.fieldName,
    required this.originalValue,
    required this.newValue,
    required this.changedBy,
    required this.changedAt,
    required this.justification,
  });

  final String id;
  final String entityId;
  final String fieldName;
  final String originalValue;
  final String newValue;
  final String changedBy;
  final DateTime changedAt;
  final String justification;
}

final class SupervisorCenterState {
  const SupervisorCenterState({
    required this.currentRole,
    required this.users,
    required this.jobs,
    required this.assignments,
    required this.schedules,
    required this.timeEntries,
    required this.reviews,
    required this.auditLogs,
    this.allowSupervisorCreateJobs = true,
    this.message,
    this.error,
  });

  final PilotRole currentRole;
  final List<PilotUser> users;
  final List<SupervisorJob> jobs;
  final List<JobAssignment> assignments;
  final List<SupervisorSchedule> schedules;
  final List<TimeEntry> timeEntries;
  final List<TimeEntryReview> reviews;
  final List<AuditLog> auditLogs;
  final bool allowSupervisorCreateJobs;
  final String? message;
  final String? error;

  PilotUser get currentUser => switch (currentRole) {
        PilotRole.supervisor => userById('joukin'),
        PilotRole.employee => userById('carlos'),
        PilotRole.contractor => userById('marcos'),
        PilotRole.owner => userById('joukin'),
        PilotRole.administrator => userById('joukin'),
        PilotRole.coordinator => userById('joukin'),
      };

  PilotUser userById(String id) => users.firstWhere((user) => user.id == id);
  SupervisorJob jobById(String id) => jobs.firstWhere((job) => job.id == id);

  bool hasPermission(PilotPermission permission) {
    final base = _permissionsFor(currentRole);
    if (permission == PilotPermission.createJob &&
        currentRole == PilotRole.supervisor) {
      return allowSupervisorCreateJobs;
    }
    return base.contains(permission);
  }

  SupervisorCenterState copyWith({
    PilotRole? currentRole,
    List<SupervisorJob>? jobs,
    List<JobAssignment>? assignments,
    List<SupervisorSchedule>? schedules,
    List<TimeEntry>? timeEntries,
    List<TimeEntryReview>? reviews,
    List<AuditLog>? auditLogs,
    bool? allowSupervisorCreateJobs,
    String? message,
    String? error,
    bool clearFeedback = false,
  }) =>
      SupervisorCenterState(
        currentRole: currentRole ?? this.currentRole,
        users: users,
        jobs: jobs ?? this.jobs,
        assignments: assignments ?? this.assignments,
        schedules: schedules ?? this.schedules,
        timeEntries: timeEntries ?? this.timeEntries,
        reviews: reviews ?? this.reviews,
        auditLogs: auditLogs ?? this.auditLogs,
        allowSupervisorCreateJobs:
            allowSupervisorCreateJobs ?? this.allowSupervisorCreateJobs,
        message: clearFeedback ? null : message,
        error: clearFeedback ? null : error,
      );

  factory SupervisorCenterState.seeded() {
    final today = DateTime.now();
    final date = DateTime(today.year, today.month, today.day);
    const users = [
      PilotUser(id: 'joukin', name: 'Joukin', role: PilotRole.supervisor),
      PilotUser(id: 'carlos', name: 'Carlos', role: PilotRole.employee),
      PilotUser(id: 'jose', name: 'Jose', role: PilotRole.employee),
      PilotUser(id: 'marcos', name: 'Marcos', role: PilotRole.contractor),
      PilotUser(id: 'pedro', name: 'Pedro', role: PilotRole.contractor),
    ];
    return SupervisorCenterState(
      currentRole: PilotRole.supervisor,
      users: users,
      jobs: [
        SupervisorJob(
          id: 'job-630',
          number: '630',
          name: 'Golden Beach',
          client: 'EWW',
          address: '630 Ocean Blvd',
          city: 'Golden Beach',
          state: 'FL',
          zipCode: '33160',
          startDate: date,
          scheduledTime: '7:00 AM',
          supervisorId: 'joukin',
          notes: 'Exterior finish and daily inspection.',
          status: JobStatus.active,
        ),
        SupervisorJob(
          id: 'job-3099',
          number: '3099',
          name: 'Boca Raton',
          client: 'EWW',
          address: '3099 Banyan Rd',
          city: 'Boca Raton',
          state: 'FL',
          zipCode: '33431',
          startDate: date,
          scheduledTime: '11:00 AM',
          supervisorId: 'joukin',
          notes: 'Midday visit and material check.',
          status: JobStatus.active,
        ),
        SupervisorJob(
          id: 'job-3131',
          number: '3131',
          name: 'Delray Beach',
          client: 'EWW',
          address: '3131 Atlantic Ave',
          city: 'Delray Beach',
          state: 'FL',
          zipCode: '33444',
          startDate: date,
          scheduledTime: '2:30 PM',
          supervisorId: 'joukin',
          notes: 'Afternoon walkthrough.',
          status: JobStatus.planned,
        ),
      ],
      assignments: [
        JobAssignment(
          id: 'assign-carlos-630',
          userId: 'carlos',
          jobId: 'job-630',
          assignmentDate: date,
          scheduledStart: '7:00 AM',
          scheduledEnd: '5:00 PM',
          assignedBy: 'joukin',
          supervisorId: 'joukin',
          status: AssignmentStatus.finished,
          notes: 'Finish crew.',
        ),
        JobAssignment(
          id: 'assign-jose-630',
          userId: 'jose',
          jobId: 'job-630',
          assignmentDate: date,
          scheduledStart: '7:00 AM',
          scheduledEnd: '4:30 PM',
          assignedBy: 'joukin',
          supervisorId: 'joukin',
          status: AssignmentStatus.finished,
          notes: 'Interior detail.',
        ),
        JobAssignment(
          id: 'assign-marcos-630',
          userId: 'marcos',
          jobId: 'job-630',
          assignmentDate: date,
          scheduledStart: '7:00 AM',
          scheduledEnd: '5:00 PM',
          assignedBy: 'joukin',
          supervisorId: 'joukin',
          status: AssignmentStatus.working,
          notes: 'Contractor punch list.',
        ),
        JobAssignment(
          id: 'assign-pedro-3099',
          userId: 'pedro',
          jobId: 'job-3099',
          assignmentDate: date,
          scheduledStart: '11:00 AM',
          scheduledEnd: '4:00 PM',
          assignedBy: 'joukin',
          supervisorId: 'joukin',
          status: AssignmentStatus.noEntry,
          notes: 'Contractor visit.',
        ),
      ],
      schedules: [
        SupervisorSchedule(
          id: 'schedule-630',
          supervisorId: 'joukin',
          jobId: 'job-630',
          date: date,
          time: '7:00 AM',
          note: 'Start day at Golden Beach.',
        ),
        SupervisorSchedule(
          id: 'schedule-3099',
          supervisorId: 'joukin',
          jobId: 'job-3099',
          date: date,
          time: '11:00 AM',
          note: 'Review Boca Raton progress.',
        ),
        SupervisorSchedule(
          id: 'schedule-3131',
          supervisorId: 'joukin',
          jobId: 'job-3131',
          date: date,
          time: '2:30 PM',
          note: 'Confirm Delray Beach start readiness.',
        ),
      ],
      timeEntries: [
        TimeEntry(
          id: 'entry-carlos',
          userId: 'carlos',
          jobId: 'job-630',
          date: date,
          clockIn: '7:00 AM',
          clockOut: '5:00 PM',
          breakMinutes: 30,
          employeeNote: 'Completed paint prep and cleanup.',
          status: TimeReviewStatus.pending,
        ),
        TimeEntry(
          id: 'entry-jose',
          userId: 'jose',
          jobId: 'job-630',
          date: date,
          clockIn: '7:10 AM',
          clockOut: '4:30 PM',
          breakMinutes: 30,
          employeeNote: 'Worked on finish details.',
          status: TimeReviewStatus.pending,
        ),
        TimeEntry(
          id: 'entry-marcos',
          userId: 'marcos',
          jobId: 'job-630',
          date: date,
          clockIn: '7:15 AM',
          clockOut: null,
          breakMinutes: 0,
          employeeNote: 'Still working on contractor items.',
          status: TimeReviewStatus.working,
        ),
      ],
      reviews: const [],
      auditLogs: const [],
    );
  }
}

Set<PilotPermission> _permissionsFor(PilotRole role) => switch (role) {
      PilotRole.owner => PilotPermission.values.toSet(),
      PilotRole.administrator => PilotPermission.values.toSet(),
      PilotRole.coordinator => {
          PilotPermission.viewManagement,
          PilotPermission.approveTime,
          PilotPermission.createJob,
          PilotPermission.createSchedule,
          PilotPermission.viewAllTime,
          PilotPermission.editJob,
        },
      PilotRole.supervisor => {
          PilotPermission.viewManagement,
          PilotPermission.approveTime,
          PilotPermission.createJob,
          PilotPermission.viewAllTime,
          PilotPermission.editJob,
        },
      PilotRole.employee => {
          PilotPermission.clockOwnTime,
          PilotPermission.requestCorrection,
        },
      PilotRole.contractor => {
          PilotPermission.clockOwnTime,
          PilotPermission.requestCorrection,
        },
    };

String roleLabel(PilotRole role) => switch (role) {
      PilotRole.owner => 'Owner',
      PilotRole.administrator => 'Administrator',
      PilotRole.coordinator => 'Coordinator',
      PilotRole.supervisor => 'Supervisor',
      PilotRole.employee => 'Employee',
      PilotRole.contractor => 'Contractor',
    };

String jobStatusLabel(JobStatus status) => switch (status) {
      JobStatus.planned => 'Planejada',
      JobStatus.active => 'Ativa',
      JobStatus.paused => 'Pausada',
      JobStatus.completed => 'Concluida',
      JobStatus.cancelled => 'Cancelada',
    };

String assignmentStatusLabel(AssignmentStatus status) => switch (status) {
      AssignmentStatus.scheduled => 'Programado',
      AssignmentStatus.working => 'Trabalhando',
      AssignmentStatus.breakTime => 'Intervalo',
      AssignmentStatus.finished => 'Finalizado',
      AssignmentStatus.noEntry => 'Sem entrada',
      AssignmentStatus.absent => 'Ausente',
    };

String reviewStatusLabel(TimeReviewStatus status) => switch (status) {
      TimeReviewStatus.pending => 'Pendente',
      TimeReviewStatus.underReview => 'Em revisao',
      TimeReviewStatus.approved => 'Aprovado',
      TimeReviewStatus.rejected => 'Rejeitado',
      TimeReviewStatus.correctionRequested => 'Correcao solicitada',
      TimeReviewStatus.corrected => 'Corrigido',
      TimeReviewStatus.resubmitted => 'Reenviado',
      TimeReviewStatus.closed => 'Fechado',
      TimeReviewStatus.working => 'Trabalhando',
    };
