import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jkdd_field_time_records_production/core/theme/app_colors.dart';
import 'package:jkdd_field_time_records_production/core/theme/app_spacing.dart';
import 'package:jkdd_field_time_records_production/src/supervisor_center/supervisor_center_controller.dart';
import 'package:jkdd_field_time_records_production/src/supervisor_center/supervisor_center_models.dart';
import 'package:jkdd_field_time_records_production/shared/widgets/jkdd_empty_state.dart';
import 'package:jkdd_field_time_records_production/shared/widgets/jkdd_info_row.dart';
import 'package:jkdd_field_time_records_production/shared/widgets/jkdd_section_header.dart';
import 'package:jkdd_field_time_records_production/shared/widgets/jkdd_status_chip.dart';
import 'package:jkdd_field_time_records_production/shared/widgets/jkdd_summary_card.dart';

enum SupervisorCenterView {
  dashboard,
  approveTime,
  schedule,
  jobs,
  peopleByJob,
  workingNow,
}

final class SupervisorCenterScreen extends ConsumerStatefulWidget {
  const SupervisorCenterScreen({super.key});

  @override
  ConsumerState<SupervisorCenterScreen> createState() =>
      _SupervisorCenterScreenState();
}

final class _SupervisorCenterScreenState
    extends ConsumerState<SupervisorCenterScreen> {
  SupervisorCenterView _view = SupervisorCenterView.dashboard;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(supervisorCenterProvider);
    if (!state.hasPermission(PilotPermission.viewManagement)) {
      return const WorkerPilotScreen();
    }
    return _PilotFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          JkddSectionHeader(
            title: _title(_view),
            subtitle:
                'Supervisor Center / Central do Supervisor / Centro del Supervisor',
            trailing: _view == SupervisorCenterView.dashboard
                ? null
                : TextButton.icon(
                    onPressed: () =>
                        setState(() => _view = SupervisorCenterView.dashboard),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Gestao'),
                  ),
          ),
          const SizedBox(height: AppSpacing.lg),
          switch (_view) {
            SupervisorCenterView.dashboard => _ManagementDashboard(
                onOpen: (view) => setState(() => _view = view),
              ),
            SupervisorCenterView.approveTime => const ApproveTimeView(),
            SupervisorCenterView.schedule => const ScheduleView(),
            SupervisorCenterView.jobs => const JobsManagementView(),
            SupervisorCenterView.peopleByJob => const PeopleByJobView(),
            SupervisorCenterView.workingNow => const WorkingNowView(),
          },
        ],
      ),
    );
  }

  String _title(SupervisorCenterView view) => switch (view) {
        SupervisorCenterView.dashboard => 'Gestao / Management / Gestion',
        SupervisorCenterView.approveTime =>
          'Aprovar Horas / Approve Time / Aprobar Horas',
        SupervisorCenterView.schedule =>
          'Programacao / Schedule / Programacion',
        SupervisorCenterView.jobs => 'Obras / Jobs / Obras',
        SupervisorCenterView.peopleByJob => 'Pessoas por Obra',
        SupervisorCenterView.workingNow => 'Trabalhando Agora',
      };
}

