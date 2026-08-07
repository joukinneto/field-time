import 'package:jkdd_field_time_records_production/features/employees/domain/employee.dart';
import 'package:jkdd_field_time_records_production/features/jobs/domain/job.dart'
    as imported_job;
import 'package:jkdd_field_time_records_production/src/domain/registration_number.dart';

enum PilotRole {
  owner,
  administrator,
  coordinator,
  supervisor,
  employee,
  contractor,
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
  absent,
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
    this.registrationNumber = '',
    this.company,
    this.category,
    this.supervisor,
    this.function,
    this.active = true,
  });

  final String id;
  final String registrationNumber;
  final String name;
  final PilotRole role;
  final String? company;
  final String? category;
  final String? supervisor;
  final String? function;
  final bool active;

  bool get isContractor => role == PilotRole.contractor;
  bool get isWorker => role == PilotRole.employee;
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
    this.registrationNumber = '',
    this.travelBonusHours = 0,
    this.payPremiumEnabled = false,
    this.payPremiumLabel = '',
  });

  final String id;
  final String registrationNumber;
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
  final double travelBonusHours;
  final bool payPremiumEnabled;
  final String payPremiumLabel;

  String get displayName => 'Job $number';

  factory SupervisorJob.placeholder(String id) => SupervisorJob(
    id: id,
    registrationNumber: id,
    number: id,
    name: '',
    client: 'EWW',
    address: '',
    city: '',
    state: '',
    zipCode: '',
    startDate: DateTime.now(),
    scheduledTime: '',
    supervisorId: '9d48bb6e-52cb-48a8-84f2-7e9a3ef8f001',
    notes: '',
    status: JobStatus.active,
    travelBonusHours: 0,
    payPremiumEnabled: false,
    payPremiumLabel: '',
  );

  SupervisorJob copyWith({
    String? id,
    String? registrationNumber,
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
    double? travelBonusHours,
    bool? payPremiumEnabled,
    String? payPremiumLabel,
  }) => SupervisorJob(
    id: id ?? this.id,
    registrationNumber: registrationNumber ?? this.registrationNumber,
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
    travelBonusHours: travelBonusHours ?? this.travelBonusHours,
    payPremiumEnabled: payPremiumEnabled ?? this.payPremiumEnabled,
    payPremiumLabel: payPremiumLabel ?? this.payPremiumLabel,
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
  }) => TimeEntry(
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
    rejectionReason: clearRejection
        ? null
        : rejectionReason ?? this.rejectionReason,
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
    this.simulatedUserId,
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
  final String? simulatedUserId;
  final String? message;
  final String? error;

  PilotUser get currentUser {
    if (users.isEmpty) {
      return const PilotUser(
        id: 'TER-0001',
        registrationNumber: 'TER-0001',
        name: 'Santana',
        role: PilotRole.employee,
        company: 'JKDD Finish & Remodeling Corp.',
        active: true,
      );
    }
    final selectedId = simulatedUserId;
    if (selectedId != null) {
      for (final user in users) {
        if (user.id == selectedId) return user;
      }
    }
    return users.firstWhere(
      (user) => user.role == currentRole,
      orElse: () => users.first,
    );
  }

  PilotUser userById(String id) =>
      users.firstWhere((user) => user.id == id, orElse: () => currentUser);
  SupervisorJob jobById(String id) => jobs.firstWhere(
    (job) => job.id == id,
    orElse: () => SupervisorJob.placeholder(id),
  );

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
    List<PilotUser>? users,
    List<SupervisorJob>? jobs,
    List<JobAssignment>? assignments,
    List<SupervisorSchedule>? schedules,
    List<TimeEntry>? timeEntries,
    List<TimeEntryReview>? reviews,
    List<AuditLog>? auditLogs,
    bool? allowSupervisorCreateJobs,
    String? simulatedUserId,
    String? message,
    String? error,
    bool clearFeedback = false,
    bool clearSimulatedUser = false,
  }) => SupervisorCenterState(
    currentRole: currentRole ?? this.currentRole,
    users: users ?? this.users,
    jobs: jobs ?? this.jobs,
    assignments: assignments ?? this.assignments,
    schedules: schedules ?? this.schedules,
    timeEntries: timeEntries ?? this.timeEntries,
    reviews: reviews ?? this.reviews,
    auditLogs: auditLogs ?? this.auditLogs,
    allowSupervisorCreateJobs:
        allowSupervisorCreateJobs ?? this.allowSupervisorCreateJobs,
    simulatedUserId: clearSimulatedUser
        ? null
        : simulatedUserId ?? this.simulatedUserId,
    message: clearFeedback ? null : message,
    error: clearFeedback ? null : error,
  );

  factory SupervisorCenterState.seeded() {
    const users = [
      PilotUser(
        id: 'TER-0001',
        registrationNumber: 'TER-0001',
        name: 'Santana',
        role: PilotRole.employee,
        company: 'JKDD Finish & Remodeling Corp.',
        category: 'Terceirizado de Mao de Obra',
        supervisor: 'Santana',
        function: 'Responsavel pela JKDD',
      ),
      ..._homologationUsers,
    ];
    return const SupervisorCenterState(
      currentRole: PilotRole.employee,
      users: users,
      jobs: [],
      assignments: [],
      schedules: [],
      timeEntries: [],
      reviews: [],
      auditLogs: [],
    );
  }

  factory SupervisorCenterState.fromEmployeesAndJobs({
    required List<Employee> employees,
    required List<imported_job.Job> jobs,
    PilotRole currentRole = PilotRole.supervisor,
    bool allowSupervisorCreateJobs = true,
  }) {
    final today = DateTime.now();
    final date = DateTime(today.year, today.month, today.day);
    final users = [
      ...employees.map(_pilotUserFromEmployee),
      ..._homologationUsers,
    ];
    final supervisorId = users.isEmpty ? 'TER-0001' : users.first.id;
    return SupervisorCenterState(
      currentRole: currentRole,
      users: users,
      jobs: jobs
          .map((job) {
            final index = jobs.indexOf(job);
            final technicalId = RegistrationNumberPolicy.isUuid(job.jobId)
                ? job.jobId
                : RegistrationNumberPolicy.deterministicUuid(
                    'supervisor-job:${job.jobId}:${job.jobNumber}',
                  );
            return SupervisorJob(
              id: technicalId,
              registrationNumber:
                  job.registrationNumber ??
                  RegistrationNumberPolicy.format(
                    RegistrationRecordType.job,
                    index + 1,
                  ),
              number: job.jobNumber,
              name: job.jobName,
              client: job.client ?? 'EWW',
              address: job.address ?? job.fullAddress,
              city: job.city ?? '',
              state: job.state ?? '',
              zipCode: job.zipCode ?? '',
              startDate: date,
              scheduledTime: '7:00 AM',
              supervisorId: supervisorId,
              notes: job.notes ?? '',
              status: _jobStatusFromText(job.status),
              travelBonusHours: job.travelBonusHours ?? 0,
              payPremiumEnabled: false,
              payPremiumLabel: '',
            );
          })
          .toList(growable: false),
      assignments: const [],
      schedules: const [],
      timeEntries: const [],
      reviews: const [],
      auditLogs: const [],
      allowSupervisorCreateJobs: allowSupervisorCreateJobs,
    );
  }
}

