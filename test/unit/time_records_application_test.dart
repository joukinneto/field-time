import 'package:flutter_test/flutter_test.dart';
import 'package:jkdd_field_time_records_production/time_records.dart';

void main() {
  const service = FieldTimeApplicationService();
  final location = GeoPoint(
    latitude: 26.3683,
    longitude: -80.1289,
    accuracyMeters: 8,
    capturedAt: DateTime.utc(2026, 8, 1, 8),
  );

  test('multiple jobs create separate segments without replacing history', () {
    var snapshot = _snapshotWithJobs();
    snapshot = service.clockIn(
      snapshot: snapshot,
      job: snapshot.jobs[0],
      at: DateTime.utc(2026, 8, 1, 8),
      location: location,
    );
    snapshot = service.switchJob(
      snapshot: snapshot,
      nextJob: snapshot.jobs[1],
      at: DateTime.utc(2026, 8, 1, 10),
      location: location,
    );
    snapshot = service.switchJob(
      snapshot: snapshot,
      nextJob: snapshot.jobs[2],
      at: DateTime.utc(2026, 8, 1, 12),
      location: location,
    );

    final day = snapshot.activeWorkDay!;
    expect(day.segments, hasLength(3));
    expect(day.segments.map((item) => item.jobId).toSet(), hasLength(3));
    expect(day.segments.where((item) => item.isOpen), hasLength(1));
    expect(day.segments[0].endedAt, DateTime.utc(2026, 8, 1, 10));
    expect(day.segments[1].endedAt, DateTime.utc(2026, 8, 1, 12));
  });

  test('end day closes final segment and calculates daily total', () {
    var snapshot = _snapshotWithJobs();
    snapshot = service.clockIn(
      snapshot: snapshot,
      job: snapshot.jobs[0],
      at: DateTime.utc(2026, 8, 1, 8),
      location: location,
    );
    snapshot = service.switchJob(
      snapshot: snapshot,
      nextJob: snapshot.jobs[1],
      at: DateTime.utc(2026, 8, 1, 10),
      location: location,
    );
    snapshot = service.endDay(
      snapshot: snapshot,
      at: DateTime.utc(2026, 8, 1, 17),
      location: location,
    );

    final day = snapshot.workDays.single;
    expect(day.status, WorkDayStatus.completed);
    expect(day.openSegment, isNull);
    expect(day.workedDuration, const Duration(hours: 9));
    expect(day.totalHours, 9);
  });

  test('weekly filter includes all days in current week', () {
    var snapshot = _snapshotWithJobs();
    for (final dayNumber in [3, 4]) {
      snapshot = service.clockIn(
        snapshot: snapshot,
        job: snapshot.jobs.first,
        at: DateTime.utc(2026, 8, dayNumber, 8),
        location: location,
      );
      snapshot = service.endDay(
        snapshot: snapshot,
        at: DateTime.utc(2026, 8, dayNumber, 16),
        location: location,
      );
    }

    final days =
        service.timesheet(snapshot, TimesheetPeriod.week, DateTime(2026, 8, 4));
    expect(days, hasLength(2));
    expect(
        days.fold<int>(0, (total, day) => total + day.workedDuration.inHours),
        16);
  });

  test('receipt is linked to job and creates reimbursement request', () async {
    final snapshot = _snapshotWithJobs();
    final job = snapshot.jobs.first;
    final attachment = Attachment(
      id: 'attachment-1',
      companyId: snapshot.companyId,
      subcontractorCompanyId: snapshot.subcontractor.id,
      workerId: snapshot.worker.id,
      jobId: job.id,
      kind: AttachmentKind.receipt,
      fileName: 'receipt.jpg',
      mimeType: 'image/jpeg',
      dataBase64: 'AA==',
      createdAt: DateTime.utc(2026, 8, 1),
    );

    final result = await service.saveReceipt(
      snapshot: snapshot,
      job: job,
      attachment: attachment,
      merchant: 'Store',
      purchaseDate: DateTime.utc(2026, 8, 1),
      total: 120,
      tax: 8,
      description: 'Materials',
      submit: true,
      userReviewed: true,
    );

    expect(result.receipts.single.jobId, job.id);
    expect(result.receipts.single.status, ReceiptStatus.submitted);
    expect(result.receipts.single.extractionResult!.hasExtractedData, isFalse);
    expect(result.reimbursements.single.receiptIds,
        contains(result.receipts.single.id));
    expect(result.reimbursements.single.amount, 120);
    expect(result.approvals.single.status, ApprovalStatus.pending);
  });
}

FieldTimeSnapshot _snapshotWithJobs() => FieldTimeSnapshot.seeded().copyWith(
      jobs: const [
        Job(
          id: 'job-1001',
          companyId: FieldTimeSnapshot.companyIdEww,
          subcontractorCompanyId: FieldTimeSnapshot.subcontractorIdJkdd,
          number: '1001',
          name: 'Imported Job 1001',
          address: 'Boca Raton, FL',
        ),
        Job(
          id: 'job-1002',
          companyId: FieldTimeSnapshot.companyIdEww,
          subcontractorCompanyId: FieldTimeSnapshot.subcontractorIdJkdd,
          number: '1002',
          name: 'Imported Job 1002',
          address: 'Delray Beach, FL',
        ),
        Job(
          id: 'job-1003',
          companyId: FieldTimeSnapshot.companyIdEww,
          subcontractorCompanyId: FieldTimeSnapshot.subcontractorIdJkdd,
          number: '1003',
          name: 'Imported Job 1003',
          address: 'Parkland, FL',
        ),
      ],
    );
