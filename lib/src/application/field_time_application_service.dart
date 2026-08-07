import 'package:jkdd_field_time_records_production/src/domain/field_time_models.dart';
import 'package:jkdd_field_time_records_production/src/domain/registration_number.dart';
import 'package:jkdd_field_time_records_production/src/domain/receipt_extraction_service.dart';
import 'package:jkdd_field_time_records_production/src/domain/value_objects/geo_point.dart';
import 'package:uuid/uuid.dart';

final class FieldTimeApplicationService {
  const FieldTimeApplicationService({
    this.uuid = const Uuid(),
    this.receiptExtractionService = const MockReceiptExtractionService(),
  });

  final Uuid uuid;
  final ReceiptExtractionService receiptExtractionService;

  FieldTimeSnapshot clockIn({
    required FieldTimeSnapshot snapshot,
    required Job job,
    required DateTime at,
    required GeoPoint location,
    String? notes,
  }) {
    if (snapshot.activeWorkDay != null) {
      throw StateError('fieldTime.openPeriodExists');
    }
    final segment = _newSegment(snapshot, job, at, location, notes);
    final previousSameDay = _lastSameDay(snapshot, at);
    if (previousSameDay != null) {
      final reopened = previousSameDay.copyWith(
        status: WorkDayStatus.open,
        clearCompletedAt: true,
        updatedAt: at,
        segments: [...previousSameDay.segments, segment],
      );
      return snapshot.copyWith(
        workDays: _replaceDay(snapshot.workDays, reopened),
        syncQueue: [
          ...snapshot.syncQueue,
          _queue(snapshot, 'WorkDay', reopened.id, SyncOperation.update, at),
          _queue(snapshot, 'WorkSegment', segment.id, SyncOperation.create, at),
        ],
      );
    }
    final timesheetSequence = _nextRegistrationSequence(
      snapshot,
      RegistrationRecordType.timesheet,
      snapshot.workDays.map((day) => day.registrationNumber),
    );
    final day = WorkDay(
      id: uuid.v7(),
      registrationNumber: RegistrationNumberPolicy.format(
        RegistrationRecordType.timesheet,
        timesheetSequence,
      ),
      companyId: snapshot.companyId,
      subcontractorCompanyId: snapshot.subcontractor.id,
      workerId: snapshot.worker.id,
      workDate: DateTime(at.year, at.month, at.day),
      status: WorkDayStatus.open,
      segments: [segment],
      createdAt: at,
      updatedAt: at,
    );
    return snapshot.copyWith(
      workDays: [...snapshot.workDays, day],
      registrationSequences: _withRegistrationSequence(
        snapshot,
        RegistrationRecordType.timesheet,
        timesheetSequence,
      ),
      syncQueue: [
        ...snapshot.syncQueue,
        _queue(snapshot, 'WorkDay', day.id, SyncOperation.create, at),
      ],
    );
  }

  FieldTimeSnapshot switchJob({
    required FieldTimeSnapshot snapshot,
    required Job nextJob,
    required DateTime at,
    required GeoPoint location,
    String? notes,
  }) {
    final activeDay = snapshot.activeWorkDay;
    final activeSegment = activeDay?.openSegment;
    if (activeDay == null || activeSegment == null) {
      throw StateError('fieldTime.clockInBeforeSwitchJob');
    }
    if (activeSegment.jobId == nextJob.id) {
      throw StateError('fieldTime.selectDifferentJob');
    }
    if (at.isBefore(activeSegment.startedAt)) {
      throw StateError('fieldTime.invalidSwitchTime');
    }
    final closed = activeSegment.close(at, location, notes: notes);
    final next = _newSegment(snapshot, nextJob, at, location, null);
    final segments = [
      for (final segment in activeDay.segments)
        if (segment.id == activeSegment.id) closed else segment,
      next,
    ];
    final updated = activeDay.copyWith(segments: segments, updatedAt: at);
    return snapshot.copyWith(
      workDays: _replaceDay(snapshot.workDays, updated),
      syncQueue: [
        ...snapshot.syncQueue,
        _queue(snapshot, 'WorkSegment', closed.id, SyncOperation.update, at),
        _queue(snapshot, 'WorkSegment', next.id, SyncOperation.create, at),
      ],
    );
  }

  FieldTimeSnapshot endDay({
    required FieldTimeSnapshot snapshot,
    required DateTime at,
    required GeoPoint location,
    String? notes,
  }) {
    final activeDay = snapshot.activeWorkDay;
    final activeSegment = activeDay?.openSegment;
    if (activeDay == null || activeSegment == null) {
      throw StateError('fieldTime.noOpenWorkday');
    }
    if (at.isBefore(activeSegment.startedAt)) {
      throw StateError('fieldTime.invalidClockOutTime');
    }
    final closed = activeSegment.close(at, location, notes: notes);
    final updated = activeDay.copyWith(
      status: WorkDayStatus.completed,
      completedAt: at,
      notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
      updatedAt: at,
      segments: [
        for (final segment in activeDay.segments)
          if (segment.id == activeSegment.id) closed else segment,
      ],
    );
    return snapshot.copyWith(
      workDays: _replaceDay(snapshot.workDays, updated),
      syncQueue: [
        ...snapshot.syncQueue,
        _queue(snapshot, 'WorkDay', updated.id, SyncOperation.update, at),
      ],
    );
  }

