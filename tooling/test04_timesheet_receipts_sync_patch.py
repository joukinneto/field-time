from pathlib import Path

# 1) Add all-time timesheet period.
models = Path('lib/src/domain/field_time_models.dart')
text = models.read_text()
text = text.replace(
    'enum TimesheetPeriod { today, week, month, year }',
    'enum TimesheetPeriod { today, week, month, year, all }',
)
models.write_text(text)

service = Path('lib/src/application/field_time_application_service.dart')
text = service.read_text()
old = '''    final start = switch (period) {
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
'''
new = '''    final start = switch (period) {
      TimesheetPeriod.today => DateTime(now.year, now.month, now.day),
      TimesheetPeriod.week => DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: now.weekday - 1)),
      TimesheetPeriod.month => DateTime(now.year, now.month),
      TimesheetPeriod.year => DateTime(now.year),
      TimesheetPeriod.all => null,
    };
    final end = switch (period) {
      TimesheetPeriod.today => start!.add(const Duration(days: 1)),
      TimesheetPeriod.week => start!.add(const Duration(days: 7)),
      TimesheetPeriod.month => DateTime(now.year, now.month + 1),
      TimesheetPeriod.year => DateTime(now.year + 1),
      TimesheetPeriod.all => null,
    };
    return snapshot.workDays
        .where(
          (day) =>
              day.workerId == snapshot.worker.id &&
              (start == null || !day.workDate.isBefore(start)) &&
              (end == null || day.workDate.isBefore(end)),
        )
'''
if old not in text:
    raise SystemExit('timesheet period service block not found')
service.write_text(text.replace(old, new, 1))

# 2) Timesheet interactions, export choice, all period, and EWW no-break UI.
timesheet = Path('lib/src/presentation/screens/timesheet_screen.dart')
text = timesheet.read_text()
text = text.replace(
    "import 'package:jkdd_field_time_records_production/src/localization/app_language.dart';\n",
    "import 'package:jkdd_field_time_records_production/src/localization/app_language.dart';\n"
    "import 'package:jkdd_field_time_records_production/src/platform/file_download.dart';\n",
    1,
)
text = text.replace(
    "import 'package:jkdd_field_time_records_production/src/timesheet/timesheet_pdf_service.dart';\n",
    "import 'package:jkdd_field_time_records_production/src/timesheet/timesheet_pdf_service.dart';\n"
    "import 'package:jkdd_field_time_records_production/src/timesheet/timesheet_excel_service.dart';\n",
    1,
)
text = text.replace(
    "    const pdfService = TimesheetPdfService();\n",
    "    const pdfService = TimesheetPdfService();\n    const excelService = TimesheetExcelService();\n",
    1,
)
old_button = '''                      FilledButton.icon(
                        onPressed: () =>
                            _generatePdf(context, snapshot, pdfService, days),
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: Text(context.tr('timesheet.generateTimesheet')),
                      ),
'''
new_button = '''                      FilledButton.icon(
                        onPressed: () => _showExportMenu(
                          context,
                          snapshot,
                          pdfService,
                          excelService,
                          days,
                        ),
                        icon: const Icon(Icons.file_download_outlined),
                        label: Text(context.tr('timesheet.generateTimesheet')),
                      ),
'''
if old_button not in text:
    raise SystemExit('generate button not found')
text = text.replace(old_button, new_button, 1)

