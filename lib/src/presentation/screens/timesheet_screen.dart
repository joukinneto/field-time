import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jkdd_field_time_records_production/core/theme/app_colors.dart';
import 'package:jkdd_field_time_records_production/core/theme/app_spacing.dart';
import 'package:jkdd_field_time_records_production/src/application/field_time_controller.dart';
import 'package:jkdd_field_time_records_production/src/domain/field_time_models.dart';
import 'package:jkdd_field_time_records_production/shared/widgets/jkdd_empty_state.dart';
import 'package:jkdd_field_time_records_production/shared/widgets/jkdd_info_row.dart';
import 'package:jkdd_field_time_records_production/shared/widgets/jkdd_section_header.dart';
import 'package:jkdd_field_time_records_production/shared/widgets/jkdd_status_chip.dart';
import 'package:jkdd_field_time_records_production/shared/widgets/jkdd_summary_card.dart';

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
      appBar: AppBar(title: const Text('Timesheet')),
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
    final snapshot = ref.watch(fieldTimeControllerProvider).snapshot;
    final service = ref.watch(fieldTimeApplicationServiceProvider);
    final days = service.timesheet(snapshot, period, DateTime.now());
    final segments = days.expand((day) => day.segments).toList();
    final receipts = snapshot.receipts.where(
      (receipt) =>
          days.any((day) => _sameDate(day.workDate, receipt.purchaseDate)),
    );
    final regularHours = segments.fold<double>(
      0,
      (total, segment) => total + segment.regularHours(),
    );
    final bonusHours = segments.fold<double>(
      0,
      (total, segment) => total + segment.travelBonusHours,
    );
    final reimbursement = receipts.fold<double>(
      0,
      (total, receipt) => total + receipt.total,
    );
    final totalsByJob = <String, double>{};
    for (final segment in segments) {
      totalsByJob.update(
        segment.jobNumber,
        (value) => value + segment.totalHours(),
        ifAbsent: segment.totalHours,
      );
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
                  title: 'Timesheet',
                  subtitle:
                      'Review hours, jobs, receipts and export readiness.',
                  trailing: FilledButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('GENERATE PDF'),
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
                    _TotalItem('Regular Hours', _hours(regularHours),
                        Icons.schedule_outlined, AppColors.blue),
                    _TotalItem('Bonus Hours', _hours(bonusHours),
                        Icons.route_outlined, AppColors.teal),
                    _TotalItem('Total Hours', _hours(regularHours + bonusHours),
                        Icons.access_time_filled, AppColors.green),
                    _TotalItem('Jobs', totalsByJob.length.toString(),
                        Icons.apartment_outlined, AppColors.purple),
                    _TotalItem('Receipts', receipts.length.toString(),
                        Icons.receipt_long_outlined, AppColors.amber),
                    _TotalItem('Reimbursements', _money(reimbursement),
                        Icons.payments_outlined, AppColors.green),
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
                        'Daily records',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    JkddStatusChip(
                      label: '${segments.length} records',
                      icon: Icons.list_alt_outlined,
                      tone: JkddStatusTone.info,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (segments.isEmpty)
                  const JkddEmptyState(
                    icon: Icons.table_chart_outlined,
                    title: 'No records for this period',
                    message: 'Clocked work periods will appear here.',
                  )
                else
                  for (final day in days)
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
              ],
            ),
          ),
        ),
      ],
    );
  }
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
            Text('Period', style: Theme.of(context).textTheme.titleMedium),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<TimesheetPeriod>(
                segments: const [
                  ButtonSegment(
                      value: TimesheetPeriod.today, label: Text('Today')),
                  ButtonSegment(
                      value: TimesheetPeriod.week, label: Text('Week')),
                  ButtonSegment(
                      value: TimesheetPeriod.month, label: Text('Month')),
                  ButtonSegment(
                      value: TimesheetPeriod.year, label: Text('Year')),
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
              ? 6
              : constraints.maxWidth >= 720
                  ? 3
                  : 2;
          return GridView.count(
            crossAxisCount: count,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
            childAspectRatio: count == 2 ? 1.15 : 1.05,
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
            Text('Total by job',
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
                      '${segment.jobNumber} - ${segment.jobName}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  JkddStatusChip(
                    label: day.isOpen ? 'In progress' : 'Pending',
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
                              label: 'Date', value: _date(day.workDate))),
                      SizedBox(
                          width: itemWidth,
                          child: JkddInfoRow(
                              label: 'Clock In',
                              value: _time(segment.startedAt))),
                      SizedBox(
                          width: itemWidth,
                          child: JkddInfoRow(
                              label: 'Clock Out',
                              value: segment.endedAt == null
                                  ? '--:--'
                                  : _time(segment.endedAt!))),
                      SizedBox(
                          width: itemWidth,
                          child: JkddInfoRow(
                              label: 'Regular',
                              value: _hours(segment.regularHours()))),
                      SizedBox(
                          width: itemWidth,
                          child: JkddInfoRow(
                              label: 'Bonus',
                              value: _hours(segment.travelBonusHours))),
                      SizedBox(
                          width: itemWidth,
                          child: JkddInfoRow(
                              label: 'Total',
                              value: _hours(segment.totalHours()))),
                      SizedBox(
                          width: itemWidth,
                          child: JkddInfoRow(
                              label: 'Receipts',
                              value: receiptCount.toString())),
                      SizedBox(
                          width: itemWidth,
                          child: JkddInfoRow(
                              label: 'Approval',
                              value: day.isOpen ? 'In progress' : 'Pending')),
                    ],
                  );
                },
              ),
              if (segment.notes?.isNotEmpty == true) ...[
                const Divider(height: 28),
                Text('Notes: ${segment.notes}'),
              ],
            ],
          ),
        ),
      );
}

bool _sameDate(DateTime left, DateTime right) =>
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day;

String _date(DateTime value) => '${value.month.toString().padLeft(2, '0')}/'
    '${value.day.toString().padLeft(2, '0')}/${value.year}';

String _time(DateTime value) => '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';

String _hours(double value) {
  final minutes = (value * 60).round();
  return '${minutes ~/ 60}h ${minutes.remainder(60).toString().padLeft(2, '0')}m';
}

String _money(double value) => '\$${value.toStringAsFixed(2)}';