final class WorkerPilotScreen extends ConsumerWidget {
  const WorkerPilotScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(supervisorCenterProvider);
    final user = state.currentUser;
    final entries =
        state.timeEntries.where((entry) => entry.userId == user.id).toList();
    final assignments =
        state.assignments.where((item) => item.userId == user.id).toList();
    return _PilotFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          JkddSectionHeader(
            title: 'Field Time',
            subtitle: '${user.name} - ${roleLabel(user.role)} pilot mode',
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              JkddStatusChip(
                label: roleLabel(user.role),
                icon: user.isContractor
                    ? Icons.engineering_outlined
                    : Icons.badge_outlined,
                tone: user.isContractor
                    ? JkddStatusTone.info
                    : JkddStatusTone.success,
              ),
              const JkddStatusChip(
                label: 'Gestao indisponivel',
                icon: Icons.lock_outline,
                tone: JkddStatusTone.neutral,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          _ResponsiveGrid(
            minWidth: 230,
            children: [
              _ActionCard(
                title: 'Registrar entrada',
                subtitle: 'Clock in',
                icon: Icons.play_circle_outline,
                onTap: () => _snack(context, 'Entrada simulada no piloto.'),
              ),
              _ActionCard(
                title: 'Registrar saida',
                subtitle: 'Clock out and send hours',
                icon: Icons.stop_circle_outlined,
                onTap: () => _submitOwnTime(context, ref),
              ),
              _ActionCard(
                title: 'Iniciar intervalo',
                subtitle: 'Break start',
                icon: Icons.pause_circle_outline,
                onTap: () => _snack(context, 'Intervalo iniciado no piloto.'),
              ),
              _ActionCard(
                title: 'Finalizar intervalo',
                subtitle: 'Break end',
                icon: Icons.restart_alt,
                onTap: () => _snack(context, 'Intervalo finalizado no piloto.'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          const JkddSectionHeader(
            title: 'Minha obra de hoje',
            subtitle: 'Minha programacao, minhas horas e correcoes.',
          ),
          const SizedBox(height: AppSpacing.md),
          for (final assignment in assignments)
            _AssignmentCard(assignment: assignment),
          const SizedBox(height: AppSpacing.lg),
          if (entries.isEmpty)
            const JkddEmptyState(
              icon: Icons.table_chart_outlined,
              title: 'Sem horas enviadas',
              message: 'Registros do perfil atual aparecem aqui.',
            )
          else
            for (final entry in entries)
              _TimeEntryCard(
                entry: entry,
                showReviewButton: false,
                trailing: TextButton.icon(
                  onPressed: entry.status == TimeReviewStatus.approved
                      ? null
                      : () => _requestOwnCorrection(context, ref, entry.id),
                  icon: const Icon(Icons.edit_note_outlined),
                  label: const Text('Solicitar correcao'),
                ),
              ),
        ],
      ),
    );
  }

  Future<void> _submitOwnTime(BuildContext context, WidgetRef ref) async {
    final note = await _textDialog(context, 'Observacao', 'Nota opcional');
    if (note == null) return;
    ref
        .read(supervisorCenterProvider.notifier)
        .submitOwnTime(clockOut: '5:00 PM', note: note);
    if (context.mounted) _snack(context, 'Horas enviadas.');
  }

  Future<void> _requestOwnCorrection(
    BuildContext context,
    WidgetRef ref,
    String entryId,
  ) async {
    final reason =
        await _textDialog(context, 'Solicitar correcao', 'Motivo da correcao');
    if (reason?.trim().isEmpty != false) return;
    ref
        .read(supervisorCenterProvider.notifier)
        .requestCorrection(entryId, reason!);
  }
}

final class PilotProfileSelector extends ConsumerWidget {
  const PilotProfileSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(supervisorCenterProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Modo de teste',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<PilotRole>(
              initialValue: state.currentRole,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.manage_accounts_outlined),
              ),
              items: const [
                DropdownMenuItem(
                  value: PilotRole.supervisor,
                  child: Text('Supervisor'),
                ),
                DropdownMenuItem(
                  value: PilotRole.employee,
                  child: Text('Employee'),
                ),
                DropdownMenuItem(
                  value: PilotRole.contractor,
                  child: Text('Contractor'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                ref.read(supervisorCenterProvider.notifier).setRole(value);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'A interface atualiza imediatamente conforme RBAC.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.gray),
            ),
          ],
        ),
      ),
    );
  }
}

final class _ManagementDashboard extends ConsumerWidget {
  const _ManagementDashboard({required this.onOpen});

  final ValueChanged<SupervisorCenterView> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(supervisorCenterProvider);
    final pending = state.timeEntries
        .where((entry) => entry.status == TimeReviewStatus.pending)
        .length;
    final working =
        state.timeEntries.where((entry) => entry.clockOut == null).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ResponsiveGrid(
          minWidth: 180,
          children: [
            JkddSummaryCard(
              label: 'Horas pendentes',
              value: '$pending',
              icon: Icons.pending_actions,
              color: AppColors.amber,
            ),
            JkddSummaryCard(
              label: 'Obras ativas',
              value:
                  '${state.jobs.where((job) => job.status == JobStatus.active).length}',
              icon: Icons.apartment,
              color: AppColors.blue,
            ),
            JkddSummaryCard(
              label: 'Trabalhando agora',
              value: '$working',
              icon: Icons.groups_outlined,
              color: AppColors.green,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        _ResponsiveGrid(
          minWidth: 240,
          children: [
            _ActionCard(
              title: 'Aprovar Horas',
              subtitle: 'Review submitted records',
              icon: Icons.fact_check_outlined,
              onTap: () => onOpen(SupervisorCenterView.approveTime),
            ),
            _ActionCard(
              title: 'Programacao',
              subtitle: 'Supervisor daily route',
              icon: Icons.event_note_outlined,
              onTap: () => onOpen(SupervisorCenterView.schedule),
            ),
            _ActionCard(
              title: 'Obras',
              subtitle: 'Jobs and job details',
              icon: Icons.apartment_outlined,
              onTap: () => onOpen(SupervisorCenterView.jobs),
            ),
            _ActionCard(
              title: 'Pessoas por Obra',
              subtitle: 'Daily job allocation',
              icon: Icons.assignment_ind_outlined,
              onTap: () => onOpen(SupervisorCenterView.peopleByJob),
            ),
            _ActionCard(
              title: 'Trabalhando Agora',
              subtitle: 'Open clock-ins',
              icon: Icons.engineering_outlined,
              onTap: () => onOpen(SupervisorCenterView.workingNow),
            ),
          ],
        ),
      ],
    );
  }
}