old_items = '''                    _TotalItem(
                      context.tr('timesheet.regularHours'),
                      _hours(regularHours),
                      Icons.schedule_outlined,
                      AppColors.blue,
                    ),
                    _TotalItem(
                      context.tr('timesheet.bonusHours'),
                      _hours(bonusHours),
                      Icons.route_outlined,
                      AppColors.teal,
                    ),
                    _TotalItem(
                      context.tr('timesheet.totalHours'),
                      _hours(regularHours + bonusHours),
                      Icons.access_time_filled,
                      AppColors.green,
                    ),
                    _TotalItem(
                      context.tr('timesheet.payPremium'),
                      segments
                          .where((item) => item.hasPayPremium)
                          .length
                          .toString(),
                      Icons.workspace_premium_outlined,
                      AppColors.purple,
                    ),
                    _TotalItem(
                      context.tr('timesheet.jobs'),
                      totalsByJob.length.toString(),
                      Icons.apartment_outlined,
                      AppColors.purple,
                    ),
'''
new_items = '''                    _TotalItem(
                      context.tr('timesheet.regularHours'),
                      _hours(regularHours),
                      Icons.schedule_outlined,
                      AppColors.blue,
                      () => _showMetricDetails(
                        context,
                        days,
                        _TimesheetMetric.regular,
                      ),
                    ),
                    _TotalItem(
                      context.tr('timesheet.bonusHours'),
                      _hours(bonusHours),
                      Icons.route_outlined,
                      AppColors.teal,
                      () => _showMetricDetails(
                        context,
                        days,
                        _TimesheetMetric.bonus,
                      ),
                    ),
                    _TotalItem(
                      context.tr('timesheet.totalHours'),
                      _hours(regularHours + bonusHours),
                      Icons.access_time_filled,
                      AppColors.green,
                      () => _showMetricDetails(
                        context,
                        days,
                        _TimesheetMetric.total,
                      ),
                    ),
                    _TotalItem(
                      context.tr('timesheet.payPremium'),
                      segments
                          .where((item) => item.hasPayPremium)
                          .length
                          .toString(),
                      Icons.workspace_premium_outlined,
                      AppColors.purple,
                      () => _showMetricDetails(
                        context,
                        days,
                        _TimesheetMetric.premium,
                      ),
                    ),
                    _TotalItem(
                      context.tr('timesheet.jobs'),
                      totalsByJob.length.toString(),
                      Icons.apartment_outlined,
                      AppColors.purple,
                      () => _showMetricDetails(
                        context,
                        days,
                        _TimesheetMetric.jobs,
                      ),
                    ),
'''
if old_items not in text:
    raise SystemExit('totals items block not found')
text = text.replace(old_items, new_items, 1)

marker = '''  Future<void> _generatePdf(
'''
insert = '''  Future<void> _showExportMenu(
    BuildContext context,
    FieldTimeSnapshot snapshot,
    TimesheetPdfService pdfService,
    TimesheetExcelService excelService,
    List<WorkDay> days,
  ) async {
    if (days.expand((day) => day.segments).isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('timesheet.noRecordsForPeriod'))),
      );
      return;
    }
    final format = await showModalBottomSheet<_TimesheetExportFormat>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Gerar Timesheet',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined),
                title: const Text('PDF'),
                subtitle: const Text('Visualizar, imprimir, compartilhar ou salvar.'),
                onTap: () => Navigator.pop(
                  context,
                  _TimesheetExportFormat.pdf,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.table_view_outlined),
                title: const Text('Excel'),
                subtitle: const Text('Planilha .xlsx para conferência e payroll.'),
                onTap: () => Navigator.pop(
                  context,
                  _TimesheetExportFormat.excel,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!context.mounted || format == null) return;
    if (format == _TimesheetExportFormat.pdf) {
      await _generatePdf(context, snapshot, pdfService, days);
    } else {
      await _generateExcel(context, snapshot, excelService, days);
    }
  }

  Future<void> _generateExcel(
    BuildContext context,
    FieldTimeSnapshot snapshot,
    TimesheetExcelService excelService,
    List<WorkDay> days,
  ) async {
    try {
      final bytes = excelService.build(snapshot: snapshot, days: days);
      final delivered = await downloadBytes(
        bytes: bytes,
        fileName: 'Field_Time_Timesheet_${snapshot.worker.displayName.replaceAll(' ', '_')}.xlsx',
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              delivered
                  ? 'Timesheet Excel gerado com sucesso.'
                  : 'Exportação Excel está disponível na versão Web/PWA.',
            ),
          ),
        );
      }
    } on Exception catch (error) {
      debugPrint('Timesheet Excel generation failed: $error');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível gerar o Excel.')),
        );
      }
    }
  }

  Future<void> _showMetricDetails(
    BuildContext context,
    List<WorkDay> days,
    _TimesheetMetric metric,
  ) async {
    final rows = <_TimesheetMetricRow>[];
    for (final day in days) {
      for (final segment in day.segments) {
        final value = switch (metric) {
          _TimesheetMetric.regular => segment.regularHours(),
          _TimesheetMetric.bonus => segment.travelBonusHours,
          _TimesheetMetric.total =>
            segment.regularHours() + segment.travelBonusHours,
          _TimesheetMetric.premium => segment.hasPayPremium ? 1.0 : 0.0,
          _TimesheetMetric.jobs => 1.0,
        };
        if (value > 0) {
          rows.add(
            _TimesheetMetricRow(
              date: day.workDate,
              jobNumber: segment.jobNumber,
              value: value,
              premium: segment.hasPayPremium,
            ),
          );
        }
      }
    }
    final maxValue = rows.fold<double>(
      0,
      (max, row) => row.value > max ? row.value : max,
    );
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.82,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              Text(
                _timesheetMetricLabel(metric),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              const Text('Gráfico e registros do período selecionado.'),
              const SizedBox(height: AppSpacing.lg),
              if (rows.isEmpty)
                const JkddEmptyState(
                  icon: Icons.query_stats_outlined,
                  title: 'Nenhum registro neste período',
                  message: 'Altere o período do Timesheet para consultar outros registros.',
                )
              else
                for (final row in rows) ...[
                  Row(
                    children: [
                      SizedBox(width: 92, child: Text(_date(row.date))),
                      SizedBox(width: 90, child: Text('Obra ${row.jobNumber}')),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: maxValue <= 0 ? 0 : row.value / maxValue,
                          minHeight: 12,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      SizedBox(
                        width: 76,
                        child: Text(
                          metric == _TimesheetMetric.premium
                              ? (row.premium ? 'Sim' : 'Não')
                              : metric == _TimesheetMetric.jobs
                              ? '1 registro'
                              : _hours(row.value),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
            ],
          ),
        ),
      ),
    );
  }

'''
if marker not in text:
    raise SystemExit('generate pdf marker not found')
