import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jkdd_field_time_records_production/src/application/field_time_controller.dart';
import 'package:jkdd_field_time_records_production/src/domain/field_time_models.dart';
import 'package:jkdd_field_time_records_production/src/domain/registration_number.dart';
import 'package:jkdd_field_time_records_production/src/supervisor_center/supervisor_center_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bridges the production Field Time clock flow with the Supervisor Center
/// approval queue used by supervisors and directors.
///
/// Test 04 keeps both modules loosely coupled: when a completed [WorkDay]
/// appears in [FieldTimeState], its closed work segments are persisted as
/// pending Supervisor Center time entries. The Supervisor Center is then
/// reloaded so the records become immediately available for review.
final fieldTimeSupervisorSyncProvider = Provider<void>((ref) {
  unawaited(
    ensureSupervisorHomologationData().then((changed) async {
      if (!changed) return;
      await ref.read(supervisorCenterProvider.notifier).initialize();
    }),
  );

  ref.listen<FieldTimeState>(fieldTimeControllerProvider, (previous, next) {
    final day = next.lastCompletedDay;
    if (day == null || day.id == previous?.lastCompletedDay?.id) return;

    final userId = day.workerId;

    unawaited(
      syncCompletedWorkDayForSupervisor(day: day, userId: userId).then((
        changed,
      ) async {
        if (!changed) return;
        await ref.read(supervisorCenterProvider.notifier).initialize();
      }),
    );
  });
});

const supervisorCenterStorageKey = 'field_time_supervisor_center_state_v1';

/// Seeds a small deterministic Test 04 workforce into the Supervisor Center.
///
/// The records are explicitly marked as homologation data and use stable IDs,
/// so they are inserted only once and any review changes made by a supervisor
/// remain persisted on later app launches.
Future<bool> ensureSupervisorHomologationData() async {
  final preferences = await SharedPreferences.getInstance();
  final raw = preferences.getString(supervisorCenterStorageKey);

  Map<String, dynamic> stateJson;
  if (raw == null || raw.trim().isEmpty) {
    stateJson = <String, dynamic>{};
  } else {
    try {
      stateJson = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } on Object {
      stateJson = <String, dynamic>{};
    }
  }

  final now = DateTime.now();
  final date = DateTime(now.year, now.month, now.day);
  final job217 = RegistrationNumberPolicy.deterministicUuid(
    'supervisor-job:217:217',
  );
  final job630 = RegistrationNumberPolicy.deterministicUuid(
    'supervisor-job:630:630',
  );

  final entries = <Map<String, dynamic>>[
    for (final item in (stateJson['timeEntries'] as List? ?? const []))
      if (item is Map) Map<String, dynamic>.from(item),
  ];
  final entryIds = entries
      .map((entry) => entry['id']?.toString())
      .whereType<String>()
      .toSet();

  final fixtures = <Map<String, dynamic>>[
    _homologationEntry(
      id: 'test04-carlos-217',
      userId: 'test-worker-0002',
      jobId: job217,
      date: date,
      clockIn: '7:00 AM',
      clockOut: '4:30 PM',
      breakMinutes: 30,
      travelBonusHours: 1,
      employeeNote: 'TESTE — registro pendente para aprovação.',
      status: 'pending',
    ),
    _homologationEntry(
      id: 'test04-lucas-630',
      userId: 'test-worker-0003',
      jobId: job630,
      date: date,
      clockIn: '7:10 AM',
      clockOut: '5:00 PM',
      breakMinutes: 30,
      travelBonusHours: 2,
      employeeNote: 'TESTE — validar Travel Bonus da Obra 630.',
      status: 'pending',
    ),
    _homologationEntry(
      id: 'test04-marcos-217',
      userId: 'test-worker-0004',
      jobId: job217,
      date: date,
      clockIn: '6:45 AM',
      clockOut: '4:00 PM',
      breakMinutes: 30,
      travelBonusHours: 1,
      employeeNote: 'TESTE — revisar horário e adicional de pagamento.',
      status: 'underReview',
      supervisorNote: 'TESTE — pronto para edição pelo supervisor.',
    ),
    _homologationEntry(
      id: 'test04-rafael-630',
      userId: 'test-worker-0005',
      jobId: job630,
      date: date,
      clockIn: '7:25 AM',
      clockOut: '4:40 PM',
      breakMinutes: 30,
      travelBonusHours: 2,
      employeeNote: 'TESTE — cenário de correção/rejeição.',
      status: 'rejected',
      supervisorNote: 'TESTE — horário de entrada precisa ser confirmado.',
      rejectionReason: 'TESTE — validar horário de entrada.',
    ),
    _homologationEntry(
      id: 'test04-andre-217',
      userId: 'test-worker-0006',
      jobId: job217,
      date: date,
      clockIn: '7:00 AM',
      clockOut: '3:45 PM',
      breakMinutes: 30,
      travelBonusHours: 1,
      employeeNote: 'TESTE — cenário ligado a recibo/reembolso.',
      status: 'correctionRequested',
      supervisorNote: 'TESTE — confirmar observação do dia.',
      reviewNote: 'TESTE — confirmar observação e reenviar.',
    ),
    _homologationEntry(
      id: 'test04-bruno-217',
      userId: 'test-worker-0007',
      jobId: job217,
      date: date,
      clockIn: '7:00 AM',
      clockOut: '11:45 AM',
      breakMinutes: 0,
      travelBonusHours: 1,
      employeeNote: 'TESTE — primeira obra do dia.',
      status: 'resubmitted',
    ),
    _homologationEntry(
      id: 'test04-bruno-630',
      userId: 'test-worker-0007',
      jobId: job630,
      date: date,
      clockIn: '12:30 PM',
      clockOut: '5:15 PM',
      breakMinutes: 0,
      travelBonusHours: 2,
      employeeNote: 'TESTE — segunda obra do mesmo dia.',
      status: 'pending',
    ),
  ];

  var changed = false;
  for (final fixture in fixtures) {
    if (entryIds.add(fixture['id']! as String)) {
      entries.add(fixture);
      changed = true;
    }
  }

  final assignments = <Map<String, dynamic>>[
    for (final item in (stateJson['assignments'] as List? ?? const []))
      if (item is Map) Map<String, dynamic>.from(item),
  ];
  final assignmentIds = assignments
      .map((item) => item['id']?.toString())
      .whereType<String>()
      .toSet();
  final assignmentFixtures = <Map<String, dynamic>>[
    _homologationAssignment(
      'test04-assignment-carlos',
      'test-worker-0002',
      job217,
      date,
      'finished',
    ),
    _homologationAssignment(
      'test04-assignment-lucas',
      'test-worker-0003',
      job630,
      date,
      'finished',
    ),
    _homologationAssignment(
      'test04-assignment-marcos',
      'test-worker-0004',
      job217,
      date,
      'finished',
    ),
    _homologationAssignment(
      'test04-assignment-rafael',
      'test-worker-0005',
      job630,
      date,
      'finished',
    ),
    _homologationAssignment(
      'test04-assignment-andre',
      'test-worker-0006',
      job217,
      date,
      'finished',
    ),
    _homologationAssignment(
      'test04-assignment-bruno',
      'test-worker-0007',
      job217,
      date,
      'finished',
    ),
  ];
  for (final fixture in assignmentFixtures) {
    if (assignmentIds.add(fixture['id']! as String)) {
      assignments.add(fixture);
      changed = true;
    }
  }

  if (!changed) return false;

  stateJson['timeEntries'] = entries;
  stateJson['assignments'] = assignments;
  stateJson.putIfAbsent('jobs', () => <dynamic>[]);
  stateJson.putIfAbsent('schedules', () => <dynamic>[]);
  stateJson.putIfAbsent('reviews', () => <dynamic>[]);
  stateJson.putIfAbsent('auditLogs', () => <dynamic>[]);

  await preferences.setString(
    supervisorCenterStorageKey,
    jsonEncode(stateJson),
  );
  return true;
}