final class ApproveTimeView extends ConsumerWidget {
  const ApproveTimeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(supervisorCenterProvider);
    final entries = state.timeEntries
        .where((entry) => entry.status != TimeReviewStatus.working)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in entries)
          _TimeEntryCard(
            entry: entry,
            showReviewButton: true,
            trailing: FilledButton.icon(
              onPressed: () => _reviewEntry(context, ref, entry),
              icon: const Icon(Icons.rate_review_outlined),
              label: const Text('Revisar'),
            ),
          ),
        if (entries.isEmpty)
          const JkddEmptyState(
            icon: Icons.fact_check_outlined,
            title: 'Sem registros enviados',
            message:
                'Registros pendentes de Employee e Contractor aparecem aqui.',
          ),
      ],
    );
  }
}

final class ScheduleView extends ConsumerStatefulWidget {
  const ScheduleView({super.key});

  @override
  ConsumerState<ScheduleView> createState() => _ScheduleViewState();
}

final class _ScheduleViewState extends ConsumerState<ScheduleView> {
  ScheduleFilter _filter = ScheduleFilter.today;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(supervisorCenterProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: SegmentedButton<ScheduleFilter>(
              selected: {_filter},
              onSelectionChanged: (value) =>
                  setState(() => _filter = value.first),
              segments: const [
                ButtonSegment(value: ScheduleFilter.today, label: Text('Hoje')),
                ButtonSegment(
                    value: ScheduleFilter.week, label: Text('Semana')),
                ButtonSegment(
                  value: ScheduleFilter.calendar,
                  label: Text('Calendario'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final item in state.schedules) _ScheduleCard(schedule: item),
      ],
    );
  }
}

final class JobsManagementView extends ConsumerWidget {
  const JobsManagementView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(supervisorCenterProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        JkddSectionHeader(
          title: 'Lista de obras',
          subtitle: 'Sem equipes fixas: alocacao por data e obra.',
          trailing: FilledButton.icon(
            onPressed: state.hasPermission(PilotPermission.createJob)
                ? () => _newJob(context, ref)
                : null,
            icon: const Icon(Icons.add),
            label: const Text('Nova Obra'),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: SwitchListTile(
            secondary: const Icon(Icons.admin_panel_settings_outlined),
            title: const Text('Permitir que Supervisor cadastre obras'),
            subtitle: Text(state.allowSupervisorCreateJobs ? 'Sim' : 'Nao'),
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

final class JobDetailScreen extends ConsumerStatefulWidget {
  const JobDetailScreen({super.key, required this.jobId});

  final String jobId;

  @override
  ConsumerState<JobDetailScreen> createState() => _JobDetailScreenState();
}

final class _JobDetailScreenState extends ConsumerState<JobDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(supervisorCenterProvider);
    final job = state.jobById(widget.jobId);
    return Scaffold(
      appBar: AppBar(
        title: Text(job.displayName),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Resumo'),
            Tab(text: 'Pessoas de Hoje'),
            Tab(text: 'Horas'),
            Tab(text: 'Historico'),
            Tab(text: 'Informacoes'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _PilotFrame(child: _JobSummary(job: job)),
            _PilotFrame(child: _JobPeopleToday(job: job)),
            _PilotFrame(child: _JobHours(job: job)),
            _PilotFrame(child: _JobHistory(job: job)),
            _PilotFrame(child: _JobInfo(job: job)),
          ],
        ),
      ),
    );
  }
}

final class PeopleByJobView extends ConsumerWidget {
  const PeopleByJobView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(supervisorCenterProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _FilterCard(labels: ['Data', 'Obra', 'Pessoa', 'Status']),
        const SizedBox(height: AppSpacing.md),
        for (final job in state.jobs)
          Card(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(job.displayName,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  const Text('Alocacao de pessoas por data e obra.'),
                  const Divider(height: 24),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      Chip(
                        label: Text(
                          '${_assignmentsFor(state, job.id).length} pessoas programadas',
                        ),
                      ),
                      Chip(
                        label: Text(
                          '${_assignmentsFor(state, job.id).where((a) => a.status == AssignmentStatus.working).length} trabalhando',
                        ),
                      ),
                      Chip(
                        label: Text(
                          '${_assignmentsFor(state, job.id).where((a) => a.status == AssignmentStatus.noEntry).length} sem entrada',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

final class WorkingNowView extends ConsumerWidget {
  const WorkingNowView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(supervisorCenterProvider);
    final open = state.timeEntries.where((entry) => entry.clockOut == null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in open)
          _TimeEntryCard(
            entry: entry,
            showReviewButton: false,
            trailing: Wrap(
              spacing: AppSpacing.sm,
              children: [
                TextButton(
                  onPressed: () => _reviewEntry(context, ref, entry),
                  child: const Text('Ver Registro'),
                ),
                FilledButton(
                  onPressed: () => _openJob(context, entry.jobId),
                  child: const Text('Ver Obra'),
                ),
              ],
            ),
          ),
        if (open.isEmpty)
          const JkddEmptyState(
            icon: Icons.engineering_outlined,
            title: 'Ninguem trabalhando agora',
            message: 'Entradas abertas aparecem aqui.',
          ),
      ],
    );
  }
}

final class _TimeEntryCard extends ConsumerWidget {
  const _TimeEntryCard({
    required this.entry,
    required this.showReviewButton,
    this.trailing,
  });

  final TimeEntry entry;
  final bool showReviewButton;
  final Widget? trailing;

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
                  child: Text(user.name,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                _StatusChip(status: entry.status),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                Chip(label: Text(roleLabel(user.role))),
                Chip(label: Text(job.displayName)),
                Chip(label: Text(job.city)),
              ],
            ),
            const Divider(height: 28),
            _InfoWrap(
              children: [
                JkddInfoRow(label: 'Data', value: _date(entry.date)),
                JkddInfoRow(label: 'Entrada', value: entry.clockIn),
                JkddInfoRow(label: 'Saida', value: entry.clockOut ?? 'Aberta'),
                JkddInfoRow(
                  label: 'Intervalo',
                  value: '${entry.breakMinutes} min',
                ),
                JkddInfoRow(label: 'Total', value: _entryHours(entry)),
                JkddInfoRow(
                  label: 'Travel Bonus',
                  value: '${entry.travelBonusHours.toStringAsFixed(2)} h',
                ),
              ],
            ),
            if (entry.employeeNote.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text('Observacao do funcionario: ${entry.employeeNote}'),
            ],
            if (entry.supervisorNote.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text('Observacao supervisor: ${entry.supervisorNote}'),
            ],
            if (trailing != null) ...[
              const SizedBox(height: AppSpacing.md),
              Align(alignment: Alignment.centerRight, child: trailing!),
            ],
          ],
        ),
      ),
    );
  }
}