text = text.replace(marker, insert + marker, 1)

# Add fifth period.
period_old = '''                  ButtonSegment(
                    value: TimesheetPeriod.year,
                    label: Text(context.tr('timesheet.year')),
                  ),
'''
period_new = period_old + '''                  const ButtonSegment(
                    value: TimesheetPeriod.all,
                    label: Text('Todo período'),
                  ),
'''
if period_old not in text:
    raise SystemExit('year period segment not found')
text = text.replace(period_old, period_new, 1)

# Make summary cards interactive.
old_grid_card = '''          for (final item in items)
            JkddSummaryCard(
              label: item.label,
              value: item.value,
              icon: item.icon,
              color: item.color,
            ),
'''
new_grid_card = '''          for (final item in items)
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: item.onTap,
              child: JkddSummaryCard(
                label: item.label,
                value: item.value,
                icon: item.icon,
                color: item.color,
              ),
            ),
'''
if old_grid_card not in text:
    raise SystemExit('total grid card block not found')
text = text.replace(old_grid_card, new_grid_card, 1)
old_total_item = '''final class _TotalItem {
  const _TotalItem(this.label, this.value, this.icon, this.color);

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}
'''
new_total_item = '''enum _TimesheetMetric { regular, bonus, total, premium, jobs }
enum _TimesheetExportFormat { pdf, excel }

final class _TimesheetMetricRow {
  const _TimesheetMetricRow({
    required this.date,
    required this.jobNumber,
    required this.value,
    required this.premium,
  });

  final DateTime date;
  final String jobNumber;
  final double value;
  final bool premium;
}

String _timesheetMetricLabel(_TimesheetMetric metric) => switch (metric) {
  _TimesheetMetric.regular => 'Horas regulares',
  _TimesheetMetric.bonus => 'Horas de bônus',
  _TimesheetMetric.total => 'Total de horas',
  _TimesheetMetric.premium => 'Adicional salarial',
  _TimesheetMetric.jobs => 'Obras trabalhadas',
};

final class _TotalItem {
  const _TotalItem(
    this.label,
    this.value,
    this.icon,
    this.color,
    this.onTap,
  );

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}
'''
if old_total_item not in text:
    raise SystemExit('TotalItem class not found')
text = text.replace(old_total_item, new_total_item, 1)

# EWW has no lunch break: remove break field from supervisor cards/editor and do not subtract it.
break_card = '''                SizedBox(
                  width: 150,
                  child: JkddInfoRow(
                    label: context.tr('approval.breakMinutes'),
                    value: '${entry.breakMinutes} min',
                  ),
                ),
'''
text = text.replace(break_card, '', 1)
text = text.replace(
    "  final breakMinutes = TextEditingController(text: '${entry.breakMinutes}');\n",
    '',
    1,
)
break_editor = '''              TextField(
                controller: breakMinutes,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.tr('approval.breakMinutes'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
'''
text = text.replace(break_editor, '', 1)
text = text.replace(
    '        breakMinutes: int.tryParse(breakMinutes.text) ?? entry.breakMinutes,\n',
    '        breakMinutes: 0,\n',
    1,
)
text = text.replace('  breakMinutes.dispose();\n', '', 1)
text = text.replace(
    '  var minutes = end - start - entry.breakMinutes;\n',
    '  var minutes = end - start;\n',
    1,
)
timesheet.write_text(text)

