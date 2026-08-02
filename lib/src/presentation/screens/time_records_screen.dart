import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jkdd_field_time_records_production/core/theme/app_assets.dart';
import 'package:jkdd_field_time_records_production/core/theme/app_colors.dart';
import 'package:jkdd_field_time_records_production/core/theme/app_radius.dart';
import 'package:jkdd_field_time_records_production/core/theme/app_shadows.dart';
import 'package:jkdd_field_time_records_production/core/theme/app_spacing.dart';
import 'package:jkdd_field_time_records_production/src/application/field_time_controller.dart';
import 'package:jkdd_field_time_records_production/src/domain/field_time_models.dart';
import 'package:jkdd_field_time_records_production/src/presentation/dialogs/receipt_dialog.dart';
import 'package:jkdd_field_time_records_production/src/presentation/screens/timesheet_screen.dart';
import 'package:jkdd_field_time_records_production/shared/widgets/jkdd_app_bar.dart';
import 'package:jkdd_field_time_records_production/shared/widgets/jkdd_buttons.dart';
import 'package:jkdd_field_time_records_production/shared/widgets/jkdd_empty_state.dart';
import 'package:jkdd_field_time_records_production/shared/widgets/jkdd_info_row.dart';
import 'package:jkdd_field_time_records_production/shared/widgets/jkdd_section_header.dart';
import 'package:jkdd_field_time_records_production/shared/widgets/jkdd_status_chip.dart';
import 'package:jkdd_field_time_records_production/shared/widgets/jkdd_summary_card.dart';

enum _Destination { home, timesheet, jobs, receipts, settings }

final class TimeRecordsScreen extends ConsumerStatefulWidget {
  const TimeRecordsScreen({super.key});

  @override
  ConsumerState<TimeRecordsScreen> createState() => _TimeRecordsScreenState();
}

final class _TimeRecordsScreenState extends ConsumerState<TimeRecordsScreen> {
  final _picker = ImagePicker();
  Timer? _ticker;
  DateTime _now = DateTime.now();
  _Destination _destination = _Destination.home;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(fieldTimeControllerProvider);