final class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final TimeReviewStatus status;

  @override
  Widget build(BuildContext context) => JkddStatusChip(
        label: reviewStatusLabel(status),
        icon: switch (status) {
          TimeReviewStatus.approved => Icons.check_circle_outline,
          TimeReviewStatus.rejected => Icons.cancel_outlined,
          TimeReviewStatus.correctionRequested => Icons.edit_note_outlined,
          TimeReviewStatus.closed => Icons.lock_outline,
          TimeReviewStatus.working => Icons.play_circle_outline,
          _ => Icons.pending_actions,
        },
        tone: switch (status) {
          TimeReviewStatus.approved => JkddStatusTone.success,
          TimeReviewStatus.rejected => JkddStatusTone.danger,
          TimeReviewStatus.underReview => JkddStatusTone.info,
          TimeReviewStatus.closed => JkddStatusTone.neutral,
          TimeReviewStatus.working => JkddStatusTone.success,
          _ => JkddStatusTone.warning,
        },
      );
}

final class _ScheduleCard extends ConsumerWidget {
  const _ScheduleCard({required this.schedule});

  final SupervisorSchedule schedule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(supervisorCenterProvider);
    final job = state.jobById(schedule.jobId);
    final people =
        state.assignments.where((item) => item.jobId == job.id).length;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: ListTile(
        leading: const Icon(Icons.event_note_outlined, color: AppColors.blue),
        title: Text('${schedule.time} - Obra ${job.number} - ${job.name}'),
        subtitle: Text(
            '${job.address}, ${job.city} - $people pessoas - ${schedule.note}'),
        trailing: Wrap(
          spacing: AppSpacing.sm,
          children: [
            TextButton(
              onPressed: () => _openJob(context, job.id),
              child: const Text('Abrir Obra'),
            ),
            FilledButton.icon(
              onPressed: null,
              icon: const Icon(Icons.route_outlined),
              label: const Text('Abrir Rota'),
            ),
          ],
        ),
      ),
    );
  }
}

