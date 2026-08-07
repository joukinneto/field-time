import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jkdd_field_time_records_production/src/application/field_time_controller.dart';
import 'package:jkdd_field_time_records_production/src/auth/auth_session.dart';
import 'package:jkdd_field_time_records_production/src/domain/field_time_models.dart';
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
  ref.listen<FieldTimeState>(fieldTimeControllerProvider, (previous, next) {
    final day = next.lastCompletedDay;
    if (day == null || day.id == previous?.lastCompletedDay?.id) return;

    final sessionUser = ref.read(authSessionProvider).user;
    final userId = sessionUser?.id ?? day.workerId;

    unawaited(
      syncCompletedWorkDayForSupervisor(day: day, userId: userId).then((changed) {
        if (!changed) return;
        return ref.read(supervisorCenterProvider.notifier).initialize();
      }),
    );
  });
});

const supervisorCenterStorageKey = 'field_time_supervisor_center_state_v1';

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

  await preferences.setString(supervisorCenterStorageKey, jsonEncode(stateJson));
  return true;
}

bool _syncJobCompensation(
  Map<String, dynamic> stateJson,
  WorkSegment segment,
) {
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

String _supervisorJobId(
  Map<String, dynamic> stateJson,
  WorkSegment segment,
) {
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
