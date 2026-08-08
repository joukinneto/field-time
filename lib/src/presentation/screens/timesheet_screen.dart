import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jkdd_field_time_records_production/core/theme/app_colors.dart';
import 'package:jkdd_field_time_records_production/core/theme/app_spacing.dart';
import 'package:jkdd_field_time_records_production/src/application/field_time_controller.dart';
import 'package:jkdd_field_time_records_production/src/domain/field_time_models.dart';
import 'package:jkdd_field_time_records_production/src/localization/app_language.dart';
import 'package:jkdd_field_time_records_production/src/platform/file_download.dart';
import 'package:jkdd_field_time_records_production/src/supervisor_center/supervisor_center_controller.dart';
import 'package:jkdd_field_time_records_production/src/supervisor_center/supervisor_center_models.dart';
import 'package:jkdd_field_time_records_production/src/timesheet/timesheet_pdf_service.dart';
import 'package:jkdd_field_time_records_production/src/timesheet/timesheet_excel_service.dart';
import 'package:jkdd_field_time_records_production/shared/widgets/jkdd_empty_state.dart';
import 'package:jkdd_field_time_records_production/shared/widgets/jkdd_info_row.dart';
import 'package:jkdd_field_time_records_production/shared/widgets/jkdd_section_header.dart';
import 'package:jkdd_field_time_records_production/shared/widgets/jkdd_status_chip.dart';
import 'package:jkdd_field_time_records_production/shared/widgets/jkdd_summary_card.dart';
import 'package:printing/printing.dart';

final class TimesheetScreen extends ConsumerStatefulWidget {
  const TimesheetScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<TimesheetScreen> createState() => _TimesheetScreenState();
}

final class _TimesheetScreenState extends ConsumerState<TimesheetScreen> {
  TimesheetPeriod _period = TimesheetPeriod.today;

  @override
  Widget build(BuildContext context) {
    final content = _TimesheetContent(
      period: _period,
      onPeriodChanged: (value) => setState(() => _period = value),
    );
    if (widget.embedded) return content;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('timesheet.title'))),
      body: SafeArea(child: content),
    );
  }
}

final class _TimesheetContent extends ConsumerWidget {
  const _TimesheetContent({
    required this.period,
    required this.onPeriodChanged,
  });

  final TimesheetPeriod period;
  final ValueChanged<TimesheetPeriod> onPeriodChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supervisor = ref.watch(supervisorCenterProvider);
    if (supervisor.hasPermission(PilotPermission.viewAllTime)) {
      return const _SupervisorTeamTimesheet();
    }

    final snapshot = ref.watch(fieldTimeControllerProvider).snapshot;
    final service = ref.watch(fieldTimeApplicationServiceProvider);
    const pdfService = TimesheetPdfService();
    const excelService = TimesheetExcelService();
    final days = service.timesheet(snapshot, period, DateTime.now());
    final segments = days.expand((day) => day.segments).toList();
    final regularHours = segments.fold<double>(
      0,
      (total, segment) => total + segment.regularHours(),
    );
    final bonusHours = days.fold<double>(
      0,
      (total, day) => total + day.travelBonusHours,
    );
    final totalsByJob = <String, double>{};
    for (final segment in segments) {
      totalsByJob.update(
        segment.jobNumber,
        (value) => value + segment.regularHours(),
        ifAbsent: () => segment.regularHours(),
      );
    }
    for (final day in days) {
      for (final segment in _bonusSegments(day)) {
        totalsByJob.update(
          segment.jobNumber,
          (value) => value + segment.travelBonusHours,
          ifAbsent: () => segment.travelBonusHours,
        );
      }
    }

