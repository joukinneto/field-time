import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:jkdd_field_time_records_production/core/theme/app_assets.dart';
import 'package:jkdd_field_time_records_production/src/domain/field_time_models.dart';
import 'package:jkdd_field_time_records_production/src/localization/app_language.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

final class TimesheetWeek {
  const TimesheetWeek({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  bool contains(DateTime value) {
    final day = DateTime(value.year, value.month, value.day);
    return !day.isBefore(start) && !day.isAfter(end);
  }
}

final class TimesheetPdfService {
  const TimesheetPdfService();

  TimesheetWeek weekFor(DateTime value) {
    final day = DateTime(value.year, value.month, value.day);
    final start = day.subtract(Duration(days: day.weekday - 1));
    return TimesheetWeek(start: start, end: start.add(const Duration(days: 6)));
  }

  double decimalHours(Duration duration) => duration.inMinutes / 60;

  String decimalHoursText(Duration duration) =>
      '${decimalHours(duration).toStringAsFixed(2)} h';

  Future<Uint8List> buildWeeklyTimesheetPdf({
    required FieldTimeSnapshot snapshot,
    required DateTime anchorDate,
    AppLanguage language = AppLanguage.en,
    String? employerName,
  }) async {
    const strings = AppStrings(AppLanguage.en);
    final week = weekFor(anchorDate);
    final days = snapshot.workDays
        .where((day) => week.contains(day.workDate))
        .toList(growable: false)
      ..sort((left, right) => left.workDate.compareTo(right.workDate));
    final receipts = snapshot.receipts.where((receipt) {
      final linkedJob = snapshot.jobs.any((job) => job.id == receipt.jobId);
      return linkedJob && week.contains(receipt.purchaseDate);
    }).toList(growable: false);
    final totalDuration = days.fold<Duration>(
      Duration.zero,
      (total, day) => total + day.workedDuration,
    );
    final bonusMinutes = days.fold<int>(
      0,
      (total, day) => total + (day.travelBonusHours * 60).round(),
    );
    final totalWithBonus = totalDuration + Duration(minutes: bonusMinutes);
    final document = pw.Document(title: strings.t('pdf.title'));
    final logoBytes = await _loadLogoBytes();
    final timesheetRegistrationNumbers = days
        .map((day) => day.registrationNumber)
        .where((value) => value.trim().isNotEmpty)
        .toList(growable: false);

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          _header(snapshot, week, employerName, strings, logoBytes,
              timesheetRegistrationNumbers),
          pw.SizedBox(height: 14),
          _recordsTable(days, strings),
          pw.SizedBox(height: 12),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Total Worked Hours: ${decimalHoursText(totalDuration)}',
            ),
          ),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Total Travel Bonus: '
              '${decimalHoursText(Duration(minutes: bonusMinutes))}',
            ),
          ),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Grand Total: ${decimalHoursText(totalWithBonus)}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
            ),
          ),
        ],
      ),
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Text(strings.t('pdf.receiptsSummary'),
              style:
                  pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          if (receipts.isEmpty)
            pw.Text(strings.t('pdf.noLinkedReceipts'))
          else
            _receiptsTable(snapshot, receipts, strings),
        ],
      ),
    );

    for (final receipt in receipts) {
      final attachments = snapshot.attachments.where(
        (attachment) =>
            receipt.attachmentIds.contains(attachment.id) &&
            attachment.kind == AttachmentKind.receipt,
      );
      if (attachments.isEmpty) continue;
      for (final attachment in attachments) {
        document.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.letter,
            margin: const pw.EdgeInsets.all(24),
            build: (context) =>
                _receiptPhotoPage(snapshot, receipt, attachment, strings),
          ),
        );
      }
    }

    return document.save();
  }

  pw.Widget _header(
    FieldTimeSnapshot snapshot,
    TimesheetWeek week,
    String? employerName,
    AppStrings strings,
    Uint8List? logoBytes,
    List<String> timesheetRegistrationNumbers,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.blueGrey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          logoBytes == null
              ? pw.Container(
                  width: 90,
                  height: 44,
                  alignment: pw.Alignment.center,
                  color: PdfColors.blueGrey900,
                  child: pw.Text(
                    'FIELD TIME',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                )
              : pw.Image(
                  pw.MemoryImage(logoBytes),
                  width: 128,
                  height: 46,
                  fit: pw.BoxFit.contain,
                ),
          pw.SizedBox(width: 16),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'FIELD TIME',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text('BY JKDD TECH'),
                pw.SizedBox(height: 6),
                pw.Text('Contracting Company:'),
                pw.Text(employerName?.trim().isNotEmpty == true
                    ? employerName!.trim()
                    : snapshot.companyName),
                pw.Text('Subcontractor:'),
                pw.Text(snapshot.subcontractor.displayName),
                pw.Text('Responsible:'),
                pw.Text(snapshot.worker.displayName),
                pw.Text('Reporting Period: ${_date(week.start)} to '
                    '${_date(week.end)}'),
                if (timesheetRegistrationNumbers.isNotEmpty)
                  pw.Text('Timesheet Registration Number: '
                      '${timesheetRegistrationNumbers.join(', ')}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _recordsTable(List<WorkDay> days, AppStrings strings) {
    final rows = <List<String>>[];
    for (final day in days) {
      for (final segment in day.segments) {
        rows.add([
          _date(day.workDate),
          _weekDay(day.workDate),
          '${segment.jobNumber} - ${segment.jobName}',
          segment.jobAddress,
          _time(segment.startedAt),
          segment.endedAt == null ? '--:--' : _time(segment.endedAt!),
          _duration(segment.duration()),
          '',
          _duration(segment.duration()),
          segment.notes ?? '',
        ]);
      }
      for (final segment in _bonusSegments(day)) {
        final bonusDuration =
            Duration(minutes: (segment.travelBonusHours * 60).round());
        rows.add([
          _date(day.workDate),
          _weekDay(day.workDate),
          '${segment.jobNumber} - ${segment.jobName}',
          segment.jobAddress,
          '',
          '',
          '00:00',
          _duration(bonusDuration),
          _duration(bonusDuration),
          'Travel Bonus',
        ]);
      }
    }
    return pw.TableHelper.fromTextArray(
      headers: [
        'Date',
        'Week Day',
        'Job',
        'Location',
        'Time In',
        'Time Out',
        'Worked Hours',
        'Travel Bonus',
        'Total Hours',
        'Observations',
      ],
      data: rows.isEmpty
          ? [
              [
                '-',
                '-',
                '-',
                '-',
                '-',
                '-',
                '00:00',
                '00:00',
                '00:00',
                strings.t('pdf.noRecords')
              ],
            ]
          : rows,
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey100),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellAlignment: pw.Alignment.centerLeft,
      columnWidths: const {
        0: pw.FixedColumnWidth(54),
        1: pw.FixedColumnWidth(54),
        4: pw.FixedColumnWidth(40),
        5: pw.FixedColumnWidth(40),
        6: pw.FixedColumnWidth(54),
        7: pw.FixedColumnWidth(54),
        8: pw.FixedColumnWidth(54),
      },
    );
  }

  pw.Widget _receiptsTable(
    FieldTimeSnapshot snapshot,
    List<Receipt> receipts,
    AppStrings strings,
  ) {
    return pw.TableHelper.fromTextArray(
      headers: [
        'Registration Number',
        strings.t('receipts.date'),
        strings.t('receipts.amount'),
        strings.t('receipts.merchant'),
        strings.t('timesheet.job'),
        strings.t('jobs.address'),
        strings.t('receipts.category'),
        strings.t('home.subcontractor'),
        strings.t('receipts.observation'),
      ],
      data: [
        for (final receipt in receipts)
          [
            receipt.registrationNumber,
            _date(receipt.purchaseDate),
            '\$${receipt.total.toStringAsFixed(2)}',
            receipt.merchant,
            _jobLabel(snapshot, receipt.jobId),
            _jobAddress(snapshot, receipt.jobId),
            receipt.description,
            snapshot.worker.displayName,
            receipt.notes ?? '',
          ],
      ],
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey100),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellAlignment: pw.Alignment.centerLeft,
    );
  }

  pw.Widget _receiptPhotoPage(
    FieldTimeSnapshot snapshot,
    Receipt receipt,
    Attachment attachment,
    AppStrings strings,
  ) {
    final bytes = base64Decode(attachment.dataBase64);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(strings.t('pdf.receipt', {'merchant': receipt.merchant}),
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        if (receipt.registrationNumber.isNotEmpty)
          pw.Text('Registration Number: ${receipt.registrationNumber}'),
        pw.Text(
          '${_date(receipt.purchaseDate)} - ${_jobLabel(snapshot, receipt.jobId)} - '
          '${snapshot.worker.displayName}',
        ),
        pw.Text(
          '${strings.t('jobs.address')}: ${_jobAddress(snapshot, receipt.jobId)}',
        ),
        pw.Text('${strings.t('receipts.category')}: ${receipt.description}'),
        if (receipt.notes?.trim().isNotEmpty == true)
          pw.Text('${strings.t('receipts.observation')}: ${receipt.notes}'),
        pw.SizedBox(height: 12),
        pw.Expanded(
          child: pw.Center(
            child: pw.Image(
              pw.MemoryImage(bytes),
              fit: pw.BoxFit.contain,
            ),
          ),
        ),
      ],
    );
  }
}