# 3) Clarify that pending header items are sync queue items.
appbar = Path('lib/shared/widgets/jkdd_app_bar.dart')
text = appbar.read_text()
text = text.replace(
    "        Text(context.tr('home.pendingItems', {'count': pendingItems})),",
    "        Text('$pendingItems aguardando sincronização'),",
    1,
)
appbar.write_text(text)

# 4) Receipt rows always open details; submitted receipts are no longer dead rows.
records = Path('lib/src/presentation/screens/time_records_screen.dart')
text = records.read_text()
if "import 'dart:convert';" not in text:
    text = text.replace("import 'dart:async';\n", "import 'dart:async';\nimport 'dart:convert';\n", 1)
old_tap = '''                  onTap: receipt.status == ReceiptStatus.draft
                      ? () => onEditReceipt(receipt)
                      : null,
'''
new_tap = '''                  onTap: () => _showReceiptDetails(context, receipt),
'''
if old_tap not in text:
    raise SystemExit('receipt onTap block not found')
text = text.replace(old_tap, new_tap, 1)
marker = '''  }
}

final class _SettingsView extends StatelessWidget {
'''
insert = '''  }

  Future<void> _showReceiptDetails(
    BuildContext context,
    Receipt receipt,
  ) async {
    Attachment? attachment;
    for (final id in receipt.attachmentIds) {
      for (final item in snapshot.attachments) {
        if (item.id == id) {
          attachment = item;
          break;
        }
      }
      if (attachment != null) break;
    }
    Job? job;
    for (final item in snapshot.jobs) {
      if (item.id == receipt.jobId) {
        job = item;
        break;
      }
    }
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.9,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              JkddSectionHeader(
                title: 'Detalhes do recibo',
                subtitle: receipt.registrationNumber.isEmpty
                    ? receipt.merchant
                    : receipt.registrationNumber,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (attachment != null &&
                  attachment.mimeType.toLowerCase().startsWith('image/'))
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.memory(
                    base64Decode(attachment.dataBase64),
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox(
                      height: 180,
                      child: Center(child: Text('Não foi possível abrir a imagem.')),
                    ),
                  ),
                )
              else if (attachment != null)
                ListTile(
                  leading: const Icon(Icons.attach_file_outlined),
                  title: Text(attachment.fileName),
                  subtitle: Text(attachment.mimeType),
                ),
              const SizedBox(height: AppSpacing.lg),
              JkddInfoRow(
                icon: Icons.storefront_outlined,
                label: 'Estabelecimento',
                value: receipt.merchant,
              ),
              JkddInfoRow(
                icon: Icons.apartment_outlined,
                label: 'Obra',
                value: job == null ? receipt.jobId : _jobLabel(context, job.number),
              ),
              JkddInfoRow(
                icon: Icons.category_outlined,
                label: 'Categoria',
                value: receipt.description,
              ),
              JkddInfoRow(
                icon: Icons.calendar_today_outlined,
                label: 'Data',
                value: _date(receipt.purchaseDate),
              ),
              JkddInfoRow(
                icon: Icons.payments_outlined,
                label: 'Valor',
                value: _money(receipt.total),
              ),
              JkddInfoRow(
                icon: Icons.receipt_long_outlined,
                label: 'Imposto',
                value: _money(receipt.tax),
              ),
              JkddInfoRow(
                icon: Icons.info_outline,
                label: 'Status',
                value: _receiptStatus(context, receipt.status),
              ),
              if (receipt.receiptNumber?.trim().isNotEmpty == true)
                JkddInfoRow(
                  icon: Icons.numbers_outlined,
                  label: 'Número do recibo',
                  value: receipt.receiptNumber!,
                ),
              if (receipt.notes?.trim().isNotEmpty == true)
                JkddInfoRow(
                  icon: Icons.notes_outlined,
                  label: 'Observações',
                  value: receipt.notes!,
                ),
              const SizedBox(height: AppSpacing.lg),
              if (receipt.status == ReceiptStatus.draft)
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    onEditReceipt(receipt);
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Editar recibo'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _SettingsView extends StatelessWidget {
'''
if marker not in text:
    raise SystemExit('receipts class closing marker not found')
text = text.replace(marker, insert, 1)
records.write_text(text)
