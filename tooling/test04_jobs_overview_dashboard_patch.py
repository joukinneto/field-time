from pathlib import Path

path = Path('lib/src/supervisor_center/supervisor_center_screen.dart')
text = path.read_text()
old = '''final class JobsManagementView extends ConsumerWidget {
  const JobsManagementView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(supervisorCenterProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        JkddSectionHeader(
          title: context.tr('jobs.listTitle'),
          subtitle: context.tr('jobs.fixedTeamsDisabled'),
          trailing: FilledButton.icon(
            onPressed: state.hasPermission(PilotPermission.createJob)
                ? () => _newJob(context, ref)
                : null,
            icon: const Icon(Icons.add),
            label: Text(context.tr('jobs.newJob')),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: SwitchListTile(
            secondary: const Icon(Icons.admin_panel_settings_outlined),
            title: Text(context.tr('jobs.allowSupervisorCreateJobs')),
            subtitle: Text(
              state.allowSupervisorCreateJobs
                  ? context.tr('common.yes')
                  : context.tr('common.no'),
            ),
            value: state.allowSupervisorCreateJobs,
            onChanged: state.currentRole == PilotRole.supervisor
                ? null
                : (value) => ref
                      .read(supervisorCenterProvider.notifier)
                      .setSupervisorCreateJobs(value),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final job in state.jobs) _JobListCard(job: job),
      ],
    );
  }
}
'''
new = '''enum _JobsOverviewPeriod { day, week, month, year, all }

final class JobsManagementView extends ConsumerStatefulWidget {
  const JobsManagementView({super.key});

  @override
  ConsumerState<JobsManagementView> createState() => _JobsManagementViewState();
}

final class _JobsManagementViewState extends ConsumerState<JobsManagementView> {
  _JobsOverviewPeriod _period = _JobsOverviewPeriod.week;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(supervisorCenterProvider);
    final now = DateTime.now();
    final entries = state.timeEntries
        .where((entry) => _entryInJobsOverviewPeriod(entry.date, now, _period))
        .toList(growable: false);
    final hoursByJob = <String, double>{};
    for (final entry in entries) {
      hoursByJob.update(
        entry.jobId,
        (value) => value + _entryHoursValue(entry),
        ifAbsent: () => _entryHoursValue(entry),
      );
    }
    final rankedJobs = [...state.jobs]
      ..sort(
        (left, right) => (hoursByJob[right.id] ?? 0)
            .compareTo(hoursByJob[left.id] ?? 0),
      );
    final totalHours = hoursByJob.values.fold<double>(0, (sum, value) => sum + value);
    final activeJobs = state.jobs.where((job) => job.status == JobStatus.active).length;
    final jobsWithHours = hoursByJob.values.where((value) => value > 0).length;
    final pendingHours = entries
        .where((entry) => entry.status != TimeReviewStatus.approved && entry.clockOut != null)
        .fold<double>(0, (sum, entry) => sum + _entryHoursValue(entry));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        JkddSectionHeader(
          title: 'Visão geral das obras',
          subtitle: 'Horas consumidas por obra e período.',
          trailing: FilledButton.icon(
            onPressed: state.hasPermission(PilotPermission.createJob)
                ? () => _newJob(context, ref)
                : null,
            icon: const Icon(Icons.add),
            label: Text(context.tr('jobs.newJob')),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.query_stats_outlined, color: AppColors.blue),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Horas por obra',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    Text(
                      _jobsOverviewPeriodLabel(_period),
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(color: AppColors.gray),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<_JobsOverviewPeriod>(
                    selected: {_period},
                    onSelectionChanged: (selection) =>
                        setState(() => _period = selection.first),
                    segments: const [
                      ButtonSegment(value: _JobsOverviewPeriod.day, label: Text('Dia')),
                      ButtonSegment(value: _JobsOverviewPeriod.week, label: Text('Semana')),
                      ButtonSegment(value: _JobsOverviewPeriod.month, label: Text('Mês')),
                      ButtonSegment(value: _JobsOverviewPeriod.year, label: Text('Ano')),
                      ButtonSegment(value: _JobsOverviewPeriod.all, label: Text('Todo período')),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _ResponsiveGrid(
                  minWidth: 170,
                  children: [
                    JkddSummaryCard(
                      label: 'Horas no período',
                      value: _hours(totalHours),
                      icon: Icons.schedule_outlined,
                      color: AppColors.blue,
                    ),
                    JkddSummaryCard(
                      label: 'Obras em andamento',
                      value: '$activeJobs',
                      icon: Icons.apartment_outlined,
                      color: AppColors.green,
                    ),
                    JkddSummaryCard(
                      label: 'Obras com horas',
                      value: '$jobsWithHours',
                      icon: Icons.bar_chart_outlined,
                      color: AppColors.purple,
                    ),
                    JkddSummaryCard(
                      label: 'Horas pendentes',
                      value: _hours(pendingHours),
                      icon: Icons.pending_actions_outlined,
                      color: AppColors.amber,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                if (rankedJobs.isEmpty)
                  const JkddEmptyState(
                    icon: Icons.apartment_outlined,
                    title: 'Nenhuma obra cadastrada',
                    message: 'Cadastre uma obra para começar a acompanhar as horas.',
                  )
                else
                  _JobsHoursChart(
                    jobs: rankedJobs,
                    hoursByJob: hoursByJob,
                    onOpenJob: (job) => _openJob(context, job.id),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: Text(
                context.tr('jobs.listTitle'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Text(
              '${state.jobs.length} obras',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.gray),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: SwitchListTile(
            secondary: const Icon(Icons.admin_panel_settings_outlined),
            title: Text(context.tr('jobs.allowSupervisorCreateJobs')),
            subtitle: Text(
              state.allowSupervisorCreateJobs
                  ? context.tr('common.yes')
                  : context.tr('common.no'),
            ),
            value: state.allowSupervisorCreateJobs,
            onChanged: state.currentRole == PilotRole.supervisor
                ? null
                : (value) => ref
                      .read(supervisorCenterProvider.notifier)
                      .setSupervisorCreateJobs(value),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final job in state.jobs) _JobListCard(job: job),
      ],
    );
  }
}

final class _JobsHoursChart extends StatelessWidget {
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
      (max, job) => (hoursByJob[job.id] ?? 0) > max ? (hoursByJob[job.id] ?? 0) : max,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Comparativo de horas por obra',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.md),
        for (final job in jobs)
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onOpenJob(job),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: [
                  SizedBox(
                    width: 150,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Obra ${job.number}',
                          style: Theme.of(context).textTheme.titleSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (job.name.trim().isNotEmpty)
                          Text(
                            job.name,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.gray),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final hours = hoursByJob[job.id] ?? 0;
                        final fraction = maxHours <= 0 ? 0.0 : (hours / maxHours).clamp(0.0, 1.0);
                        return Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            Container(
                              height: 24,
                              decoration: BoxDecoration(
                                color: AppColors.blue.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              height: 24,
                              width: constraints.maxWidth * fraction,
                              decoration: BoxDecoration(
                                color: AppColors.blue.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  SizedBox(
                    width: 88,
                    child: Text(
                      _hours(hoursByJob[job.id] ?? 0),
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

bool _entryInJobsOverviewPeriod(
  DateTime date,
  DateTime now,
  _JobsOverviewPeriod period,
) {
  if (period == _JobsOverviewPeriod.all) return true;
  final day = DateTime(date.year, date.month, date.day);
  final today = DateTime(now.year, now.month, now.day);
  return switch (period) {
    _JobsOverviewPeriod.day => day == today,
    _JobsOverviewPeriod.week => () {
      final start = today.subtract(Duration(days: today.weekday - 1));
      final end = start.add(const Duration(days: 7));
      return !day.isBefore(start) && day.isBefore(end);
    }(),
    _JobsOverviewPeriod.month => date.year == now.year && date.month == now.month,
    _JobsOverviewPeriod.year => date.year == now.year,
    _JobsOverviewPeriod.all => true,
  };
}

String _jobsOverviewPeriodLabel(_JobsOverviewPeriod period) => switch (period) {
  _JobsOverviewPeriod.day => 'Hoje',
  _JobsOverviewPeriod.week => 'Esta semana',
  _JobsOverviewPeriod.month => 'Este mês',
  _JobsOverviewPeriod.year => 'Este ano',
  _JobsOverviewPeriod.all => 'Todo período',
};
'''
if old not in text:
    raise SystemExit('JobsManagementView block not found')
path.write_text(text.replace(old, new, 1))
