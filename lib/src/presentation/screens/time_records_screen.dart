import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jkdd_field_time_records_production/core/theme/app_assets.dart';
import 'package:jkdd_field_time_records_production/core/theme/app_colors.dart';
import 'package:jkdd_field_time_records_production/core/theme/app_radius.dart';
import 'package:jkdd_field_time_records_production/core/theme/app_shadows.dart';
import 'package:jkdd_field_time_records_production/core/theme/app_spacing.dart';
import 'package:jkdd_field_time_records_production/features/employees/presentation/employees_management_screen.dart';
import 'package:jkdd_field_time_records_production/features/jobs/presentation/jobs_import_screen.dart';
import 'package:jkdd_field_time_records_production/src/application/field_time_controller.dart';
import 'package:jkdd_field_time_records_production/src/auth/auth_session.dart';
import 'package:jkdd_field_time_records_production/src/domain/field_time_models.dart';
import 'package:jkdd_field_time_records_production/src/domain/registration_number.dart';
import 'package:jkdd_field_time_records_production/src/localization/app_language.dart';
import 'package:jkdd_field_time_records_production/src/platform/app_refresh.dart';
import 'package:jkdd_field_time_records_production/src/presentation/dialogs/receipt_dialog.dart';
import 'package:jkdd_field_time_records_production/src/presentation/screens/timesheet_screen.dart';
import 'package:jkdd_field_time_records_production/src/supervisor_center/supervisor_center_controller.dart';
import 'package:jkdd_field_time_records_production/src/supervisor_center/supervisor_center_models.dart';
import 'package:jkdd_field_time_records_production/src/supervisor_center/supervisor_center_screen.dart';
import 'package:jkdd_field_time_records_production/shared/widgets/jkdd_app_bar.dart';
import 'package:jkdd_field_time_records_production/shared/widgets/jkdd_buttons.dart';
import 'package:jkdd_field_time_records_production/shared/widgets/jkdd_empty_state.dart';
import 'package:jkdd_field_time_records_production/shared/widgets/jkdd_info_row.dart';
import 'package:jkdd_field_time_records_production/shared/widgets/jkdd_job_navigation_button.dart';
import 'package:jkdd_field_time_records_production/shared/widgets/jkdd_section_header.dart';
import 'package:jkdd_field_time_records_production/shared/widgets/jkdd_status_chip.dart';

enum _Destination {
  home,
  timesheet,
  jobs,
  receipts,
  employees,
  management,
  settings,
}

final class TimeRecordsScreen extends ConsumerStatefulWidget {
  const TimeRecordsScreen({super.key});

  @override
  ConsumerState<TimeRecordsScreen> createState() => _TimeRecordsScreenState();
}

final class _TimeRecordsScreenState extends ConsumerState<TimeRecordsScreen> {
  final _picker = ImagePicker();
  Timer? _ticker;
  DateTime _now = DateTime.now();
  _Destination _destination = Uri.base.queryParameters['section'] == 'settings'
      ? _Destination.settings
      : _Destination.home;
  int _managementResetToken = 0;

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
    final pilotState = ref.watch(supervisorCenterProvider);
    final session = ref.watch(authSessionProvider);

