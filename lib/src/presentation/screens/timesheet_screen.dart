import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jkdd_field_time_records_production/core/theme/app_colors.dart';
import 'package:jkdd_field_time_records_production/core/theme/app_spacing.dart';
import 'package:jkdd_field_time_records_production/src/application/field_time_controller.dart';
import 'package:jkdd_field_time_records_production/src/domain/field_time_models.dart';
import 'package:jkdd_field_time_records_production/src/localization/app_language.dart';
import 'package:jkdd_field_time_records_production/src/supervisor_center/supervisor_center_controller.dart';
import 'package:jkdd_field_time_records_production/src/supervisor_center/supervisor_center_models.dart';
import 'package:jkdd_field_time_records_production/src/timesheet/timesheet_pdf_service.dart';
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
                        onPressed: () => _previewPdf(
                          context,
                          snapshot,
                          pdfService,
                          days,
                        ),
                        icon: const Icon(Icons.picture_as_pdf_outlined),
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
                        AppColors.blue),
                    _TotalItem(
                        context.tr('timesheet.bonusHours'),
                        _hours(bonusHours),
                        Icons.route_outlined,
                        AppColors.teal),
                    _TotalItem(
                        context.tr('timesheet.totalHours'),
                        _hours(regularHours + bonusHours),
                        Icons.access_time_filled,
                        AppColors.green),
                    _TotalItem(
                        context.tr('timesheet.payPremium'),
                        segments
                            .where((item) => item.hasPayPremium)
                            .length
                            .toString(),
                        Icons.workspace_premium_outlined,
                        AppColors.purple),
                    _TotalItem(
                        context.tr('timesheet.jobs'),
                        totalsByJob.length.toString(),
                        Icons.apartment_outlined,
                        AppColors.purple),
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
                      label: context.tr(
                        'common.recordsCount',
                        {'count': segments.length},
                      ),
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

  Future<void> _previewPdf(
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
      await Printing.layoutPdf(
        name: reportStrings.t('timesheet.fileName'),
        onLayout: (_) => pdfService.buildWeeklyTimesheetPdf(
          snapshot: snapshot,
          anchorDate: DateTime.now(),
          period: period,
        ),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('timesheet.generatedSuccess'))),
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

final class _SupervisorTeamTimesheet extends ConsumerWidget {
  const _SupervisorTeamTimesheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(supervisorCenterProvider);
    final entries = state.timeEntries
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
    final pending = entries
        .where((entry) => entry.status == TimeReviewStatus.pending)
        .length;
    final approved = entries
        .where((entry) => entry.status == TimeReviewStatus.approved)
        .length;
    final rejected = entries
        .where((entry) => entry.status == TimeReviewStatus.rejected)
        .length;
    final review = entries
        .where((entry) => {
              TimeReviewStatus.underReview,
              TimeReviewStatus.correctionRequested,
              TimeReviewStatus.corrected,
              TimeReviewStatus.resubmitted,
            }.contains(entry.status))
        .length;

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
                _TotalsGrid(
                  items: [
                    _TotalItem('Pendentes', '$pending', Icons.pending_actions,
                        AppColors.amber),
                    _TotalItem('Em revisão', '$review', Icons.rate_review_outlined,
                        AppColors.blue),
                    _TotalItem('Aprovados', '$approved',
                        Icons.check_circle_outline, AppColors.green),
                    _TotalItem('Rejeitados', '$rejected', Icons.cancel_outlined,
                        AppColors.red),
                    _TotalItem('Registros', '${entries.length}',
                        Icons.list_alt_outlined, AppColors.purple),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                if (entries.isEmpty)
                  JkddEmptyState(
                    icon: Icons.fact_check_outlined,
                    title: context.tr('approval.noSubmittedRecords'),
                    message: context.tr('approval.noSubmittedRecordsHelp'),
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
}

final class _SupervisorEntryCard extends ConsumerWidget {
  const _SupervisorEntryCard({required this.entry});

  final TimeEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(supervisorCenterProvider);
    final user = state.userById(entry.userId);
    final job = state.jobById(entry.jobId);
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
                      Text(user.name,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text('${_jobLabel(context, job.number)} — ${job.address}'),
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
                    label: context.tr('approval.breakMinutes'),
                    value: '${entry.breakMinutes} min',
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
              Text('${context.tr('supervisor.employeeNote')}: ${entry.employeeNote}'),
            ],
            if (entry.supervisorNote.trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                  '${context.tr('supervisor.supervisorNote')}: ${entry.supervisorNote}'),
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
                        : () => _requestSupervisorCorrection(
                              context,
                              ref,
                              entry,
                            ),
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
          TimeReviewStatus.correctionRequested =>
            context.tr('approval.correctionRequested'),
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
  final breakMinutes = TextEditingController(text: '${entry.breakMinutes}');
  final bonus =
      TextEditingController(text: entry.travelBonusHours.toStringAsFixed(2));
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
                decoration:
                    InputDecoration(labelText: context.tr('approval.clockIn')),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: clockOut,
                decoration:
                    InputDecoration(labelText: context.tr('approval.clockOut')),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: breakMinutes,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                    labelText: context.tr('approval.breakMinutes')),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: bonus,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText: context.tr('approval.travelBonus')),
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
                    labelText: context.tr('approval.observation')),
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
        breakMinutes: int.tryParse(breakMinutes.text) ?? entry.breakMinutes,
        travelBonusHours: double.tryParse(bonus.text) ?? entry.travelBonusHours,
        supervisorNote: note.text.trim(),
        justification: reason,
      );
      final premiumLabel = premium.text.trim();
      if (premiumLabel != job.payPremiumLabel) {
        controller.updateJob(job.copyWith(
          payPremiumEnabled: premiumLabel.isNotEmpty,
          payPremiumLabel: premiumLabel,
        ));
      }
    } on StateError catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  clockIn.dispose();
  clockOut.dispose();
  breakMinutes.dispose();
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
    ref
        .read(supervisorCenterProvider.notifier)
        .approveEntry(entry.id, 'Aprovado pelo supervisor.');
  } on StateError catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
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
  var minutes = end - start - entry.breakMinutes;
  if (minutes < 0) minutes += 24 * 60;
  return (minutes / 60) + entry.travelBonusHours;
}