    ref.listen(fieldTimeControllerProvider, (previous, next) {
      final text = next.error ?? next.message;
      if (text == null ||
          text == previous?.error ||
          text == previous?.message) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(text)));
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 1024;
        final child = _selectedScreen(state);
        return Scaffold(
          appBar: JkddAppBar(
            online: state.online,
            pendingItems: state.pendingItems,
            onSettings: () =>
                setState(() => _destination = _Destination.settings),
          ),
          bottomNavigationBar: desktop
              ? null
              : BottomNavigationBar(
                  type: BottomNavigationBarType.fixed,
                  currentIndex: _destination.index,
                  selectedItemColor: AppColors.blue,
                  unselectedItemColor: AppColors.gray,
                  showUnselectedLabels: true,
                  onTap: (index) => setState(
                    () => _destination = _Destination.values[index],
                  ),
                  items: const [
                    BottomNavigationBarItem(
                      icon: Icon(Icons.dashboard),
                      label: 'Home',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.table_chart),
                      label: 'Timesheet',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.apartment),
                      label: 'Jobs',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.receipt_long),
                      label: 'Receipts',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.menu),
                      label: 'Menu',
                    ),
                  ],
                ),
          body: SafeArea(
            child: desktop
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _DesktopNavigation(
                        selected: _destination,
                        onSelected: (value) =>
                            setState(() => _destination = value),
                      ),
                      Expanded(child: child),
                    ],
                  )
                : child,
          ),
        );
      },
    );
  }

  Widget _selectedScreen(FieldTimeState state) => switch (_destination) {
        _Destination.home => _HomeView(
            state: state,
            now: _now,
            onClockIn: _clockIn,
            onSwitchJob: _switchJob,
            onEndDay: _endDay,
            onReceipt: _receipt,
            onPhoto: _photo,
            onObservation: _observation,
            onTimesheet: () =>
                setState(() => _destination = _Destination.timesheet),
          ),
        _Destination.timesheet => const TimesheetScreen(embedded: true),
        _Destination.jobs => _JobsView(snapshot: state.snapshot),
        _Destination.receipts => _ReceiptsView(
            snapshot: state.snapshot,
            onReceipt: _receipt,
          ),
        _Destination.settings => _SettingsView(
            currentVersion: 'v1.0.0',
            onLanguageSelected: () => _message(
              'Language switching is a pending functional requirement.',
            ),
          ),
      };

  Future<void> _clockIn() async {
    final snapshot = ref.read(fieldTimeControllerProvider).snapshot;
    final job = await _selectJob('Select job for clock in', snapshot.jobs);
    if (job == null) return;
    await ref.read(fieldTimeControllerProvider.notifier).clockIn(job, null);
  }

  Future<void> _switchJob() async {
    final state = ref.read(fieldTimeControllerProvider);
    final currentJobId = state.activeSegment?.jobId;
    final jobs = state.snapshot.jobs
        .where((job) => job.id != currentJobId)
        .toList(growable: false);
    final job = await _selectJob('Switch to which job?', jobs);
    if (job == null) return;
    await ref.read(fieldTimeControllerProvider.notifier).switchJob(job, null);
  }

  Future<void> _endDay() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End workday?'),
        content: const Text(
          'The current work period will be closed with the current time and GPS status.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('End workday'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(fieldTimeControllerProvider.notifier).endDay(null);
    if (!mounted) return;
    final state = ref.read(fieldTimeControllerProvider);
    if (state.lastCompletedDay != null) {
      await _showDaySummary(state.lastCompletedDay!, state.snapshot);
    }
  }

  Future<void> _receipt() async {
    final state = ref.read(fieldTimeControllerProvider);
    final activeJobId = state.activeSegment?.jobId;
    Job? initialJob;
    for (final job in state.snapshot.jobs) {
      if (job.id == activeJobId) initialJob = job;
    }
    final submission = await showDialog<ReceiptSubmission>(
      context: context,
      builder: (_) => ReceiptDialog(
        jobs: state.snapshot.jobs,
        initialJob: initialJob,
      ),
    );
    if (submission == null) return;
    await ref
        .read(fieldTimeControllerProvider.notifier)
        .saveReceipt(submission.draft, submission.file);
  }

  Future<void> _photo() async {
    final state = ref.read(fieldTimeControllerProvider);
    final active = state.activeSegment;
    if (active == null) {
      _message('Clock in before adding a job photo.');
      return;
    }
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Add photo'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, ImageSource.camera),
            child: const ListTile(
              leading: Icon(Icons.photo_camera_outlined),
              title: Text('Take photo'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
            child: const ListTile(
              leading: Icon(Icons.photo_library_outlined),
              title: Text('Select image'),
            ),
          ),
        ],
      ),
    );
    if (source == null) return;
    try {
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 72,
        maxWidth: 1600,
      );
      if (file == null || !mounted) return;
      final job =
          state.snapshot.jobs.firstWhere((job) => job.id == active.jobId);
      await ref
          .read(fieldTimeControllerProvider.notifier)
          .addJobPhoto(file, job);
    } on Exception {
      _message('Camera or photo library could not be opened on this device.');
    }
  }

  Future<void> _observation() async {
    final state = ref.read(fieldTimeControllerProvider);
    if (state.activeSegment == null) {
      _message('Clock in before adding notes.');
      return;
    }
    final controller = TextEditingController(text: state.activeSegment?.notes);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Current period note'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(hintText: 'Type a note'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value?.trim().isEmpty != false) return;
    await ref.read(fieldTimeControllerProvider.notifier).addObservation(value!);
  }

  Future<Job?> _selectJob(String title, List<Job> jobs) => showDialog<Job>(
        context: context,
        builder: (context) => SimpleDialog(
          title: Text(title),
          children: [
            for (final job in jobs)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, job),
                child: ListTile(
                  leading: const Icon(Icons.apartment_outlined),
                  title: Text(job.displayName),
                  subtitle: Text(job.address),
                ),
              ),
          ],
        ),
      );

  Future<void> _showDaySummary(WorkDay day, FieldTimeSnapshot snapshot) async {
    final sentReceipts = snapshot.receipts
        .where(
          (receipt) =>
              _sameDate(receipt.purchaseDate, day.workDate) &&
              receipt.status != ReceiptStatus.draft,
        )
        .length;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Workday summary'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SummaryLine('First clock in', _time(day.firstClockIn)),
                _SummaryLine('Last clock out', _time(day.lastClockOut)),
                _SummaryLine('Hours worked', _duration(day.workedDuration)),
                _SummaryLine('Bonus hours', _hours(day.travelBonusHours)),
                _SummaryLine('Receipts submitted', sentReceipts.toString()),
                _SummaryLine(
                  'Pending sync',
                  snapshot.syncQueue.length.toString(),
                ),
                const Divider(height: 24),
                Text('Jobs visited',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final segment in day.segments)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '${segment.jobNumber} - ${segment.jobName}: '
                      '${_duration(segment.duration())}',
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _message(String value) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(value)));
}

