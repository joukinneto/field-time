import 'package:jkdd_field_time_records_production/src/data/remote/supabase_time_entry_sync.dart';
import 'package:jkdd_field_time_records_production/src/domain/field_time_models.dart';

/// Coordinates offline-first clock mutations with the Supabase TEST mirror.
///
/// Local persistence remains authoritative for the current TEST build. This
/// coordinator only mirrors segments that are new or materially changed after
/// a successful local save. It is intentionally separate from the controller
/// until authenticated end-to-end tests are available.
final class SupabaseClockSyncCoordinator {
  SupabaseClockSyncCoordinator({SupabaseTimeEntrySync? sync})
      : _sync = sync ?? SupabaseTimeEntrySync();

  final SupabaseTimeEntrySync _sync;

  Future<void> syncAfterMutation({
    required FieldTimeSnapshot before,
    required FieldTimeSnapshot after,
  }) async {
    final changed = changedSegments(before: before, after: after);
    if (changed.isEmpty) return;
    await _sync.syncSegments(changed);
  }

  static List<WorkSegment> changedSegments({
    required FieldTimeSnapshot before,
    required FieldTimeSnapshot after,
  }) {
    final previousById = <String, WorkSegment>{
      for (final day in before.workDays)
        for (final segment in day.segments) segment.id: segment,
    };

    final changed = <WorkSegment>[];
    for (final day in after.workDays) {
      for (final segment in day.segments) {
        final previous = previousById[segment.id];
        if (previous == null || _materiallyChanged(previous, segment)) {
          changed.add(segment);
        }
      }
    }
    return changed;
  }

  static bool _materiallyChanged(WorkSegment before, WorkSegment after) {
    return before.jobNumber != after.jobNumber ||
        before.startedAt != after.startedAt ||
        before.endedAt != after.endedAt ||
        before.notes != after.notes ||
        before.startedLocation.latitude != after.startedLocation.latitude ||
        before.startedLocation.longitude != after.startedLocation.longitude ||
        before.startedLocation.accuracyMeters !=
            after.startedLocation.accuracyMeters ||
        before.endedLocation?.latitude != after.endedLocation?.latitude ||
        before.endedLocation?.longitude != after.endedLocation?.longitude ||
        before.endedLocation?.accuracyMeters !=
            after.endedLocation?.accuracyMeters;
  }
}
