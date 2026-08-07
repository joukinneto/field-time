from pathlib import Path

path = Path('lib/src/supervisor_center/supervisor_center_screen.dart')
text = path.read_text()


def replace_once(old: str, new: str, label: str):
    global text
    if old not in text:
        raise RuntimeError(f'Pattern not found: {label}')
    text = text.replace(old, new, 1)

replace_once(
"""            _PilotFrame(child: _JobSummary(job: job)),
""",
"""            _PilotFrame(
              child: _JobSummary(
                job: job,
                onOpenHours: () => _tabController.animateTo(2),
                onOpenPeople: () => _tabController.animateTo(1),
              ),
            ),
""",
'job summary callbacks')

replace_once(
"""final class _JobSummary extends ConsumerStatefulWidget {
  const _JobSummary({required this.job});

  final SupervisorJob job;
""",
"""final class _JobSummary extends ConsumerStatefulWidget {
  const _JobSummary({
    required this.job,
    required this.onOpenHours,
    required this.onOpenPeople,
  });

  final SupervisorJob job;
  final VoidCallback onOpenHours;
  final VoidCallback onOpenPeople;
""",
'job summary constructor')

replace_once(
"""    final totalHours = entries.fold<double>(
      0,
      (sum, entry) => sum + _entryHoursValue(entry),
    );
""",
"""    final regularHours = entries.fold<double>(
      0,
      (sum, entry) => sum + _entryRegularHoursValue(entry),
    );
    final bonusHours = entries.fold<double>(
      0,
      (sum, entry) => sum + entry.travelBonusHours,
    );
    final totalHours = regularHours + bonusHours;
""",
'total regular bonus')

replace_once(
"""    final hoursByUser = <String, double>{};
    for (final entry in entries) {
      hoursByUser.update(
        entry.userId,
        (value) => value + _entryHoursValue(entry),
        ifAbsent: () => _entryHoursValue(entry),
      );
    }
""",
"""    final hoursByUser = <String, double>{};
    final regularByUser = <String, double>{};
    final bonusByUser = <String, double>{};
    for (final entry in entries) {
      hoursByUser.update(
        entry.userId,
        (value) => value + _entryHoursValue(entry),
        ifAbsent: () => _entryHoursValue(entry),
      );
      regularByUser.update(
        entry.userId,
        (value) => value + _entryRegularHoursValue(entry),
        ifAbsent: () => _entryRegularHoursValue(entry),
      );
      bonusByUser.update(
        entry.userId,
        (value) => value + entry.travelBonusHours,
        ifAbsent: () => entry.travelBonusHours,
      );
    }
""",
'user breakdown')

replace_once(
"""    final maxHours = userHours.isEmpty ? 1.0 : userHours.first.value;

    return Column(
""",
"""    final maxHours = userHours.isEmpty ? 1.0 : userHours.first.value;
    final activity = _jobActivityBuckets(entries, now, _period);

    return Column(
""",
'activity buckets')