final class _JobListCard extends ConsumerWidget {
  const _JobListCard({required this.job});

  final SupervisorJob job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(supervisorCenterProvider);
    final assigned = _assignmentsFor(state, job.id);
    final working =
        assigned.where((item) => item.status == AssignmentStatus.working);
    final entries = state.timeEntries.where((entry) => entry.jobId == job.id);
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
                  child: Text(job.displayName,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                JkddStatusChip(
                  label: jobStatusLabel(job.status),
                  icon: Icons.apartment_outlined,
                  tone: job.status == JobStatus.active
                      ? JkddStatusTone.success
                      : JkddStatusTone.neutral,
                ),
              ],
            ),
            const Divider(height: 28),
            _InfoWrap(
              children: [
                JkddInfoRow(label: 'Cliente', value: job.client),
                JkddInfoRow(label: 'Endereco', value: job.address),
                JkddInfoRow(label: 'Cidade', value: job.city),
                JkddInfoRow(
                  label: 'Supervisor',
                  value: state.userById(job.supervisorId).name,
                ),
                JkddInfoRow(
                  label: 'Programadas hoje',
                  value: '${assigned.length}',
                ),
                JkddInfoRow(
                  label: 'Trabalhando agora',
                  value: '${working.length}',
                ),
                JkddInfoRow(
                  label: 'Horas hoje',
                  value: _hours(entries.fold<double>(
                    0,
                    (total, entry) => total + _entryHoursValue(entry),
                  )),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => _openJob(context, job.id),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Ver Obra'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _JobSummary extends ConsumerWidget {
  const _JobSummary({required this.job});

  final SupervisorJob job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(supervisorCenterProvider);
    final assignments = _assignmentsFor(state, job.id);
    final entries = state.timeEntries.where((entry) => entry.jobId == job.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ResponsiveGrid(
          minWidth: 180,
          children: [
            JkddSummaryCard(
              label: 'Pessoas programadas',
              value: '${assignments.length}',
              icon: Icons.groups_outlined,
              color: AppColors.blue,
            ),
            JkddSummaryCard(
              label: 'Pessoas trabalhando',
              value:
                  '${assignments.where((a) => a.status == AssignmentStatus.working).length}',
              icon: Icons.engineering_outlined,
              color: AppColors.green,
            ),
            JkddSummaryCard(
              label: 'Sem entrada',
              value:
                  '${assignments.where((a) => a.status == AssignmentStatus.noEntry).length}',
              icon: Icons.person_off_outlined,
              color: AppColors.amber,
            ),
            JkddSummaryCard(
              label: 'Horas pendentes',
              value:
                  '${entries.where((e) => e.status == TimeReviewStatus.pending).length}',
              icon: Icons.pending_actions,
              color: AppColors.red,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: _InfoWrap(
              children: [
                JkddInfoRow(label: 'Numero', value: job.number),
                JkddInfoRow(label: 'Endereco', value: job.address),
                JkddInfoRow(label: 'Status', value: jobStatusLabel(job.status)),
                JkddInfoRow(
                  label: 'Supervisor',
                  value: state.userById(job.supervisorId).name,
                ),
                JkddInfoRow(
                  label: 'Total de horas do dia',
                  value: _hours(entries.fold<double>(
                    0,
                    (sum, entry) => sum + _entryHoursValue(entry),
                  )),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

final class _JobPeopleToday extends ConsumerWidget {
  const _JobPeopleToday({required this.job});

  final SupervisorJob job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(supervisorCenterProvider);
    final assignments = _assignmentsFor(state, job.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Pessoas programadas hoje',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        for (final assignment in assignments)
          _AssignmentCard(assignment: assignment),
        const SizedBox(height: AppSpacing.lg),
        Text('Pessoas trabalhando agora',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        for (final assignment in assignments
            .where((item) => item.status == AssignmentStatus.working))
          _AssignmentCard(assignment: assignment),
      ],
    );
  }
}

final class _JobHours extends ConsumerWidget {
  const _JobHours({required this.job});

  final SupervisorJob job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(supervisorCenterProvider);
    final entries = state.timeEntries.where((entry) => entry.jobId == job.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: () async {
              final reason = await _textDialog(
                context,
                'Aprovar todos',
                'Justificativa',
              );
              if (reason?.trim().isEmpty != false) return;
              ref
                  .read(supervisorCenterProvider.notifier)
                  .approveAllValidForJob(job.id, reason!);
            },
            icon: const Icon(Icons.done_all),
            label: const Text('Aprovar todos validos'),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final entry in entries)
          _TimeEntryCard(
            entry: entry,
            showReviewButton: true,
            trailing: Wrap(
              spacing: AppSpacing.sm,
              children: [
                TextButton(
                  onPressed: () => _reviewEntry(context, ref, entry),
                  child: const Text('Revisar'),
                ),
                FilledButton(
                  onPressed: () async {
                    final reason = await _textDialog(
                      context,
                      'Aprovar registro',
                      'Justificativa',
                    );
                    if (reason?.trim().isEmpty != false) return;
                    ref
                        .read(supervisorCenterProvider.notifier)
                        .approveEntry(entry.id, reason!);
                  },
                  child: const Text('Aprovar'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

final class _JobHistory extends ConsumerWidget {
  const _JobHistory({required this.job});

  final SupervisorJob job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(supervisorCenterProvider);
    final entries = state.timeEntries.where((entry) => entry.jobId == job.id);
    final logs = state.auditLogs.where(
      (log) => entries.any((entry) => entry.id == log.entityId),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              '${_date(DateTime.now())} - ${entries.length} pessoas - ${_hours(entries.fold<double>(0, (sum, entry) => sum + _entryHoursValue(entry)))} - Supervisor ${state.userById(job.supervisorId).name}',
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final log in logs) _AuditLogTile(log: log),
        if (logs.isEmpty)
          const JkddEmptyState(
            icon: Icons.history_outlined,
            title: 'Sem alteracoes',
            message: 'Alteracoes e aprovacoes aparecem aqui.',
          ),
      ],
    );
  }
}

final class _JobInfo extends ConsumerWidget {
  const _JobInfo({required this.job});

  final SupervisorJob job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(supervisorCenterProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoWrap(
              children: [
                JkddInfoRow(label: 'Numero da obra', value: job.number),
                JkddInfoRow(label: 'Cliente', value: job.client),
                JkddInfoRow(label: 'Endereco', value: job.address),
                JkddInfoRow(label: 'Cidade', value: job.city),
                JkddInfoRow(
                    label: 'Data de inicio', value: _date(job.startDate)),
                JkddInfoRow(
                    label: 'Horario previsto', value: job.scheduledTime),
                JkddInfoRow(label: 'Observacoes', value: job.notes),
                JkddInfoRow(label: 'Status', value: jobStatusLabel(job.status)),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: state.hasPermission(PilotPermission.editJob)
                  ? () => _snack(context, 'Edicao visual habilitada no piloto.')
                  : null,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Editar conforme permissao'),
            ),
          ],
        ),
      ),
    );
  }
}

final class _AssignmentCard extends ConsumerWidget {
  const _AssignmentCard({required this.assignment});

  final JobAssignment assignment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(supervisorCenterProvider);
    final user = state.userById(assignment.userId);
    final job = state.jobById(assignment.jobId);
    final entry = state.timeEntries
        .where((item) => item.userId == user.id && item.jobId == job.id)
        .cast<TimeEntry?>()
        .firstOrNull;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: Icon(
          user.isContractor ? Icons.engineering_outlined : Icons.badge_outlined,
          color: AppColors.blue,
        ),
        title: Text('${user.name} - ${roleLabel(user.role)}'),
        subtitle: Text(
          '${job.displayName} - ${assignment.scheduledStart} - ${assignment.scheduledEnd}\n'
          'Entrada: ${entry?.clockIn ?? "--"} | Saida: ${entry?.clockOut ?? "--"} | Total: ${entry == null ? "--" : _entryHours(entry)}',
        ),
        trailing: JkddStatusChip(
          label: assignmentStatusLabel(assignment.status),
          icon: Icons.circle,
          tone: assignment.status == AssignmentStatus.working
              ? JkddStatusTone.success
              : assignment.status == AssignmentStatus.noEntry
                  ? JkddStatusTone.warning
                  : JkddStatusTone.neutral,
        ),
      ),
    );
  }
}

final class _AuditLogTile extends StatelessWidget {
  const _AuditLogTile({required this.log});

  final AuditLog log;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: ListTile(
          leading: const Icon(Icons.history_outlined, color: AppColors.purple),
          title:
              Text('${log.fieldName}: ${log.originalValue} -> ${log.newValue}'),
          subtitle: Text(
            '${log.changedBy} - ${_date(log.changedAt)} ${_time(log.changedAt)}\n${log.justification}',
          ),
        ),
      );
}

final class _FilterCard extends StatelessWidget {
  const _FilterCard({required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final label in labels)
                FilterChip(
                  label: Text(label),
                  selected: false,
                  onSelected: (_) {},
                ),
            ],
          ),
        ),
      );
}

final class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: AppColors.blue, size: 30),
                const SizedBox(height: AppSpacing.lg),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.gray),
                ),
              ],
            ),
          ),
        ),
      );
}