final class _DesktopNavigation extends StatelessWidget {
  const _DesktopNavigation({required this.selected, required this.onSelected});

  final _Destination selected;
  final ValueChanged<_Destination> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 252,
      color: AppColors.navy,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
            child: Image.asset(AppAssets.fieldTimeLogoDark),
          ),
          Expanded(
            child: NavigationRail(
              extended: true,
              selectedIndex: selected.index,
              onDestinationSelected: (index) =>
                  onSelected(_Destination.values[index]),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: Text('Home'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.table_chart_outlined),
                  selectedIcon: Icon(Icons.table_chart),
                  label: Text('Timesheet'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.apartment_outlined),
                  selectedIcon: Icon(Icons.apartment),
                  label: Text('Jobs'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long),
                  label: Text('Receipts'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: Text('Settings'),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'by JKDD TECH',
              style: TextStyle(
                  color: Color(0xffcbd5e1), fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

final class _HomeView extends StatelessWidget {
  const _HomeView({
    required this.state,
    required this.now,
    required this.onClockIn,
    required this.onSwitchJob,
    required this.onEndDay,
    required this.onReceipt,
    required this.onPhoto,
    required this.onObservation,
    required this.onTimesheet,
  });

  final FieldTimeState state;
  final DateTime now;
  final VoidCallback onClockIn;
  final VoidCallback onSwitchJob;
  final VoidCallback onEndDay;
  final VoidCallback onReceipt;
  final VoidCallback onPhoto;
  final VoidCallback onObservation;
  final VoidCallback onTimesheet;

  @override
  Widget build(BuildContext context) {
    final snapshot = state.snapshot;
    final activeSegment = state.activeSegment;
    final working = activeSegment != null;
    final todaySegments = _todaySegments(snapshot, now);
    final worked = todaySegments.fold(
      Duration.zero,
      (total, segment) => total + segment.duration(now),
    );
    final bonusHours = todaySegments.fold<double>(
      0,
      (total, segment) => total + segment.travelBonusHours,
    );
    final reimbursementTotal = snapshot.reimbursements.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );

    return _PageFrame(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 860;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _GreetingBand(state: state, now: now),
              const SizedBox(height: AppSpacing.xl),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 6,
                      child: _CurrentStatusCard(
                        state: state,
                        now: now,
                        activeSegment: activeSegment,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xl),
                    Expanded(
                      flex: 4,
                      child: _ActionCenter(
                        working: working,
                        loading: state.loading,
                        onClockIn: onClockIn,
                        onEndDay: onEndDay,
                        onSwitchJob: onSwitchJob,
                        onReceipt: onReceipt,
                        onPhoto: onPhoto,
                        onObservation: onObservation,
                        onTimesheet: onTimesheet,
                      ),
                    ),
                  ],
                )
              else ...[
                _CurrentStatusCard(
                  state: state,
                  now: now,
                  activeSegment: activeSegment,
                ),
                const SizedBox(height: AppSpacing.lg),
                _ActionCenter(
                  working: working,
                  loading: state.loading,
                  onClockIn: onClockIn,
                  onEndDay: onEndDay,
                  onSwitchJob: onSwitchJob,
                  onReceipt: onReceipt,
                  onPhoto: onPhoto,
                  onObservation: onObservation,
                  onTimesheet: onTimesheet,
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              JkddSectionHeader(
                title: 'Daily summary',
                subtitle: _date(now),
              ),
              const SizedBox(height: AppSpacing.md),
              _SummaryGrid(
                items: [
                  _SummarySpec('Hours Worked', _duration(worked),
                      Icons.schedule, AppColors.blue),
                  _SummarySpec('Bonus Hours', _hours(bonusHours),
                      Icons.route_outlined, AppColors.teal),
                  _SummarySpec(
                    'Jobs Visited',
                    todaySegments
                        .map((item) => item.jobId)
                        .toSet()
                        .length
                        .toString(),
                    Icons.apartment_outlined,
                    AppColors.purple,
                  ),
                  _SummarySpec(
                    'Receipts',
                    snapshot.receipts.length.toString(),
                    Icons.receipt_long_outlined,
                    AppColors.amber,
                  ),
                  _SummarySpec(
                    'Reimbursements',
                    _money(reimbursementTotal),
                    Icons.payments_outlined,
                    AppColors.green,
                  ),
                  _SummarySpec(
                    'Pending Sync',
                    state.pendingItems.toString(),
                    Icons.sync_problem_outlined,
                    state.pendingItems == 0 ? AppColors.green : AppColors.amber,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _TodayTimeline(segments: todaySegments, now: now),
                    ),
                    const SizedBox(width: AppSpacing.xl),
                    Expanded(
                      child: _ReceiptOverview(snapshot: snapshot),
                    ),
                  ],
                )
              else ...[
                _TodayTimeline(segments: todaySegments, now: now),
                const SizedBox(height: AppSpacing.xl),
                _ReceiptOverview(snapshot: snapshot),
              ],
            ],
          );
        },
      ),
    );
  }
}

