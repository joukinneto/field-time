import 'package:jkdd_field_time_records_production/src/domain/field_time_models.dart';
import 'package:jkdd_field_time_records_production/src/timesheet/timesheet_approval_service.dart';

final class TimesheetApprovalSummary {
  const TimesheetApprovalSummary({
    required this.total,
    required this.approved,
    required this.pending,
    required this.rejected,
    required this.underReview,
  });

  final int total;
  final int approved;
  final int pending;
  final int rejected;
  final int underReview;

  bool get fullyApproved => total > 0 && approved == total;

  String get formalStatus {
    if (total == 0) return 'No approval records';
    if (fullyApproved) return 'Fully Approved';
    if (rejected > 0) return 'Rejected Records Present';
    if (underReview > 0) return 'Review In Progress';
    return 'Pending Approval';
  }
}

TimesheetApprovalSummary summarizeApprovals({
  required List<WorkDay> days,
  required Map<String, TimesheetApprovalStamp> stamps,
}) {
  var total = 0;
  var approved = 0;
  var pending = 0;
  var rejected = 0;
  var underReview = 0;

  for (final day in days) {
    for (final segment in day.segments) {
      if (segment.endedAt == null) continue;
      total++;
      final stamp = stamps[approvalEntryId(day.id, segment.id)];
      final status = stamp?.status ?? 'pending';
      switch (status) {
        case 'approved':
          approved++;
          break;
        case 'rejected':
          rejected++;
          break;
        case 'underReview':
        case 'correctionRequested':
        case 'corrected':
        case 'resubmitted':
          underReview++;
          break;
        default:
          pending++;
      }
    }
  }

  return TimesheetApprovalSummary(
    total: total,
    approved: approved,
    pending: pending,
    rejected: rejected,
    underReview: underReview,
  );
}