final class _ResponsiveGrid extends StatelessWidget {
  const _ResponsiveGrid({required this.children, required this.minWidth});

  final List<Widget> children;
  final double minWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final columns = (constraints.maxWidth / minWidth).floor().clamp(1, 4);
          return GridView.count(
            crossAxisCount: columns,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
            childAspectRatio: columns == 1 ? 2.5 : 1.4,
            children: children,
          );
        },
      );
}

final class _PilotFrame extends StatelessWidget {
  const _PilotFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ListView(
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.sizeOf(context).width < 600 ? 16 : 28,
          vertical: 24,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: child,
            ),
          ),
        ],
      );
}

final class _InfoWrap extends StatelessWidget {
  const _InfoWrap({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: AppSpacing.xl,
        runSpacing: AppSpacing.md,
        children: [
          for (final child in children)
            SizedBox(
              width: MediaQuery.sizeOf(context).width < 620 ? 140 : 180,
              child: child,
            ),
        ],
      );
}

Future<void> _reviewEntry(
  BuildContext context,
  WidgetRef ref,
  TimeEntry entry,
) async {
  final clockIn = TextEditingController(text: entry.clockIn);
  final clockOut = TextEditingController(text: entry.clockOut ?? '');
  final breakMinutes = TextEditingController(text: '${entry.breakMinutes}');
  final bonus =
      TextEditingController(text: entry.travelBonusHours.toStringAsFixed(2));
  final note = TextEditingController(text: entry.supervisorNote);
  final justification = TextEditingController();
  final action = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Revisar registro'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: clockIn,
                decoration: const InputDecoration(labelText: 'Entrada'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: clockOut,
                decoration: const InputDecoration(labelText: 'Saida'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: breakMinutes,
                decoration: const InputDecoration(labelText: 'Intervalo min'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: bonus,
                decoration: const InputDecoration(labelText: 'Travel Bonus h'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: note,
                decoration: const InputDecoration(labelText: 'Observacao'),
                minLines: 2,
                maxLines: 4,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: justification,
                decoration: const InputDecoration(
                  labelText: 'Justificativa obrigatoria',
                ),
                minLines: 2,
                maxLines: 4,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, 'correction'),
          child: const Text('Solicitar correcao'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, 'reject'),
          child: const Text('Rejeitar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, 'approve'),
          child: const Text('Aprovar'),
        ),
        FilledButton.tonal(
          onPressed: () => Navigator.pop(context, 'save'),
          child: const Text('Salvar revisao'),
        ),
      ],
    ),
  );
  if (action == null) return;
  final reason = justification.text.trim();
  try {
    final controller = ref.read(supervisorCenterProvider.notifier);
    if (action == 'save') {
      controller.updateTimeEntry(
        entryId: entry.id,
        clockIn: clockIn.text.trim(),
        clockOut: clockOut.text.trim().isEmpty ? null : clockOut.text.trim(),
        breakMinutes: int.tryParse(breakMinutes.text) ?? entry.breakMinutes,
        travelBonusHours: double.tryParse(bonus.text) ?? entry.travelBonusHours,
        supervisorNote: note.text.trim(),
        justification: reason,
      );
    } else if (action == 'approve') {
      controller.updateTimeEntry(
        entryId: entry.id,
        clockIn: clockIn.text.trim(),
        clockOut: clockOut.text.trim().isEmpty ? null : clockOut.text.trim(),
        breakMinutes: int.tryParse(breakMinutes.text) ?? entry.breakMinutes,
        travelBonusHours: double.tryParse(bonus.text) ?? entry.travelBonusHours,
        supervisorNote: note.text.trim(),
        justification: reason,
      );
      controller.approveEntry(entry.id, reason);
    } else if (action == 'reject') {
      controller.rejectEntry(entry.id, reason);
    } else {
      controller.correctionRequestedBySupervisor(entry.id, reason);
    }
  } on StateError catch (error) {
    if (context.mounted) _snack(context, error.message);
  } finally {
    clockIn.dispose();
    clockOut.dispose();
    breakMinutes.dispose();
    bonus.dispose();
    note.dispose();
    justification.dispose();
  }
}

Future<void> _newJob(BuildContext context, WidgetRef ref) async {
  final number = TextEditingController();
  final name = TextEditingController();
  final client = TextEditingController(text: 'EWW');
  final address = TextEditingController();
  final city = TextEditingController();
  final zip = TextEditingController();
  final notes = TextEditingController();
  JobStatus status = JobStatus.planned;
  final saved = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Nova Obra'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: number,
                    decoration:
                        const InputDecoration(labelText: 'Numero da obra')),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                    controller: name,
                    decoration:
                        const InputDecoration(labelText: 'Nome da obra')),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                    controller: client,
                    decoration: const InputDecoration(labelText: 'Cliente')),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                    controller: address,
                    decoration: const InputDecoration(labelText: 'Endereco')),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                    controller: city,
                    decoration: const InputDecoration(labelText: 'Cidade')),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                    controller: zip,
                    decoration: const InputDecoration(labelText: 'ZIP Code')),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<JobStatus>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: [
                    for (final item in JobStatus.values)
                      DropdownMenuItem(
                          value: item, child: Text(jobStatusLabel(item))),
                  ],
                  onChanged: (value) =>
                      setState(() => status = value ?? status),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                    controller: notes,
                    decoration:
                        const InputDecoration(labelText: 'Observacoes')),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Salvar')),
        ],
      ),
    ),
  );
  if (saved == true) {
    ref.read(supervisorCenterProvider.notifier).addJob(
          SupervisorJob(
            id: 'job-${DateTime.now().millisecondsSinceEpoch}',
            number: number.text.trim().isEmpty ? 'NEW' : number.text.trim(),
            name: name.text.trim().isEmpty ? 'Nova Obra' : name.text.trim(),
            client: client.text.trim(),
            address: address.text.trim(),
            city: city.text.trim(),
            state: 'FL',
            zipCode: zip.text.trim(),
            startDate: DateTime.now(),
            scheduledTime: '7:00 AM',
            supervisorId: 'joukin',
            notes: notes.text.trim(),
            status: status,
          ),
        );
  }
  number.dispose();
  name.dispose();
  client.dispose();
  address.dispose();
  city.dispose();
  zip.dispose();
  notes.dispose();
}