  Future<FieldTimeSnapshot> saveReceipt({
    required FieldTimeSnapshot snapshot,
    required Job job,
    required Attachment attachment,
    required String merchant,
    required DateTime purchaseDate,
    required double total,
    required double tax,
    required String description,
    required bool submit,
    required bool userReviewed,
    String? receiptNumber,
    String? notes,
  }) async {
    if (submit && !userReviewed) {
      throw StateError('fieldTime.confirmReceiptBeforeSubmit');
    }
    if (merchant.trim().isEmpty || description.trim().isEmpty || total < 0) {
      throw StateError('fieldTime.invalidReceiptFields');
    }
    final now = DateTime.now();
    final receiptId = uuid.v7();
    final receiptSequence = _nextRegistrationSequence(
      snapshot,
      RegistrationRecordType.receipt,
      snapshot.receipts.map((receipt) => receipt.registrationNumber),
    );
    final reimbursementSequence = _nextRegistrationSequence(
      snapshot,
      RegistrationRecordType.reimbursement,
      snapshot.reimbursements.map((item) => item.registrationNumber),
    );
    final extraction = await receiptExtractionService.extract(
      receiptId: receiptId,
      companyId: snapshot.companyId,
      subcontractorCompanyId: snapshot.subcontractor.id,
      attachment: attachment,
    );
    final status = submit ? ReceiptStatus.submitted : ReceiptStatus.draft;
    final receiptRegistrationNumber = RegistrationNumberPolicy.format(
      RegistrationRecordType.receipt,
      receiptSequence,
    );
    final reimbursementRegistrationNumber = RegistrationNumberPolicy.format(
      RegistrationRecordType.reimbursement,
      reimbursementSequence,
    );
    if (snapshot.receipts.any(
          (receipt) => receipt.registrationNumber == receiptRegistrationNumber,
        ) ||
        snapshot.reimbursements.any(
          (item) => item.registrationNumber == reimbursementRegistrationNumber,
        )) {
      throw StateError('fieldTime.duplicateRegistration');
    }
    final receipt = Receipt(
      id: receiptId,
      registrationNumber: receiptRegistrationNumber,
      companyId: snapshot.companyId,
      subcontractorCompanyId: snapshot.subcontractor.id,
      workerId: snapshot.worker.id,
      jobId: job.id,
      purchaseDate: purchaseDate,
      merchant: merchant.trim(),
      total: total,
      tax: tax,
      receiptNumber: receiptNumber?.trim().isEmpty == true
          ? null
          : receiptNumber?.trim(),
      description: description.trim(),
      notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
      status: status,
      attachmentIds: [attachment.id],
      extractionResult: extraction,
      userReviewed: userReviewed,
      createdAt: now,
      updatedAt: now,
    );
    final reimbursement = ReimbursementRequest(
      id: uuid.v7(),
      registrationNumber: reimbursementRegistrationNumber,
      companyId: snapshot.companyId,
      subcontractorCompanyId: snapshot.subcontractor.id,
      workerId: snapshot.worker.id,
      jobId: job.id,
      receiptIds: [receipt.id],
      attachmentIds: [attachment.id],
      amount: total,
      status: status,
      createdAt: now,
      updatedAt: now,
    );
    final approval = Approval(
      id: uuid.v7(),
      companyId: snapshot.companyId,
      subcontractorCompanyId: snapshot.subcontractor.id,
      subjectId: reimbursement.id,
      status: ApprovalStatus.pending,
      createdAt: now,
    );
    return snapshot.copyWith(
      attachments: [...snapshot.attachments, attachment],
      receipts: [...snapshot.receipts, receipt],
      reimbursements: [...snapshot.reimbursements, reimbursement],
      approvals: [...snapshot.approvals, approval],
      registrationSequences: _withRegistrationSequence(
        snapshot.copyWith(
          registrationSequences: _withRegistrationSequence(
            snapshot,
            RegistrationRecordType.receipt,
            receiptSequence,
          ),
        ),
        RegistrationRecordType.reimbursement,
        reimbursementSequence,
      ),
      syncQueue: [
        ...snapshot.syncQueue,
        _queue(snapshot, 'Receipt', receipt.id, SyncOperation.create, now),
        _queue(
          snapshot,
          'ReimbursementRequest',
          reimbursement.id,
          SyncOperation.create,
          now,
        ),
      ],
    );
  }

  FieldTimeSnapshot addJobPhoto({
    required FieldTimeSnapshot snapshot,
    required Attachment attachment,
  }) {
    final now = DateTime.now();
    return snapshot.copyWith(
      attachments: [...snapshot.attachments, attachment],
      syncQueue: [
        ...snapshot.syncQueue,
        _queue(
          snapshot,
          'Attachment',
          attachment.id,
          SyncOperation.create,
          now,
        ),
      ],
    );
  }

