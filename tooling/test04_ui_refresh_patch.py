from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise RuntimeError(f"Pattern not found: {label}")
    return text.replace(old, new, 1)


# -----------------------------------------------------------------------------
# TimeRecordsScreen: bottom navigation always returns to section root +
# Settings controls to update / clear cache and update.
# -----------------------------------------------------------------------------
path = Path("lib/src/presentation/screens/time_records_screen.dart")
text = path.read_text()

if "src/platform/app_refresh.dart" not in text:
    text = replace_once(
        text,
        "import 'package:jkdd_field_time_records_production/src/localization/app_language.dart';\n",
        "import 'package:jkdd_field_time_records_production/src/localization/app_language.dart';\n"
        "import 'package:jkdd_field_time_records_production/src/platform/app_refresh.dart';\n",
        "app refresh import",
    )

if "_managementNavigationRevision" not in text:
    text = replace_once(
        text,
        "  _Destination _destination = _Destination.home;\n",
        "  _Destination _destination = _Destination.home;\n"
        "  int _managementNavigationRevision = 0;\n",
        "management revision field",
    )

if "void _selectRootDestination(" not in text:
    marker = "  @override\n  Widget build(BuildContext context) {"
    method = """  void _selectRootDestination(_Destination destination) {
    setState(() {
      if (destination == _Destination.management) {
        _managementNavigationRevision++;
      }
      _destination = destination;
    });
  }

"""
    text = replace_once(text, marker, method + marker, "root destination method")

text = text.replace(
    "                  onTap: (index) =>\n"
    "                      setState(() => _destination = destinations[index]),",
    "                  onTap: (index) =>\n"
    "                      _selectRootDestination(destinations[index]),",
)
text = text.replace(
    "                        onSelected: (value) =>\n"
    "                            setState(() => _destination = value),",
    "                        onSelected: _selectRootDestination,",
)
text = text.replace(
    "    _Destination.management => const SupervisorCenterScreen(),",
    "    _Destination.management => SupervisorCenterScreen(\n"
    "      key: ValueKey('management-$_managementNavigationRevision'),\n"
    "    ),",
)

if "onRefreshApp: () => refreshApplication()" not in text:
    text = replace_once(
        text,
        "      onLogout: _logout,\n",
        "      onLogout: _logout,\n"
        "      onRefreshApp: () => refreshApplication(),\n"
        "      onClearCacheAndRefresh: () => refreshApplication(clearCache: true),\n",
        "settings refresh callbacks",
    )

if "required this.onRefreshApp" not in text:
    text = replace_once(
        text,
        "    required this.onLogout,\n",
        "    required this.onLogout,\n"
        "    required this.onRefreshApp,\n"
        "    required this.onClearCacheAndRefresh,\n",
        "settings constructor refresh callbacks",
    )

if "final Future<void> Function() onRefreshApp;" not in text:
    text = replace_once(
        text,
        "  final VoidCallback onLogout;\n",
        "  final VoidCallback onLogout;\n"
        "  final Future<void> Function() onRefreshApp;\n"
        "  final Future<void> Function() onClearCacheAndRefresh;\n",
        "settings refresh callback fields",
    )

if "title: 'Sistema'" not in text:
    anchor = "          _SettingsSection(\n            title: context.tr('settings.preferences'),"
    section = """          _SettingsSection(
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
"""
    text = replace_once(text, anchor, section + anchor, "system settings section")

path.write_text(text)


# -----------------------------------------------------------------------------
# Browser refresh implementation. Cache API/service worker are cleared without
# touching localStorage / IndexedDB, so local test records remain intact.
# -----------------------------------------------------------------------------
platform = Path("lib/src/platform")
platform.mkdir(parents=True, exist_ok=True)
(platform / "app_refresh.dart").write_text(
    "export 'app_refresh_stub.dart'\n"
    "    if (dart.library.html) 'app_refresh_web.dart';\n"
)
(platform / "app_refresh_stub.dart").write_text(
    "Future<void> refreshApplication({bool clearCache = false}) async {}\n"
)
(platform / "app_refresh_web.dart").write_text(
    """// ignore_for_file: deprecated_member_use

import 'dart:html' as html;

Future<void> refreshApplication({bool clearCache = false}) async {
  if (clearCache) {
    try {
      final cacheStorage = html.window.caches;
      final keys = await cacheStorage.keys();
      for (final key in keys) {
        await cacheStorage.delete(key);
      }
    } catch (_) {
      // Some browsers may restrict Cache API access. Reload still proceeds.
    }

    try {
      final serviceWorker = html.window.navigator.serviceWorker;
      final registrations = await serviceWorker.getRegistrations();
      for (final registration in registrations) {
        await registration.unregister();
      }
    } catch (_) {
      // Service workers are optional and may be unavailable.
    }
  }

  final current = Uri.parse(html.window.location.href);
  final query = Map<String, String>.from(current.queryParameters);
  query['refresh'] = DateTime.now().millisecondsSinceEpoch.toString();
  html.window.location.replace(current.replace(queryParameters: query).toString());
}
"""
)


# -----------------------------------------------------------------------------
# Supervisor/Director Timesheet: all square status cards are interactive filters.
# -----------------------------------------------------------------------------
path = Path("lib/src/presentation/screens/timesheet_screen.dart")
text = path.read_text()
start_marker = "final class _SupervisorTeamTimesheet extends ConsumerWidget {"
end_marker = "final class _SupervisorEntryCard extends ConsumerWidget {"
start = text.find(start_marker)
end = text.find(end_marker)
if start == -1 or end == -1 or end <= start:
    # Already patched is acceptable/idempotent.
    if "enum _SupervisorTimesheetFilter" not in text:
        raise RuntimeError("Could not locate Supervisor Team Timesheet block")