Map<String, dynamic> _homologationEntry({
  required String id,
  required String userId,
  required String jobId,
  required DateTime date,
  required String clockIn,
  required String clockOut,
  required int breakMinutes,
  required double travelBonusHours,
  required String employeeNote,
  required String status,
  String supervisorNote = '',
  String? rejectionReason,
  String? reviewNote,
}) => <String, dynamic>{
  'id': id,
  'userId': userId,
  'jobId': jobId,
  'date': date.toIso8601String(),
  'clockIn': clockIn,
  'clockOut': clockOut,
  'breakMinutes': breakMinutes,
  'employeeNote': employeeNote,
  'status': status,
  'travelBonusHours': travelBonusHours,
  'supervisorNote': supervisorNote,
  'approvedAt': null,
  'approvedBy': null,
  'rejectedAt': status == 'rejected' ? date.toIso8601String() : null,
  'rejectedBy': status == 'rejected' ? 'Supervisor Test' : null,
  'rejectionReason': rejectionReason,
  'reviewRequestedAt': status == 'correctionRequested'
      ? date.toIso8601String()
      : null,
  'reviewRequestedBy': status == 'correctionRequested'
      ? 'Supervisor Test'
      : null,
  'reviewNote': reviewNote,
  'resubmittedAt': status == 'resubmitted' ? date.toIso8601String() : null,
};

Map<String, dynamic> _homologationAssignment(
  String id,
  String userId,
  String jobId,
  DateTime date,
  String status,
) => <String, dynamic>{
  'id': id,
  'userId': userId,
  'jobId': jobId,
  'assignmentDate': date.toIso8601String(),
  'scheduledStart': '7:00 AM',
  'scheduledEnd': '5:00 PM',
  'assignedBy': 'Director Test',
  'supervisorId': 'test-supervisor',
  'status': status,
  'notes': 'TESTE — alocação fictícia para homologação do Test 04.',
};

