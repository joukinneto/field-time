import 'dart:convert';
import 'dart:typed_data';

import 'package:jkdd_field_time_records_production/src/domain/field_time_models.dart';
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
    String? employerName,
  }) async {
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
    final document = pw.Document(title: 'Field Time Timesheet');

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          _header(snapshot, week, employerName),
          pw.SizedBox(height: 14),
          _recordsTable(days),
          pw.SizedBox(height: 12),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Total geral: ${decimalHoursText(totalWithBonus)}',
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
          pw.Text('Resumo dos recibos',
              style:
                  pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          if (receipts.isEmpty)
            pw.Text('Nenhum recibo vinculado a obra nesta semana.')
          else
            _receiptsTable(snapshot, receipts),
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
                _receiptPhotoPage(snapshot, receipt, attachment),
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
          pw.Container(
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
          ),
          pw.SizedBox(width: 16),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  employerName?.trim().isNotEmpty == true
                      ? employerName!.trim()
                      : snapshot.companyName,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text('Colaborador: ${snapshot.worker.displayName}'),
                pw.Text('Periodo: ${_date(week.start)} ate ${_date(week.end)}'),
                pw.Text('Semana: segunda-feira a domingo'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _recordsTable(List<WorkDay> days) {
    final rows = <List<String>>[];
    for (final day in days) {
      for (final segment in day.segments) {
        rows.add([
          _date(day.workDate),
          segment.jobNumber,
          segment.jobName,
          segment.jobAddress,
          _time(segment.startedAt),
          segment.endedAt == null ? '--:--' : _time(segment.endedAt!),
          _duration(segment.duration()),
          segment.notes ?? '',
        ]);
      }
    }
    return pw.TableHelper.fromTextArray(
      headers: const [
        'Data',
        'Obra',
        'Nome',
        'Endereco',
        'Entrada',
        'Saida',
        'Total do dia',
        'Obs.',
      ],
      data: rows.isEmpty
          ? const [
              ['-', '-', '-', '-', '-', '-', '00:00', 'Sem registros'],
            ]
          : rows,
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey100),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellAlignment: pw.Alignment.centerLeft,
      columnWidths: const {
        0: pw.FixedColumnWidth(54),
        1: pw.FixedColumnWidth(42),
        4: pw.FixedColumnWidth(40),
        5: pw.FixedColumnWidth(40),
        6: pw.FixedColumnWidth(54),
      },
    );
  }

  pw.Widget _receiptsTable(FieldTimeSnapshot snapshot, List<Receipt> receipts) {
    return pw.TableHelper.fromTextArray(
      headers: const [
        'Data',
        'Valor',
        'Estabelecimento',
        'Obra',
        'Endereco',
        'Categoria',
        'Colaborador',
        'Observacao',
      ],
      data: [
        for (final receipt in receipts)
          [
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
  ) {
    final bytes = base64Decode(attachment.dataBase64);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Recibo - ${receipt.merchant}',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Text(
          '${_date(receipt.purchaseDate)} - ${_jobLabel(snapshot, receipt.jobId)} - '
          '${snapshot.worker.displayName}',
        ),
        pw.Text('Endereco: ${_jobAddress(snapshot, receipt.jobId)}'),
        pw.Text('Categoria: ${receipt.description}'),
        if (receipt.notes?.trim().isNotEmpty == true)
          pw.Text('Observacao: ${receipt.notes}'),
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

String _time(DateTime value) => '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';

String _duration(Duration duration) =>
    '${duration.inHours.toString().padLeft(2, '0')}:'
    '${duration.inMinutes.remainder(60).toString().padLeft(2, '0')}';