    return ListView(
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.sizeOf(context).width < 600 ? 16 : 28,
        vertical: 24,
      ),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                JkddSectionHeader(
                  title: context.tr('timesheet.title'),
                  subtitle: context.tr('timesheet.subtitle'),
                  trailing: Wrap(
                    spacing: AppSpacing.sm,
                    children: [
                      FilledButton.icon(
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
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _TimesheetFilters(
                  period: period,
                  onPeriodChanged: onPeriodChanged,
                ),
                const SizedBox(height: AppSpacing.xl),
                _TotalsGrid(
                  items: [
                    _TotalItem(
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
                  ],
                ),
                if (totalsByJob.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xl),
                  _TotalsByJob(totalsByJob: totalsByJob),
                ],
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.tr('timesheet.dailyRecords'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    JkddStatusChip(
                      label: context.tr('common.recordsCount', {
                        'count': segments.length,
                      }),
                      icon: Icons.list_alt_outlined,
                      tone: JkddStatusTone.info,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (segments.isEmpty)
                  JkddEmptyState(
                    icon: Icons.table_chart_outlined,
                    title: context.tr('timesheet.noRecords'),
                    message: context.tr('timesheet.noRecordsHelp'),
                  )
                else
                  for (final day in days) ...[
                    for (final segment in day.segments)
                      _SegmentCard(
                        day: day,
                        segment: segment,
                        receiptCount: snapshot.receipts
                            .where(
                              (receipt) =>
                                  receipt.jobId == segment.jobId &&
                                  _sameDate(receipt.purchaseDate, day.workDate),
                            )
                            .length,
                      ),
                    for (final segment in _bonusSegments(day))
                      _TravelBonusCard(day: day, segment: segment),
                  ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showExportMenu(
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
                subtitle: const Text(
                  'Visualizar, imprimir, compartilhar ou salvar.',
                ),
                onTap: () => Navigator.pop(context, _TimesheetExportFormat.pdf),
              ),
              ListTile(
                leading: const Icon(Icons.table_view_outlined),
                title: const Text('Excel'),
                subtitle: const Text(
                  'Planilha .xlsx para conferência e payroll.',
                ),
                onTap: () =>
                    Navigator.pop(context, _TimesheetExportFormat.excel),
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
        fileName:
            'Field_Time_Timesheet_${snapshot.worker.displayName.replaceAll(' ', '_')}.xlsx',
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
                  message:
                      'Altere o período do Timesheet para consultar outros registros.',
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

  Future<void> _generatePdf(
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
        await Printing.layoutPdf(name: fileName, onLayout: (_) async => bytes);
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
}

enum _SupervisorTimesheetFilter { all, pending, review, approved, rejected }

final class _SupervisorTeamTimesheet extends ConsumerStatefulWidget {
  const _SupervisorTeamTimesheet();

  @override
  ConsumerState<_SupervisorTeamTimesheet> createState() =>
      _SupervisorTeamTimesheetState();
}

final class _SupervisorTeamTimesheetState
    extends ConsumerState<_SupervisorTeamTimesheet> {
  _SupervisorTimesheetFilter _filter = _SupervisorTimesheetFilter.all;

  static const _reviewStatuses = {
    TimeReviewStatus.underReview,
    TimeReviewStatus.correctionRequested,
    TimeReviewStatus.corrected,
    TimeReviewStatus.resubmitted,
  };

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(supervisorCenterProvider);
    final allEntries =
        state.timeEntries
            .where((entry) => entry.status != TimeReviewStatus.working)
            .toList(growable: false)
          ..sort((left, right) {
            final dateCompare = right.date.compareTo(left.date);
            if (dateCompare != 0) return dateCompare;
            return state
                .userById(left.userId)
                .name
                .compareTo(state.userById(right.userId).name);
          });

    final pending = allEntries
        .where((entry) => entry.status == TimeReviewStatus.pending)
        .length;
    final approved = allEntries
        .where((entry) => entry.status == TimeReviewStatus.approved)
        .length;
    final rejected = allEntries
        .where((entry) => entry.status == TimeReviewStatus.rejected)
        .length;
    final review = allEntries
        .where((entry) => _reviewStatuses.contains(entry.status))
        .length;
    final entries = allEntries
        .where(_matchesCurrentFilter)
        .toList(growable: false);

    return ListView(
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.sizeOf(context).width < 600 ? 16 : 28,
        vertical: 24,
      ),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                JkddSectionHeader(
                  title: context.tr('timesheet.dailyRecords'),
                  subtitle: context.tr('supervisor.reviewSubmittedRecords'),
                ),
                const SizedBox(height: AppSpacing.lg),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 900 ? 4 : 2;
                    final itemWidth =
                        (constraints.maxWidth - AppSpacing.md * (columns - 1)) /
                        columns;
                    return Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.md,
                      children: [
                        _TimesheetStatusCard(
                          width: itemWidth,
                          label: 'Pendentes',
                          value: '$pending',
                          icon: Icons.pending_actions,
                          color: AppColors.amber,
                          selected:
                              _filter == _SupervisorTimesheetFilter.pending,
                          onTap: () =>
                              _setFilter(_SupervisorTimesheetFilter.pending),
                        ),
                        _TimesheetStatusCard(
                          width: itemWidth,
                          label: 'Em revisão',
                          value: '$review',
                          icon: Icons.rate_review_outlined,
                          color: AppColors.blue,
                          selected:
                              _filter == _SupervisorTimesheetFilter.review,
                          onTap: () =>
                              _setFilter(_SupervisorTimesheetFilter.review),
                        ),
                        _TimesheetStatusCard(
                          width: itemWidth,
                          label: 'Aprovados',
                          value: '$approved',
                          icon: Icons.check_circle_outline,
                          color: AppColors.green,
                          selected:
                              _filter == _SupervisorTimesheetFilter.approved,
                          onTap: () =>
                              _setFilter(_SupervisorTimesheetFilter.approved),
                        ),
                        _TimesheetStatusCard(
                          width: itemWidth,
                          label: 'Rejeitados',
                          value: '$rejected',
                          icon: Icons.cancel_outlined,
                          color: AppColors.red,
                          selected:
                              _filter == _SupervisorTimesheetFilter.rejected,
                          onTap: () =>
                              _setFilter(_SupervisorTimesheetFilter.rejected),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _setFilter(_SupervisorTimesheetFilter.all),
                    icon: const Icon(Icons.list_alt_outlined),
                    label: Text('Todos os registros (${allEntries.length})'),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    const Icon(Icons.filter_alt_outlined, size: 18),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        'Mostrando: ${_supervisorTimesheetFilterLabel(_filter)}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    if (_filter != _SupervisorTimesheetFilter.all)
                      TextButton(
                        onPressed: () =>
                            _setFilter(_SupervisorTimesheetFilter.all),
                        child: const Text('Limpar filtro'),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (entries.isEmpty)
                  const JkddEmptyState(
                    icon: Icons.fact_check_outlined,
                    title: 'Nenhum registro neste filtro',
                    message:
                        'Toque em outro card acima para consultar os demais registros.',
                  )
                else
                  for (final entry in entries)
                    _SupervisorEntryCard(entry: entry),
              ],
            ),
          ),
        ),
      ],
    );
  }

  bool _matchesCurrentFilter(TimeEntry entry) => switch (_filter) {
    _SupervisorTimesheetFilter.all => true,
    _SupervisorTimesheetFilter.pending =>
      entry.status == TimeReviewStatus.pending,
    _SupervisorTimesheetFilter.review => _reviewStatuses.contains(entry.status),
    _SupervisorTimesheetFilter.approved =>
      entry.status == TimeReviewStatus.approved,
    _SupervisorTimesheetFilter.rejected =>
      entry.status == TimeReviewStatus.rejected,
  };

  void _setFilter(_SupervisorTimesheetFilter value) {
    setState(() => _filter = value);
  }
}

final class _TimesheetStatusCard extends StatelessWidget {
  const _TimesheetStatusCard({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final double width;
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Stack(
        children: [
          JkddSummaryCard(label: label, value: value, icon: icon, color: color),
          if (selected)
            Positioned(
              top: 10,
              right: 10,
              child: Icon(Icons.check_circle, color: color, size: 20),
            ),
        ],
      ),
    ),
  );
}

String _supervisorTimesheetFilterLabel(_SupervisorTimesheetFilter filter) =>
    switch (filter) {
      _SupervisorTimesheetFilter.all => 'todos os registros',
      _SupervisorTimesheetFilter.pending => 'pendentes',
      _SupervisorTimesheetFilter.review => 'em revisão',
      _SupervisorTimesheetFilter.approved => 'aprovados',
      _SupervisorTimesheetFilter.rejected => 'rejeitados',
    };

final class _SupervisorEntryCard extends ConsumerWidget {
  const _SupervisorEntryCard({required this.entry});

  final TimeEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(supervisorCenterProvider);
    final user = state.userById(entry.userId);
    final job = state.jobById(entry.jobId);
    final entryReviews = state.reviews
        .where((review) => review.timeEntryId == entry.id)
        .toList(growable: false);
    final questions = entryReviews
        .where((review) => review.reason == 'DIRECTOR_QUESTION')
        .toList(growable: false);
    final responses = entryReviews
        .where((review) => review.reason == 'SUPERVISOR_RESPONSE')
        .toList(growable: false);
    final hasUnansweredQuestion =
        questions.isNotEmpty &&
        (responses.isEmpty ||
            responses.last.reviewedAt.isBefore(questions.last.reviewedAt));
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_jobLabel(context, job.number)} — ${job.address}',
                      ),
                    ],
                  ),
                ),
                _SupervisorStatusChip(status: entry.status),
              ],
            ),
            const Divider(height: 28),
            Wrap(
              spacing: AppSpacing.xl,
              runSpacing: AppSpacing.md,
              children: [
                SizedBox(
                  width: 150,
                  child: JkddInfoRow(
                    label: context.tr('timesheet.date'),
                    value: _date(entry.date),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: JkddInfoRow(
                    label: context.tr('timesheet.clockIn'),
                    value: entry.clockIn,
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: JkddInfoRow(
                    label: context.tr('timesheet.clockOut'),
                    value: entry.clockOut ?? '--:--',
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: JkddInfoRow(
                    label: context.tr('approval.travelBonus'),
                    value: _hours(entry.travelBonusHours),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: JkddInfoRow(
                    label: context.tr('timesheet.total'),
                    value: _hours(_supervisorEntryHours(entry)),
                  ),
                ),
              ],
            ),
            if (job.payPremiumEnabled) ...[
              const SizedBox(height: AppSpacing.md),
              JkddStatusChip(
                label:
                    '${context.tr('jobs.payPremium')}: ${job.payPremiumLabel}',
                icon: Icons.workspace_premium_outlined,
                tone: JkddStatusTone.info,
              ),
            ],
            if (entry.employeeNote.trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                '${context.tr('supervisor.employeeNote')}: ${entry.employeeNote}',
              ),
            ],
            if (entry.supervisorNote.trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${context.tr('supervisor.supervisorNote')}: ${entry.supervisorNote}',
              ),
            ],
            if (questions.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              JkddStatusChip(
                label: 'Diretor: ${questions.last.observation}',
                icon: Icons.help_outline,
                tone: JkddStatusTone.warning,
              ),
            ],
            if (responses.isNotEmpty &&
                (questions.isEmpty ||
                    !responses.last.reviewedAt.isBefore(
                      questions.last.reviewedAt,
                    ))) ...[
              const SizedBox(height: AppSpacing.sm),
              JkddStatusChip(
                label: 'Supervisor: ${responses.last.observation}',
                icon: Icons.reply_outlined,
                tone: JkddStatusTone.info,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  OutlinedButton.icon(
                    onPressed: entry.isLocked
                        ? null
                        : () => _editSupervisorEntry(context, ref, entry),
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(context.tr('approval.review')),
                  ),
                  FilledButton.icon(
                    onPressed: entry.isLocked
                        ? null
                        : () => _approveSupervisorEntry(context, ref, entry),
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(context.tr('approval.approve')),
                  ),
                  if (entry.status == TimeReviewStatus.approved &&
                      {
                        PilotRole.owner,
                        PilotRole.administrator,
                      }.contains(state.currentRole))
                    TextButton.icon(
                      onPressed: () => _questionSupervisor(context, ref, entry),
                      icon: const Icon(Icons.help_outline),
                      label: const Text('Questionar supervisor'),
                    ),
                  if (entry.status == TimeReviewStatus.approved &&
                      state.currentRole == PilotRole.supervisor &&
                      hasUnansweredQuestion)
                    TextButton.icon(
                      onPressed: () => _respondDirector(context, ref, entry),
                      icon: const Icon(Icons.reply_outlined),
                      label: const Text('Responder diretor'),
                    ),
                  OutlinedButton.icon(
                    onPressed: entry.isLocked
                        ? null
                        : () => _rejectSupervisorEntry(context, ref, entry),
                    icon: const Icon(Icons.cancel_outlined),
                    label: Text(context.tr('approval.reject')),
                  ),
                  TextButton.icon(
                    onPressed: entry.isLocked
                        ? null
                        : () =>
                              _requestSupervisorCorrection(context, ref, entry),
                    icon: const Icon(Icons.edit_note_outlined),
                    label: Text(context.tr('supervisor.requestCorrection')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _SupervisorStatusChip extends StatelessWidget {
  const _SupervisorStatusChip({required this.status});

  final TimeReviewStatus status;

  @override
  Widget build(BuildContext context) => JkddStatusChip(
    label: switch (status) {
      TimeReviewStatus.pending => context.tr('approval.pending'),
      TimeReviewStatus.approved => context.tr('approval.approved'),
      TimeReviewStatus.rejected => context.tr('approval.rejected'),
      TimeReviewStatus.underReview => context.tr('approval.underReview'),
      TimeReviewStatus.correctionRequested => context.tr(
        'approval.correctionRequested',
      ),
      TimeReviewStatus.corrected => context.tr('approval.corrected'),
      TimeReviewStatus.resubmitted => context.tr('approval.resubmitted'),
      TimeReviewStatus.closed => context.tr('approval.closed'),
      TimeReviewStatus.working => context.tr('approval.working'),
    },
    icon: switch (status) {
      TimeReviewStatus.approved => Icons.check_circle_outline,
      TimeReviewStatus.rejected => Icons.cancel_outlined,
      TimeReviewStatus.correctionRequested => Icons.edit_note_outlined,
      TimeReviewStatus.underReview => Icons.rate_review_outlined,
      TimeReviewStatus.resubmitted => Icons.upload_file_outlined,
      _ => Icons.pending_actions,
    },
    tone: switch (status) {
      TimeReviewStatus.approved => JkddStatusTone.success,
      TimeReviewStatus.rejected => JkddStatusTone.danger,
      TimeReviewStatus.underReview => JkddStatusTone.info,
      TimeReviewStatus.corrected => JkddStatusTone.info,
      TimeReviewStatus.resubmitted => JkddStatusTone.warning,
      _ => JkddStatusTone.warning,
    },
  );
}

Future<void> _editSupervisorEntry(
  BuildContext context,
  WidgetRef ref,
  TimeEntry entry,
) async {
  final state = ref.read(supervisorCenterProvider);
  final job = state.jobById(entry.jobId);
  final clockIn = TextEditingController(text: entry.clockIn);
  final clockOut = TextEditingController(text: entry.clockOut ?? '');
  final bonus = TextEditingController(
    text: entry.travelBonusHours.toStringAsFixed(2),
  );
  final premium = TextEditingController(text: job.payPremiumLabel);
  final note = TextEditingController(text: entry.supervisorNote);
  final justification = TextEditingController();

  final saved = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.tr('approval.reviewEntry')),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: clockIn,
                decoration: InputDecoration(
                  labelText: context.tr('approval.clockIn'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: clockOut,
                decoration: InputDecoration(
                  labelText: context.tr('approval.clockOut'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: bonus,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: context.tr('approval.travelBonus'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: premium,
                decoration: InputDecoration(
                  labelText: context.tr('jobs.payPremium'),
                  hintText: '25%, \$5/h, Double time',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: note,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: context.tr('approval.observation'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: justification,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: context.tr('approval.requiredJustification'),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(context.tr('common.cancel')),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.save_outlined),
          label: Text(context.tr('approval.saveReview')),
        ),
      ],
    ),
  );

  if (saved == true) {
    final reason = justification.text.trim();
    try {
      final controller = ref.read(supervisorCenterProvider.notifier);
      controller.updateTimeEntry(
        entryId: entry.id,
        clockIn: clockIn.text.trim(),
        clockOut: clockOut.text.trim().isEmpty ? null : clockOut.text.trim(),
        breakMinutes: 0,
        travelBonusHours: double.tryParse(bonus.text) ?? entry.travelBonusHours,
        supervisorNote: note.text.trim(),
        justification: reason,
      );
      final premiumLabel = premium.text.trim();
      if (premiumLabel != job.payPremiumLabel) {
        controller.updateJob(
          job.copyWith(
            payPremiumEnabled: premiumLabel.isNotEmpty,
            payPremiumLabel: premiumLabel,
          ),
        );
      }
    } on StateError catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  clockIn.dispose();
  clockOut.dispose();
  bonus.dispose();
  premium.dispose();
  note.dispose();
  justification.dispose();
}

Future<void> _approveSupervisorEntry(
  BuildContext context,
  WidgetRef ref,
  TimeEntry entry,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.tr('approval.confirmApprove')),
      content: Text(context.tr('approval.approveMessage')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(context.tr('common.cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(context.tr('approval.approve')),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  try {
    ref.read(supervisorCenterProvider.notifier).approveEntry(entry.id);
  } on StateError catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

Future<void> _questionSupervisor(
  BuildContext context,
  WidgetRef ref,
  TimeEntry entry,
) async {
  final question = await _supervisorTextDialog(
    context,
    'Questionar supervisor',
    'Digite a pergunta sobre esta aprovação.',
  );
  if (question?.trim().isEmpty != false) return;
  try {
    ref
        .read(supervisorCenterProvider.notifier)
        .questionSupervisor(entry.id, question!);
  } on StateError catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

Future<void> _respondDirector(
  BuildContext context,
  WidgetRef ref,
  TimeEntry entry,
) async {
  final response = await _supervisorTextDialog(
    context,
    'Responder diretor',
    'Digite a resposta ao questionamento.',
  );
  if (response?.trim().isEmpty != false) return;
  try {
    ref
        .read(supervisorCenterProvider.notifier)
        .respondDirectorQuestion(entry.id, response!);
  } on StateError catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

Future<void> _rejectSupervisorEntry(
  BuildContext context,
  WidgetRef ref,
  TimeEntry entry,
) async {
  final reason = await _supervisorTextDialog(
    context,
    context.tr('approval.rejectRecord'),
    context.tr('approval.rejectionReasonRequired'),
  );
  if (reason == null || reason.trim().isEmpty) return;
  try {
    ref.read(supervisorCenterProvider.notifier).rejectEntry(entry.id, reason);
  } on StateError catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

Future<void> _requestSupervisorCorrection(
  BuildContext context,
  WidgetRef ref,
  TimeEntry entry,
) async {
  final reason = await _supervisorTextDialog(
    context,
    context.tr('supervisor.requestCorrection'),
    context.tr('supervisor.correctionReason'),
  );
  if (reason == null || reason.trim().isEmpty) return;
  try {
    ref
        .read(supervisorCenterProvider.notifier)
        .correctionRequestedBySupervisor(entry.id, reason);
  } on StateError catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

Future<String?> _supervisorTextDialog(
  BuildContext context,
  String title,
  String label,
) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        minLines: 2,
        maxLines: 4,
        decoration: InputDecoration(labelText: label),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.tr('common.cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: Text(context.tr('common.save')),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}

double _supervisorEntryHours(TimeEntry entry) {
  final start = _parseClock(entry.clockIn);
  final end = entry.clockOut == null ? null : _parseClock(entry.clockOut!);
  if (start == null || end == null) return entry.travelBonusHours;
  var minutes = end - start;
  if (minutes < 0) minutes += 24 * 60;
  return (minutes / 60) + entry.travelBonusHours;
}

int? _parseClock(String value) {
  final match = RegExp(
    r'^(\d{1,2}):(\d{2})\s*(AM|PM)?$',
    caseSensitive: false,
  ).firstMatch(value.trim());
  if (match == null) return null;
  var hour = int.tryParse(match.group(1)!) ?? 0;
  final minute = int.tryParse(match.group(2)!) ?? 0;
  final suffix = match.group(3)?.toUpperCase();
  if (suffix == 'PM' && hour < 12) hour += 12;
  if (suffix == 'AM' && hour == 12) hour = 0;
  return hour * 60 + minute;
}

final class _TimesheetFilters extends StatelessWidget {
  const _TimesheetFilters({
    required this.period,
    required this.onPeriodChanged,
  });

  final TimesheetPeriod period;
  final ValueChanged<TimesheetPeriod> onPeriodChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            Text(
              context.tr('timesheet.period'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<TimesheetPeriod>(
                segments: [
                  ButtonSegment(
                    value: TimesheetPeriod.today,
                    label: Text(context.tr('timesheet.today')),
                  ),
                  ButtonSegment(
                    value: TimesheetPeriod.week,
                    label: Text(context.tr('timesheet.week')),
                  ),
                  ButtonSegment(
                    value: TimesheetPeriod.month,
                    label: Text(context.tr('timesheet.month')),
                  ),
                  ButtonSegment(
                    value: TimesheetPeriod.year,
                    label: Text(context.tr('timesheet.year')),
                  ),
                  const ButtonSegment(
                    value: TimesheetPeriod.all,
                    label: Text('Todo período'),
                  ),
                ],
                selected: {period},
                onSelectionChanged: (value) => onPeriodChanged(value.first),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _TotalsGrid extends StatelessWidget {
  const _TotalsGrid({required this.items});

  final List<_TotalItem> items;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final count = constraints.maxWidth >= 1040
          ? 5
          : constraints.maxWidth >= 720
          ? 5
          : 2;
      return GridView.count(
        crossAxisCount: count,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: count == 2 ? 1.55 : 1.45,
        children: [
          for (final item in items)
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
        ],
      );
    },
  );
}

enum _TimesheetMetric { regular, bonus, total, premium, jobs }

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
  const _TotalItem(this.label, this.value, this.icon, this.color, this.onTap);

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

final class _TotalsByJob extends StatelessWidget {
  const _TotalsByJob({required this.totalsByJob});

  final Map<String, double> totalsByJob;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('timesheet.totalByJob'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final entry in totalsByJob.entries)
                  Chip(label: Text('${entry.key}: ${_hours(entry.value)}')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

final class _SegmentCard extends StatelessWidget {
  const _SegmentCard({
    required this.day,
    required this.segment,
    required this.receiptCount,
  });

  final WorkDay day;
  final WorkSegment segment;
  final int receiptCount;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _jobLabel(context, segment.jobNumber),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              JkddStatusChip(
                label: day.isOpen
                    ? context.tr('timesheet.inProgress')
                    : context.tr('approval.pending'),
                icon: day.isOpen
                    ? Icons.play_circle_outline
                    : Icons.pending_outlined,
                tone: day.isOpen
                    ? JkddStatusTone.success
                    : JkddStatusTone.warning,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(segment.jobAddress),
          const Divider(height: 28),
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth >= 760 ? 150.0 : 132.0;
              return Wrap(
                spacing: AppSpacing.xl,
                runSpacing: AppSpacing.md,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: JkddInfoRow(
                      label: context.tr('timesheet.date'),
                      value: _date(day.workDate),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: JkddInfoRow(
                      label: context.tr('timesheet.clockIn'),
                      value: _time(segment.startedAt),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: JkddInfoRow(
                      label: context.tr('timesheet.clockOut'),
                      value: segment.endedAt == null
                          ? '--:--'
                          : _time(segment.endedAt!),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: JkddInfoRow(
                      label: context.tr('timesheet.regularHours'),
                      value: _hours(segment.regularHours()),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: JkddInfoRow(
                      label: context.tr('timesheet.bonus'),
                      value: _hours(segment.travelBonusHours),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: JkddInfoRow(
                      label: context.tr('timesheet.total'),
                      value: _hours(segment.totalHours()),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: JkddInfoRow(
                      label: context.tr('timesheet.receipts'),
                      value: receiptCount.toString(),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: JkddInfoRow(
                      label: context.tr('timesheet.approval'),
                      value: day.isOpen
                          ? context.tr('timesheet.inProgress')
                          : context.tr('approval.pending'),
                    ),
                  ),
                ],
              );
            },
          ),
          if (segment.notes?.isNotEmpty == true) ...[
            const Divider(height: 28),
            Text('${context.tr('timesheet.notes')}: ${segment.notes}'),
          ],
        ],
      ),
    ),
  );
}

final class _TravelBonusCard extends StatelessWidget {
  const _TravelBonusCard({required this.day, required this.segment});

  final WorkDay day;
  final WorkSegment segment;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: AppSpacing.md),
    child: ListTile(
      leading: const Icon(Icons.route_outlined, color: AppColors.amber),
      title: Text(context.tr('timesheet.travelBonusLine')),
      subtitle: Text(
        '${_jobLabel(context, segment.jobNumber)}\n'
        '${_date(day.workDate)} - ${segment.jobAddress}',
      ),
      trailing: Text(
        _hours(segment.travelBonusHours),
        style: Theme.of(context).textTheme.titleMedium,
      ),
    ),
  );
}

List<WorkSegment> _bonusSegments(WorkDay day) {
  return day.travelBonusSegments;
}

bool _sameDate(DateTime left, DateTime right) =>
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day;

String _jobLabel(BuildContext context, String number) {
  final title = context.tr('jobs.title').toLowerCase().startsWith('job')
      ? 'Job'
      : context.tr('jobs.title').replaceAll('s', '');
  return '$title $number';
}

String _date(DateTime value) =>
    '${value.month.toString().padLeft(2, '0')}/'
    '${value.day.toString().padLeft(2, '0')}/${value.year}';

String _time(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';

String _hours(double value) {
  final minutes = (value * 60).round();
  return '${minutes ~/ 60}h ${minutes.remainder(60).toString().padLeft(2, '0')}m';
}