Future<String?> _textDialog(
  BuildContext context,
  String title,
  String label,
) async {
  final controller = TextEditingController();
  final value = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        minLines: 2,
        maxLines: 4,
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Salvar')),
      ],
    ),
  );
  controller.dispose();
  return value;
}

void _openJob(BuildContext context, String jobId) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => JobDetailScreen(jobId: jobId)),
  );
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

List<JobAssignment> _assignmentsFor(
        SupervisorCenterState state, String jobId) =>
    state.assignments.where((item) => item.jobId == jobId).toList();

double _entryHoursValue(TimeEntry entry) {
  if (entry.clockOut == null) return 7.25 + entry.travelBonusHours;
  final start = _parseHour(entry.clockIn);
  final end = _parseHour(entry.clockOut!);
  return (end - start) - (entry.breakMinutes / 60) + entry.travelBonusHours;
}

double _parseHour(String value) {
  final parts = value.replaceAll(' ', '').toUpperCase();
  final isPm = parts.endsWith('PM');
  final clean = parts.replaceAll('AM', '').replaceAll('PM', '');
  final time = clean.split(':');
  var hour = int.tryParse(time.first) ?? 0;
  final minute = time.length > 1 ? int.tryParse(time[1]) ?? 0 : 0;
  if (isPm && hour != 12) hour += 12;
  if (!isPm && hour == 12) hour = 0;
  return hour + minute / 60;
}

String _entryHours(TimeEntry entry) => _hours(_entryHoursValue(entry));

String _hours(double value) {
  final minutes = (value * 60).round().clamp(0, 24 * 60);
  return '${minutes ~/ 60}h ${minutes.remainder(60).toString().padLeft(2, '0')}m';
}

String _date(DateTime value) =>
    '${value.month.toString().padLeft(2, '0')}/${value.day.toString().padLeft(2, '0')}/${value.year}';

String _time(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
