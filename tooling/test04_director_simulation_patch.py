from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
models = ROOT / 'lib/src/supervisor_center/supervisor_center_models.dart'
controller = ROOT / 'lib/src/supervisor_center/supervisor_center_controller.dart'
screen = ROOT / 'lib/src/presentation/screens/time_records_screen.dart'
supervisor = ROOT / 'lib/src/supervisor_center/supervisor_center_screen.dart'


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise RuntimeError(f'{label} anchor not found')
    return text.replace(old, new, 1)

# --- SupervisorCenterState: persist an explicit simulated user ---
text = models.read_text(encoding='utf-8')
text = replace_once(
    text,
    """    this.allowSupervisorCreateJobs = true,\n    this.message,\n    this.error,\n  });""",
    """    this.allowSupervisorCreateJobs = true,\n    this.simulatedUserId,\n    this.message,\n    this.error,\n  });""",
    'state constructor',
)
text = replace_once(
    text,
    """  final bool allowSupervisorCreateJobs;\n  final String? message;""",
    """  final bool allowSupervisorCreateJobs;\n  final String? simulatedUserId;\n  final String? message;""",
    'state field',
)
text = replace_once(
    text,
    """  PilotUser get currentUser {\n    if (users.isEmpty) {""",
    """  PilotUser get currentUser {\n    if (users.isEmpty) {""",
    'current user start',
)
text = replace_once(
    text,
    """    return users.firstWhere(\n      (user) => user.role == currentRole,\n      orElse: () => users.first,\n    );\n  }""",
    """    final selectedId = simulatedUserId;\n    if (selectedId != null) {\n      for (final user in users) {\n        if (user.id == selectedId) return user;\n      }\n    }\n    return users.firstWhere(\n      (user) => user.role == currentRole,\n      orElse: () => users.first,\n    );\n  }""",
    'current user selection',
)
text = replace_once(
    text,
    """    bool? allowSupervisorCreateJobs,\n    String? message,\n    String? error,\n    bool clearFeedback = false,""",
    """    bool? allowSupervisorCreateJobs,\n    String? simulatedUserId,\n    String? message,\n    String? error,\n    bool clearFeedback = false,\n    bool clearSimulatedUser = false,""",
    'copyWith args',
)
text = replace_once(
    text,
    """        allowSupervisorCreateJobs:\n            allowSupervisorCreateJobs ?? this.allowSupervisorCreateJobs,\n        message: clearFeedback ? null : message,""",
    """        allowSupervisorCreateJobs:\n            allowSupervisorCreateJobs ?? this.allowSupervisorCreateJobs,\n        simulatedUserId:\n            clearSimulatedUser ? null : simulatedUserId ?? this.simulatedUserId,\n        message: clearFeedback ? null : message,""",
    'copyWith body',
)
models.write_text(text, encoding='utf-8')

# --- Controller: switch role and exact user, persist it ---
text = controller.read_text(encoding='utf-8')
text = replace_once(
    text,
    """  void setRole(PilotRole role) {\n    state = state.copyWith(\n      currentRole: role,\n      message: 'supervisor.roleChanged',\n    );\n    unawaited(_save());\n  }""",
    """  void setRole(PilotRole role) {\n    state = state.copyWith(\n      currentRole: role,\n      clearSimulatedUser: true,\n      message: 'supervisor.roleChanged',\n    );\n    unawaited(_save());\n  }\n\n  void setSimulation(PilotRole role, {String? userId}) {\n    PilotUser? selected;\n    if (userId != null) {\n      for (final user in state.users) {\n        if (user.id == userId) {\n          selected = user;\n          break;\n        }\n      }\n    }\n    final effectiveRole = selected?.role ?? role;\n    state = state.copyWith(\n      currentRole: effectiveRole,\n      simulatedUserId: selected?.id,\n      clearSimulatedUser: selected == null,\n      message: 'supervisor.roleChanged',\n    );\n    unawaited(_save());\n  }""",
    'controller simulation method',
)
text = replace_once(
    text,
    """        currentRole:\n            _roleFromName(json['currentRole'] as String?) ?? base.currentRole,\n        allowSupervisorCreateJobs:""",
    """        currentRole:\n            _roleFromName(json['currentRole'] as String?) ?? base.currentRole,\n        simulatedUserId: json['simulatedUserId'] as String?,\n        allowSupervisorCreateJobs:""",
    'load simulated user',
)
text = replace_once(
    text,
    """        'currentRole': value.currentRole.name,\n        'allowSupervisorCreateJobs': value.allowSupervisorCreateJobs,""",
    """        'currentRole': value.currentRole.name,\n        'simulatedUserId': value.simulatedUserId,\n        'allowSupervisorCreateJobs': value.allowSupervisorCreateJobs,""",
    'save simulated user',
)
controller.write_text(text, encoding='utf-8')