    ref.listen(authSessionProvider, (previous, next) {
      final user = next.user;
      if (user == null || previous?.user?.id == user.id) return;
      final controller = ref.read(supervisorCenterProvider.notifier);
      if (user.role == PilotRole.owner) {
        controller.setSimulation(PilotRole.owner, userId: user.id);
      } else {
        controller.setRole(user.role);
      }
    });
    if (session.user != null &&
        !{PilotRole.owner, PilotRole.supervisor}.contains(session.user!.role) &&
        pilotState.currentRole != session.user!.role) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(supervisorCenterProvider.notifier).setRole(session.user!.role);
      });
    }

    ref.listen(fieldTimeControllerProvider, (previous, next) {
      final text = next.error ?? next.message;
      final values = next.error != null ? next.errorValues : next.messageValues;
      if (text == null ||
          text == previous?.error ||
          text == previous?.message) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(_localizedFeedback(context, text, values))),
        );
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 1024;
        final destinations = _visibleDestinations(pilotState);
        final selected = destinations.contains(_destination)
            ? _destination
            : _Destination.home;
        final child = _selectedScreen(state, pilotState, selected);
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
                  currentIndex: destinations.indexOf(selected),
                  selectedItemColor: AppColors.blue,
                  unselectedItemColor: AppColors.gray,
                  showUnselectedLabels: true,
                  onTap: (index) => _selectDestination(destinations[index]),
                  items: [
                    for (final destination in destinations)
                      _bottomItem(context, destination),
                  ],
                ),
          body: SafeArea(
            child: desktop
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _DesktopNavigation(
                        selected: selected,
                        destinations: destinations,
                        onSelected: _selectDestination,
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

  void _selectDestination(_Destination destination) {
    setState(() {
      _destination = destination;
      if (destination == _Destination.management) {
        _managementResetToken += 1;
      }
    });
  }

  List<_Destination> _visibleDestinations(SupervisorCenterState pilotState) => [
    _Destination.home,
    _Destination.timesheet,
    _Destination.jobs,
    _Destination.receipts,
    if (pilotState.hasPermission(PilotPermission.viewManagement))
      _Destination.employees,
    if (pilotState.hasPermission(PilotPermission.viewManagement))
      _Destination.management,
    _Destination.settings,
  ];

  BottomNavigationBarItem _bottomItem(
    BuildContext context,
    _Destination destination,
  ) => switch (destination) {
    _Destination.home => BottomNavigationBarItem(
      icon: const Icon(Icons.dashboard),
      label: context.tr('nav.home'),
    ),
    _Destination.timesheet => BottomNavigationBarItem(
      icon: const Icon(Icons.table_chart),
      label: context.tr('nav.timesheet'),
    ),
    _Destination.jobs => BottomNavigationBarItem(
      icon: const Icon(Icons.apartment),
      label: context.tr('nav.jobs'),
    ),
    _Destination.receipts => BottomNavigationBarItem(
      icon: const Icon(Icons.receipt_long),
      label: context.tr('nav.receipts'),
    ),
    _Destination.employees => BottomNavigationBarItem(
      icon: const Icon(Icons.badge),
      label: context.tr('nav.employees'),
    ),
    _Destination.management => BottomNavigationBarItem(
      icon: const Icon(Icons.engineering_outlined),
      label: context.tr('nav.management'),
    ),
    _Destination.settings => BottomNavigationBarItem(
      icon: const Icon(Icons.menu),
      label: context.tr('nav.menu'),
    ),
  };

  Widget _selectedScreen(
    FieldTimeState state,
    SupervisorCenterState pilotState,
    _Destination selected,
  ) => switch (selected) {
    _Destination.home => _HomeView(
      state: state,
      now: _now,
      onClockIn: _clockIn,
      onSwitchJob: _switchJob,
      onEndDay: _endDay,
      onReceipt: _receipt,
      onPhoto: _photo,
      onObservation: _observation,
      onTimesheet: () => setState(() => _destination = _Destination.timesheet),
    ),
    _Destination.timesheet => const TimesheetScreen(embedded: true),
    _Destination.jobs => _JobsView(
      snapshot: state.snapshot,
      canCreateJob: pilotState.hasPermission(PilotPermission.createJob),
    ),
    _Destination.receipts => _ReceiptsView(
      snapshot: state.snapshot,
      onReceipt: _receipt,
      onEditReceipt: _editReceipt,
    ),
    _Destination.employees => const EmployeesManagementScreen(embedded: true),
    _Destination.management => SupervisorCenterScreen(
      key: ValueKey('management-$_managementResetToken'),
    ),
    _Destination.settings => _SettingsView(
      currentVersion: 'v1.1.0-test4',
      onJobsImport: _openJobsImport,
      onLogout: _logout,
      onRefreshApp: () => refreshApplication(returnToSettings: true),
      onClearCacheAndRefresh: () =>
          refreshApplication(clearCache: true, returnToSettings: true),
      directorTestMode: {
        PilotRole.owner,
        PilotRole.supervisor,
      }.contains(ref.watch(authSessionProvider).user?.role),
      pilotState: pilotState,
      onSimulationChanged: (role, userId) {
        ref
            .read(supervisorCenterProvider.notifier)
            .setSimulation(role, userId: userId);
        if ({PilotRole.employee, PilotRole.contractor}.contains(role) &&
            userId != null) {
          unawaited(
            ref
                .read(fieldTimeControllerProvider.notifier)
                .setSimulatedWorker(userId),
          );
        }
        // Keep the user inside Settings after changing the simulated
        // profile. The new identity is reflected when they intentionally
        // navigate to Home, Timesheet, Management, or another section.
        if (mounted) {
          setState(() => _destination = _Destination.settings);
        }
      },
      currentLanguage: ref.watch(appLanguageControllerProvider),
      onLanguageChanged: (language) async {
        final savedMessage = context.tr('settings.saved');
        await ref
            .read(appLanguageControllerProvider.notifier)
            .setLanguage(language);
        if (mounted) _message(savedMessage);
      },
    ),
  };

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('auth.logout')),
        content: Text(context.tr('auth.logoutConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('auth.logout')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(authSessionProvider.notifier).logout();
  }

  Future<void> _clockIn() async {
    final snapshot = ref.read(fieldTimeControllerProvider).snapshot;
    final jobs = snapshot.jobs.where((job) => job.active).toList();
    final job = await _selectJob(context.tr('jobs.selectJobForClockIn'), jobs);
    if (job == null) return;
    await ref.read(fieldTimeControllerProvider.notifier).clockIn(job, null);
  }

  Future<void> _switchJob() async {
    final state = ref.read(fieldTimeControllerProvider);
    final currentJobId = state.activeSegment?.jobId;
    final jobs = state.snapshot.jobs
        .where((job) => job.active && job.id != currentJobId)
        .toList(growable: false);
    final job = await _selectJob(context.tr('jobs.switchToWhichJob'), jobs);
    if (job == null) return;
    await ref.read(fieldTimeControllerProvider.notifier).switchJob(job, null);
  }

  Future<void> _endDay() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('endDay.title')),
        content: Text(context.tr('endDay.message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('endDay.confirm')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await ref.read(fieldTimeControllerProvider.notifier).endDay(null);
    if (!mounted) return;
    final state = ref.read(fieldTimeControllerProvider);
    if (state.lastCompletedDay == null) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('endDay.success')),
        content: Text(
          '${context.tr('endDay.success')}. ${context.tr('endDay.rest')}!',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('common.done')),
          ),
        ],
      ),
    );
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
      builder: (_) =>
          ReceiptDialog(jobs: state.snapshot.jobs, initialJob: initialJob),
    );
    if (submission == null) return;
    await ref
        .read(fieldTimeControllerProvider.notifier)
        .saveReceipt(submission.draft, submission.file);
  }

  Future<void> _editReceipt(Receipt receipt) async {
    if (receipt.status != ReceiptStatus.draft) return;
    final state = ref.read(fieldTimeControllerProvider);
    if (state.snapshot.jobs.isEmpty) return;
    Job? initialJob;
    for (final job in state.snapshot.jobs) {
      if (job.id == receipt.jobId) initialJob = job;
    }
    final submission = await showDialog<ReceiptSubmission>(
      context: context,
      builder: (_) => ReceiptDialog(
        jobs: state.snapshot.jobs,
        initialJob: initialJob,
        initialReceipt: receipt,
      ),
    );
    if (submission == null) return;
    await ref
        .read(fieldTimeControllerProvider.notifier)
        .updateReceipt(receipt, submission.draft, submission.file);
  }

  Future<void> _photo() async {
    final state = ref.read(fieldTimeControllerProvider);
    final active = state.activeSegment;
    if (active == null) {
      _message(context.tr('photo.clockInRequired'));
      return;
    }
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(context.tr('photo.addPhoto')),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, ImageSource.camera),
            child: ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(context.tr('photo.takePhoto')),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
            child: ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(context.tr('photo.selectImage')),
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
      final job = state.snapshot.jobs.firstWhere(
        (job) => job.id == active.jobId,
        orElse: () => Job(
          id: active.jobId,
          companyId: active.companyId,
          subcontractorCompanyId: active.subcontractorCompanyId,
          number: active.jobNumber,
          name: active.jobName,
          address: active.jobAddress,
        ),
      );
      await ref
          .read(fieldTimeControllerProvider.notifier)
          .addJobPhoto(file, job);
    } on Exception {
      if (!mounted) return;
      _message(context.tr('photo.cameraUnavailable'));
    }
  }

  Future<void> _observation() async {
    final state = ref.read(fieldTimeControllerProvider);
    if (state.activeSegment == null) {
      _message(context.tr('note.clockInRequired'));
      return;
    }
    final controller = TextEditingController(text: state.activeSegment?.notes);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('note.currentPeriod')),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 3,
          maxLines: 6,
          decoration: InputDecoration(hintText: context.tr('note.hint')),
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
    if (value?.trim().isEmpty != false) return;
    await ref.read(fieldTimeControllerProvider.notifier).addObservation(value!);
  }

  Future<Job?> _selectJob(String title, List<Job> jobs) async {
    final search = TextEditingController();
    var query = '';
    final selected = await showDialog<Job>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final normalized = query.trim().toLowerCase();
          final filtered = normalized.isEmpty
              ? jobs
              : jobs
                    .where((job) {
                      final haystack = [
                        job.number,
                        job.name,
                        job.address,
                        job.city ?? '',
                        job.client ?? '',
                      ].join(' ').toLowerCase();
                      return haystack.contains(normalized);
                    })
                    .toList(growable: false);
          return AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: 560,
              height: MediaQuery.sizeOf(context).height * 0.62,
              child: Column(
                children: [
                  TextField(
                    controller: search,
                    autofocus: jobs.length > 6,
                    onChanged: (value) => setDialogState(() => query = value),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      labelText: 'Buscar obra',
                      hintText: 'Número, nome, endereço, cidade ou cliente',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Expanded(
                    child: jobs.isEmpty
                        ? JkddEmptyState(
                            icon: Icons.apartment_outlined,
                            title: context.tr('jobs.noJobsAvailable'),
                            message: context.tr('jobs.noJobsAvailableHelp'),
                          )
                        : filtered.isEmpty
                        ? const JkddEmptyState(
                            icon: Icons.search_off_outlined,
                            title: 'Nenhuma obra encontrada',
                            message:
                                'Tente outro número, nome, endereço ou cliente.',
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final job = filtered[index];
                              return ListTile(
                                leading: const Icon(Icons.apartment_outlined),
                                title: Text('${job.number} - ${job.name}'),
                                subtitle: Text(
                                  [
                                    job.address,
                                    if (job.city?.trim().isNotEmpty == true)
                                      job.city!,
                                  ].join(' • '),
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => Navigator.pop(context, job),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.tr('common.cancel')),
              ),
            ],
          );
        },
      ),
    );
    search.dispose();
    return selected;
  }

  Future<void> _openJobsImport() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (context) => const JobsImportScreen()),
    );
  }

  void _message(String value) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(value)));
}