const _homologationUsers = [
  PilotUser(
    id: 'test-supervisor',
    registrationNumber: 'TER-9001',
    name: 'Supervisor Test',
    role: PilotRole.supervisor,
    company: 'JKDD TECH - Homologation',
    category: 'Homologation data',
    function: 'Supervisor',
  ),
  PilotUser(
    id: 'test-director',
    registrationNumber: 'TER-9002',
    name: 'Director Test',
    role: PilotRole.owner,
    company: 'JKDD TECH - Homologation',
    category: 'Homologation data',
    function: 'Director',
  ),
];

PilotUser _pilotUserFromEmployee(Employee employee) => PilotUser(
  id: employee.id.isNotEmpty ? employee.id : employee.employeeId,
  registrationNumber: employee.registrationNumber.isNotEmpty
      ? employee.registrationNumber
      : employee.employeeId,
  name: employee.displayName,
  role: _roleFromEmployee(employee),
  company: employee.company,
  category: employee.category,
  supervisor: employee.supervisor,
  function: employee.role,
  active: employee.active,
);

PilotRole _roleFromEmployee(Employee employee) {
  if (employee.employeeId == 'TER-0001') return PilotRole.employee;
  final text = [
    employee.role,
    employee.category,
    employee.employmentType,
  ].whereType<String>().join(' ').toLowerCase();
  if (text.contains('owner')) return PilotRole.owner;
  if (text.contains('admin')) return PilotRole.administrator;
  if (text.contains('coorden') || text.contains('coordin')) {
    return PilotRole.coordinator;
  }
  if (text.contains('respons') || text.contains('supervisor')) {
    return PilotRole.supervisor;
  }
  if (text.contains('terceir') || text.contains('contract')) {
    return PilotRole.contractor;
  }
  return PilotRole.employee;
}

JobStatus _jobStatusFromText(String value) {
  final text = value.trim().toLowerCase();
  if (text == 'planned') return JobStatus.planned;
  if (text == 'paused') return JobStatus.paused;
  if (text == 'completed') return JobStatus.completed;
  if (text == 'cancelled' || text == 'canceled') return JobStatus.cancelled;
  return JobStatus.active;
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
    PilotPermission.clockOwnTime,
    PilotPermission.requestCorrection,
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
  PilotRole.owner => 'Director',
  PilotRole.administrator => 'Administrator',
  PilotRole.coordinator => 'Coordinator',
  PilotRole.supervisor => 'Supervisor',
  PilotRole.employee => 'Collaborator',
  PilotRole.contractor => 'Collaborator',
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
