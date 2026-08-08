from pathlib import Path
import re

# --- TimeEntry fields: generic bonus + individual 25% premium ---
models = Path('lib/src/supervisor_center/supervisor_center_models.dart')
text = models.read_text()
text = text.replace(
"""    this.travelBonusHours = 0,\n    this.supervisorNote = '',\n""",
"""    this.travelBonusHours = 0,\n    this.extraBonusHours = 0,\n    this.payPremiumPercent = 0,\n    this.supervisorNote = '',\n""",1)
text = text.replace(
"""  final double travelBonusHours;\n  final String supervisorNote;\n""",
"""  final double travelBonusHours;\n  final double extraBonusHours;\n  final double payPremiumPercent;\n  final String supervisorNote;\n""",1)
text = text.replace(
"""    double? travelBonusHours,\n    String? supervisorNote,\n""",
"""    double? travelBonusHours,\n    double? extraBonusHours,\n    double? payPremiumPercent,\n    String? supervisorNote,\n""",1)
text = text.replace(
"""    travelBonusHours: travelBonusHours ?? this.travelBonusHours,\n    supervisorNote: supervisorNote ?? this.supervisorNote,\n""",
"""    travelBonusHours: travelBonusHours ?? this.travelBonusHours,\n    extraBonusHours: extraBonusHours ?? this.extraBonusHours,\n    payPremiumPercent: payPremiumPercent ?? this.payPremiumPercent,\n    supervisorNote: supervisorNote ?? this.supervisorNote,\n""",1)
models.write_text(text)

# --- Controller: save review without mandatory note; persist individual additions ---
controller = Path('lib/src/supervisor_center/supervisor_center_controller.dart')
text = controller.read_text()
text = text.replace(
"""    required double travelBonusHours,\n    required String supervisorNote,\n    required String justification,\n""",
"""    required double travelBonusHours,\n    required double extraBonusHours,\n    required double payPremiumPercent,\n    required String supervisorNote,\n    required String justification,\n""",1)
text = text.replace(
"""    if (justification.trim().isEmpty) {\n      throw StateError('supervisor.changeJustificationRequired');\n    }\n""","",1)
text = text.replace(
"""      travelBonusHours: travelBonusHours,\n      supervisorNote: supervisorNote,\n""",
"""      travelBonusHours: travelBonusHours,\n      extraBonusHours: extraBonusHours,\n      payPremiumPercent: payPremiumPercent,\n      supervisorNote: supervisorNote,\n""",1)
text = text.replace(
"""    addLog(\n      'travelBonusHours',\n      entry.travelBonusHours.toStringAsFixed(2),\n      updated.travelBonusHours.toStringAsFixed(2),\n    );\n""",
"""    addLog(\n      'travelBonusHours',\n      entry.travelBonusHours.toStringAsFixed(2),\n      updated.travelBonusHours.toStringAsFixed(2),\n    );\n    addLog(\n      'extraBonusHours',\n      entry.extraBonusHours.toStringAsFixed(2),\n      updated.extraBonusHours.toStringAsFixed(2),\n    );\n    addLog(\n      'payPremiumPercent',\n      entry.payPremiumPercent.toStringAsFixed(0),\n      updated.payPremiumPercent.toStringAsFixed(0),\n    );\n""",1)
controller.write_text(text)

screen = Path('lib/src/supervisor_center/supervisor_center_screen.dart')
text = screen.read_text()

# Overview: only jobs that actually had hours in selected period.
text = text.replace(
"""    final rankedJobs = [...state.jobs]\n      ..sort(\n""",
"""    final rankedJobs = state.jobs\n        .where((job) => (hoursByJob[job.id] ?? 0) > 0)\n        .toList(growable: false)\n      ..sort(\n""",1)

