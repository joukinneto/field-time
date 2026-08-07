import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jkdd_field_time_records_production/core/theme/app_colors.dart';
import 'package:jkdd_field_time_records_production/core/theme/app_spacing.dart';
import 'package:jkdd_field_time_records_production/features/employees/presentation/employees_management_screen.dart';
import 'package:jkdd_field_time_records_production/src/application/field_time_controller.dart';
import 'package:jkdd_field_time_records_production/src/localization/app_language.dart';
import 'package:jkdd_field_time_records_production/src/domain/registration_number.dart';
import 'package:jkdd_field_time_records_production/src/supervisor_center/supervisor_center_controller.dart';
import 'package:jkdd_field_time_records_production/src/supervisor_center/supervisor_center_models.dart';
import 'package:jkdd_field_time_records_production/shared/widgets/jkdd_empty_state.dart';
import 'package:jkdd_field_time_records_production/shared/widgets/jkdd_info_row.dart';
import 'package:jkdd_field_time_records_production/shared/widgets/jkdd_job_navigation_button.dart';
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
            title: _title(context, _view),
            subtitle: context.tr('supervisor.title'),
            trailing: _view == SupervisorCenterView.dashboard
                ? null
                : TextButton.icon(
                    onPressed: () =>
                        setState(() => _view = SupervisorCenterView.dashboard),
                    icon: const Icon(Icons.arrow_back),
                    label: Text(context.tr('supervisor.management')),
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

  String _title(
    BuildContext context,
    SupervisorCenterView view,
  ) => switch (view) {
    SupervisorCenterView.dashboard => context.tr('supervisor.management'),
    SupervisorCenterView.approveTime => context.tr('supervisor.approveTime'),
    SupervisorCenterView.schedule => context.tr('supervisor.schedule'),
    SupervisorCenterView.jobs => context.tr('supervisor.jobs'),
    SupervisorCenterView.peopleByJob => context.tr('supervisor.peopleByJob'),
    SupervisorCenterView.workingNow => context.tr('supervisor.workingNow'),
  };
}

