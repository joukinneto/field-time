from pathlib import Path


def replace_once(text, old, new, label):
    if old not in text:
        raise SystemExit(f'missing pattern: {label}')
    return text.replace(old, new, 1)

# 1) Hierarchy model and cost center.
path = Path('lib/src/supervisor_center/supervisor_center_models.dart')
text = path.read_text()
text = replace_once(text,
"""    this.function,\n    this.active = true,\n""",
"""    this.function,\n    this.costCenter = 'Field',\n    this.active = true,\n""", 'pilot user ctor')
text = replace_once(text,
"""  final String? supervisor;\n  final String? function;\n  final bool active;\n\n  bool get isContractor => role == PilotRole.contractor;\n  bool get isWorker => role == PilotRole.employee;\n""",
"""  final String? supervisor;\n  final String? function;\n  final String costCenter;\n  final bool active;\n\n  bool get isContractor => role == PilotRole.contractor;\n  bool get isWorker => true;\n""", 'pilot user fields')
text = replace_once(text,
"""  PilotUser userById(String id) =>\n      users.firstWhere((user) => user.id == id, orElse: () => currentUser);\n  SupervisorJob jobById(String id) => jobs.firstWhere(\n    (job) => job.id == id,\n    orElse: () => SupervisorJob.placeholder(id),\n  );\n""",
"""  PilotUser userById(String id) =>\n      users.firstWhere((user) => user.id == id, orElse: () => currentUser);\n\n  List<PilotUser> directReportsFor(PilotUser manager) => users\n      .where(\n        (user) =>\n            user.id != manager.id &&\n            ((user.supervisor ?? '').trim().toLowerCase() ==\n                    manager.name.trim().toLowerCase() ||\n                (user.supervisor ?? '').trim().toLowerCase() ==\n                    manager.id.trim().toLowerCase()),\n      )\n      .toList(growable: false);\n\n  bool canCurrentUserReview(TimeEntry entry) {\n    if (entry.userId == currentUser.id) return false;\n    final target = userById(entry.userId);\n    return directReportsFor(currentUser).any((user) => user.id == target.id);\n  }\n\n  String approverLabelFor(PilotUser user) {\n    final supervisorRef = (user.supervisor ?? '').trim();\n    if (supervisorRef.isEmpty) return 'Superior não definido';\n    for (final candidate in users) {\n      if (candidate.id.toLowerCase() == supervisorRef.toLowerCase() ||\n          candidate.name.toLowerCase() == supervisorRef.toLowerCase()) {\n        return candidate.name;\n      }\n    }\n    return supervisorRef;\n  }\n\n  SupervisorJob jobById(String id) => jobs.firstWhere(\n    (job) => job.id == id,\n    orElse: () => id == 'cost-center-office'\n        ? SupervisorJob(\n            id: 'cost-center-office',\n            registrationNumber: 'OFFICE',\n            number: 'OFFICE',\n            name: 'Escritório',\n            client: 'EWW',\n            address: 'Centro de custo administrativo',\n            city: '',\n            state: '',\n            zipCode: '',\n            startDate: DateTime(2026),\n            scheduledTime: '',\n            supervisorId: '',\n            notes: 'Horas administrativas',\n            status: JobStatus.active,\n          )\n        : SupervisorJob.placeholder(id),\n  );\n""", 'hierarchy helpers')
text = replace_once(text,
"""    category: 'Homologation data',\n    function: 'Supervisor',\n  ),\n""",
"""    category: 'Homologation data',\n    supervisor: 'Director Test',\n    function: 'Supervisor',\n    costCenter: 'Escritório',\n  ),\n""", 'test supervisor hierarchy')
text = replace_once(text,
"""  function: employee.role,\n  active: employee.active,\n);\n""",
"""  function: employee.role,\n  costCenter: _costCenterForRole(_roleFromEmployee(employee)),\n  active: employee.active,\n);\n\nString _costCenterForRole(PilotRole role) => switch (role) {\n  PilotRole.owner ||\n  PilotRole.administrator ||\n  PilotRole.coordinator ||\n  PilotRole.supervisor => 'Escritório',\n  _ => 'Obra',\n};\n""", 'employee cost center')
path.write_text(text)

