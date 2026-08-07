from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
time_screen = ROOT / 'lib/src/presentation/screens/time_records_screen.dart'
supervisor_screen = ROOT / 'lib/src/supervisor_center/supervisor_center_screen.dart'

# --- Profile simulation from Director/Supervisor login ---
text = time_screen.read_text()
text = text.replace(
    "session.user!.role != PilotRole.owner &&\n        pilotState.currentRole != session.user!.role",
    "!{PilotRole.owner, PilotRole.supervisor}.contains(session.user!.role) &&\n        pilotState.currentRole != session.user!.role",
)
text = text.replace(
    "directorTestMode:\n          ref.watch(authSessionProvider).user?.role == PilotRole.owner,",
    "directorTestMode: {PilotRole.owner, PilotRole.supervisor}.contains(\n          ref.watch(authSessionProvider).user?.role,\n        ),",
)
old_profile = """              _SettingsTile(\n                context.tr('settings.profile'),\n                Icons.person_outline,\n                context.tr('common.comingSoon'),\n              ),"""
new_profile = """              if (directorTestMode)\n                _ProfileSimulationTile(\n                  pilotState: pilotState,\n                  onChanged: onSimulationChanged,\n                )\n              else\n                _SettingsTile(\n                  context.tr('settings.profile'),\n                  Icons.person_outline,\n                  context.tr('common.comingSoon'),\n                ),"""
if old_profile not in text:
    raise SystemExit('Profile settings block not found')
text = text.replace(old_profile, new_profile, 1)
text = text.replace(
    "'Use somente o login do Diretor durante a homologação.'",
    "'Use o login do Diretor ou Supervisor para trocar o perfil durante a homologação.'",
)

marker = "final class _SettingsSection extends StatelessWidget {"
profile_widget = r'''final class _ProfileSimulationTile extends StatelessWidget {
  const _ProfileSimulationTile({
    required this.pilotState,
    required this.onChanged,
  });

  final SupervisorCenterState pilotState;
  final void Function(PilotRole role, String? userId) onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.person_search_outlined, color: AppColors.blue),
      title: const Text('Perfil'),
      subtitle: Text(
        'Simulando: ${pilotState.currentUser.name} — ${roleLabel(pilotState.currentRole)}',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (sheetContext) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.xl,
            ),
            child: _DirectorSimulationSection(
              pilotState: pilotState,
              onChanged: (role, userId) {
                onChanged(role, userId);
                Navigator.of(sheetContext).pop();
              },
            ),
          ),
        ),
      ),
    );
  }
}

'''
if marker not in text:
    raise SystemExit('SettingsSection marker not found')
text = text.replace(marker, profile_widget + marker, 1)
time_screen.write_text(text)

