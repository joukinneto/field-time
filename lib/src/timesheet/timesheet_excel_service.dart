import 'package:excel/excel.dart';
import 'package:jkdd_field_time_records_production/src/domain/field_time_models.dart';

final class TimesheetExcelService {
  const TimesheetExcelService();

  List<int> build({
    required FieldTimeSnapshot snapshot,
    required List<WorkDay> days,
  }) {
    final excel = Excel.createExcel();
    final sheet = excel['Timesheet'];
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    sheet.appendRow([
      TextCellValue('Colaborador'),
      TextCellValue('Data'),
      TextCellValue('Obra'),
      TextCellValue('Endereço'),
      TextCellValue('Entrada'),
      TextCellValue('Saída'),
      TextCellValue('Horas regulares'),
      TextCellValue('Bônus de viagem'),
      TextCellValue('Adicional salarial'),
      TextCellValue('Total de horas'),
      TextCellValue('Observações'),
    ]);

    for (final day in days) {
      for (final segment in day.segments) {
        final regular = segment.regularHours();
        final bonus = segment.travelBonusHours;
        sheet.appendRow([
          TextCellValue(snapshot.worker.displayName),
          TextCellValue(_date(day.workDate)),
          TextCellValue(segment.jobNumber),
          TextCellValue(segment.jobAddress),
          TextCellValue(_time(segment.startedAt)),
          TextCellValue(segment.endedAt == null ? '' : _time(segment.endedAt!)),
          DoubleCellValue(regular),
          DoubleCellValue(bonus),
          TextCellValue(_premium(segment)),
          DoubleCellValue(regular + bonus),
          TextCellValue(segment.notes ?? ''),
        ]);
      }
    }

    final encoded = excel.encode();
    if (encoded == null) {
      throw StateError('Não foi possível gerar o arquivo Excel.');
    }
    return encoded;
  }

  String _premium(WorkSegment segment) {
    if (!segment.hasPayPremium) return '';
    return switch (segment.payPremiumType) {
      PayPremiumType.percentage =>
        '${segment.payPremiumValue.toStringAsFixed(0)}%',
      PayPremiumType.fixedHourly =>
        '\$${segment.payPremiumValue.toStringAsFixed(2)}/h',
      PayPremiumType.doubleTime => 'Double time',
      null => segment.payPremiumValue.toStringAsFixed(2),
    };
  }

  String _date(DateTime value) =>
      '${value.month.toString().padLeft(2, '0')}/${value.day.toString().padLeft(2, '0')}/${value.year}';

  String _time(DateTime value) {
    final hour = value.hour == 0
        ? 12
        : (value.hour > 12 ? value.hour - 12 : value.hour);
    final minute = value.minute.toString().padLeft(2, '0');
    final suffix = value.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }
}