# 2) Controller: own time for leaders, no lunch, office fallback, strict immediate-superior approval.
path = Path('lib/src/supervisor_center/supervisor_center_controller.dart')
text = path.read_text()
text = replace_once(text,
"""    final jobId = existing?.jobId ?? assignment?.jobId;\n    if (jobId == null) {\n      throw StateError('supervisor.noAssignedJob');\n    }\n""",
"""    final jobId =\n        existing?.jobId ??\n        assignment?.jobId ??\n        (user.costCenter == 'Escritório' ? 'cost-center-office' : null);\n    if (jobId == null) {\n      throw StateError('supervisor.noAssignedJob');\n    }\n""", 'office fallback')
text = replace_once(text,
"""            breakMinutes: 30,\n""",
"""            breakMinutes: 0,\n""", 'no lunch')
old = """    final target = state.userById(entry.userId);\n    if (status == TimeReviewStatus.approved &&\n        state.currentRole == PilotRole.supervisor &&\n        !{PilotRole.employee, PilotRole.contractor}.contains(target.role)) {\n      throw StateError('Horas de supervisor devem ser aprovadas pelo diretor.');\n    }\n"""
new = """    final target = state.userById(entry.userId);\n    if (!state.canCurrentUserReview(entry)) {\n      throw StateError(\n        'Este registro deve ser aprovado pelo superior imediato de ${target.name}: '\n        '${state.approverLabelFor(target)}.',\n      );\n    }\n"""
text = replace_once(text, old, new, 'direct superior review')
old = """    final validIds = state.timeEntries\n        .where(\n          (entry) =>\n              entry.jobId == jobId &&\n              entry.clockOut != null &&\n              entry.status != TimeReviewStatus.approved,\n        )\n"""
new = """    final validIds = state.timeEntries\n        .where(\n          (entry) =>\n              entry.jobId == jobId &&\n              entry.clockOut != null &&\n              entry.status != TimeReviewStatus.approved &&\n              state.canCurrentUserReview(entry),\n        )\n"""
text = replace_once(text, old, new, 'bulk hierarchy')
path.write_text(text)

# 3) Timesheet: leaders switch between own and direct reports, own cards have no approval actions.
path = Path('lib/src/presentation/screens/timesheet_screen.dart')
text = path.read_text()
text = replace_once(text,
"""enum _SupervisorTimesheetFilter { all, pending, review, approved, rejected }\n\nfinal class _SupervisorTeamTimesheet""",
"""enum _SupervisorTimesheetFilter { all, pending, review, approved, rejected }\nenum _SupervisorTimesheetScope { own, team }\n\nfinal class _SupervisorTeamTimesheet""", 'scope enum')
text = replace_once(text,
"""  _SupervisorTimesheetFilter _filter = _SupervisorTimesheetFilter.all;\n""",
"""  _SupervisorTimesheetFilter _filter = _SupervisorTimesheetFilter.all;\n  _SupervisorTimesheetScope _scope = _SupervisorTimesheetScope.own;\n""", 'scope state')
old = """    final allEntries =\n        state.timeEntries\n            .where((entry) => entry.status != TimeReviewStatus.working)\n            .toList(growable: false)\n"""
new = """    final directReportIds = state\n        .directReportsFor(state.currentUser)\n        .map((user) => user.id)\n        .toSet();\n    final allEntries =\n        state.timeEntries\n            .where(\n              (entry) =>\n                  entry.status != TimeReviewStatus.working &&\n                  (_scope == _SupervisorTimesheetScope.own\n                      ? entry.userId == state.currentUser.id\n                      : directReportIds.contains(entry.userId)),\n            )\n            .toList(growable: false)\n"""
text = replace_once(text, old, new, 'scope filtering')
old = """                JkddSectionHeader(\n                  title: context.tr('timesheet.dailyRecords'),\n                  subtitle: context.tr('supervisor.reviewSubmittedRecords'),\n                ),\n                const SizedBox(height: AppSpacing.lg),\n"""
new = """                JkddSectionHeader(\n                  title: _scope == _SupervisorTimesheetScope.own\n                      ? 'Meu Timesheet'\n                      : 'Timesheets da equipe',\n                  subtitle: _scope == _SupervisorTimesheetScope.own\n                      ? 'Minhas horas — aprovação por ${state.approverLabelFor(state.currentUser)} · Centro de custo: ${state.currentUser.costCenter}'\n                      : 'Horas dos subordinados diretos de ${state.currentUser.name}',\n                ),\n                const SizedBox(height: AppSpacing.md),\n                SegmentedButton<_SupervisorTimesheetScope>(\n                  segments: const [\n                    ButtonSegment(\n                      value: _SupervisorTimesheetScope.own,\n                      icon: Icon(Icons.person_outline),\n                      label: Text('Meu Timesheet'),\n                    ),\n                    ButtonSegment(\n                      value: _SupervisorTimesheetScope.team,\n                      icon: Icon(Icons.groups_outlined),\n                      label: Text('Minha equipe'),\n                    ),\n                  ],\n                  selected: {_scope},\n                  onSelectionChanged: (selection) {\n                    setState(() {\n                      _scope = selection.first;\n                      _filter = _SupervisorTimesheetFilter.all;\n                    });\n                  },\n                ),\n                const SizedBox(height: AppSpacing.lg),\n"""
text = replace_once(text, old, new, 'scope selector')
text = replace_once(text,
"""                    _SupervisorEntryCard(entry: entry),\n""",
"""                    _SupervisorEntryCard(\n                      entry: entry,\n                      allowReviewActions: _scope == _SupervisorTimesheetScope.team,\n                    ),\n""", 'card flag')
text = replace_once(text,
"""final class _SupervisorEntryCard extends ConsumerWidget {\n  const _SupervisorEntryCard({required this.entry});\n\n  final TimeEntry entry;\n""",
"""final class _SupervisorEntryCard extends ConsumerWidget {\n  const _SupervisorEntryCard({\n    required this.entry,\n    required this.allowReviewActions,\n  });\n\n  final TimeEntry entry;\n  final bool allowReviewActions;\n""", 'card ctor')
old = """            const SizedBox(height: AppSpacing.md),\n            Align(\n              alignment: Alignment.centerRight,\n              child: Wrap(\n"""
new = """            const SizedBox(height: AppSpacing.md),\n            if (!allowReviewActions)\n              JkddStatusChip(\n                label: 'Aprovação: ${state.approverLabelFor(user)} · Centro de custo: ${user.costCenter}',\n                icon: Icons.account_tree_outlined,\n                tone: JkddStatusTone.info,\n              ),\n            if (allowReviewActions)\n            Align(\n              alignment: Alignment.centerRight,\n              child: Wrap(\n"""
text = replace_once(text, old, new, 'hide own actions')
path.write_text(text)

