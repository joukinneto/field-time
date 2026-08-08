import 'package:jkdd_field_time_records_production/src/domain/field_time_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Mirrors local Field Time work segments into the Supabase TEST backend.
///
/// The local repository remains the offline-first source used by the current
/// TEST build. This adapter is deliberately isolated until authenticated test
/// users, memberships, workers, jobs, and client-side RLS tests are available.
final class SupabaseTimeEntrySync {
  SupabaseTimeEntrySync({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<void> syncSegment(WorkSegment segment) async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw StateError('Supabase Auth session is required to sync time entries.');
    }

    final membership = await _client
        .from('company_members')
        .select('company_id')
        .eq('user_id', authUser.id)
        .eq('status', 'active')
        .limit(1)
        .maybeSingle();
    if (membership == null) {
      throw StateError('Active company membership was not found.');
    }
    final companyId = membership['company_id'] as String;

    final worker = await _client
        .from('workers')
        .select('id')
        .eq('company_id', companyId)
        .eq('user_id', authUser.id)
        .eq('status', 'active')
        .isFilter('deleted_at', null)
        .limit(1)
        .maybeSingle();
    if (worker == null) {
      throw StateError('Active worker profile was not found.');
    }
    final workerId = worker['id'] as String;

    final job = await _client
        .from('jobs')
        .select('id')
        .eq('company_id', companyId)
        .eq('job_number', segment.jobNumber)
        .eq('status', 'active')
        .isFilter('deleted_at', null)
        .limit(1)
        .maybeSingle();
    if (job == null) {
      throw StateError('Remote job ${segment.jobNumber} was not found.');
    }
    final jobId = job['id'] as String;

    await _client.from('time_entries').upsert(
      buildPayload(
        segment: segment,
        companyId: companyId,
        workerId: workerId,
        jobId: jobId,
      ),
      onConflict: 'id',
    );
  }

  static Map<String, Object?> buildPayload({
    required WorkSegment segment,
    required String companyId,
    required String workerId,
    required String jobId,
  }) =>
      {
        'id': segment.id,
        'company_id': companyId,
        'worker_id': workerId,
        'job_id': jobId,
        'clock_in_at': segment.startedAt.toUtc().toIso8601String(),
        'clock_out_at': segment.endedAt?.toUtc().toIso8601String(),
        'clock_in_latitude': segment.startedLocation.latitude,
        'clock_in_longitude': segment.startedLocation.longitude,
        'clock_in_accuracy_meters': segment.startedLocation.accuracyMeters,
        'clock_out_latitude': segment.endedLocation?.latitude,
        'clock_out_longitude': segment.endedLocation?.longitude,
        'clock_out_accuracy_meters': segment.endedLocation?.accuracyMeters,
        'notes': segment.notes,
        // `sync` is one of the values accepted by the TEST database constraint.
        'source': 'sync',
        // The database requires open entries to be `active` and closed entries
        // to have a non-active status. A locally completed segment is submitted
        // for supervisor review rather than self-approved by the worker.
        'status': segment.isOpen ? 'active' : 'submitted',
        'sync_status': 'synced',
      };

  Future<void> syncSegments(Iterable<WorkSegment> segments) async {
    for (final segment in segments) {
      await syncSegment(segment);
    }
  }
}