# KPI 'active jobs' means jobs with hours in period, per approved UX language.
text = text.replace(
"""    final activeJobs = state.jobs\n        .where((job) => job.status == JobStatus.active)\n        .length;\n    final jobsWithHours = hoursByJob.values.where((value) => value > 0).length;\n""",
"""    final activeJobs = hoursByJob.values.where((value) => value > 0).length;\n    final jobsWithHours = activeJobs;\n""",1)

# Replace horizontal chart with vertical columns, removing duplicated secondary job name.
start = text.index('final class _JobsHoursChart extends StatelessWidget {')
end = text.index('\nbool _entryInJobsOverviewPeriod(', start)
new_chart = r'''final class _JobsHoursChart extends StatelessWidget {
  const _JobsHoursChart({
    required this.jobs,
    required this.hoursByJob,
    required this.onOpenJob,
  });

  final List<SupervisorJob> jobs;
  final Map<String, double> hoursByJob;
  final ValueChanged<SupervisorJob> onOpenJob;

  @override
  Widget build(BuildContext context) {
    final maxHours = jobs.fold<double>(
      0,
      (max, job) =>
          (hoursByJob[job.id] ?? 0) > max ? (hoursByJob[job.id] ?? 0) : max,
    );
    if (jobs.isEmpty) {
      return const JkddEmptyState(
        icon: Icons.bar_chart_outlined,
        title: 'Nenhuma obra com horas neste período',
        message: 'Altere o período para consultar outras obras.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Horas por obra', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 270,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final job in jobs)
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => onOpenJob(job),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: SizedBox(
                        width: 82,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              _hours(hoursByJob[job.id] ?? 0),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                            const SizedBox(height: 6),
                            Container(
                              width: 48,
                              height: maxHours <= 0
                                  ? 6
                                  : 24 + 150 * (hoursByJob[job.id] ?? 0) / maxHours,
                              decoration: BoxDecoration(
                                color: AppColors.blue.withValues(alpha: 0.55),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(10),
                                ),
                                border: Border.all(color: AppColors.blue),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Obra ${job.number}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
'''
text = text[:start] + new_chart + text[end:]

# Replace entire redundant job list with a compact selector.
old_list = """        const SizedBox(height: AppSpacing.lg),\n        Row(\n          children: [\n            Expanded(\n              child: Text(\n                context.tr('jobs.listTitle'),\n                style: Theme.of(context).textTheme.titleLarge,\n              ),\n            ),\n            Text(\n              '${state.jobs.length} obras',\n              style: Theme.of(\n                context,\n              ).textTheme.bodyMedium?.copyWith(color: AppColors.gray),\n            ),\n          ],\n        ),\n        const SizedBox(height: AppSpacing.sm),\n        Card(\n          child: SwitchListTile(\n            secondary: const Icon(Icons.admin_panel_settings_outlined),\n            title: Text(context.tr('jobs.allowSupervisorCreateJobs')),\n            subtitle: Text(\n              state.allowSupervisorCreateJobs\n                  ? context.tr('common.yes')\n                  : context.tr('common.no'),\n            ),\n            value: state.allowSupervisorCreateJobs,\n            onChanged: state.currentRole == PilotRole.supervisor\n                ? null\n                : (value) => ref\n                      .read(supervisorCenterProvider.notifier)\n                      .setSupervisorCreateJobs(value),\n          ),\n        ),\n        const SizedBox(height: AppSpacing.md),\n        for (final job in state.jobs) _JobListCard(job: job),\n"""
new_list = """        const SizedBox(height: AppSpacing.lg),\n        Card(\n          child: Padding(\n            padding: const EdgeInsets.all(AppSpacing.lg),\n            child: DropdownButtonFormField<String>(\n              decoration: const InputDecoration(\n                labelText: 'Selecionar obra',\n                prefixIcon: Icon(Icons.search_outlined),\n              ),\n              items: [\n                for (final job in state.jobs)\n                  DropdownMenuItem(\n                    value: job.id,\n                    child: Text('Obra ${job.number} — ${job.address}'),\n                  ),\n              ],\n              onChanged: (jobId) {\n                if (jobId != null) _openJob(context, jobId);\n              },\n            ),\n          ),\n        ),\n"""
if old_list not in text:
    raise SystemExit('overview list block not found')
