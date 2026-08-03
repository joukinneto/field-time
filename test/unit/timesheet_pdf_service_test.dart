import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jkdd_field_time_records_production/time_records.dart';

void main() {
  const service = TimesheetPdfService();

  test('week starts Monday and ends Sunday', () {
    final week = service.weekFor(DateTime(2026, 8, 5));

    expect(week.start, DateTime(2026, 8, 3));
    expect(week.end, DateTime(2026, 8, 9));
  });

  test('minute conversion uses decimal hours for grand total', () {
    expect(service.decimalHours(const Duration(minutes: 30)), 0.5);
    expect(service.decimalHours(const Duration(minutes: 15)), 0.25);
    expect(service.decimalHours(const Duration(minutes: 45)), 0.75);
    expect(service.decimalHoursText(const Duration(hours: 42, minutes: 30)),
        '42.50 h');
  });

  test('generates a PDF without wage or salary labels', () async {
    var snapshot = FieldTimeSnapshot.seeded();
    const appService = FieldTimeApplicationService();
    final location = GeoPoint(
      latitude: 26.36,
      longitude: -80.12,
      accuracyMeters: 8,
      capturedAt: DateTime.utc(2026, 8, 3, 8),
    );
    snapshot = appService.clockIn(
      snapshot: snapshot,
      job: snapshot.jobs.first,
      at: DateTime.utc(2026, 8, 3, 8),
      location: location,
    );
    snapshot = appService.endDay(
      snapshot: snapshot,
      at: DateTime.utc(2026, 8, 3, 17, 30),
      location: location,
    );

    final bytes = await service.buildWeeklyTimesheetPdf(
      snapshot: snapshot,
      anchorDate: DateTime(2026, 8, 5),
    );
    final text = String.fromCharCodes(bytes);

    expect(
        bytes.take(4).map((byte) => String.fromCharCode(byte)).join(), '%PDF');
    expect(text.contains('hourly rate'), isFalse);
    expect(text.contains('salary'), isFalse);
    expect(text.contains('total payment'), isFalse);
  });

  test('includes linked weekly receipt attachments in the generated PDF',
      () async {
    var snapshot = FieldTimeSnapshot.seeded();
    final job = snapshot.jobs.first;
    final attachment = Attachment(
      id: 'receipt-photo-1',
      companyId: snapshot.companyId,
      subcontractorCompanyId: snapshot.subcontractor.id,
      workerId: snapshot.worker.id,
      jobId: job.id,
      kind: AttachmentKind.receipt,
      fileName: 'receipt.png',
      mimeType: 'image/png',
      dataBase64: base64Encode(base64Decode(_onePixelPngBase64)),
      createdAt: DateTime.utc(2026, 8, 3, 18),
    );
    final receipt = Receipt(
      id: 'receipt-1',
      companyId: snapshot.companyId,
      subcontractorCompanyId: snapshot.subcontractor.id,
      workerId: snapshot.worker.id,
      jobId: job.id,
      purchaseDate: DateTime.utc(2026, 8, 3),
      merchant: 'Supply Store',
      total: 18.75,
      tax: 0,
      description: 'Materials',
      status: ReceiptStatus.submitted,
      attachmentIds: [attachment.id],
      userReviewed: true,
      createdAt: DateTime.utc(2026, 8, 3, 18),
      updatedAt: DateTime.utc(2026, 8, 3, 18),
      notes: 'Linked receipt',
    );
    snapshot = snapshot.copyWith(
      receipts: [receipt],
      attachments: [attachment],
    );

    final bytes = await service.buildWeeklyTimesheetPdf(
      snapshot: snapshot,
      anchorDate: DateTime(2026, 8, 5),
    );

    expect(
        bytes.take(4).map((byte) => String.fromCharCode(byte)).join(), '%PDF');
    expect(bytes.length, greaterThan(2500));
  });
}

const _onePixelPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4//8/AAX+Av4N70a4AAAAAElFTkSuQmCC';