# 4) Tests: hierarchy is explicit and superior-only approvals are enforced.
path = Path('test/unit/supervisor_approval_test.dart')
text = path.read_text()
text = text.replace(
"""        role: PilotRole.supervisor,\n        company: 'JKDD Finish & Remodeling Corp.',\n      ),\n      PilotUser(\n        id: 'TER-0002',\n        name: 'Employee Under Review',\n        role: PilotRole.employee,\n        company: 'JKDD Finish & Remodeling Corp.',\n      ),\n""",
"""        role: PilotRole.supervisor,\n        company: 'JKDD Finish & Remodeling Corp.',\n        supervisor: 'Director Test',\n        costCenter: 'Escritório',\n      ),\n      PilotUser(\n        id: 'TER-0002',\n        name: 'Employee Under Review',\n        role: PilotRole.employee,\n        company: 'JKDD Finish & Remodeling Corp.',\n        supervisor: 'Santana',\n      ),\n      PilotUser(\n        id: 'test-director',\n        name: 'Director Test',\n        role: PilotRole.owner,\n        company: 'JKDD Finish & Remodeling Corp.',\n        costCenter: 'Escritório',\n      ),\n""", 1)
insert = """
  test('approval follows the immediate command chain', () {
    final controller = _controllerWithEntries();
    expect(controller.state.canCurrentUserReview(
      controller.state.timeEntries.firstWhere((e) => e.id == 'entry-ter-0002'),
    ), isTrue);
    expect(controller.state.canCurrentUserReview(
      controller.state.timeEntries.firstWhere((e) => e.id == 'entry-ter-0001'),
    ), isFalse);

    controller.setSimulation(PilotRole.owner, userId: 'test-director');
    controller.approveEntry('entry-ter-0001');
    expect(
      controller.state.timeEntries.firstWhere((e) => e.id == 'entry-ter-0001').status,
      TimeReviewStatus.approved,
    );
  });

  test('supervisor own time uses office cost center and no lunch by default', () {
    final controller = _controllerWithEntries();
    final supervisor = controller.state.currentUser;
    expect(supervisor.costCenter, 'Escritório');
    expect(controller.state.approverLabelFor(supervisor), 'Director Test');
  });
"""
marker = "\n}\n\nSupervisorCenterController _controllerWithEntries"
if marker not in text:
    raise SystemExit('missing test insertion marker')
text = text.replace(marker, insert + marker, 1)
path.write_text(text)