text = text.replace(old_list, new_list, 1)

# Replace _JobHours with stateful filtering + interactive cards + direct approval.
start = text.index('final class _JobHours extends ConsumerWidget {')
end = text.index('\nfinal class _JobHistory extends ConsumerWidget {', start)
new_job_hours = r'''enum _JobHoursFilter { today, all, approved, pending }

final class _JobHours extends ConsumerStatefulWidget {
  const _JobHours({required this.job});

  final SupervisorJob job;

  @override
  ConsumerState<_JobHours> createState() => _JobHoursState();
}

final class _JobHoursState extends ConsumerState<_JobHours> {
  _JobHoursFilter _filter = _JobHoursFilter.all;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(supervisorCenterProvider);
    final entries = state.timeEntries
        .where((entry) => entry.jobId == widget.job.id)
        .toList(growable: false);
    final todayEntries = entries.where(
      (entry) => _sameDay(entry.date, DateTime.now()),
    );
    final approvedEntries = entries.where(
      (entry) => entry.status == TimeReviewStatus.approved,
    );
    final pendingEntries = entries.where(
      (entry) => entry.status != TimeReviewStatus.approved && entry.clockOut != null,
    );
    final visibleEntries = entries.where((entry) => switch (_filter) {
      _JobHoursFilter.today => _sameDay(entry.date, DateTime.now()),
      _JobHoursFilter.all => true,
      _JobHoursFilter.approved => entry.status == TimeReviewStatus.approved,
      _JobHoursFilter.pending => entry.status != TimeReviewStatus.approved && entry.clockOut != null,
    }).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ResponsiveGrid(
          minWidth: 170,
          children: [
            _InteractiveSummaryCard(
              label: context.tr('supervisor.hoursToday'),
              value: _hours(todayEntries.fold<double>(0, (sum, entry) => sum + _entryHoursValue(entry))),
              icon: Icons.today_outlined,
              color: AppColors.blue,
              onTap: () => setState(() => _filter = _JobHoursFilter.today),
            ),
            _InteractiveSummaryCard(
              label: context.tr('timesheet.totalHours'),
              value: _hours(entries.fold<double>(0, (sum, entry) => sum + _entryHoursValue(entry))),
              icon: Icons.schedule_outlined,
              color: AppColors.purple,
              onTap: () => setState(() => _filter = _JobHoursFilter.all),
            ),
            _InteractiveSummaryCard(
              label: context.tr('approval.approved'),
              value: _hours(approvedEntries.fold<double>(0, (sum, entry) => sum + _entryHoursValue(entry))),
              icon: Icons.verified_outlined,
              color: AppColors.green,
              onTap: () => setState(() => _filter = _JobHoursFilter.approved),
            ),
            _InteractiveSummaryCard(
              label: context.tr('supervisor.pendingHours'),
              value: _hours(pendingEntries.fold<double>(0, (sum, entry) => sum + _entryHoursValue(entry))),
              icon: Icons.pending_actions_outlined,
              color: AppColors.amber,
              onTap: () => setState(() => _filter = _JobHoursFilter.pending),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(child: Text('Mostrando: ${_jobHoursFilterLabel(_filter)}')),
            if (_filter != _JobHoursFilter.all)
              TextButton(
                onPressed: () => setState(() => _filter = _JobHoursFilter.all),
                child: const Text('Limpar filtro'),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (pendingEntries.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () => ref
                  .read(supervisorCenterProvider.notifier)
                  .approveAllValidForJob(widget.job.id),
              icon: const Icon(Icons.done_all),
              label: Text(context.tr('approval.approveAllValid')),
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        if (visibleEntries.isEmpty)
          const JkddEmptyState(
            icon: Icons.schedule_outlined,
            title: 'Nenhum registro neste filtro',
            message: 'Escolha outro card para consultar as horas da obra.',
          )
        else
          for (final entry in visibleEntries)
            _TimeEntryCard(
              entry: entry,
              showReviewButton: true,
              trailing: Wrap(
                spacing: AppSpacing.sm,
                children: [
                  TextButton(
                    onPressed: () => _reviewEntry(context, ref, entry),
                    child: Text(context.tr('approval.review')),
                  ),
                  if (entry.status != TimeReviewStatus.approved)
                    FilledButton(
                      onPressed: () => ref
                          .read(supervisorCenterProvider.notifier)
                          .approveEntry(entry.id),
                      child: Text(context.tr('approval.approve')),
                    ),
                ],
              ),
            ),
      ],
    );
  }
}

String _jobHoursFilterLabel(_JobHoursFilter filter) => switch (filter) {
  _JobHoursFilter.today => 'horas de hoje',
  _JobHoursFilter.all => 'todas as horas',
  _JobHoursFilter.approved => 'horas aprovadas',
  _JobHoursFilter.pending => 'horas pendentes',
};
'''
text = text[:start] + new_job_hours + text[end:]