Future<Uint8List?> _loadLogoBytes() async {
  try {
    final data = await rootBundle.load(AppAssets.fieldTimeLogoHorizontal);
    return data.buffer.asUint8List();
  } catch (_) {
    return null;
  }
}

List<WorkSegment> _bonusSegments(WorkDay day) {
  final byJob = <String, WorkSegment>{};
  for (final segment in day.segments) {
    if (segment.travelBonusHours <= 0) continue;
    final current = byJob[segment.jobId];
    if (current == null ||
        current.travelBonusHours < segment.travelBonusHours) {
      byJob[segment.jobId] = segment;
    }
  }
  return byJob.values.toList(growable: false)
    ..sort((left, right) => left.jobNumber.compareTo(right.jobNumber));
}

String _jobLabel(FieldTimeSnapshot snapshot, String jobId) {
  final job = snapshot.jobs.firstWhere((job) => job.id == jobId);
  return '${job.number} - ${job.name}';
}

String _jobAddress(FieldTimeSnapshot snapshot, String jobId) {
  final job = snapshot.jobs.firstWhere((job) => job.id == jobId);
  return job.address;
}

String _date(DateTime value) => '${value.month.toString().padLeft(2, '0')}/'
    '${value.day.toString().padLeft(2, '0')}/${value.year}';

String _weekDay(DateTime value) => switch (value.weekday) {
      DateTime.monday => 'Monday',
      DateTime.tuesday => 'Tuesday',
      DateTime.wednesday => 'Wednesday',
      DateTime.thursday => 'Thursday',
      DateTime.friday => 'Friday',
      DateTime.saturday => 'Saturday',
      DateTime.sunday => 'Sunday',
      _ => '',
    };

String _time(DateTime value) => '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';

String _duration(Duration duration) =>
    '${duration.inHours.toString().padLeft(2, '0')}:'
    '${duration.inMinutes.remainder(60).toString().padLeft(2, '0')}';