/// Persists one completed work day into the Supervisor Center approval queue.
/// Returns true when at least one new entry or compensation metadata was added.
Future<bool> syncCompletedWorkDayForSupervisor({
  required WorkDay day,
  required String userId,
}) async {
  final preferences = await SharedPreferences.getInstance();
  final raw = preferences.getString(supervisorCenterStorageKey);

  Map<String, dynamic> stateJson;
  if (raw == null || raw.trim().isEmpty) {
    stateJson = <String, dynamic>{};
  } else {
    try {
      stateJson = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } on Object {
      stateJson = <String, dynamic>{};
    }
  }

  final existing = <Map<String, dynamic>>[
    for (final item in (stateJson['timeEntries'] as List? ?? const []))
      if (item is Map) Map<String, dynamic>.from(item),
  ];
  final existingIds = existing
      .map((entry) => entry['id']?.toString())
      .whereType<String>()
      .toSet();

  var compensationChanged = false;
  final additions = <Map<String, dynamic>>[];
  for (final segment in day.segments) {
    if (segment.endedAt == null) continue;

    compensationChanged =
        _syncJobCompensation(stateJson, segment) || compensationChanged;

    final entryId = 'field-${day.id}-${segment.id}';
    if (existingIds.contains(entryId)) continue;

    additions.add(<String, dynamic>{
      'id': entryId,
      'userId': userId,
      'jobId': _supervisorJobId(stateJson, segment),
      'date': day.workDate.toIso8601String(),
      'clockIn': _formatClock(segment.startedAt),
      'clockOut': _formatClock(segment.endedAt!),
      'breakMinutes': 0,
      'employeeNote': _entryNote(day, segment),
      'status': 'pending',
      'travelBonusHours': segment.travelBonusHours,
      'supervisorNote': '',
      'approvedAt': null,
      'approvedBy': null,
      'rejectedAt': null,
      'rejectedBy': null,
      'rejectionReason': null,
      'reviewRequestedAt': null,
      'reviewRequestedBy': null,
      'reviewNote': null,
      'resubmittedAt': null,
    });
  }

  if (additions.isEmpty && !compensationChanged) return false;

  if (additions.isNotEmpty) {
    stateJson['timeEntries'] = [...existing, ...additions];
  }
  stateJson.putIfAbsent('jobs', () => <dynamic>[]);
  stateJson.putIfAbsent('assignments', () => <dynamic>[]);
  stateJson.putIfAbsent('schedules', () => <dynamic>[]);
  stateJson.putIfAbsent('reviews', () => <dynamic>[]);
  stateJson.putIfAbsent('auditLogs', () => <dynamic>[]);

  await preferences.setString(
    supervisorCenterStorageKey,
    jsonEncode(stateJson),
  );
  return true;
}

bool _syncJobCompensation(Map<String, dynamic> stateJson, WorkSegment segment) {
  final jobs = stateJson['jobs'];
  if (jobs is! List) return false;

  for (var index = 0; index < jobs.length; index++) {
    final item = jobs[index];
    if (item is! Map) continue;
    final job = Map<String, dynamic>.from(item);
    if (job['number']?.toString() != segment.jobNumber) continue;

    var changed = false;
    void setIfChanged(String key, Object? value) {
      if (job[key] == value) return;
      job[key] = value;
      changed = true;
    }

    setIfChanged('travelBonusHours', segment.travelBonusHours);
    setIfChanged('payPremiumEnabled', segment.payPremiumEnabled);
    setIfChanged('payPremiumLabel', _payPremiumLabel(segment));

    if (changed) jobs[index] = job;
    return changed;
  }
  return false;
}

String _payPremiumLabel(WorkSegment segment) {
  if (!segment.payPremiumEnabled || segment.payPremiumValue <= 0) return '';
  return switch (segment.payPremiumType) {
    PayPremiumType.percentage =>
      '${(segment.payPremiumValue * 100).toStringAsFixed(0)}%',
    PayPremiumType.fixedHourly =>
      '\$${segment.payPremiumValue.toStringAsFixed(2)}/h',
    PayPremiumType.doubleTime => 'Double time',
    null => '',
  };
}

String _supervisorJobId(Map<String, dynamic> stateJson, WorkSegment segment) {
  final jobs = stateJson['jobs'];
  if (jobs is List) {
    for (final item in jobs) {
      if (item is! Map) continue;
      final job = Map<String, dynamic>.from(item);
      if (job['number']?.toString() == segment.jobNumber) {
        final id = job['id']?.toString().trim() ?? '';
        if (id.isNotEmpty) return id;
      }
    }
  }
  return segment.jobId;
}

String _entryNote(WorkDay day, WorkSegment segment) {
  final segmentNote = segment.notes?.trim() ?? '';
  if (segmentNote.isNotEmpty) return segmentNote;
  return day.notes?.trim() ?? '';
}

String _formatClock(DateTime value) {
  var hour = value.hour;
  final suffix = hour >= 12 ? 'PM' : 'AM';
  hour %= 12;
  if (hour == 0) hour = 12;
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute $suffix';
}