else:
    replacement = r'''enum _SupervisorTimesheetFilter {
  all,
  pending,
  review,
  approved,
  rejected,
}

final class _SupervisorTeamTimesheet extends ConsumerStatefulWidget {
  const _SupervisorTeamTimesheet();

  @override
  ConsumerState<_SupervisorTeamTimesheet> createState() =>
      _SupervisorTeamTimesheetState();
}

final class _SupervisorTeamTimesheetState
    extends ConsumerState<_SupervisorTeamTimesheet> {
  _SupervisorTimesheetFilter _filter = _SupervisorTimesheetFilter.all;

  static const _reviewStatuses = {
    TimeReviewStatus.underReview,
    TimeReviewStatus.correctionRequested,
    TimeReviewStatus.corrected,
    TimeReviewStatus.resubmitted,
  };

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(supervisorCenterProvider);
    final allEntries = state.timeEntries
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

    final pending = allEntries
        .where((entry) => entry.status == TimeReviewStatus.pending)
        .length;
    final approved = allEntries
        .where((entry) => entry.status == TimeReviewStatus.approved)
        .length;
    final rejected = allEntries
        .where((entry) => entry.status == TimeReviewStatus.rejected)
        .length;
    final review = allEntries
        .where((entry) => _reviewStatuses.contains(entry.status))
        .length;
    final entries = allEntries.where(_matchesCurrentFilter).toList(growable: false);

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
                LayoutBuilder(
                  builder: (context, constraints) {
                    final itemWidth = constraints.maxWidth < 620
                        ? (constraints.maxWidth - AppSpacing.md) / 2
                        : 210.0;
                    return Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.md,
                      children: [
                        _TimesheetStatusCard(
                          width: itemWidth,
                          label: 'Pendentes',
                          value: '$pending',
                          icon: Icons.pending_actions,
                          color: AppColors.amber,
                          selected: _filter == _SupervisorTimesheetFilter.pending,
                          onTap: () => _setFilter(_SupervisorTimesheetFilter.pending),
                        ),
                        _TimesheetStatusCard(
                          width: itemWidth,
                          label: 'Em revisão',
                          value: '$review',
                          icon: Icons.rate_review_outlined,
                          color: AppColors.blue,
                          selected: _filter == _SupervisorTimesheetFilter.review,
                          onTap: () => _setFilter(_SupervisorTimesheetFilter.review),
                        ),
                        _TimesheetStatusCard(
                          width: itemWidth,
                          label: 'Aprovados',
                          value: '$approved',
                          icon: Icons.check_circle_outline,
                          color: AppColors.green,
                          selected: _filter == _SupervisorTimesheetFilter.approved,
                          onTap: () => _setFilter(_SupervisorTimesheetFilter.approved),
                        ),
                        _TimesheetStatusCard(
                          width: itemWidth,
                          label: 'Rejeitados',
                          value: '$rejected',
                          icon: Icons.cancel_outlined,
                          color: AppColors.red,
                          selected: _filter == _SupervisorTimesheetFilter.rejected,
                          onTap: () => _setFilter(_SupervisorTimesheetFilter.rejected),
                        ),
                        _TimesheetStatusCard(
                          width: itemWidth,
                          label: 'Registros',
                          value: '${allEntries.length}',
                          icon: Icons.list_alt_outlined,
                          color: AppColors.purple,
                          selected: _filter == _SupervisorTimesheetFilter.all,
                          onTap: () => _setFilter(_SupervisorTimesheetFilter.all),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    const Icon(Icons.filter_alt_outlined, size: 18),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        'Mostrando: ${_supervisorTimesheetFilterLabel(_filter)}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    if (_filter != _SupervisorTimesheetFilter.all)
                      TextButton(
                        onPressed: () => _setFilter(_SupervisorTimesheetFilter.all),
                        child: const Text('Limpar filtro'),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (entries.isEmpty)
                  JkddEmptyState(
                    icon: Icons.fact_check_outlined,
                    title: 'Nenhum registro neste filtro',
                    message:
                        'Toque em outro card acima para consultar os demais registros.',
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

  bool _matchesCurrentFilter(TimeEntry entry) => switch (_filter) {
        _SupervisorTimesheetFilter.all => true,
        _SupervisorTimesheetFilter.pending =>
          entry.status == TimeReviewStatus.pending,
        _SupervisorTimesheetFilter.review =>
          _reviewStatuses.contains(entry.status),
        _SupervisorTimesheetFilter.approved =>
          entry.status == TimeReviewStatus.approved,
        _SupervisorTimesheetFilter.rejected =>
          entry.status == TimeReviewStatus.rejected,
      };

  void _setFilter(_SupervisorTimesheetFilter value) {
    setState(() => _filter = value);
  }
}

final class _TimesheetStatusCard extends StatelessWidget {
  const _TimesheetStatusCard({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final double width;
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Stack(
            children: [
              JkddSummaryCard(
                label: label,
                value: value,
                icon: icon,
                color: color,
              ),
              if (selected)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Icon(Icons.check_circle, color: color, size: 20),
                ),
            ],
          ),
        ),
      );
}

String _supervisorTimesheetFilterLabel(_SupervisorTimesheetFilter filter) =>
    switch (filter) {
      _SupervisorTimesheetFilter.all => 'todos os registros',
      _SupervisorTimesheetFilter.pending => 'pendentes',
      _SupervisorTimesheetFilter.review => 'em revisão',
      _SupervisorTimesheetFilter.approved => 'aprovados',
      _SupervisorTimesheetFilter.rejected => 'rejeitados',
    };

'''
    text = text[:start] + replacement + text[end:]

path.write_text(text)
