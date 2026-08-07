from pathlib import Path

path = Path('lib/src/presentation/screens/timesheet_screen.dart')
text = path.read_text()

old_call = """                        onPressed: () =>
                            _previewPdf(context, snapshot, pdfService, days),
"""
new_call = """                        onPressed: () =>
                            _generatePdf(context, snapshot, pdfService, days),
"""
if old_call not in text:
    raise RuntimeError('Generate button callback not found')
text = text.replace(old_call, new_call, 1)

start = text.find('  Future<void> _previewPdf(')
end = text.find('\n}\n\nenum _SupervisorTimesheetFilter', start)
if start < 0 or end < 0:
    raise RuntimeError('PDF function block not found')

replacement = r'''  Future<void> _generatePdf(
    BuildContext context,
    FieldTimeSnapshot snapshot,
    TimesheetPdfService pdfService,
    List<WorkDay> days,
  ) async {
    if (days.expand((day) => day.segments).isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('timesheet.noRecordsForPeriod'))),
      );
      return;
    }
    const reportStrings = AppStrings(AppLanguage.en);
    try {
      final bytes = await pdfService.buildWeeklyTimesheetPdf(
        snapshot: snapshot,
        anchorDate: DateTime.now(),
        period: period,
      );
      final baseName = reportStrings.t('timesheet.fileName');
      final fileName = baseName.toLowerCase().endsWith('.pdf')
          ? baseName
          : '$baseName.pdf';

      final delivered = await Printing.sharePdf(
        bytes: bytes,
        filename: fileName,
      );

      if (!delivered) {
        await Printing.layoutPdf(
          name: fileName,
          onLayout: (_) async => bytes,
        );
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              delivered
                  ? 'Timesheet pronto para compartilhar ou salvar em PDF.'
                  : context.tr('timesheet.generatedSuccess'),
            ),
          ),
        );
      }
    } on Exception catch (error) {
      debugPrint('Timesheet PDF generation failed: $error');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('timesheet.generationError'))),
        );
      }
    }
  }
'''

text = text[:start] + replacement + text[end:]
path.write_text(text)