  FieldTimeSnapshot addObservation({
    required FieldTimeSnapshot snapshot,
    required String notes,
    required DateTime at,
  }) {
    final activeDay = snapshot.activeWorkDay;
    final activeSegment = activeDay?.openSegment;
    if (activeDay == null || activeSegment == null) {
      throw StateError('fieldTime.clockInBeforeObservation');
    }
    if (notes.trim().isEmpty) {
      throw StateError('fieldTime.typeObservation');
    }
    final updatedSegment = activeSegment.withNotes(notes);
    final updatedDay = activeDay.copyWith(
      updatedAt: at,
      segments: [
        for (final segment in activeDay.segments)
          if (segment.id == activeSegment.id) updatedSegment else segment,
      ],
    );
    return snapshot.copyWith(
      workDays: _replaceDay(snapshot.workDays, updatedDay),
      syncQueue: [
        ...snapshot.syncQueue,
        _queue(
          snapshot,
          'WorkSegment',
          updatedSegment.id,
          SyncOperation.update,
          at,
        ),
      ],
    );
  }

  List<WorkDay> timesheet(
    FieldTimeSnapshot snapshot,
    TimesheetPeriod period,
    DateTime now,
  ) {
    final start = switch (period) {
      TimesheetPeriod.today => DateTime(now.year, now.month, now.day),
      TimesheetPeriod.week => DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: now.weekday - 1)),
      TimesheetPeriod.month => DateTime(now.year, now.month),
      TimesheetPeriod.year => DateTime(now.year),
    };
    final end = switch (period) {
      TimesheetPeriod.today => start.add(const Duration(days: 1)),
      TimesheetPeriod.week => start.add(const Duration(days: 7)),
      TimesheetPeriod.month => DateTime(now.year, now.month + 1),
      TimesheetPeriod.year => DateTime(now.year + 1),
    };
    return snapshot.workDays
        .where(
          (day) =>
              day.workerId == snapshot.worker.id &&
              !day.workDate.isBefore(start) &&
              day.workDate.isBefore(end),
        )
        .toList(growable: false)
      ..sort((left, right) => right.workDate.compareTo(left.workDate));
  }

  WorkSegment _newSegment(
    FieldTimeSnapshot snapshot,
    Job job,
    DateTime at,
    GeoPoint location,
    String? notes,
  ) => WorkSegment(
    id: uuid.v7(),
    companyId: snapshot.companyId,
    subcontractorCompanyId: snapshot.subcontractor.id,
    workerId: snapshot.worker.id,
    jobId: job.id,
    jobNumber: job.number,
    jobName: job.name,
    jobAddress: job.address,
    startedAt: at,
    startedLocation: location,
    notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
    laborType: snapshot.worker.laborType,
    travelBonusHours: job.travelBonusHours,
    travelBonusEnabled: job.hasTravelBonus,
    payPremiumEnabled: job.hasPayPremium,
    payPremiumType: job.payPremiumType,
    payPremiumValue: job.payPremiumValue,
    jobLatitude: job.latitude,
    jobLongitude: job.longitude,
  );

  WorkDay? _lastSameDay(FieldTimeSnapshot snapshot, DateTime at) {
    final date = DateTime(at.year, at.month, at.day);
    for (final day in snapshot.workDays.reversed) {
      if (day.workerId == snapshot.worker.id &&
          day.workDate == date &&
          day.status == WorkDayStatus.completed) {
        return day;
      }
    }
    return null;
  }

  int _nextRegistrationSequence(
    FieldTimeSnapshot snapshot,
    RegistrationRecordType type,
    Iterable<String?> existingNumbers,
  ) {
    final stored = snapshot.registrationSequences[type.prefix] ?? 0;
    final existing = RegistrationNumberPolicy.maxSequenceFor(
      type,
      existingNumbers,
    );
    final max = stored > existing ? stored : existing;
    return max + 1;
  }

  Map<String, int> _withRegistrationSequence(
    FieldTimeSnapshot snapshot,
    RegistrationRecordType type,
    int sequence,
  ) {
    final current = snapshot.registrationSequences[type.prefix] ?? 0;
    return {
      ...snapshot.registrationSequences,
      type.prefix: sequence > current ? sequence : current,
    };
  }

  List<WorkDay> _replaceDay(List<WorkDay> days, WorkDay replacement) => [
    for (final day in days)
      if (day.id == replacement.id) replacement else day,
  ];

  SyncQueueItem _queue(
    FieldTimeSnapshot snapshot,
    String entityType,
    String entityId,
    SyncOperation operation,
    DateTime at,
  ) => SyncQueueItem(
    id: uuid.v7(),
    companyId: snapshot.companyId,
    subcontractorCompanyId: snapshot.subcontractor.id,
    entityType: entityType,
    entityId: entityId,
    operation: operation,
    createdAt: at,
  );
}