replace_once(
"""        _ResponsiveGrid(
          minWidth: 160,
          children: [
            JkddSummaryCard(
              label: 'Horas no período',
              value: _hours(totalHours),
              icon: Icons.schedule_outlined,
              color: AppColors.blue,
            ),
            JkddSummaryCard(
              label: 'Horas aprovadas',
              value: _hours(approvedHours),
              icon: Icons.verified_outlined,
              color: AppColors.green,
            ),
            JkddSummaryCard(
              label: 'Horas pendentes',
              value: _hours(pendingHours),
              icon: Icons.pending_actions_outlined,
              color: AppColors.amber,
            ),
            JkddSummaryCard(
              label: 'Colaboradores',
              value: '${hoursByUser.length}',
              icon: Icons.groups_outlined,
              color: AppColors.purple,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
""",
"""        _ManagementMetricsGrid(
          children: [
            _InteractiveSummaryCard(
              label: 'Horas regulares',
              value: _hours(regularHours),
              icon: Icons.schedule_outlined,
              color: AppColors.blue,
              onTap: widget.onOpenHours,
            ),
            _InteractiveSummaryCard(
              label: 'Horas de bônus',
              value: _hours(bonusHours),
              icon: Icons.route_outlined,
              color: AppColors.green,
              onTap: widget.onOpenHours,
            ),
            _InteractiveSummaryCard(
              label: 'Total de horas',
              value: _hours(totalHours),
              icon: Icons.access_time_filled_outlined,
              color: AppColors.purple,
              onTap: widget.onOpenHours,
            ),
            _InteractiveSummaryCard(
              label: 'Colaboradores',
              value: '${hoursByUser.length}',
              icon: Icons.groups_outlined,
              color: AppColors.amber,
              onTap: widget.onOpenPeople,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: _JobApprovalMetric(
                    label: 'Aprovadas',
                    value: _hours(approvedHours),
                    icon: Icons.verified_outlined,
                    color: AppColors.green,
                    onTap: widget.onOpenHours,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _JobApprovalMetric(
                    label: 'Pendentes',
                    value: _hours(pendingHours),
                    icon: Icons.pending_actions_outlined,
                    color: AppColors.amber,
                    onTap: widget.onOpenHours,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _JobActivityChart(
          period: _period,
          buckets: activity,
          onTap: widget.onOpenHours,
        ),
        const SizedBox(height: AppSpacing.lg),
""",
'summary metrics')

replace_once(
"""                    _CollaboratorHoursBar(
                      user: state.userById(item.key),
                      hours: item.value,
                      maxHours: maxHours,
                    ),
""",
"""                    _CollaboratorHoursBar(
                      user: state.userById(item.key),
                      hours: item.value,
                      regularHours: regularByUser[item.key] ?? 0,
                      bonusHours: bonusByUser[item.key] ?? 0,
                      maxHours: maxHours,
                      onTap: widget.onOpenHours,
                    ),
""",
'collaborator bar args')

replace_once(
"""final class _CollaboratorHoursBar extends StatelessWidget {
  const _CollaboratorHoursBar({
    required this.user,
    required this.hours,
    required this.maxHours,
  });

  final PilotUser user;
  final double hours;
  final double maxHours;
""",
"""final class _CollaboratorHoursBar extends StatelessWidget {
  const _CollaboratorHoursBar({
    required this.user,
    required this.hours,
    required this.regularHours,
    required this.bonusHours,
    required this.maxHours,
    required this.onTap,
  });

  final PilotUser user;
  final double hours;
  final double regularHours;
  final double bonusHours;
  final double maxHours;
  final VoidCallback onTap;
""",
'collaborator bar class')

replace_once(
"""  @override
  Widget build(BuildContext context) {
    final value = maxHours <= 0 ? 0.0 : (hours / maxHours).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.name, style: Theme.of(context).textTheme.bodyLarge),
                  if (user.function?.trim().isNotEmpty == true)
                    Text(
                      user.function!,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.gray),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(_hours(hours), style: Theme.of(context).textTheme.titleSmall),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(value: value, minHeight: 10),
        ),
      ],
    );
  }
}
""",
"""  @override
  Widget build(BuildContext context) {
    final value = maxHours <= 0 ? 0.0 : (hours / maxHours).clamp(0.0, 1.0);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.name, style: Theme.of(context).textTheme.bodyLarge),
                      Text(
                        'Regular ${_hours(regularHours)} • Bônus ${_hours(bonusHours)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.gray,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Text(_hours(hours), style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, size: 18),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(value: value, minHeight: 10),
            ),
          ],
        ),
      ),
    );
  }
}
""",
'collaborator bar build')