final class _PageFrame extends StatelessWidget {
  const _PageFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
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
}

final class _GreetingBand extends StatelessWidget {
  const _GreetingBand({required this.state, required this.now});

  final FieldTimeState state;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final working = state.activeSegment != null;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.soft,
      ),
      child: Wrap(
        spacing: AppSpacing.xl,
        runSpacing: AppSpacing.lg,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset(AppAssets.fieldTimeLogoDark, height: 58),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  '${_greeting(now)}, Joukin.',
                  style: Theme.of(context)
                      .textTheme
                      .headlineLarge
                      ?.copyWith(color: AppColors.white),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${_date(now)} - ${working ? 'Workday in progress' : 'Ready to clock in'}',
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: const Color(0xffcbd5e1)),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              JkddStatusChip(
                label: working ? 'Clocked in' : 'Clocked out',
                icon: working
                    ? Icons.play_circle_outline
                    : Icons.pause_circle_outline,
                tone: working ? JkddStatusTone.success : JkddStatusTone.neutral,
              ),
              JkddStatusChip(
                label: state.online ? 'Online' : 'Offline',
                icon: state.online
                    ? Icons.cloud_done_outlined
                    : Icons.cloud_off_outlined,
                tone: state.online
                    ? JkddStatusTone.success
                    : JkddStatusTone.warning,
              ),
              JkddStatusChip(
                label: '${state.pendingItems} pending',
                icon: Icons.sync_problem_outlined,
                tone: state.pendingItems == 0
                    ? JkddStatusTone.success
                    : JkddStatusTone.warning,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

final class _CurrentStatusCard extends StatelessWidget {
  const _CurrentStatusCard({
    required this.state,
    required this.now,
    required this.activeSegment,
  });

  final FieldTimeState state;
  final DateTime now;
  final WorkSegment? activeSegment;

  @override
  Widget build(BuildContext context) {
    final segment = activeSegment;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            JkddSectionHeader(
              title: 'Current status',
              subtitle: 'Live field activity overview',
              trailing: JkddStatusChip(
                label: segment == null ? 'Clocked out' : 'Clocked in',
                icon: segment == null ? Icons.logout : Icons.login,
                tone: segment == null
                    ? JkddStatusTone.neutral
                    : JkddStatusTone.success,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              segment == null
                  ? 'No active job'
                  : '${segment.jobNumber} - ${segment.jobName}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              segment?.jobAddress ?? 'Select a job when clocking in.',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: AppColors.gray),
            ),
            const Divider(height: 36),
            _InfoGrid(
              children: [
                JkddInfoRow(
                  icon: Icons.login,
                  label: 'Clock in time',
                  value: _time(segment?.startedAt),
                ),
                JkddInfoRow(
                  icon: Icons.timer_outlined,
                  label: 'Worked time',
                  value: segment == null
                      ? '00h 00m'
                      : _duration(segment.duration(now)),
                ),
                JkddInfoRow(
                  icon: Icons.gps_fixed,
                  label: 'GPS',
                  value: _gps(state.lastLocation ?? segment?.startedLocation),
                ),
                JkddInfoRow(
                  icon: Icons.business_outlined,
                  label: 'Client company',
                  value: state.snapshot.companyName,
                ),
                JkddInfoRow(
                  icon: Icons.engineering_outlined,
                  label: 'Subcontractor',
                  value: state.snapshot.worker.displayName,
                ),
              ],
            ),
            if (segment?.notes?.isNotEmpty == true) ...[
              const Divider(height: 36),
              JkddInfoRow(
                icon: Icons.note_outlined,
                label: 'Current note',
                value: segment!.notes!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

final class _ActionCenter extends StatelessWidget {
  const _ActionCenter({
    required this.working,
    required this.loading,
    required this.onClockIn,
    required this.onEndDay,
    required this.onSwitchJob,
    required this.onReceipt,
    required this.onPhoto,
    required this.onObservation,
    required this.onTimesheet,
  });

  final bool working;
  final bool loading;
  final VoidCallback onClockIn;
  final VoidCallback onEndDay;
  final VoidCallback onSwitchJob;
  final VoidCallback onReceipt;
  final VoidCallback onPhoto;
  final VoidCallback onObservation;
  final VoidCallback onTimesheet;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Primary action',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            JkddPrimaryButton(
              label: working ? 'END WORKDAY' : 'CLOCK IN',
              icon: working
                  ? Icons.stop_circle_outlined
                  : Icons.play_circle_outline,
              critical: working,
              loading: loading,
              onPressed: working ? onEndDay : onClockIn,
            ),
            if (loading) ...[
              const SizedBox(height: AppSpacing.md),
              const LinearProgressIndicator(),
            ],
            const SizedBox(height: AppSpacing.xl),
            Text('Secondary actions',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            _ActionButtonGrid(
              actions: [
                _ActionSpec('Switch Job', Icons.swap_horiz, onSwitchJob,
                    enabled: working),
                _ActionSpec(
                    'Attach Receipt', Icons.receipt_long_outlined, onReceipt),
                _ActionSpec('Request Reimbursement', Icons.payments_outlined,
                    onReceipt),
                _ActionSpec('Add Photo', Icons.add_a_photo_outlined, onPhoto,
                    enabled: working),
                _ActionSpec('Add Note', Icons.note_add_outlined, onObservation,
                    enabled: working),
                _ActionSpec(
                    'My Timesheet', Icons.table_chart_outlined, onTimesheet),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

final class _ActionSpec {
  const _ActionSpec(this.label, this.icon, this.onPressed,
      {this.enabled = true});

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool enabled;
}

final class _ActionButtonGrid extends StatelessWidget {
  const _ActionButtonGrid({required this.actions});

  final List<_ActionSpec> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 520 ? 2 : 1;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: columns == 1 ? 4.8 : 2.8,
          crossAxisSpacing: AppSpacing.sm,
          mainAxisSpacing: AppSpacing.sm,
          children: [
            for (final action in actions)
              JkddSecondaryButton(
                label: action.label,
                icon: action.icon,
                onPressed: action.onPressed,
                enabled: action.enabled,
              ),
          ],
        );
      },
    );
  }
}

final class _SummarySpec {
  const _SummarySpec(this.label, this.value, this.icon, this.color);

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

final class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.items});

  final List<_SummarySpec> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth >= 1040
            ? 6
            : constraints.maxWidth >= 760
                ? 3
                : 2;
        return GridView.count(
          crossAxisCount: count,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: count == 2 ? 1.2 : 1.05,
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
}

final class _TodayTimeline extends StatelessWidget {
  const _TodayTimeline({required this.segments, required this.now});

  final List<WorkSegment> segments;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const JkddSectionHeader(
          title: 'Today timesheet',
          subtitle: 'Timeline of work periods for this device.',
        ),
        const SizedBox(height: AppSpacing.md),
        if (segments.isEmpty)
          const JkddEmptyState(
            icon: Icons.timeline_outlined,
            title: 'No work periods yet',
            message: "Clock in to start building today's timesheet.",
          )
        else
          for (final segment in segments)
            Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: ListTile(
                leading:
                    const Icon(Icons.apartment_outlined, color: AppColors.blue),
                title: Text('${segment.jobNumber} - ${segment.jobName}'),
                subtitle: Text(
                    '${_time(segment.startedAt)} - ${_time(segment.endedAt)}'),
                trailing: Text(_duration(segment.duration(now))),
              ),
            ),
      ],
    );
  }
}