# --- Main screen: director login becomes the single homologation master login ---
text = screen.read_text(encoding='utf-8')
old = """    ref.listen(authSessionProvider, (previous, next) {\n      final user = next.user;\n      if (user == null || previous?.user?.role == user.role) return;\n      ref.read(supervisorCenterProvider.notifier).setRole(user.role);\n    });\n    if (session.user != null && pilotState.currentRole != session.user!.role) {\n      WidgetsBinding.instance.addPostFrameCallback((_) {\n        ref.read(supervisorCenterProvider.notifier).setRole(session.user!.role);\n      });\n    }"""
new = """    ref.listen(authSessionProvider, (previous, next) {\n      final user = next.user;\n      if (user == null || previous?.user?.id == user.id) return;\n      final controller = ref.read(supervisorCenterProvider.notifier);\n      if (user.role == PilotRole.owner) {\n        controller.setSimulation(PilotRole.owner, userId: user.id);\n      } else {\n        controller.setRole(user.role);\n      }\n    });\n    if (session.user != null &&\n        session.user!.role != PilotRole.owner &&\n        pilotState.currentRole != session.user!.role) {\n      WidgetsBinding.instance.addPostFrameCallback((_) {\n        ref.read(supervisorCenterProvider.notifier).setRole(session.user!.role);\n      });\n    }"""
text = replace_once(text, old, new, 'auth role sync')

old = """    _Destination.settings => _SettingsView(\n      currentVersion: 'v1.1.0-test4',\n      onJobsImport: _openJobsImport,\n      onLogout: _logout,\n      currentLanguage: ref.watch(appLanguageControllerProvider),"""
new = """    _Destination.settings => _SettingsView(\n      currentVersion: 'v1.1.0-test4',\n      onJobsImport: _openJobsImport,\n      onLogout: _logout,\n      directorTestMode: ref.watch(authSessionProvider).user?.role == PilotRole.owner,\n      pilotState: pilotState,\n      onSimulationChanged: (role, userId) {\n        ref\n            .read(supervisorCenterProvider.notifier)\n            .setSimulation(role, userId: userId);\n        setState(() {\n          _destination = {\n            PilotRole.owner,\n            PilotRole.administrator,\n            PilotRole.coordinator,\n            PilotRole.supervisor,\n          }.contains(role)\n              ? _Destination.management\n              : _Destination.home;\n        });\n      },\n      currentLanguage: ref.watch(appLanguageControllerProvider),"""
text = replace_once(text, old, new, 'settings invocation')

old = """    required this.onLogout,\n    required this.currentLanguage,\n    required this.onLanguageChanged,\n  });\n\n  final String currentVersion;\n  final VoidCallback onJobsImport;\n  final VoidCallback onLogout;\n  final AppLanguage currentLanguage;\n  final ValueChanged<AppLanguage> onLanguageChanged;"""
new = """    required this.onLogout,\n    required this.directorTestMode,\n    required this.pilotState,\n    required this.onSimulationChanged,\n    required this.currentLanguage,\n    required this.onLanguageChanged,\n  });\n\n  final String currentVersion;\n  final VoidCallback onJobsImport;\n  final VoidCallback onLogout;\n  final bool directorTestMode;\n  final SupervisorCenterState pilotState;\n  final void Function(PilotRole role, String? userId) onSimulationChanged;\n  final AppLanguage currentLanguage;\n  final ValueChanged<AppLanguage> onLanguageChanged;"""
text = replace_once(text, old, new, 'settings fields')