final class _DesktopNavigation extends StatelessWidget {
  const _DesktopNavigation({
    required this.selected,
    required this.destinations,
    required this.onSelected,
  });

  final _Destination selected;
  final List<_Destination> destinations;
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
              selectedIndex: destinations.indexOf(selected),
              onDestinationSelected: (index) => onSelected(destinations[index]),
              destinations: [
                for (final destination in destinations)
                  _railDestination(context, destination),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              context.tr('brand.byDeveloper'),
              style: const TextStyle(
                color: Color(0xffcbd5e1),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  NavigationRailDestination _railDestination(
    BuildContext context,
    _Destination destination,
  ) => switch (destination) {
    _Destination.home => NavigationRailDestination(
      icon: const Icon(Icons.dashboard_outlined),
      selectedIcon: const Icon(Icons.dashboard),
      label: Text(context.tr('nav.home')),
    ),
    _Destination.timesheet => NavigationRailDestination(
      icon: const Icon(Icons.table_chart_outlined),
      selectedIcon: const Icon(Icons.table_chart),
      label: Text(context.tr('nav.timesheet')),
    ),
    _Destination.jobs => NavigationRailDestination(
      icon: const Icon(Icons.apartment_outlined),
      selectedIcon: const Icon(Icons.apartment),
      label: Text(context.tr('nav.jobs')),
    ),
    _Destination.receipts => NavigationRailDestination(
      icon: const Icon(Icons.receipt_long_outlined),
      selectedIcon: const Icon(Icons.receipt_long),
      label: Text(context.tr('nav.receipts')),
    ),
    _Destination.employees => NavigationRailDestination(
      icon: const Icon(Icons.badge_outlined),
      selectedIcon: const Icon(Icons.badge),
      label: Text(context.tr('nav.employees')),
    ),
    _Destination.management => NavigationRailDestination(
      icon: const Icon(Icons.engineering_outlined),
      selectedIcon: const Icon(Icons.engineering),
      label: Text(context.tr('nav.management')),
    ),
    _Destination.settings => NavigationRailDestination(
      icon: const Icon(Icons.settings_outlined),
      selectedIcon: const Icon(Icons.settings),
      label: Text(context.tr('settings.title')),
    ),
  };
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

    return _PageFrame(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 860;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _GreetingBand(state: state, now: now),
              const SizedBox(height: AppSpacing.md),
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
              const SizedBox(height: AppSpacing.md),
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
                    Expanded(child: _ReceiptOverview(snapshot: snapshot)),
                  ],
                )
              else
                _CurrentStatusCard(
                  state: state,
                  now: now,
                  activeSegment: activeSegment,
                ),
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
      padding: const EdgeInsets.all(AppSpacing.lg),
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
                Text(
                  '${_greeting(context, now)}, ${state.snapshot.worker.displayName.isEmpty ? 'Santana' : state.snapshot.worker.displayName}.',
                  style: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(color: AppColors.white),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${_date(now)} - ${working ? context.tr('home.workdayInProgress') : context.tr('home.readyToClockIn')}',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xffcbd5e1),
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              JkddStatusChip(
                label: working
                    ? context.tr('home.clockedIn')
                    : context.tr('home.clockedOut'),
                icon: working
                    ? Icons.play_circle_outline
                    : Icons.pause_circle_outline,
                tone: working ? JkddStatusTone.success : JkddStatusTone.neutral,
              ),
              JkddStatusChip(
                label: state.online
                    ? context.tr('home.online')
                    : context.tr('home.offline'),
                icon: state.online
                    ? Icons.cloud_done_outlined
                    : Icons.cloud_off_outlined,
                tone: state.online
                    ? JkddStatusTone.success
                    : JkddStatusTone.warning,
              ),
              JkddStatusChip(
                label: context.tr('home.pendingItems', {
                  'count': state.pendingItems,
                }),
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
              title: context.tr('home.currentStatus'),
              subtitle: context.tr('home.currentStatusSubtitle'),
              trailing: JkddStatusChip(
                label: segment == null
                    ? context.tr('home.clockedOut')
                    : context.tr('home.clockedIn'),
                icon: segment == null ? Icons.logout : Icons.login,
                tone: segment == null
                    ? JkddStatusTone.neutral
                    : JkddStatusTone.success,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              segment == null
                  ? context.tr('home.noActiveJob')
                  : _jobLabel(context, segment.jobNumber),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    segment?.jobAddress ??
                        context.tr('home.selectJobWhenClockingIn'),
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: AppColors.gray),
                  ),
                ),
                if (segment != null)
                  JkddJobNavigationButton(
                    address: segment.jobAddress,
                    latitude: segment.jobLatitude,
                    longitude: segment.jobLongitude,
                  ),
              ],
            ),
            const Divider(height: 36),
            Row(
              children: [
                Expanded(
                  child: JkddInfoRow(
                    icon: Icons.login,
                    label: context.tr('home.clockInTime'),
                    value: _time(segment?.startedAt),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: JkddInfoRow(
                    icon: Icons.timer_outlined,
                    label: context.tr('home.workedTime'),
                    value: segment == null
                        ? '00h 00m'
                        : _duration(segment.duration(now)),
                  ),
                ),
              ],
            ),
            if (segment?.notes?.isNotEmpty == true) ...[
              const Divider(height: 36),
              JkddInfoRow(
                icon: Icons.note_outlined,
                label: context.tr('home.currentNote'),
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
            Text(
              context.tr('home.primaryAction'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            JkddPrimaryButton(
              label: working
                  ? context.tr('home.endWorkday')
                  : context.tr('home.clockIn'),
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
            Text(
              context.tr('home.secondaryActions'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            _ActionButtonGrid(
              actions: [
                _ActionSpec(
                  context.tr('home.switchJob'),
                  Icons.swap_horiz,
                  onSwitchJob,
                  enabled: working,
                ),
                _ActionSpec(
                  context.tr('home.attachReceipt'),
                  Icons.receipt_long_outlined,
                  onReceipt,
                ),
                _ActionSpec(
                  context.tr('home.addPhoto'),
                  Icons.add_a_photo_outlined,
                  onPhoto,
                  enabled: working,
                ),
                _ActionSpec(
                  context.tr('home.addNote'),
                  Icons.note_add_outlined,
                  onObservation,
                  enabled: working,
                ),
                _ActionSpec(
                  context.tr('home.myTimesheet'),
                  Icons.table_chart_outlined,
                  onTimesheet,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

final class _ActionSpec {
  const _ActionSpec(
    this.label,
    this.icon,
    this.onPressed, {
    this.enabled = true,
  });

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
          title: context.tr('home.receiptsAndReimbursements'),
          subtitle: context.tr('common.receiptsTotal', {
            'count': snapshot.receipts.length,
            'total': _money(total),
          }),
        ),
        const SizedBox(height: AppSpacing.md),
        if (snapshot.receipts.isEmpty)
          JkddEmptyState(
            icon: Icons.receipt_long_outlined,
            title: context.tr('home.noReceiptsYet'),
            message: context.tr('home.noReceiptsYetHelp'),
          )
        else
          for (final receipt in snapshot.receipts.reversed.take(3))
            Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: ListTile(
                leading: const Icon(
                  Icons.receipt_long_outlined,
                  color: AppColors.amber,
                ),
                title: Text(receipt.merchant),
                subtitle: Text(_receiptStatus(context, receipt.status)),
                trailing: Text(_money(receipt.total)),
              ),
            ),
      ],
    );
  }
}

enum _JobFilter { active, inactive, withBonus, all }

final class _JobsView extends StatefulWidget {
  const _JobsView({required this.snapshot, required this.canCreateJob});

  final FieldTimeSnapshot snapshot;
  final bool canCreateJob;

  @override
  State<_JobsView> createState() => _JobsViewState();
}

final class _JobsViewState extends State<_JobsView> {
  final _search = TextEditingController();
  _JobFilter _filter = _JobFilter.active;
  int _newJobRequestSequence = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Job> get _filteredJobs {
    final query = _search.text.trim().toLowerCase();
    return widget.snapshot.jobs
        .where((job) {
          final matchesFilter = switch (_filter) {
            _JobFilter.active => job.active,
            _JobFilter.inactive => !job.active,
            _JobFilter.withBonus => job.travelBonusHours > 0,
            _JobFilter.all => true,
          };
          if (!matchesFilter) return false;
          if (query.isEmpty) return true;
          return [
            job.number,
            job.name,
            job.address,
            job.city ?? '',
          ].any((value) => value.toLowerCase().contains(query));
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final jobs = _filteredJobs;
    return _PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          JkddSectionHeader(
            title: context.tr('jobs.title'),
            subtitle: context.tr('jobs.subtitle'),
            trailing: widget.canCreateJob
                ? FilledButton.icon(
                    onPressed: _showNewJobRequest,
                    icon: const Icon(Icons.add_business_outlined),
                    label: Text(context.tr('jobs.newJobAdmin')),
                  )
                : null,
          ),
          const SizedBox(height: AppSpacing.lg),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      labelText: context.tr('jobs.search'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<_JobFilter>(
                      segments: [
                        ButtonSegment(
                          value: _JobFilter.active,
                          label: Text(context.tr('jobs.active')),
                        ),
                        ButtonSegment(
                          value: _JobFilter.inactive,
                          label: Text(context.tr('jobs.inactive')),
                        ),
                        ButtonSegment(
                          value: _JobFilter.withBonus,
                          label: Text(context.tr('jobs.withBonus')),
                        ),
                        ButtonSegment(
                          value: _JobFilter.all,
                          label: Text(context.tr('common.all')),
                        ),
                      ],
                      selected: {_filter},
                      onSelectionChanged: (value) =>
                          setState(() => _filter = value.first),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (jobs.isEmpty)
            JkddEmptyState(
              icon: Icons.apartment_outlined,
              title: context.tr('jobs.noJobsFound'),
              message: context.tr('jobs.noJobsAvailableHelp'),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 900 ? 2 : 1;
                final width = columns == 1
                    ? constraints.maxWidth
                    : (constraints.maxWidth - AppSpacing.md) / 2;
                return Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: [
                    for (final job in jobs)
                      SizedBox(
                        width: width,
                        child: _JobCompactTile(
                          job: job,
                          onTap: () => _showJobDetails(job),
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

  Future<void> _showJobDetails(Job job) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.md,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              JkddSectionHeader(
                title: context.tr('jobs.details'),
                subtitle: _jobLabel(context, job.number),
              ),
              const SizedBox(height: AppSpacing.lg),
              JkddInfoRow(
                icon: Icons.tag_outlined,
                label: context.tr('common.registrationNumber'),
                value: job.registrationNumber.isNotEmpty
                    ? job.registrationNumber
                    : context.tr('common.unavailable'),
              ),
              JkddInfoRow(
                icon: Icons.numbers_outlined,
                label: context.tr('jobs.jobNumber'),
                value: job.number,
              ),
              JkddInfoRow(
                icon: Icons.apartment_outlined,
                label: context.tr('jobs.jobName'),
                value: _jobLabel(context, job.number),
              ),
              JkddInfoRow(
                icon: Icons.location_on_outlined,
                label: context.tr('jobs.address'),
                value: job.address,
              ),
              JkddInfoRow(
                icon: Icons.location_city_outlined,
                label: context.tr('jobs.city'),
                value: _cityStateZip(context, job),
              ),
              JkddInfoRow(
                icon: Icons.flag_outlined,
                label: context.tr('jobs.status'),
                value: job.active
                    ? context.tr('jobs.active')
                    : context.tr('jobs.inactive'),
              ),
              JkddInfoRow(
                icon: Icons.route_outlined,
                label: context.tr('jobs.travelBonus'),
                value: job.hasTravelBonus
                    ? _hours(job.travelBonusHours)
                    : context.tr('common.none'),
              ),
              JkddInfoRow(
                icon: Icons.workspace_premium_outlined,
                label: context.tr('jobs.payPremium'),
                value: job.hasPayPremium
                    ? _payPremiumLabel(context, job)
                    : context.tr('jobs.noPayPremium'),
              ),
              JkddInfoRow(
                icon: Icons.business_outlined,
                label: context.tr('jobs.client'),
                value: job.client ?? widget.snapshot.companyName,
              ),
              JkddInfoRow(
                icon: Icons.supervisor_account_outlined,
                label: context.tr('jobs.supervisor'),
                value: job.supervisor ?? context.tr('common.unavailable'),
              ),
              JkddInfoRow(
                icon: Icons.engineering_outlined,
                label: context.tr('home.subcontractor'),
                value: widget.snapshot.subcontractor.displayName,
              ),
              if (job.accessInstructions?.trim().isNotEmpty == true)
                JkddInfoRow(
                  icon: Icons.key_outlined,
                  label: context.tr('jobs.accessInstructions'),
                  value: job.accessInstructions!,
                ),
              const SizedBox(height: AppSpacing.md),
              JkddJobNavigationButton(
                compact: false,
                address: [job.address, job.city].whereType<String>().join(' '),
                latitude: job.latitude,
                longitude: job.longitude,
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: job.active ? () => Navigator.pop(context) : null,
                icon: const Icon(Icons.check_circle_outline),
                label: Text(context.tr('jobs.selectThisJob')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showNewJobRequest() async {
    final requestNumber =
        RegistrationNumberPolicy.next(RegistrationRecordType.newJobRequest, [
          if (_newJobRequestSequence > 0)
            RegistrationNumberPolicy.format(
              RegistrationRecordType.newJobRequest,
              _newJobRequestSequence,
            ),
        ]);
    final number = TextEditingController(text: requestNumber);
    final name = TextEditingController();
    final address = TextEditingController();
    final city = TextEditingController();
    final state = TextEditingController(text: 'FL');
    final zip = TextEditingController();
    final note = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('jobs.newJobAdmin')),
        content: SingleChildScrollView(
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
              TextField(
                controller: name,
                decoration: InputDecoration(
                  labelText: context.tr('jobs.jobName'),
                ),
              ),
              TextField(
                controller: address,
                decoration: InputDecoration(
                  labelText: context.tr('jobs.address'),
                ),
              ),
              TextField(
                controller: city,
                decoration: InputDecoration(labelText: context.tr('jobs.city')),
              ),
              TextField(
                controller: state,
                decoration: InputDecoration(
                  labelText: context.tr('jobs.state'),
                ),
              ),
              TextField(
                controller: zip,
                decoration: InputDecoration(
                  labelText: context.tr('jobs.zipCode'),
                ),
              ),
              TextField(
                controller: note,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: context.tr('timesheet.notes'),
                ),
              ),
            ],
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
    );
    final duplicate = widget.snapshot.jobs.any(
      (job) =>
          job.number == number.text.trim() ||
          job.address.toLowerCase() == address.text.trim().toLowerCase(),
    );
    number.dispose();
    name.dispose();
    address.dispose();
    city.dispose();
    state.dispose();
    zip.dispose();
    note.dispose();
    if (submitted != true || !mounted) return;
    _newJobRequestSequence += 1;
    _message(
      duplicate
          ? context.tr('jobs.duplicateWarning')
          : context.tr('jobs.requestPrepared'),
    );
  }

  void _message(String value) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(value)));
}

final class _JobCompactTile extends StatelessWidget {
  const _JobCompactTile({required this.job, required this.onTap});

  final Job job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: ListTile(
      minVerticalPadding: AppSpacing.xs,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      leading: const Icon(Icons.apartment_outlined, color: AppColors.blue),
      title: Text(
        _jobLabel(context, job.number),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          JkddStatusChip(
            label: job.active
                ? context.tr('jobs.active')
                : context.tr('jobs.inactive'),
            icon: job.active ? Icons.check_circle_outline : Icons.block,
            tone: job.active ? JkddStatusTone.success : JkddStatusTone.neutral,
          ),
          if (job.travelBonusHours > 0)
            JkddStatusChip(
              label: context.tr('jobs.travelBonusValue', {
                'hours': _hours(job.travelBonusHours),
              }),
              icon: Icons.route_outlined,
              tone: JkddStatusTone.warning,
            ),
          if (job.hasPayPremium)
            JkddStatusChip(
              label: context.tr('jobs.payPremiumValue', {
                'value': _payPremiumLabel(context, job),
              }),
              icon: Icons.workspace_premium_outlined,
              tone: JkddStatusTone.info,
            ),
        ],
      ),
      trailing: Wrap(
        spacing: AppSpacing.xs,
        children: [
          JkddJobNavigationButton(
            address: [job.address, job.city].whereType<String>().join(' '),
            latitude: job.latitude,
            longitude: job.longitude,
          ),
          IconButton(
            tooltip: context.tr('common.details'),
            icon: const Icon(Icons.chevron_right),
            onPressed: onTap,
          ),
        ],
      ),
      onTap: onTap,
    ),
  );
}

final class _ReceiptsView extends StatelessWidget {
  const _ReceiptsView({
    required this.snapshot,
    required this.onReceipt,
    required this.onEditReceipt,
  });

  final FieldTimeSnapshot snapshot;
  final VoidCallback onReceipt;
  final ValueChanged<Receipt> onEditReceipt;

  @override
  Widget build(BuildContext context) {
    final total = snapshot.reimbursements.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );
    return _PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          JkddSectionHeader(
            title: context.tr('receipts.andReimbursements'),
            subtitle: context.tr('common.receiptsTotal', {
              'count': snapshot.receipts.length,
              'total': _money(total),
            }),
            trailing: FilledButton.icon(
              onPressed: onReceipt,
              icon: const Icon(Icons.add),
              label: Text(context.tr('receipts.attachReceipt')),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (snapshot.receipts.isEmpty)
            JkddEmptyState(
              icon: Icons.receipt_long_outlined,
              title: context.tr('receipts.noReceiptsDevice'),
              message: context.tr('receipts.noReceiptsDeviceHelp'),
            )
          else
            for (final receipt in snapshot.receipts.reversed)
              Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                child: ListTile(
                  leading: const Icon(
                    Icons.receipt_long_outlined,
                    color: AppColors.amber,
                  ),
                  title: Text(receipt.merchant),
                  subtitle: Text(
                    '${receipt.registrationNumber.isEmpty ? '' : '${receipt.registrationNumber} - '}'
                    '${_date(receipt.purchaseDate)} - ${_receiptStatus(context, receipt.status)}',
                  ),
                  trailing: Wrap(
                    spacing: AppSpacing.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(_money(receipt.total)),
                      if (receipt.status == ReceiptStatus.draft)
                        OutlinedButton.icon(
                          onPressed: () => onEditReceipt(receipt),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Editar'),
                        ),
                    ],
                  ),
                  onTap: receipt.status == ReceiptStatus.draft
                      ? () => onEditReceipt(receipt)
                      : null,
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
    required this.onJobsImport,
    required this.onLogout,
    required this.onRefreshApp,
    required this.onClearCacheAndRefresh,
    required this.directorTestMode,
    required this.pilotState,
    required this.onSimulationChanged,
    required this.currentLanguage,
    required this.onLanguageChanged,
  });

  final String currentVersion;
  final VoidCallback onJobsImport;
  final VoidCallback onLogout;
  final Future<void> Function() onRefreshApp;
  final Future<void> Function() onClearCacheAndRefresh;
  final bool directorTestMode;
  final SupervisorCenterState pilotState;
  final void Function(PilotRole role, String? userId) onSimulationChanged;
  final AppLanguage currentLanguage;
  final ValueChanged<AppLanguage> onLanguageChanged;

  @override
  Widget build(BuildContext context) {
    return _PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          JkddSectionHeader(
            title: context.tr('settings.title'),
            subtitle: context.tr('settings.subtitle'),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (directorTestMode) ...[
            _DirectorSimulationSection(
              pilotState: pilotState,
              onChanged: onSimulationChanged,
            ),
          ],
          _SettingsSection(
            title: context.tr('settings.data'),
            children: [
              _SettingsActionTile(
                title: context.tr('import.title'),
                icon: Icons.dataset_outlined,
                value: context.tr('common.localExcel'),
                onTap: onJobsImport,
              ),
            ],
          ),
          _SettingsSection(
            title: context.tr('settings.account'),
            children: [
              if (directorTestMode)
                _ProfileSimulationTile(
                  pilotState: pilotState,
                  onChanged: onSimulationChanged,
                )
              else
                _SettingsTile(
                  context.tr('settings.profile'),
                  Icons.person_outline,
                  context.tr('common.comingSoon'),
                ),
              _SettingsTile(
                context.tr('settings.company'),
                Icons.business_outlined,
                context.tr('common.comingSoon'),
              ),
              _SettingsTile(
                context.tr('settings.permissions'),
                Icons.verified_user_outlined,
                context.tr('common.comingSoon'),
              ),
              _SettingsActionTile(
                title: context.tr('auth.logout'),
                icon: Icons.logout_outlined,
                value: context.tr('auth.logoutHelp'),
                onTap: onLogout,
              ),
            ],
          ),
          _SettingsSection(
            title: 'Sistema',
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.system_update_alt_outlined,
                  color: AppColors.blue,
                ),
                title: const Text('Atualizar aplicativo'),
                subtitle: Text('Versão instalada: $currentVersion'),
                trailing: const Icon(Icons.refresh),
                onTap: onRefreshApp,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.cleaning_services_outlined,
                  color: AppColors.amber,
                ),
                title: const Text('Limpar cache e atualizar'),
                subtitle: const Text(
                  'Remove apenas arquivos temporários do JKDD Field e baixa novamente a versão publicada. Seus registros locais não são apagados.',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Limpar cache e atualizar?'),
                      content: const Text(
                        'Esta ação limpa somente o cache do aplicativo. Timesheets, recibos e demais dados locais continuam preservados.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('Cancelar'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          child: const Text('Limpar e atualizar'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await onClearCacheAndRefresh();
                  }
                },
              ),
            ],
          ),
          _SettingsSection(
            title: context.tr('settings.preferences'),
            children: [
              _LanguageTile(
                currentLanguage: currentLanguage,
                onChanged: onLanguageChanged,
              ),
              _SettingsTile(
                context.tr('settings.theme'),
                Icons.dark_mode_outlined,
                context.tr('common.systemDefault'),
              ),
              _SettingsTile(
                context.tr('settings.dateFormat'),
                Icons.calendar_today_outlined,
                context.tr('settings.dateFormatValue'),
              ),
              _SettingsTile(
                context.tr('settings.timeFormat'),
                Icons.schedule_outlined,
                context.tr('settings.timeFormatValue'),
              ),
              _SettingsTile(
                context.tr('settings.units'),
                Icons.straighten_outlined,
                context.tr('common.us'),
              ),
            ],
          ),
          _SettingsSection(
            title: context.tr('settings.reports'),
            children: [
              _SettingsTile(
                context.tr('settings.timesheetFormat'),
                Icons.table_chart_outlined,
                context.tr('common.comingSoon'),
              ),
              _SettingsTile(
                context.tr('settings.defaultPaperSize'),
                Icons.description_outlined,
                context.tr('common.letter'),
              ),
              _SettingsTile(
                context.tr('settings.pdfOrientation'),
                Icons.screen_rotation_alt_outlined,
                context.tr('settings.landscapePlanned'),
              ),
            ],
          ),
          _SettingsSection(
            title: context.tr('settings.about'),
            children: [
              _SettingsTile(
                context.tr('app.title'),
                Icons.info_outline,
                context.tr('brand.byDeveloper'),
              ),
              _SettingsTile(
                context.tr('settings.version'),
                Icons.tag_outlined,
                currentVersion,
              ),
              _SettingsTile(
                context.tr('settings.privacy'),
                Icons.privacy_tip_outlined,
                context.tr('common.comingSoon'),
              ),
              _SettingsTile(
                context.tr('settings.terms'),
                Icons.article_outlined,
                context.tr('common.comingSoon'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

final class _DirectorSimulationSection extends StatelessWidget {
  const _DirectorSimulationSection({
    required this.pilotState,
    required this.onChanged,
  });

  final SupervisorCenterState pilotState;
  final void Function(PilotRole role, String? userId) onChanged;

  @override
  Widget build(BuildContext context) {
    final currentRole = pilotState.currentRole;
    final selectedMode = currentRole == PilotRole.owner
        ? PilotRole.owner
        : currentRole == PilotRole.supervisor
        ? PilotRole.supervisor
        : PilotRole.employee;
    final workers = pilotState.users
        .where(
          (user) =>
              user.active &&
              (user.role == PilotRole.employee ||
                  user.role == PilotRole.contractor),
        )
        .toList(growable: false);
    final currentWorker =
        workers.any((user) => user.id == pilotState.currentUser.id)
        ? pilotState.currentUser.id
        : (workers.isEmpty ? null : workers.first.id);

    return _SettingsSection(
      title: 'AMBIENTE DE TESTE — Simulação de perfil',
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: DropdownButtonFormField<PilotRole>(
            initialValue: selectedMode,
            decoration: const InputDecoration(
              labelText: 'Exibir aplicativo como',
              helperText:
                  'Use o login do Diretor ou Supervisor para trocar o perfil durante a homologação.',
            ),
            items: const [
              DropdownMenuItem(value: PilotRole.owner, child: Text('Diretor')),
              DropdownMenuItem(
                value: PilotRole.supervisor,
                child: Text('Supervisor'),
              ),
              DropdownMenuItem(
                value: PilotRole.employee,
                child: Text('Colaborador'),
              ),
            ],
            onChanged: (role) {
              if (role == null) return;
              if (role == PilotRole.owner) {
                onChanged(PilotRole.owner, 'test-director');
              } else if (role == PilotRole.supervisor) {
                onChanged(PilotRole.supervisor, 'test-supervisor');
              } else {
                final worker = workers.isEmpty ? null : workers.first;
                onChanged(worker?.role ?? PilotRole.employee, worker?.id);
              }
            },
          ),
        ),
        if (selectedMode == PilotRole.employee && workers.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: DropdownButtonFormField<String>(
              initialValue: currentWorker,
              decoration: const InputDecoration(
                labelText: 'Selecionar colaborador para simular',
                helperText:
                    'A tela passa a usar o nome, função e permissões desse colaborador.',
              ),
              items: [
                for (final worker in workers)
                  DropdownMenuItem(
                    value: worker.id,
                    child: Text(
                      '${worker.name}${worker.function?.trim().isNotEmpty == true ? ' — ${worker.function}' : ''}',
                    ),
                  ),
              ],
              onChanged: (userId) {
                if (userId == null) return;
                final worker = workers.firstWhere((user) => user.id == userId);
                onChanged(worker.role, worker.id);
              },
            ),
          ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.science_outlined, color: AppColors.amber),
          title: Text('Simulando: ${pilotState.currentUser.name}'),
          subtitle: Text(
            selectedMode == PilotRole.owner
                ? 'Perfil Diretor'
                : selectedMode == PilotRole.supervisor
                ? 'Perfil Supervisor'
                : 'Perfil Colaborador',
          ),
        ),
      ],
    );
  }
}

final class _ProfileSimulationTile extends StatelessWidget {
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

final class _SettingsActionTile extends StatelessWidget {
  const _SettingsActionTile({
    required this.title,
    required this.icon,
    required this.value,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.blue),
      title: Text(title),
      subtitle: Text(value),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

final class _LanguageTile extends StatefulWidget {
  const _LanguageTile({required this.currentLanguage, required this.onChanged});

  final AppLanguage currentLanguage;
  final ValueChanged<AppLanguage> onChanged;

  @override
  State<_LanguageTile> createState() => _LanguageTileState();
}

final class _LanguageTileState extends State<_LanguageTile> {
  late AppLanguage _draftLanguage;

  @override
  void initState() {
    super.initState();
    _draftLanguage = widget.currentLanguage;
  }

  @override
  void didUpdateWidget(covariant _LanguageTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentLanguage != widget.currentLanguage &&
        _draftLanguage == oldWidget.currentLanguage) {
      _draftLanguage = widget.currentLanguage;
    }
  }

  bool get _dirty => _draftLanguage != widget.currentLanguage;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
                Text(
                  context.tr('settings.language'),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr('settings.languageHelp'),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.gray),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final language in AppLanguage.values)
                      ChoiceChip(
                        label: Text(language.label),
                        selected: _draftLanguage == language,
                        onSelected: (_) =>
                            setState(() => _draftLanguage = language),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (_dirty)
                      JkddStatusChip(
                        label: context.tr('settings.unsavedChanges'),
                        icon: Icons.edit_outlined,
                        tone: JkddStatusTone.warning,
                      ),
                    OutlinedButton.icon(
                      onPressed: _dirty
                          ? () => setState(
                              () => _draftLanguage = widget.currentLanguage,
                            )
                          : null,
                      icon: const Icon(Icons.undo_outlined),
                      label: Text(context.tr('common.discard')),
                    ),
                    FilledButton.icon(
                      onPressed: _dirty
                          ? () => widget.onChanged(_draftLanguage)
                          : null,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(context.tr('common.saveChanges')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _greeting(BuildContext context, DateTime value) {
  if (value.hour < 12) return context.tr('home.goodMorning');
  if (value.hour < 18) return context.tr('home.goodAfternoon');
  return context.tr('home.goodEvening');
}

String _date(DateTime value) =>
    '${value.month.toString().padLeft(2, '0')}/'
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

String _jobLabel(BuildContext context, String number) {
  final title = context.tr('jobs.title').toLowerCase().startsWith('job')
      ? 'Job'
      : context.tr('jobs.title').replaceAll('s', '');
  return '$title $number';
}

String _payPremiumLabel(BuildContext context, Job job) {
  if (!job.hasPayPremium) return context.tr('jobs.noPayPremium');
  return switch (job.payPremiumType) {
    PayPremiumType.percentage =>
      '+${(job.payPremiumValue * 100).toStringAsFixed(0)}%',
    PayPremiumType.fixedHourly =>
      '+\$${job.payPremiumValue.toStringAsFixed(2)}/h',
    PayPremiumType.doubleTime => '2x',
    null => context.tr('jobs.noPayPremium'),
  };
}

String _cityStateZip(BuildContext context, Job job) {
  final value = [
    job.city,
    job.state,
    job.zipCode,
  ].whereType<String>().where((item) => item.trim().isNotEmpty).join(', ');
  return value.isEmpty ? context.tr('common.unavailable') : value;
}

String _receiptStatus(BuildContext context, ReceiptStatus status) =>
    switch (status) {
      ReceiptStatus.draft => context.tr('receiptStatus.draft'),
      ReceiptStatus.submitted => context.tr('receiptStatus.submitted'),
      ReceiptStatus.underReview => context.tr('receiptStatus.underReview'),
      ReceiptStatus.approved => context.tr('receiptStatus.approved'),
      ReceiptStatus.rejected => context.tr('receiptStatus.rejected'),
      ReceiptStatus.paid => context.tr('receiptStatus.paid'),
    };

String _localizedFeedback(
  BuildContext context,
  String text, [
  Map<String, Object?>? values,
]) {
  final isTranslationKey = RegExp(
    r'^[a-zA-Z][a-zA-Z0-9]*(\.[a-zA-Z0-9]+)+$',
  ).hasMatch(text);
  return isTranslationKey ? context.tr(text, values ?? const {}) : text;
}