final class _ReceiptOverview extends StatelessWidget {
  const _ReceiptOverview({required this.snapshot});

  final FieldTimeSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final total = snapshot.reimbursements.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        JkddSectionHeader(
          title: 'Receipts and reimbursements',
          subtitle:
              '${snapshot.receipts.length} receipts - ${_money(total)} total',
        ),
        const SizedBox(height: AppSpacing.md),
        if (snapshot.receipts.isEmpty)
          const JkddEmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No receipts yet',
            message: 'Attach a receipt when a job expense needs reimbursement.',
          )
        else
          for (final receipt in snapshot.receipts.reversed.take(3))
            Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: ListTile(
                leading: const Icon(Icons.receipt_long_outlined,
                    color: AppColors.amber),
                title: Text(receipt.merchant),
                subtitle: Text(_receiptStatus(receipt.status)),
                trailing: Text(_money(receipt.total)),
              ),
            ),
      ],
    );
  }
}

final class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth >= 620 ? 260.0 : double.infinity;
        return Wrap(
          spacing: AppSpacing.xl,
          runSpacing: AppSpacing.lg,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

final class _JobsView extends StatelessWidget {
  const _JobsView({required this.snapshot});

  final FieldTimeSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return _PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const JkddSectionHeader(
            title: 'Jobs',
            subtitle: 'Visual directory of available Field Time jobs.',
          ),
          const SizedBox(height: AppSpacing.lg),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 900
                  ? 3
                  : constraints.maxWidth >= 620
                      ? 2
                      : 1;
              return GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: columns == 1 ? 2.9 : 1.7,
                crossAxisSpacing: AppSpacing.md,
                mainAxisSpacing: AppSpacing.md,
                children: [
                  for (final job in snapshot.jobs)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.apartment_outlined,
                                    color: AppColors.blue),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    job.displayName,
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Text(job.address),
                            const SizedBox(height: AppSpacing.sm),
                            JkddStatusChip(
                              label: job.active ? 'Active' : 'Inactive',
                              icon: job.active
                                  ? Icons.check_circle_outline
                                  : Icons.block,
                              tone: job.active
                                  ? JkddStatusTone.success
                                  : JkddStatusTone.neutral,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

final class _ReceiptsView extends StatelessWidget {
  const _ReceiptsView({required this.snapshot, required this.onReceipt});

  final FieldTimeSnapshot snapshot;
  final VoidCallback onReceipt;

  @override
  Widget build(BuildContext context) {
    final total = snapshot.reimbursements
        .fold<double>(0, (sum, item) => sum + item.amount);
    return _PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          JkddSectionHeader(
            title: 'Receipts and reimbursements',
            subtitle:
                '${snapshot.receipts.length} receipts - ${_money(total)} total',
            trailing: FilledButton.icon(
              onPressed: onReceipt,
              icon: const Icon(Icons.add),
              label: const Text('Attach Receipt'),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (snapshot.receipts.isEmpty)
            const JkddEmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No receipts on this device',
              message:
                  'Use Attach Receipt to capture an expense and request reimbursement.',
            )
          else
            for (final receipt in snapshot.receipts.reversed)
              Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                child: ListTile(
                  leading: const Icon(Icons.receipt_long_outlined,
                      color: AppColors.amber),
                  title: Text(receipt.merchant),
                  subtitle: Text(
                      '${_date(receipt.purchaseDate)} - ${_receiptStatus(receipt.status)}'),
                  trailing: Text(_money(receipt.total)),
                ),
              ),
        ],
      ),
    );
  }
}