# Review dialog: remove break/observation/justification; add generic bonus, travel bonus and fixed 25% premium.
start = text.index('Future<void> _reviewEntry(')
end = text.index('\nFuture<void> _approveEntry(', start)
new_review = r'''Future<void> _reviewEntry(
  BuildContext context,
  WidgetRef ref,
  TimeEntry entry,
) async {
  final clockIn = TextEditingController(text: entry.clockIn);
  final clockOut = TextEditingController(text: entry.clockOut ?? '');
  final bonus = TextEditingController(text: entry.extraBonusHours.toStringAsFixed(2));
  final travel = TextEditingController(text: entry.travelBonusHours.toStringAsFixed(2));
  var premium25 = entry.payPremiumPercent == 25;
  final action = await showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(context.tr('approval.reviewEntry')),
        content: SizedBox(
          width: 540,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: clockIn,
                  decoration: InputDecoration(labelText: context.tr('approval.clockIn')),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: clockOut,
                  decoration: InputDecoration(labelText: context.tr('approval.clockOut')),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: bonus,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Horas bônus adicionais',
                    helperText: 'Ex.: 1.00 para adicionar uma hora bônus.',
                    prefixIcon: Icon(Icons.add_circle_outline),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: travel,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Travel Bonus — horas de viagem',
                    helperText: 'Informe a quantidade de horas de viagem.',
                    prefixIcon: Icon(Icons.route_outlined),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: premium25,
                  onChanged: (value) => setDialogState(() => premium25 = value),
                  title: const Text('Adicional salarial +25%'),
                  subtitle: const Text('Aplica 25% somente a este registro.'),
                  secondary: const Icon(Icons.workspace_premium_outlined),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'correction'),
            child: Text(context.tr('supervisor.requestCorrection')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'reject'),
            child: Text(context.tr('approval.reject')),
          ),
          if (entry.status != TimeReviewStatus.approved)
            FilledButton(
              onPressed: () => Navigator.pop(context, 'approve'),
              child: Text(context.tr('approval.approve')),
            ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, 'save'),
            child: Text(context.tr('approval.saveReview')),
          ),
        ],
      ),
    ),
  );
  if (action == null) return;
  try {
    final controller = ref.read(supervisorCenterProvider.notifier);
    if (action == 'reject' || action == 'correction') {
      final reason = await _textDialog(
        context,
        action == 'reject' ? context.tr('approval.rejectRecord') : context.tr('supervisor.requestCorrection'),
        action == 'reject' ? context.tr('approval.rejectionReasonRequired') : context.tr('supervisor.correctionReason'),
      );
      if (reason?.trim().isEmpty != false) return;
      if (action == 'reject') {
        controller.rejectEntry(entry.id, reason!);
      } else {
        controller.correctionRequestedBySupervisor(entry.id, reason!);
      }
      return;
    }
    controller.updateTimeEntry(
      entryId: entry.id,
      clockIn: clockIn.text.trim(),
      clockOut: clockOut.text.trim().isEmpty ? null : clockOut.text.trim(),
      breakMinutes: 0,
      travelBonusHours: double.tryParse(travel.text) ?? entry.travelBonusHours,
      extraBonusHours: double.tryParse(bonus.text) ?? entry.extraBonusHours,
      payPremiumPercent: premium25 ? 25 : 0,
      supervisorNote: entry.supervisorNote,
      justification: '',
    );
    if (action == 'approve') controller.approveEntry(entry.id);
  } on StateError catch (error) {
    if (context.mounted) _snack(context, error.message);
  } finally {
    clockIn.dispose();
    clockOut.dispose();
    bonus.dispose();
    travel.dispose();
  }
}
'''
text = text[:start] + new_review + text[end:]