# --- Job dashboard: Hoje / Semana / Mês / Ano + hours by collaborator ---
s = supervisor_screen.read_text()
pattern = re.compile(
    r"final class _JobSummary extends ConsumerWidget \{.*?\n\}\n\nfinal class _JobPeopleToday",
    re.S,
)
replacement = r'''enum _JobDashboardPeriod { day, week, month, year }

final class _JobSummary extends ConsumerStatefulWidget {
  const _JobSummary({required this.job});

  final SupervisorJob job;

  @override
  ConsumerState<_JobSummary> createState() => _JobSummaryState();
}

final class _JobSummaryState extends ConsumerState<_JobSummary> {
  _JobDashboardPeriod _period = _JobDashboardPeriod.week;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(supervisorCenterProvider);
    final job = widget.job;
    final now = DateTime.now();
    final allEntries = state.timeEntries
        .where((entry) => entry.jobId == job.id)
        .toList(growable: false);
    final entries = allEntries
        .where((entry) => _entryInDashboardPeriod(entry.date, now, _period))
        .toList(growable: false);
    final approvedEntries = entries.where(
      (entry) => entry.status == TimeReviewStatus.approved,
    );
    final pendingEntries = entries.where(
      (entry) =>
          entry.status != TimeReviewStatus.approved && entry.clockOut != null,
    );
    final totalHours = entries.fold<double>(
      0,
      (sum, entry) => sum + _entryHoursValue(entry),
    );
    final approvedHours = approvedEntries.fold<double>(
      0,
      (sum, entry) => sum + _entryHoursValue(entry),
    );
    final pendingHours = pendingEntries.fold<double>(
      0,
      (sum, entry) => sum + _entryHoursValue(entry),
    );
    final hoursByUser = <String, double>{};
    for (final entry in entries) {
      hoursByUser.update(
        entry.userId,
        (value) => value + _entryHoursValue(entry),
        ifAbsent: () => _entryHoursValue(entry),
      );
    }
    final userHours = hoursByUser.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxHours = userHours.isEmpty ? 1.0 : userHours.first.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_jobDisplayName(context, job)} — Resumo',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Acompanhe horas e pessoas da obra por período.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.gray),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    _PeriodChip(
                      label: 'Hoje',
                      selected: _period == _JobDashboardPeriod.day,
                      onTap: () => setState(
                        () => _period = _JobDashboardPeriod.day,
                      ),
                    ),
                    _PeriodChip(
                      label: 'Semana',
                      selected: _period == _JobDashboardPeriod.week,
                      onTap: () => setState(
                        () => _period = _JobDashboardPeriod.week,
                      ),
                    ),
                    _PeriodChip(
                      label: 'Mês',
                      selected: _period == _JobDashboardPeriod.month,
                      onTap: () => setState(
                        () => _period = _JobDashboardPeriod.month,
                      ),
                    ),
                    _PeriodChip(
                      label: 'Ano',
                      selected: _period == _JobDashboardPeriod.year,
                      onTap: () => setState(
                        () => _period = _JobDashboardPeriod.year,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _ResponsiveGrid(
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
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bar_chart_outlined, color: AppColors.blue),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Horas por colaborador',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      _dashboardPeriodLabel(_period),
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: AppColors.gray),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                if (userHours.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    child: Text(
                      'Ainda não há horas registradas nesta obra para o período selecionado.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.gray),
                    ),
                  )
                else
                  for (final item in userHours) ...[
                    _CollaboratorHoursBar(
                      user: state.userById(item.key),
                      hours: item.value,
                      maxHours: maxHours,
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: _InfoWrap(
              children: [
                JkddInfoRow(
                  label: context.tr('supervisor.number'),
                  value: job.number,
                ),
                JkddInfoRow(
                  label: context.tr('jobs.address'),
                  value: job.address,
                ),
                JkddInfoRow(
                  label: context.tr('jobs.status'),
                  value: _jobStatusLabel(context, job.status),
                ),
                JkddInfoRow(
                  label: context.tr('supervisor.supervisor'),
                  value: state.userById(job.supervisorId).name,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

final class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      );
}

final class _CollaboratorHoursBar extends StatelessWidget {
  const _CollaboratorHoursBar({
    required this.user,
    required this.hours,
    required this.maxHours,
  });

  final PilotUser user;
  final double hours;
  final double maxHours;

  @override
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
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.gray),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              _hours(hours),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 10,
          ),
        ),
      ],
    );
  }
}

bool _entryInDashboardPeriod(
  DateTime date,
  DateTime now,
  _JobDashboardPeriod period,
) {
  final day = DateTime(date.year, date.month, date.day);
  final today = DateTime(now.year, now.month, now.day);
  return switch (period) {
    _JobDashboardPeriod.day => day == today,
    _JobDashboardPeriod.week => () {
        final start = today.subtract(Duration(days: today.weekday - 1));
        final end = start.add(const Duration(days: 7));
        return !day.isBefore(start) && day.isBefore(end);
      }(),
    _JobDashboardPeriod.month =>
      date.year == now.year && date.month == now.month,
    _JobDashboardPeriod.year => date.year == now.year,
  };
}

String _dashboardPeriodLabel(_JobDashboardPeriod period) => switch (period) {
      _JobDashboardPeriod.day => 'Hoje',
      _JobDashboardPeriod.week => 'Esta semana',
      _JobDashboardPeriod.month => 'Este mês',
      _JobDashboardPeriod.year => 'Este ano',
    };

final class _JobPeopleToday'''

s2, count = pattern.subn(replacement, s, count=1)
if count != 1:
    raise SystemExit(f'JobSummary block replacement count={count}')
supervisor_screen.write_text(s2)

print('Test 04 profile selection and job dashboard patch applied.')
