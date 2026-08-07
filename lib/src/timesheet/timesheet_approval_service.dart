import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const supervisorCenterStorageKey = 'field_time_supervisor_center_state_v1';

final class TimesheetApprovalStamp {
  const TimesheetApprovalStamp({
    required this.entryId,
    required this.status,
    this.approvedBy,
    this.approvedAt,
    this.rejectedBy,
    this.rejectedAt,
    this.rejectionReason,
    this.reviewRequestedBy,
    this.reviewRequestedAt,
    this.reviewNote,
  });

  final String entryId;
  final String status;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? rejectedBy;
  final DateTime? rejectedAt;
  final String? rejectionReason;
  final String? reviewRequestedBy;
  final DateTime? reviewRequestedAt;
  final String? reviewNote;

  bool get approved => status == 'approved';
  bool get rejected => status == 'rejected';

  String get displayStatus => switch (status) {
        'approved' => 'Approved',
        'rejected' => 'Rejected',
        'underReview' => 'Under Review',
        'correctionRequested' => 'Correction Requested',
        'corrected' => 'Corrected',
        'resubmitted' => 'Resubmitted',
        'closed' => 'Closed',
        'working' => 'Working',
        _ => 'Pending',
      };
}

final class TimesheetApprovalService {
  const TimesheetApprovalService();

  Future<Map<String, TimesheetApprovalStamp>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(supervisorCenterStorageKey);
    if (raw == null || raw.trim().isEmpty) return const {};

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      final state = Map<String, dynamic>.from(decoded);
      final items = state['timeEntries'];
      if (items is! List) return const {};

      final result = <String, TimesheetApprovalStamp>{};
      for (final item in items) {
        if (item is! Map) continue;
        final json = Map<String, dynamic>.from(item);
        final id = json['id']?.toString().trim() ?? '';
        if (id.isEmpty) continue;
        result[id] = TimesheetApprovalStamp(
          entryId: id,
          status: json['status']?.toString() ?? 'pending',
          approvedBy: _text(json['approvedBy']),
          approvedAt: _date(json['approvedAt']),
          rejectedBy: _text(json['rejectedBy']),
          rejectedAt: _date(json['rejectedAt']),
          rejectionReason: _text(json['rejectionReason']),
          reviewRequestedBy: _text(json['reviewRequestedBy']),
          reviewRequestedAt: _date(json['reviewRequestedAt']),
          reviewNote: _text(json['reviewNote']),
        );
      }
      return result;
    } on Object {
      return const {};
    }
  }
}

String approvalEntryId(String workDayId, String segmentId) =>
    'field-$workDayId-$segmentId';

String? _text(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

DateTime? _date(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : DateTime.tryParse(text);
}