marker = "final class _PeriodChip extends StatelessWidget {\n"
helpers = r'''final class _InteractiveSummaryCard extends StatelessWidget {
  const _InteractiveSummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(16),
    onTap: onTap,
    child: JkddSummaryCard(
      label: label,
      value: value,
      icon: icon,
      color: color,
    ),
  );
}

final class _JobApprovalMetric extends StatelessWidget {
  const _JobApprovalMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium),
                Text(value, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 18),
        ],
      ),
    ),
  );
}

final class _JobActivityBucket {
  const _JobActivityBucket(this.label, this.hours);

  final String label;
  final double hours;
}

final class _JobActivityChart extends StatelessWidget {
  const _JobActivityChart({
    required this.period,
    required this.buckets,
    required this.onTap,
  });

  final _JobDashboardPeriod period;
  final List<_JobActivityBucket> buckets;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final maxHours = buckets.fold<double>(
      0,
      (current, bucket) => bucket.hours > current ? bucket.hours : current,
    );
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.insights_outlined, color: AppColors.blue),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Evolução das horas',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Text(
                    _dashboardPeriodLabel(period),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.gray,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              if (buckets.every((bucket) => bucket.hours == 0))
                Text(
                  'Sem horas registradas neste período.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.gray,
                  ),
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final bucket in buckets)
                        Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.sm),
                          child: SizedBox(
                            width: 48,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  _hours(bucket.hours),
                                  style: Theme.of(context).textTheme.labelSmall,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  height: maxHours <= 0
                                      ? 4
                                      : 18 + (92 * bucket.hours / maxHours),
                                  width: 28,
                                  decoration: BoxDecoration(
                                    color: AppColors.blue.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.blue),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  bucket.label,
                                  style: Theme.of(context).textTheme.labelSmall,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

List<_JobActivityBucket> _jobActivityBuckets(
  List<TimeEntry> entries,
  DateTime now,
  _JobDashboardPeriod period,
) {
  double hoursOn(DateTime day) => entries
      .where((entry) => _sameDay(entry.date, day))
      .fold<double>(0, (sum, entry) => sum + _entryHoursValue(entry));

  if (period == _JobDashboardPeriod.day) {
    return [_JobActivityBucket('Hoje', hoursOn(now))];
  }
  if (period == _JobDashboardPeriod.week) {
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(Duration(days: today.weekday - 1));
    const labels = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
    return List.generate(7, (index) {
      final day = start.add(Duration(days: index));
      return _JobActivityBucket(labels[index], hoursOn(day));
    });
  }
  if (period == _JobDashboardPeriod.month) {
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final bucketCount = ((daysInMonth + 6) / 7).floor();
    return List.generate(bucketCount, (index) {
      final startDay = index * 7 + 1;
      final endDay = (startDay + 6).clamp(1, daysInMonth);
      var hours = 0.0;
      for (var day = startDay; day <= endDay; day++) {
        hours += hoursOn(DateTime(now.year, now.month, day));
      }
      return _JobActivityBucket('S${index + 1}', hours);
    });
  }

  const monthLabels = [
    'Jan',
    'Fev',
    'Mar',
    'Abr',
    'Mai',
    'Jun',
    'Jul',
    'Ago',
    'Set',
    'Out',
    'Nov',
    'Dez',
  ];
  return List.generate(12, (index) {
    final month = index + 1;
    final hours = entries
        .where((entry) => entry.date.year == now.year && entry.date.month == month)
        .fold<double>(0, (sum, entry) => sum + _entryHoursValue(entry));
    return _JobActivityBucket(monthLabels[index], hours);
  });
}

'''
replace_once(marker, helpers + marker, 'dashboard helper widgets')

needle = "double _entryHoursValue(TimeEntry entry) {\n"
if needle not in text:
    raise RuntimeError('Pattern not found: entry hours helper')
text = text.replace(
    needle,
    "double _entryRegularHoursValue(TimeEntry entry) =>\n    (_entryHoursValue(entry) - entry.travelBonusHours).clamp(0.0, double.infinity);\n\n" + needle,
    1,
)

path.write_text(text)