int? _parseClock(String value) {
  final match = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)?$', caseSensitive: false)
      .firstMatch(value.trim());
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
            Text(context.tr('timesheet.period'),
                style: Theme.of(context).textTheme.titleMedium),
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
                JkddSummaryCard(
                  label: item.label,
                  value: item.value,
                  icon: item.icon,
                  color: item.color,
                ),
            ],
          );
        },
      );
}

final class _TotalItem {
  const _TotalItem(this.label, this.value, this.icon, this.color);

  final String label;
  final String value;
  final IconData icon;
  final Color color;
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
            Text(context.tr('timesheet.totalByJob'),
                style: Theme.of(context).textTheme.titleMedium),
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
                              value: _date(day.workDate))),
                      SizedBox(
                          width: itemWidth,
                          child: JkddInfoRow(
                              label: context.tr('timesheet.clockIn'),
                              value: _time(segment.startedAt))),
                      SizedBox(
                          width: itemWidth,
                          child: JkddInfoRow(
                              label: context.tr('timesheet.clockOut'),
                              value: segment.endedAt == null
                                  ? '--:--'
                                  : _time(segment.endedAt!))),
                      SizedBox(
                          width: itemWidth,
                          child: JkddInfoRow(
                              label: context.tr('timesheet.regularHours'),
                              value: _hours(segment.regularHours()))),
                      SizedBox(
                          width: itemWidth,
                          child: JkddInfoRow(
                              label: context.tr('timesheet.bonus'),
                              value: _hours(segment.travelBonusHours))),
                      SizedBox(
                          width: itemWidth,
                          child: JkddInfoRow(
                              label: context.tr('timesheet.total'),
                              value: _hours(segment.totalHours()))),
                      SizedBox(
                          width: itemWidth,
                          child: JkddInfoRow(
                              label: context.tr('timesheet.receipts'),
                              value: receiptCount.toString())),
                      SizedBox(
                          width: itemWidth,
                          child: JkddInfoRow(
                              label: context.tr('timesheet.approval'),
                              value: day.isOpen
                                  ? context.tr('timesheet.inProgress')
                                  : context.tr('approval.pending'))),
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
          title: Text(
            context.tr('timesheet.travelBonusLine'),
          ),
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

String _date(DateTime value) => '${value.month.toString().padLeft(2, '0')}/'
    '${value.day.toString().padLeft(2, '0')}/${value.year}';

String _time(DateTime value) => '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';

String _hours(double value) {
  final minutes = (value * 60).round();
  return '${minutes ~/ 60}h ${minutes.remainder(60).toString().padLeft(2, '0')}m';
}