final class _SettingsView extends StatelessWidget {
  const _SettingsView({
    required this.currentVersion,
    required this.onLanguageSelected,
  });

  final String currentVersion;
  final VoidCallback onLanguageSelected;

  @override
  Widget build(BuildContext context) {
    return _PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const JkddSectionHeader(
            title: 'Settings',
            subtitle: 'Visual layout only. Functional preferences are pending.',
          ),
          const SizedBox(height: AppSpacing.lg),
          const _SettingsSection(
            title: 'Account',
            children: [
              _SettingsTile('Profile', Icons.person_outline, 'Coming Soon'),
              _SettingsTile('Company', Icons.business_outlined, 'Coming Soon'),
              _SettingsTile(
                  'Permissions', Icons.verified_user_outlined, 'Coming Soon'),
            ],
          ),
          _SettingsSection(
            title: 'Preferences',
            children: [
              _LanguageTile(onTap: onLanguageSelected),
              const _SettingsTile(
                  'Theme', Icons.dark_mode_outlined, 'System default'),
              const _SettingsTile(
                  'Date Format', Icons.calendar_today_outlined, 'MM/DD/YYYY'),
              const _SettingsTile(
                  'Time Format', Icons.schedule_outlined, '12-hour'),
              const _SettingsTile(
                  'Measurement Units', Icons.straighten_outlined, 'U.S.'),
            ],
          ),
          const _SettingsSection(
            title: 'Reports',
            children: [
              _SettingsTile('Timesheet Format', Icons.table_chart_outlined,
                  'Coming Soon'),
              _SettingsTile(
                  'Default Paper Size', Icons.description_outlined, 'Letter'),
              _SettingsTile('PDF Orientation',
                  Icons.screen_rotation_alt_outlined, 'Landscape planned'),
            ],
          ),
          _SettingsSection(
            title: 'About',
            children: [
              const _SettingsTile(
                  'Field Time', Icons.info_outline, 'by JKDD TECH'),
              _SettingsTile('Version', Icons.tag_outlined, currentVersion),
              const _SettingsTile(
                  'Privacy', Icons.privacy_tip_outlined, 'Coming Soon'),
              const _SettingsTile(
                  'Terms', Icons.article_outlined, 'Coming Soon'),
            ],
          ),
        ],
      ),
    );
  }
}

