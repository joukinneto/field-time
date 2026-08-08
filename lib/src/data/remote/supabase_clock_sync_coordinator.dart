import 'package:jkdd_field_time_records_production/src/data/remote/supabase_time_entry_sync.dart';
import 'package:jkdd_field_time_records_production/src/domain/field_time_models.dart';

/// Coordinates offline-first clock mutations with the Supabase TEST mirror.
///
/// Local persistence remains authoritative for the current TEST build. This
/// coordinator mirrors only segments that are new or materially changed after
/// a successful local save. Remote failures must never roll back a local clock
/// mutation; the persisted snapshot can later be replayed idempotently.
final class SupabaseClockSyncCoordinator {
  const SupabaseClockSyncCoordinator({SupabaseTimeEntrySync? sync})
      : _sync = sync;

  final SupabaseTimeEntrySync? _sync;

  Future<void> syncAfterMutation({
    required FieldTimeSnapshot before,
    required FieldTimeSnapshot after,
  }) async {
    final changed = changedSegments(before: before, after: after);
    if (changed.isEmpty) return;

    final sync = _sync ?? SupabaseTimeEntrySync();
    await sync.syncSegments(changed);
  }

  /// Explicit TEST retry for persisted clock segments after connectivity or
  /// authentication recovery. Automatic scheduling will be wired only after
  /// authenticated end-to-end validation is available.
  ///
  /// The remote adapter uses upsert semantics, so replaying the persisted
  /// snapshot is intentionally idempotent and avoids depending on a perfect
  /// local queue history while the TEST architecture is still evolving.
  Future<void> retryPersistedSnapshot(FieldTimeSnapshot snapshot) async {
    final segments = segmentsForRetry(snapshot);
    if (segments.isEmpty) return;

    final sync = _sync ?? SupabaseTimeEntrySync();
    await sync.syncSegments(segments);
  }

  static List<WorkSegment> segmentsForRetry(FieldTimeSnapshot snapshot) => [
        for (final day in snapshot.workDays)
          for (final segment in day.segments) segment,
      ];

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