final class WorkerPilotScreen extends ConsumerWidget {
  const WorkerPilotScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(supervisorCenterProvider);
    final user = state.currentUser;
    final entries = state.timeEntries
        .where((entry) => entry.userId == user.id)
        .toList();
    final assignments = state.assignments
        .where((item) => item.userId == user.id)
        .toList();
    return _PilotFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          JkddSectionHeader(
            title: context.tr('app.title'),
            subtitle:
                '${user.name} - ${_roleLabel(context, user.role)} ${context.tr('supervisor.pilotMode')}',
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              JkddStatusChip(
                label: _roleLabel(context, user.role),
                icon: user.isContractor
                    ? Icons.engineering_outlined
                    : Icons.badge_outlined,
                tone: user.isContractor
                    ? JkddStatusTone.info
                    : JkddStatusTone.success,
              ),
              JkddStatusChip(
                label: context.tr('supervisor.managementUnavailable'),
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
                title: context.tr('home.clockIn'),
                subtitle: context.tr('approval.clockIn'),
                icon: Icons.play_circle_outline,
                onTap: () =>
                    _snack(context, context.tr('supervisor.clockInSimulated')),
              ),
              _ActionCard(
                title: context.tr('approval.clockOut'),
                subtitle: context.tr('supervisor.reviewSubmittedRecords'),
                icon: Icons.stop_circle_outlined,
                onTap: () => _submitOwnTime(context, ref),
              ),
              _ActionCard(
                title: context.tr('assignment.breakTime'),
                subtitle: context.tr('approval.breakMinutes'),
                icon: Icons.pause_circle_outline,
                onTap: () =>
                    _snack(context, context.tr('supervisor.breakStarted')),
              ),
              _ActionCard(
                title: context.tr('assignment.finished'),
                subtitle: context.tr('approval.breakMinutes'),
                icon: Icons.restart_alt,
                onTap: () =>
                    _snack(context, context.tr('supervisor.breakEnded')),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          JkddSectionHeader(
            title: context.tr('supervisor.currentWorkerJob'),
            subtitle: context.tr('supervisor.workerJobSubtitle'),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final assignment in assignments)
            _AssignmentCard(assignment: assignment),
          const SizedBox(height: AppSpacing.lg),
          if (entries.isEmpty)
            JkddEmptyState(
              icon: Icons.table_chart_outlined,
              title: context.tr('supervisor.noHoursSent'),
              message: context.tr('supervisor.noHoursSentHelp'),
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
                  label: Text(context.tr('supervisor.requestCorrection')),
                ),
              ),
        ],
      ),
    );
  }

  Future<void> _submitOwnTime(BuildContext context, WidgetRef ref) async {
    final note = await _textDialog(
      context,
      context.tr('supervisor.observation'),
      context.tr('supervisor.optionalNote'),
    );
    if (note == null) return;
    ref
        .read(supervisorCenterProvider.notifier)
        .submitOwnTime(clockOut: '5:00 PM', note: note);
    if (context.mounted) _snack(context, context.tr('supervisor.hoursSent'));
  }

  Future<void> _requestOwnCorrection(
    BuildContext context,
    WidgetRef ref,
    String entryId,
  ) async {
    final reason = await _textDialog(
      context,
      context.tr('supervisor.requestCorrection'),
      context.tr('supervisor.correctionReason'),
    );
    if (reason?.trim().isEmpty != false) return;
    ref
        .read(supervisorCenterProvider.notifier)
        .requestCorrection(entryId, reason!);
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
    final working = state.timeEntries
        .where((entry) => entry.clockOut == null)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ResponsiveGrid(
          minWidth: 180,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onOpen(SupervisorCenterView.approveTime),
              child: JkddSummaryCard(
                label: context.tr('supervisor.pendingHours'),
                value: '$pending',
                icon: Icons.pending_actions,
                color: AppColors.amber,
              ),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onOpen(SupervisorCenterView.jobs),
              child: JkddSummaryCard(
                label: context.tr('supervisor.activeJobs'),
                value:
                    '${state.jobs.where((job) => job.status == JobStatus.active).length}',
                icon: Icons.apartment,
                color: AppColors.blue,
              ),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onOpen(SupervisorCenterView.workingNow),
              child: JkddSummaryCard(
                label: context.tr('supervisor.workingNow'),
                value: '$working',
                icon: Icons.groups_outlined,
                color: AppColors.green,
              ),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const EmployeesManagementScreen(),
                ),
              ),
              child: JkddSummaryCard(
                label: context.tr('nav.employees'),
                value: '${state.users.length}',
                icon: Icons.badge_outlined,
                color: AppColors.purple,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        _ResponsiveGrid(
          minWidth: 240,
          children: [
            _ActionCard(
              title: context.tr('supervisor.approveTime'),
              subtitle: context.tr('supervisor.reviewSubmittedRecords'),
              icon: Icons.fact_check_outlined,
              onTap: () => onOpen(SupervisorCenterView.approveTime),
            ),
            _ActionCard(
              title: context.tr('supervisor.schedule'),
              subtitle: context.tr('supervisor.dailyRoute'),
              icon: Icons.event_note_outlined,
              onTap: () => onOpen(SupervisorCenterView.schedule),
            ),
            _ActionCard(
              title: context.tr('supervisor.jobs'),
              subtitle: context.tr('supervisor.jobsAndDetails'),
              icon: Icons.apartment_outlined,
              onTap: () => onOpen(SupervisorCenterView.jobs),
            ),
            _ActionCard(
              title: context.tr('supervisor.peopleByJob'),
              subtitle: context.tr('supervisor.dailyAllocation'),
              icon: Icons.assignment_ind_outlined,
              onTap: () => onOpen(SupervisorCenterView.peopleByJob),
            ),
            _ActionCard(
              title: context.tr('supervisor.workingNow'),
              subtitle: context.tr('supervisor.openClockIns'),
              icon: Icons.engineering_outlined,
              onTap: () => onOpen(SupervisorCenterView.workingNow),
            ),
            _ActionCard(
              title: context.tr('employees.management'),
              subtitle: context.tr('employees.subtitle'),
              icon: Icons.badge_outlined,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const EmployeesManagementScreen(),
                ),
              ),
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
        .where(
          (entry) =>
              entry.status != TimeReviewStatus.working &&
              entry.status != TimeReviewStatus.approved &&
              entry.userId != state.currentUser.id,
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in entries)
          _TimeEntryCard(
            entry: entry,
            showReviewButton: true,
            trailing: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              alignment: WrapAlignment.end,
              children: [
                FilledButton.icon(
                  onPressed: entry.isLocked
                      ? null
                      : () => _approveEntry(context, ref, entry),
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(context.tr('approval.approve')),
                ),
                OutlinedButton.icon(
                  onPressed: entry.isLocked
                      ? null
                      : () => _rejectEntry(context, ref, entry),
                  icon: const Icon(Icons.cancel_outlined),
                  label: Text(context.tr('approval.reject')),
                ),
                TextButton.icon(
                  onPressed: entry.isLocked
                      ? null
                      : () => _sendToReview(context, ref, entry),
                  icon: const Icon(Icons.rate_review_outlined),
                  label: Text(context.tr('approval.review')),
                ),
              ],
            ),
          ),
        if (entries.isEmpty)
          JkddEmptyState(
            icon: Icons.fact_check_outlined,
            title: context.tr('approval.noSubmittedRecords'),
            message: context.tr('approval.noSubmittedRecordsHelp'),
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
              segments: [
                ButtonSegment(
                  value: ScheduleFilter.today,
                  label: Text(context.tr('supervisor.today')),
                ),
                ButtonSegment(
                  value: ScheduleFilter.week,
                  label: Text(context.tr('supervisor.week')),
                ),
                ButtonSegment(
                  value: ScheduleFilter.calendar,
                  label: Text(context.tr('supervisor.calendar')),
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
        title: Text(_jobDisplayName(context, job)),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            Tab(text: context.tr('supervisor.summary')),
            Tab(text: context.tr('supervisor.peopleToday')),
            Tab(text: context.tr('supervisor.hours')),
            Tab(text: context.tr('supervisor.history')),
            Tab(text: context.tr('supervisor.jobInfo')),
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
        _FilterCard(
          labels: [
            context.tr('supervisor.date'),
            context.tr('supervisor.job'),
            context.tr('supervisor.person'),
            context.tr('supervisor.status'),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        for (final job in state.jobs)
          Card(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _jobDisplayName(context, job),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(context.tr('supervisor.dailyAllocation')),
                  const Divider(height: 24),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      Chip(
                        label: Text(
                          context.tr('common.peopleScheduled', {
                            'count': _assignmentsFor(state, job.id).length,
                          }),
                        ),
                      ),
                      Chip(
                        label: Text(
                          context.tr('common.peopleWorking', {
                            'count': _assignmentsFor(state, job.id)
                                .where(
                                  (a) => a.status == AssignmentStatus.working,
                                )
                                .length,
                          }),
                        ),
                      ),
                      Chip(
                        label: Text(
                          context.tr('common.noEntryCount', {
                            'count': _assignmentsFor(state, job.id)
                                .where(
                                  (a) => a.status == AssignmentStatus.noEntry,
                                )
                                .length,
                          }),
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
    final fieldTime = ref.watch(fieldTimeControllerProvider);
    final open = state.timeEntries.where((entry) => entry.clockOut == null);
    final activeSegment = fieldTime.activeSegment;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (activeSegment != null)
          Card(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            child: ListTile(
              leading: const Icon(
                Icons.engineering_outlined,
                color: AppColors.green,
              ),
              title: const Text('Santana'),
              subtitle: Text(
                '${context.tr('approval.working')} - '
                '${_jobNumberLabel(context, activeSegment.jobNumber)}\n'
                '${context.tr('supervisor.clockIn')}: ${_time(activeSegment.startedAt)}',
              ),
              trailing: JkddStatusChip(
                label: context.tr('approval.working'),
                icon: Icons.play_circle_outline,
                tone: JkddStatusTone.success,
              ),
            ),
          ),
        for (final entry in open)
          _TimeEntryCard(
            entry: entry,
            showReviewButton: false,
            trailing: Wrap(
              spacing: AppSpacing.sm,
              children: [
                TextButton(
                  onPressed: () => _reviewEntry(context, ref, entry),
                  child: Text(context.tr('supervisor.viewRecord')),
                ),
                FilledButton(
                  onPressed: () => _openJob(context, entry.jobId),
                  child: Text(context.tr('supervisor.viewJob')),
                ),
              ],
            ),
          ),
        if (open.isEmpty && activeSegment == null)
          JkddEmptyState(
            icon: Icons.engineering_outlined,
            title: context.tr('supervisor.nobodyWorking'),
            message: context.tr('supervisor.openEntriesAppear'),
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
    final reviews =
        state.reviews
            .where((review) => review.timeEntryId == entry.id)
            .toList(growable: false)
          ..sort((left, right) => right.reviewedAt.compareTo(left.reviewedAt));
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
                  child: Text(
                    user.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _StatusChip(status: entry.status),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                Chip(label: Text(_roleLabel(context, user.role))),
                Chip(label: Text(_jobDisplayName(context, job))),
                Chip(label: Text(job.city)),
              ],
            ),
            const Divider(height: 28),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (job.travelBonusHours > 0)
                  JkddStatusChip(
                    label:
                        '${context.tr('jobs.travelBonus')}: ${job.travelBonusHours.toStringAsFixed(2)} h',
                    icon: Icons.route_outlined,
                    tone: JkddStatusTone.warning,
                  ),
                if (job.payPremiumEnabled)
                  JkddStatusChip(
                    label:
                        '${context.tr('jobs.payPremium')}: ${job.payPremiumLabel}',
                    icon: Icons.workspace_premium_outlined,
                    tone: JkddStatusTone.info,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _InfoWrap(
              children: [
                JkddInfoRow(
                  label: context.tr('supervisor.date'),
                  value: _date(entry.date),
                ),
                JkddInfoRow(
                  label: context.tr('supervisor.clockIn'),
                  value: entry.clockIn,
                ),
                JkddInfoRow(
                  label: context.tr('supervisor.clockOut'),
                  value: entry.clockOut ?? context.tr('supervisor.openStatus'),
                ),
                JkddInfoRow(
                  label: context.tr('supervisor.interval'),
                  value: '${entry.breakMinutes} min',
                ),
                JkddInfoRow(
                  label: context.tr('supervisor.total'),
                  value: _entryHours(entry),
                ),
                JkddInfoRow(
                  label: context.tr('approval.travelBonus'),
                  value: '${entry.travelBonusHours.toStringAsFixed(2)} h',
                ),
              ],
            ),
            if (entry.employeeNote.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                '${context.tr('supervisor.employeeNote')}: ${entry.employeeNote}',
              ),
            ],
            if (entry.supervisorNote.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${context.tr('supervisor.supervisorNote')}: ${entry.supervisorNote}',
              ),
            ],
            if (entry.rejectionReason?.trim().isNotEmpty == true) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${context.tr('supervisor.rejectionReason')}: ${entry.rejectionReason}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
            if (entry.reviewNote?.trim().isNotEmpty == true) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${context.tr('supervisor.reviewRequest')}: ${entry.reviewNote}',
              ),
            ],
            if (reviews.isNotEmpty) ...[
              const Divider(height: 28),
              Text(
                context.tr('approval.history'),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              for (final review in reviews.take(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '${_localizedReviewStatus(context, review.previousStatus)} -> '
                    '${_localizedReviewStatus(context, review.newStatus)} | '
                    '${state.userById(review.reviewerId).name} | '
                    '${_date(review.reviewedAt)} ${_time(review.reviewedAt)} | '
                    '${review.reason}'
                    '${review.observation.isEmpty ? '' : ' | ${review.observation}'}',
                  ),
                ),
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
    label: _localizedReviewStatus(context, status),
    icon: switch (status) {
      TimeReviewStatus.approved => Icons.check_circle_outline,
      TimeReviewStatus.rejected => Icons.cancel_outlined,
      TimeReviewStatus.correctionRequested => Icons.edit_note_outlined,
      TimeReviewStatus.corrected => Icons.task_alt_outlined,
      TimeReviewStatus.resubmitted => Icons.upload_file_outlined,
      TimeReviewStatus.closed => Icons.lock_outline,
      TimeReviewStatus.working => Icons.play_circle_outline,
      _ => Icons.pending_actions,
    },
    tone: switch (status) {
      TimeReviewStatus.approved => JkddStatusTone.success,
      TimeReviewStatus.rejected => JkddStatusTone.danger,
      TimeReviewStatus.underReview => JkddStatusTone.info,
      TimeReviewStatus.corrected => JkddStatusTone.info,
      TimeReviewStatus.resubmitted => JkddStatusTone.warning,
      TimeReviewStatus.closed => JkddStatusTone.neutral,
      TimeReviewStatus.working => JkddStatusTone.success,
      _ => JkddStatusTone.warning,
    },
  );
}

String _localizedReviewStatus(BuildContext context, TimeReviewStatus status) {
  return switch (status) {
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
  };
}

String _roleLabel(BuildContext context, PilotRole role) => switch (role) {
  PilotRole.owner => context.tr('supervisor.director'),
  PilotRole.administrator => context.tr('supervisor.administrator'),
  PilotRole.coordinator => context.tr('supervisor.coordinator'),
  PilotRole.supervisor => context.tr('supervisor.supervisor'),
  PilotRole.employee => context.tr('auth.roleCollaborator'),
  PilotRole.contractor => context.tr('auth.roleCollaborator'),
};

String _jobDisplayName(BuildContext context, SupervisorJob job) =>
    '${context.tr('supervisor.job')} ${job.number}';

String _jobNumberLabel(BuildContext context, String number) =>
    '${context.tr('supervisor.job')} $number';

String _auditFieldLabel(BuildContext context, String fieldName) =>
    switch (fieldName) {
      'clockIn' => context.tr('approval.clockIn'),
      'clockOut' => context.tr('approval.clockOut'),
      'breakMinutes' => context.tr('approval.breakMinutes'),
      'travelBonusHours' => context.tr('approval.travelBonus'),
      'supervisorNote' => context.tr('supervisor.supervisorNote'),
      _ => fieldName,
    };

String _jobStatusLabel(BuildContext context, JobStatus status) =>
    switch (status) {
      JobStatus.planned => context.tr('jobStatus.planned'),
      JobStatus.active => context.tr('jobStatus.active'),
      JobStatus.paused => context.tr('jobStatus.paused'),
      JobStatus.completed => context.tr('jobStatus.completed'),
      JobStatus.cancelled => context.tr('jobStatus.cancelled'),
    };

String _assignmentStatusLabel(BuildContext context, AssignmentStatus status) =>
    switch (status) {
      AssignmentStatus.scheduled => context.tr('assignment.scheduled'),
      AssignmentStatus.working => context.tr('assignment.working'),
      AssignmentStatus.breakTime => context.tr('assignment.breakTime'),
      AssignmentStatus.finished => context.tr('assignment.finished'),
      AssignmentStatus.noEntry => context.tr('assignment.noEntry'),
      AssignmentStatus.absent => context.tr('assignment.absent'),
    };

final class _ScheduleCard extends ConsumerWidget {
  const _ScheduleCard({required this.schedule});

  final SupervisorSchedule schedule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(supervisorCenterProvider);
    final job = state.jobById(schedule.jobId);
    final people = state.assignments
        .where((item) => item.jobId == job.id)
        .length;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: ListTile(
        leading: const Icon(Icons.event_note_outlined, color: AppColors.blue),
        title: Text(
          '${schedule.time} - ${context.tr('supervisor.job')} ${job.number} - ${job.name}',
        ),
        subtitle: Text(
          '${job.address}, ${job.city} - ${context.tr('common.peopleCount', {'count': people})} - ${schedule.note}',
        ),
        trailing: Wrap(
          spacing: AppSpacing.sm,
          children: [
            TextButton(
              onPressed: () => _openJob(context, job.id),
              child: Text(context.tr('jobs.openJob')),
            ),
            JkddJobNavigationButton(
              address: '${job.address} ${job.city} ${job.state} ${job.zipCode}',
              compact: false,
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
    final working = assigned.where(
      (item) => item.status == AssignmentStatus.working,
    );
    final entries = state.timeEntries
        .where((entry) => entry.jobId == job.id)
        .toList(growable: false);
    final todayEntries = entries.where(
      (entry) => _sameDay(entry.date, DateTime.now()),
    );
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
                  child: Text(
                    _jobDisplayName(context, job),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                JkddStatusChip(
                  label: _jobStatusLabel(context, job.status),
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
                JkddInfoRow(
                  label: context.tr('supervisor.client'),
                  value: job.client,
                ),
                JkddInfoRow(
                  label: context.tr('jobs.address'),
                  value: job.address,
                ),
                JkddInfoRow(label: context.tr('jobs.city'), value: job.city),
                JkddInfoRow(
                  label: context.tr('supervisor.supervisor'),
                  value: state.userById(job.supervisorId).name,
                ),
                JkddInfoRow(
                  label: context.tr('supervisor.scheduledToday'),
                  value: '${assigned.length}',
                ),
                JkddInfoRow(
                  label: context.tr('supervisor.workingNow'),
                  value: '${working.length}',
                ),
                JkddInfoRow(
                  label: context.tr('supervisor.hoursToday'),
                  value: _hours(
                    todayEntries.fold<double>(
                      0,
                      (total, entry) => total + _entryHoursValue(entry),
                    ),
                  ),
                ),
                JkddInfoRow(
                  label: context.tr('timesheet.totalHours'),
                  value: _hours(
                    entries.fold<double>(
                      0,
                      (total, entry) => total + _entryHoursValue(entry),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  JkddJobNavigationButton(
                    address:
                        '${job.address} ${job.city} ${job.state} ${job.zipCode}',
                    compact: false,
                  ),
                  OutlinedButton.icon(
                    onPressed: state.hasPermission(PilotPermission.editJob)
                        ? () => _editJobOperations(context, ref, job)
                        : null,
                    icon: const Icon(Icons.tune_outlined),
                    label: Text(context.tr('common.saveChanges')),
                  ),
                  FilledButton.icon(
                    onPressed: () => _openJob(context, job.id),
                    icon: const Icon(Icons.open_in_new),
                    label: Text(context.tr('supervisor.viewJob')),
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

enum _JobDashboardPeriod { day, week, month, year }

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
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.gray),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    _PeriodChip(
                      label: 'Hoje',
                      selected: _period == _JobDashboardPeriod.day,
                      onTap: () =>
                          setState(() => _period = _JobDashboardPeriod.day),
                    ),
                    _PeriodChip(
                      label: 'Semana',
                      selected: _period == _JobDashboardPeriod.week,
                      onTap: () =>
                          setState(() => _period = _JobDashboardPeriod.week),
                    ),
                    _PeriodChip(
                      label: 'Mês',
                      selected: _period == _JobDashboardPeriod.month,
                      onTap: () =>
                          setState(() => _period = _JobDashboardPeriod.month),
                    ),
                    _PeriodChip(
                      label: 'Ano',
                      selected: _period == _JobDashboardPeriod.year,
                      onTap: () =>
                          setState(() => _period = _JobDashboardPeriod.year),
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
                      style: Theme.of(
                        context,
                      ).textTheme.labelMedium?.copyWith(color: AppColors.gray),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                if (userHours.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.lg,
                    ),
                    child: Text(
                      'Ainda não há horas registradas nesta obra para o período selecionado.',
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: AppColors.gray),
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
        Text(
          context.tr('supervisor.peopleScheduledToday'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final assignment in assignments)
          _AssignmentCard(assignment: assignment),
        const SizedBox(height: AppSpacing.lg),
        Text(
          context.tr('supervisor.peopleWorkingNow'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final assignment in assignments.where(
          (item) => item.status == AssignmentStatus.working,
        ))
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
    final entries = state.timeEntries
        .where((entry) => entry.jobId == job.id)
        .toList(growable: false);
    final todayEntries = entries.where(
      (entry) => _sameDay(entry.date, DateTime.now()),
    );
    final approvedEntries = entries.where(
      (entry) => entry.status == TimeReviewStatus.approved,
    );
    final pendingEntries = entries.where(
      (entry) =>
          entry.status != TimeReviewStatus.approved && entry.clockOut != null,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ResponsiveGrid(
          minWidth: 170,
          children: [
            JkddSummaryCard(
              label: context.tr('supervisor.hoursToday'),
              value: _hours(
                todayEntries.fold<double>(
                  0,
                  (sum, entry) => sum + _entryHoursValue(entry),
                ),
              ),
              icon: Icons.today_outlined,
              color: AppColors.blue,
            ),
            JkddSummaryCard(
              label: context.tr('timesheet.totalHours'),
              value: _hours(
                entries.fold<double>(
                  0,
                  (sum, entry) => sum + _entryHoursValue(entry),
                ),
              ),
              icon: Icons.schedule_outlined,
              color: AppColors.purple,
            ),
            JkddSummaryCard(
              label: context.tr('approval.approved'),
              value: _hours(
                approvedEntries.fold<double>(
                  0,
                  (sum, entry) => sum + _entryHoursValue(entry),
                ),
              ),
              icon: Icons.verified_outlined,
              color: AppColors.green,
            ),
            JkddSummaryCard(
              label: context.tr('supervisor.pendingHours'),
              value: _hours(
                pendingEntries.fold<double>(
                  0,
                  (sum, entry) => sum + _entryHoursValue(entry),
                ),
              ),
              icon: Icons.pending_actions_outlined,
              color: AppColors.amber,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: () async {
              final reason = await _textDialog(
                context,
                context.tr('approval.approveAll'),
                context.tr('approval.requiredJustification'),
              );
              if (reason?.trim().isEmpty != false) return;
              ref
                  .read(supervisorCenterProvider.notifier)
                  .approveAllValidForJob(job.id, reason!);
            },
            icon: const Icon(Icons.done_all),
            label: Text(context.tr('approval.approveAllValid')),
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
                  child: Text(context.tr('approval.review')),
                ),
                FilledButton(
                  onPressed: () async {
                    final reason = await _textDialog(
                      context,
                      context.tr('approval.approve'),
                      context.tr('approval.requiredJustification'),
                    );
                    if (reason?.trim().isEmpty != false) return;
                    ref
                        .read(supervisorCenterProvider.notifier)
                        .approveEntry(entry.id, reason!);
                  },
                  child: Text(context.tr('approval.approve')),
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
              '${_date(DateTime.now())} - ${context.tr('common.peopleCount', {'count': entries.length})} - ${_hours(entries.fold<double>(0, (sum, entry) => sum + _entryHoursValue(entry)))} - ${context.tr('supervisor.supervisor')} ${state.userById(job.supervisorId).name}',
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final log in logs) _AuditLogTile(log: log),
        if (logs.isEmpty)
          JkddEmptyState(
            icon: Icons.history_outlined,
            title: context.tr('supervisor.noChanges'),
            message: context.tr('supervisor.noChangesHelp'),
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
                JkddInfoRow(
                  label: context.tr('jobs.jobNumber'),
                  value: job.number,
                ),
                JkddInfoRow(
                  label: context.tr('supervisor.client'),
                  value: job.client,
                ),
                JkddInfoRow(
                  label: context.tr('jobs.address'),
                  value: job.address,
                ),
                JkddInfoRow(label: context.tr('jobs.city'), value: job.city),
                JkddInfoRow(
                  label: context.tr('supervisor.startDate'),
                  value: _date(job.startDate),
                ),
                JkddInfoRow(
                  label: context.tr('supervisor.scheduledTime'),
                  value: job.scheduledTime,
                ),
                JkddInfoRow(
                  label: context.tr('supervisor.notes'),
                  value: job.notes,
                ),
                JkddInfoRow(
                  label: context.tr('jobs.status'),
                  value: _jobStatusLabel(context, job.status),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: state.hasPermission(PilotPermission.editJob)
                  ? () => _snack(
                      context,
                      context.tr('supervisor.visualEditEnabled'),
                    )
                  : null,
              icon: const Icon(Icons.edit_outlined),
              label: Text(context.tr('supervisor.editByPermission')),
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
        title: Text('${user.name} - ${_roleLabel(context, user.role)}'),
        subtitle: Text(
          '${_jobDisplayName(context, job)} - ${assignment.scheduledStart} - ${assignment.scheduledEnd}\n'
          '${context.tr('supervisor.clockIn')}: ${entry?.clockIn ?? "--"} | ${context.tr('supervisor.clockOut')}: ${entry?.clockOut ?? "--"} | ${context.tr('supervisor.total')}: ${entry == null ? "--" : _entryHours(entry)}',
        ),
        trailing: JkddStatusChip(
          label: _assignmentStatusLabel(context, assignment.status),
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
      title: Text(
        '${_auditFieldLabel(context, log.fieldName)}: '
        '${_localizedFeedback(context, log.originalValue)} -> '
        '${_localizedFeedback(context, log.newValue)}',
      ),
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
            FilterChip(label: Text(label), selected: false, onSelected: (_) {}),
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
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.gray),
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
  final bonus = TextEditingController(
    text: entry.travelBonusHours.toStringAsFixed(2),
  );
  final note = TextEditingController(text: entry.supervisorNote);
  final justification = TextEditingController();
  final action = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.tr('approval.reviewEntry')),
      content: SizedBox(
        width: 520,
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
                controller: breakMinutes,
                decoration: InputDecoration(
                  labelText: context.tr('approval.breakMinutes'),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: bonus,
                decoration: InputDecoration(
                  labelText: context.tr('approval.travelBonus'),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: note,
                decoration: InputDecoration(
                  labelText: context.tr('approval.observation'),
                ),
                minLines: 2,
                maxLines: 4,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: justification,
                decoration: InputDecoration(
                  labelText: context.tr('approval.requiredJustification'),
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

Future<void> _approveEntry(
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
  if (!context.mounted) return;
  final reason = await _textDialog(
    context,
    context.tr('approval.confirmApproveTitle'),
    context.tr('approval.approvalObservation'),
    requiredValue: false,
  );
  if (reason == null) return;
  if (!context.mounted) return;
  try {
    ref
        .read(supervisorCenterProvider.notifier)
        .approveEntry(
          entry.id,
          reason.trim().isEmpty ? context.tr('approval.approved') : reason,
        );
  } on StateError catch (error) {
    if (context.mounted) _snack(context, error.message);
  }
}

Future<void> _rejectEntry(
  BuildContext context,
  WidgetRef ref,
  TimeEntry entry,
) async {
  final reason = await _textDialog(
    context,
    context.tr('approval.rejectRecord'),
    context.tr('approval.rejectionReasonRequired'),
  );
  if (reason?.trim().isEmpty != false) return;
  if (!context.mounted) return;
  final confirmed = await _confirmDialog(
    context,
    title: context.tr('approval.confirmReject'),
    message: context.tr('approval.rejectMessage'),
    confirmLabel: context.tr('approval.reject'),
    destructive: true,
  );
  if (confirmed != true) return;
  try {
    ref.read(supervisorCenterProvider.notifier).rejectEntry(entry.id, reason!);
  } on StateError catch (error) {
    if (context.mounted) _snack(context, error.message);
  }
}

Future<void> _sendToReview(
  BuildContext context,
  WidgetRef ref,
  TimeEntry entry,
) async {
  final request = await _reviewRequestDialog(context);
  if (request == null) return;
  try {
    ref
        .read(supervisorCenterProvider.notifier)
        .correctionRequestedBySupervisor(
          entry.id,
          request.reason,
          observation: request.observation,
        );
  } on StateError catch (error) {
    if (context.mounted) _snack(context, error.message);
  }
}

Future<void> _newJob(BuildContext context, WidgetRef ref) async {
  final registrationNumber = RegistrationNumberPolicy.next(
    RegistrationRecordType.job,
    ref
        .read(supervisorCenterProvider)
        .jobs
        .map(
          (job) => job.registrationNumber.isNotEmpty
              ? job.registrationNumber
              : job.number,
        ),
  );
  final number = TextEditingController(text: registrationNumber);
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
        title: Text(context.tr('jobs.newJob')),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: number,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: context.tr('common.registrationNumber'),
                    helperText: context.tr('common.generatedAutomatically'),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: name,
                  decoration: InputDecoration(
                    labelText: context.tr('jobs.jobName'),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: client,
                  decoration: InputDecoration(
                    labelText: context.tr('supervisor.client'),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: address,
                  decoration: InputDecoration(
                    labelText: context.tr('jobs.address'),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: city,
                  decoration: InputDecoration(
                    labelText: context.tr('jobs.city'),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: zip,
                  decoration: InputDecoration(
                    labelText: context.tr('jobs.zipCode'),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<JobStatus>(
                  initialValue: status,
                  decoration: InputDecoration(
                    labelText: context.tr('jobs.status'),
                  ),
                  items: [
                    for (final item in JobStatus.values)
                      DropdownMenuItem(
                        value: item,
                        child: Text(_jobStatusLabel(context, item)),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => status = value ?? status),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: notes,
                  decoration: InputDecoration(
                    labelText: context.tr('supervisor.notes'),
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
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('common.save')),
          ),
        ],
      ),
    ),
  );
  if (saved == true) {
    if (!context.mounted) return;
    final existingJobs = ref.read(supervisorCenterProvider).jobs;
    if (existingJobs.any(
      (job) =>
          job.registrationNumber == registrationNumber ||
          job.number == registrationNumber,
    )) {
      _snack(context, context.tr('fieldTime.duplicateRegistration'));
      number.dispose();
      name.dispose();
      client.dispose();
      address.dispose();
      city.dispose();
      zip.dispose();
      notes.dispose();
      return;
    }
    final supervisorId = ref.read(supervisorCenterProvider).currentUser.id;
    ref
        .read(supervisorCenterProvider.notifier)
        .addJob(
          SupervisorJob(
            id: RegistrationNumberPolicy.newUuid(),
            registrationNumber: registrationNumber,
            number: registrationNumber,
            name: name.text.trim().isEmpty
                ? context.tr('jobs.newJob')
                : name.text.trim(),
            client: client.text.trim(),
            address: address.text.trim(),
            city: city.text.trim(),
            state: 'FL',
            zipCode: zip.text.trim(),
            startDate: DateTime.now(),
            scheduledTime: '7:00 AM',
            supervisorId: supervisorId,
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

Future<void> _editJobOperations(
  BuildContext context,
  WidgetRef ref,
  SupervisorJob job,
) async {
  final state = ref.read(supervisorCenterProvider);
  final canEditPayPremium = state.currentRole == PilotRole.owner;
  final bonus = TextEditingController(
    text: job.travelBonusHours.toStringAsFixed(2),
  );
  final payLabel = TextEditingController(text: job.payPremiumLabel);
  var payPremiumEnabled = job.payPremiumEnabled;
  final reason = TextEditingController();
  final saved = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(_jobDisplayName(context, job)),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: bonus,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: context.tr('approval.travelBonus'),
                    helperText: '0, 1.00, 2.00',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.tr('jobs.payPremium')),
                  subtitle: Text(
                    canEditPayPremium
                        ? context.tr('auth.roleDirector')
                        : context.tr('supervisor.permissionDenied'),
                  ),
                  value: payPremiumEnabled,
                  onChanged: canEditPayPremium
                      ? (value) => setState(() => payPremiumEnabled = value)
                      : null,
                ),
                TextField(
                  controller: payLabel,
                  enabled: canEditPayPremium && payPremiumEnabled,
                  decoration: InputDecoration(
                    labelText: context.tr('jobs.payPremiumValue', {
                      'value': '+25%, +\$5.00/h, 2x',
                    }),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: reason,
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
          FilledButton(
            onPressed: () {
              if (reason.text.trim().isEmpty) return;
              Navigator.pop(context, true);
            },
            child: Text(context.tr('common.save')),
          ),
        ],
      ),
    ),
  );
  if (saved == true) {
    final updated = job.copyWith(
      travelBonusHours: double.tryParse(bonus.text.trim()) ?? 0,
      payPremiumEnabled: canEditPayPremium && payPremiumEnabled,
      payPremiumLabel: canEditPayPremium && payPremiumEnabled
          ? payLabel.text.trim()
          : '',
    );
    ref.read(supervisorCenterProvider.notifier).updateJob(updated);
    if (context.mounted) {
      _snack(context, context.tr('supervisor.travelBonusUpdatedSuccess'));
    }
  }
  bonus.dispose();
  payLabel.dispose();
  reason.dispose();
}

Future<String?> _textDialog(
  BuildContext context,
  String title,
  String label, {
  bool requiredValue = true,
}) async {
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
          child: Text(context.tr('common.cancel')),
        ),
        FilledButton(
          onPressed: () {
            if (requiredValue && controller.text.trim().isEmpty) return;
            Navigator.pop(context, controller.text);
          },
          child: Text(context.tr('common.save')),
        ),
      ],
    ),
  );
  controller.dispose();
  return value;
}

Future<_ReviewRequest?> _reviewRequestDialog(BuildContext context) async {
  final reason = TextEditingController();
  final observation = TextEditingController();
  final value = await showDialog<_ReviewRequest>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.tr('approval.reviewRecord')),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: reason,
              decoration: InputDecoration(
                labelText: context.tr('approval.reviewRequest'),
              ),
              minLines: 2,
              maxLines: 4,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: observation,
              decoration: InputDecoration(
                labelText: context.tr('approval.additionalObservations'),
              ),
              minLines: 2,
              maxLines: 4,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.tr('common.cancel')),
        ),
        FilledButton(
          onPressed: () {
            if (reason.text.trim().isEmpty) return;
            Navigator.pop(
              context,
              _ReviewRequest(
                reason: reason.text.trim(),
                observation: observation.text.trim(),
              ),
            );
          },
          child: Text(context.tr('approval.sendToReview')),
        ),
      ],
    ),
  );
  reason.dispose();
  observation.dispose();
  return value;
}

Future<bool?> _confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(context.tr('common.cancel')),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: AppColors.red)
              : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}

final class _ReviewRequest {
  const _ReviewRequest({required this.reason, required this.observation});

  final String reason;
  final String observation;
}

void _openJob(BuildContext context, String jobId) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => JobDetailScreen(jobId: jobId)));
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(_localizedFeedback(context, message))),
    );
}

String _localizedFeedback(BuildContext context, String text) {
  final isTranslationKey = RegExp(
    r'^[a-zA-Z][a-zA-Z0-9]*(\.[a-zA-Z0-9]+)+$',
  ).hasMatch(text);
  return isTranslationKey ? context.tr(text) : text;
}

List<JobAssignment> _assignmentsFor(
  SupervisorCenterState state,
  String jobId,
) => state.assignments.where((item) => item.jobId == jobId).toList();

bool _sameDay(DateTime left, DateTime right) =>
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day;

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
  final minutes = (value * 60).round();
  final safeMinutes = minutes < 0 ? 0 : minutes;
  return '${safeMinutes ~/ 60}h ${safeMinutes.remainder(60).toString().padLeft(2, '0')}m';
}

String _date(DateTime value) =>
    '${value.month.toString().padLeft(2, '0')}/${value.day.toString().padLeft(2, '0')}/${value.year}';

String _time(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