final class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

final class _SettingsTile extends StatelessWidget {
  const _SettingsTile(this.title, this.icon, this.value);

  final String title;
  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.blue),
      title: Text(title),
      trailing: Text(value, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}

final class _LanguageTile extends StatelessWidget {
  const _LanguageTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.language, color: AppColors.blue),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Language',
                      style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 4),
                  Text(
                    'English is the visual base. Switching is Coming Soon.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.gray),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      Chip(label: Text('English')),
                      Chip(label: Text('Português')),
                      Chip(label: Text('Español')),
                    ],
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

final class _SummaryLine extends StatelessWidget {
  const _SummaryLine(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

List<WorkSegment> _todaySegments(FieldTimeSnapshot snapshot, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  return snapshot.workDays
      .where((day) => _sameDate(day.workDate, today))
      .expand((day) => day.segments)
      .toList(growable: false);
}

bool _sameDate(DateTime left, DateTime right) =>
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day;

String _greeting(DateTime value) {
  if (value.hour < 12) return 'Good morning';
  if (value.hour < 18) return 'Good afternoon';
  return 'Good evening';
}

String _date(DateTime value) => '${value.month.toString().padLeft(2, '0')}/'
    '${value.day.toString().padLeft(2, '0')}/${value.year}';

String _time(DateTime? value) => value == null
    ? '--:--'
    : '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';

String _duration(Duration value) =>
    '${value.inHours}h ${value.inMinutes.remainder(60).toString().padLeft(2, '0')}m';

String _hours(double value) =>
    _duration(Duration(minutes: (value * 60).round()));

String _money(double value) => '\$${value.toStringAsFixed(2)}';

String _gps(dynamic point) {
  if (point == null || point.isOfflineFallback == true) return 'Unavailable';
  return '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
}

String _receiptStatus(ReceiptStatus status) => switch (status) {
      ReceiptStatus.draft => 'Draft',
      ReceiptStatus.submitted => 'Submitted',
      ReceiptStatus.underReview => 'Under review',
      ReceiptStatus.approved => 'Approved',
      ReceiptStatus.rejected => 'Rejected',
      ReceiptStatus.paid => 'Paid',
    };