old = """          const SizedBox(height: AppSpacing.lg),\n          _SettingsSection(\n            title: context.tr('settings.data'),"""
new = """          const SizedBox(height: AppSpacing.lg),\n          if (directorTestMode) ...[\n            _DirectorSimulationSection(\n              pilotState: pilotState,\n              onChanged: onSimulationChanged,\n            ),\n          ],\n          _SettingsSection(\n            title: context.tr('settings.data'),"""
text = replace_once(text, old, new, 'settings simulation section')

anchor = """final class _SettingsSection extends StatelessWidget {"""
insert = r'''final class _DirectorSimulationSection extends StatelessWidget {
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
        .where((user) =>
            user.active &&
            (user.role == PilotRole.employee ||
                user.role == PilotRole.contractor))
        .toList(growable: false);
    final currentWorker = workers.any((user) => user.id == pilotState.currentUser.id)
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
              helperText: 'Use somente o login do Diretor durante a homologação.',
            ),
            items: const [
              DropdownMenuItem(
                value: PilotRole.owner,
                child: Text('Diretor'),
              ),
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
                helperText: 'A tela passa a usar o nome, função e permissões desse colaborador.',
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

'''
if anchor not in text:
    raise RuntimeError('settings section class anchor not found')
text = text.replace(anchor, insert + anchor, 1)
screen.write_text(text, encoding='utf-8')

# --- Management dashboard: make metric cards behave as shortcuts ---
text = supervisor.read_text(encoding='utf-8')
replacements = [
(
"""            JkddSummaryCard(\n              label: context.tr('supervisor.pendingHours'),\n              value: '$pending',\n              icon: Icons.pending_actions,\n              color: AppColors.amber,\n            ),""",
"""            InkWell(\n              borderRadius: BorderRadius.circular(16),\n              onTap: () => onOpen(SupervisorCenterView.approveTime),\n              child: JkddSummaryCard(\n                label: context.tr('supervisor.pendingHours'),\n                value: '$pending',\n                icon: Icons.pending_actions,\n                color: AppColors.amber,\n              ),\n            ),""",
'pending shortcut'),
(
"""            JkddSummaryCard(\n              label: context.tr('supervisor.activeJobs'),\n              value:\n                  '${state.jobs.where((job) => job.status == JobStatus.active).length}',\n              icon: Icons.apartment,\n              color: AppColors.blue,\n            ),""",
"""            InkWell(\n              borderRadius: BorderRadius.circular(16),\n              onTap: () => onOpen(SupervisorCenterView.jobs),\n              child: JkddSummaryCard(\n                label: context.tr('supervisor.activeJobs'),\n                value:\n                    '${state.jobs.where((job) => job.status == JobStatus.active).length}',\n                icon: Icons.apartment,\n                color: AppColors.blue,\n              ),\n            ),""",
'jobs shortcut'),
(
"""            JkddSummaryCard(\n              label: context.tr('supervisor.workingNow'),\n              value: '$working',\n              icon: Icons.groups_outlined,\n              color: AppColors.green,\n            ),""",
"""            InkWell(\n              borderRadius: BorderRadius.circular(16),\n              onTap: () => onOpen(SupervisorCenterView.workingNow),\n              child: JkddSummaryCard(\n                label: context.tr('supervisor.workingNow'),\n                value: '$working',\n                icon: Icons.groups_outlined,\n                color: AppColors.green,\n              ),\n            ),""",
'working shortcut'),
(
"""            JkddSummaryCard(\n              label: context.tr('nav.employees'),\n              value: '${state.users.length}',\n              icon: Icons.badge_outlined,\n              color: AppColors.purple,\n            ),""",
"""            InkWell(\n              borderRadius: BorderRadius.circular(16),\n              onTap: () => Navigator.of(context).push(\n                MaterialPageRoute(\n                  builder: (_) => const EmployeesManagementScreen(),\n                ),\n              ),\n              child: JkddSummaryCard(\n                label: context.tr('nav.employees'),\n                value: '${state.users.length}',\n                icon: Icons.badge_outlined,\n                color: AppColors.purple,\n              ),\n            ),""",
'employees shortcut'),
]
for old, new, label in replacements:
    text = replace_once(text, old, new, label)
supervisor.write_text(text, encoding='utf-8')

print('Director master-login simulation and interactive management cards applied.')