# Direct approve helper: no second observation prompt.
start = text.index('Future<void> _approveEntry(')
end = text.index('\nFuture<void> _rejectEntry(', start)
new_approve = r'''Future<void> _approveEntry(
  BuildContext context,
  WidgetRef ref,
  TimeEntry entry,
) async {
  final confirmed = await _confirmDialog(
    context,
    title: context.tr('approval.confirmApprove'),
    message: context.tr('approval.approveMessage'),
    confirmLabel: context.tr('approval.approve'),
  );
  if (confirmed != true) return;
  try {
    ref.read(supervisorCenterProvider.notifier).approveEntry(entry.id);
  } on StateError catch (error) {
    if (context.mounted) _snack(context, error.message);
  }
}
'''
text = text[:start] + new_approve + text[end:]

# Generic bonus displayed and counted, no interval displayed for EWW.
text = text.replace(
"""                JkddInfoRow(\n                  label: context.tr('supervisor.interval'),\n                  value: '${entry.breakMinutes} min',\n                ),\n""","",1)
text = text.replace(
"""                JkddInfoRow(\n                  label: context.tr('approval.travelBonus'),\n                  value: '${entry.travelBonusHours.toStringAsFixed(2)} h',\n                ),\n""",
"""                JkddInfoRow(\n                  label: context.tr('approval.travelBonus'),\n                  value: '${entry.travelBonusHours.toStringAsFixed(2)} h',\n                ),\n                JkddInfoRow(\n                  label: 'Horas bônus',\n                  value: '${entry.extraBonusHours.toStringAsFixed(2)} h',\n                ),\n                if (entry.payPremiumPercent > 0)\n                  JkddInfoRow(\n                    label: 'Adicional salarial',\n                    value: '+${entry.payPremiumPercent.toStringAsFixed(0)}%',\n                  ),\n""",1)

# Add audit labels.
text = text.replace(
"""      'travelBonusHours' => context.tr('approval.travelBonus'),\n      'supervisorNote' => context.tr('supervisor.supervisorNote'),\n""",
"""      'travelBonusHours' => context.tr('approval.travelBonus'),\n      'extraBonusHours' => 'Horas bônus',\n      'payPremiumPercent' => 'Adicional salarial',\n      'supervisorNote' => context.tr('supervisor.supervisorNote'),\n""",1)

# Include extra bonus in totals and permanently ignore EWW break deductions.
text = text.replace(
"""  var minutes = end - start - entry.breakMinutes;\n  if (minutes < 0) minutes += 24 * 60;\n  return (minutes / 60) + entry.travelBonusHours;\n""",
"""  var minutes = end - start;\n  if (minutes < 0) minutes += 24 * 60;\n  return (minutes / 60) + entry.travelBonusHours + entry.extraBonusHours;\n""",1)

screen.write_text(text)
