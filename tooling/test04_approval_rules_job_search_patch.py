from pathlib import Path


def replace_once(path: Path, old: str, new: str, label: str):
    text = path.read_text()
    if old not in text:
        raise RuntimeError(f'Pattern not found: {label}')
    path.write_text(text.replace(old, new, 1))

# 1) Searchable job picker for clock-in / switch-job.
path = Path('lib/src/presentation/screens/time_records_screen.dart')
old = '''  Future<Job?> _selectJob(String title, List<Job> jobs) => showDialog<Job>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(title),
      children: [
        if (jobs.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: JkddEmptyState(
              icon: Icons.apartment_outlined,
              title: context.tr('jobs.noJobsAvailable'),
              message: context.tr('jobs.noJobsAvailableHelp'),
            ),
          )
        else
          for (final job in jobs)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, job),
              child: ListTile(
                leading: const Icon(Icons.apartment_outlined),
                title: Text('${job.number} - ${job.name}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(job.address),
                    if (job.city?.trim().isNotEmpty == true) Text(job.city!),
                    const SizedBox(height: AppSpacing.xs),
                    JkddStatusChip(
                      label: job.active
                          ? context.tr('jobs.active')
                          : context.tr('jobs.inactive'),
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
    ),
  );
'''
new = '''  Future<Job?> _selectJob(String title, List<Job> jobs) async {
    final search = TextEditingController();
    var query = '';
    final selected = await showDialog<Job>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final normalized = query.trim().toLowerCase();
          final filtered = normalized.isEmpty
              ? jobs
              : jobs.where((job) {
                  final haystack = [
                    job.number,
                    job.name,
                    job.address,
                    job.city ?? '',
                    job.client ?? '',
                  ].join(' ').toLowerCase();
                  return haystack.contains(normalized);
                }).toList(growable: false);
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
                            message: 'Tente outro número, nome, endereço ou cliente.',
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final job = filtered[index];
                              return ListTile(
                                leading: const Icon(Icons.apartment_outlined),
                                title: Text('${job.number} - ${job.name}'),
                                subtitle: Text(
                                  [job.address, if (job.city?.trim().isNotEmpty == true) job.city!]
                                      .join(' • '),
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
'''
replace_once(path, old, new, 'searchable job picker')

# 2) Approval rules: approvals need no justification; supervisors approve worker hours,
# director can approve any pending hours; already-approved hours remain final.
path = Path('lib/src/supervisor_center/supervisor_center_controller.dart')
replace_once(
    path,
    '''  void approveEntry(String entryId, String justification) {
    _review(
      entryId,
      TimeReviewStatus.approved,
      justification,
      'supervisor.entryApproved',
    );
  }
''',
    '''  void approveEntry(String entryId, [String justification = '']) {
    _review(
      entryId,
      TimeReviewStatus.approved,
      justification,
      'supervisor.entryApproved',
    );
  }
''',
    'optional approval justification',
)
replace_once(
    path,
    '''  void approveAllValidForJob(String jobId, String justification) {
    _require(PilotPermission.approveTime);
    if (justification.trim().isEmpty) {
      throw StateError('supervisor.batchApproveJustificationRequired');
    }
''',
    '''  void approveAllValidForJob(String jobId, [String justification = '']) {
    _require(PilotPermission.approveTime);
''',
    'batch approval without justification',
)
replace_once(
    path,
    '''    _require(PilotPermission.approveTime);
    if (justification.trim().isEmpty) {
      throw StateError('supervisor.reviewJustificationRequired');
    }
    final entry = state.timeEntries.firstWhere((item) => item.id == entryId);
    if (entry.userId == state.currentUser.id) {
      throw StateError('supervisor.cannotReviewOwnTime');
    }
    if (status == TimeReviewStatus.rejected && justification.trim().isEmpty) {
      throw StateError('supervisor.rejectionReasonRequired');
    }
''',
    '''    _require(PilotPermission.approveTime);
    final entry = state.timeEntries.firstWhere((item) => item.id == entryId);
    if (entry.status == TimeReviewStatus.approved) {
      throw StateError('Registro já aprovado. Não é necessária nova aprovação.');
    }
    if (entry.userId == state.currentUser.id) {
      throw StateError('supervisor.cannotReviewOwnTime');
    }
    final target = state.userById(entry.userId);
    if (status == TimeReviewStatus.approved &&
        state.currentRole == PilotRole.supervisor &&
        !{PilotRole.employee, PilotRole.contractor}.contains(target.role)) {
      throw StateError('Horas de supervisor devem ser aprovadas pelo diretor.');
    }
    if (status != TimeReviewStatus.approved && justification.trim().isEmpty) {
      throw StateError(
        status == TimeReviewStatus.rejected
            ? 'supervisor.rejectionReasonRequired'
            : 'supervisor.reviewJustificationRequired',
      );
    }
''',
    'approval hierarchy and justification policy',
)
replace_once(
    path,
    '''              supervisorNote: note.trim(),
''',
    '''              supervisorNote: note.trim().isEmpty
                  ? entry.supervisorNote
                  : note.trim(),
''',
    'approval does not overwrite notes',
)

# Add director-question / supervisor-response audit thread without reopening approval.
marker = '''  void _require(PilotPermission permission) {
'''
insert = '''  void questionSupervisor(String entryId, String question) {
    if (!{PilotRole.owner, PilotRole.administrator}.contains(state.currentRole)) {
      throw StateError('Somente o diretor pode questionar uma aprovação.');
    }
    if (question.trim().isEmpty) {
      throw StateError('Informe a pergunta para o supervisor.');
    }
    final entry = state.timeEntries.firstWhere((item) => item.id == entryId);
    if (entry.status != TimeReviewStatus.approved) {
      throw StateError('Apenas registros já aprovados podem ser questionados.');
    }
    final now = DateTime.now();
    state = state.copyWith(
      reviews: [
        ...state.reviews,
        TimeEntryReview(
          id: 'question-${now.microsecondsSinceEpoch}',
          timeEntryId: entryId,
          reviewerId: state.currentUser.id,
          previousStatus: entry.status,
          newStatus: entry.status,
          reason: 'DIRECTOR_QUESTION',
          observation: question.trim(),
          reviewedAt: now,
        ),
      ],
      message: 'Questionamento enviado ao supervisor.',
    );
    unawaited(_save());
  }

  void respondDirectorQuestion(String entryId, String response) {
    if (state.currentRole != PilotRole.supervisor) {
      throw StateError('Somente o supervisor pode responder ao questionamento.');
    }
    if (response.trim().isEmpty) {
      throw StateError('Informe a resposta ao diretor.');
    }
    final entry = state.timeEntries.firstWhere((item) => item.id == entryId);
    final now = DateTime.now();
    state = state.copyWith(
      reviews: [
        ...state.reviews,
        TimeEntryReview(
          id: 'response-${now.microsecondsSinceEpoch}',
          timeEntryId: entryId,
          reviewerId: state.currentUser.id,
          previousStatus: entry.status,
          newStatus: entry.status,
          reason: 'SUPERVISOR_RESPONSE',
          observation: response.trim(),
          reviewedAt: now,
        ),
      ],
      message: 'Resposta enviada ao diretor.',
    );
    unawaited(_save());
  }

'''
text = path.read_text()
if marker not in text:
    raise RuntimeError('controller insertion marker not found')
path.write_text(text.replace(marker, insert + marker, 1))

# 3) Timesheet UI: approve immediately, show question/response thread, and actions by role.
path = Path('lib/src/presentation/screens/timesheet_screen.dart')
replace_once(
    path,
    '''    final user = state.userById(entry.userId);
    final job = state.jobById(entry.jobId);
''',
    '''    final user = state.userById(entry.userId);
    final job = state.jobById(entry.jobId);
    final entryReviews = state.reviews
        .where((review) => review.timeEntryId == entry.id)
        .toList(growable: false);
    final questions = entryReviews
        .where((review) => review.reason == 'DIRECTOR_QUESTION')
        .toList(growable: false);
    final responses = entryReviews
        .where((review) => review.reason == 'SUPERVISOR_RESPONSE')
        .toList(growable: false);
    final hasUnansweredQuestion = questions.isNotEmpty &&
        (responses.isEmpty ||
            responses.last.reviewedAt.isBefore(questions.last.reviewedAt));
''',
    'review thread state',
)
replace_once(
    path,
    '''            const SizedBox(height: AppSpacing.md),
            Align(
''',
    '''            if (questions.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              JkddStatusChip(
                label: 'Diretor: ${questions.last.observation}',
                icon: Icons.help_outline,
                tone: JkddStatusTone.warning,
              ),
            ],
            if (responses.isNotEmpty &&
                (questions.isEmpty ||
                    !responses.last.reviewedAt.isBefore(questions.last.reviewedAt))) ...[
              const SizedBox(height: AppSpacing.sm),
              JkddStatusChip(
                label: 'Supervisor: ${responses.last.observation}',
                icon: Icons.reply_outlined,
                tone: JkddStatusTone.info,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Align(
''',
    'display director question and response',
)
replace_once(
    path,
    '''                  FilledButton.icon(
                    onPressed: entry.isLocked
                        ? null
                        : () => _approveSupervisorEntry(context, ref, entry),
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(context.tr('approval.approve')),
                  ),
''',
    '''                  FilledButton.icon(
                    onPressed: entry.isLocked
                        ? null
                        : () => _approveSupervisorEntry(context, ref, entry),
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(context.tr('approval.approve')),
                  ),
                  if (entry.status == TimeReviewStatus.approved &&
                      {PilotRole.owner, PilotRole.administrator}.contains(state.currentRole))
                    TextButton.icon(
                      onPressed: () => _questionSupervisor(context, ref, entry),
                      icon: const Icon(Icons.help_outline),
                      label: const Text('Questionar supervisor'),
                    ),
                  if (entry.status == TimeReviewStatus.approved &&
                      state.currentRole == PilotRole.supervisor &&
                      hasUnansweredQuestion)
                    TextButton.icon(
                      onPressed: () => _respondDirector(context, ref, entry),
                      icon: const Icon(Icons.reply_outlined),
                      label: const Text('Responder diretor'),
                    ),
''',
    'question and response actions',
)
replace_once(
    path,
    '''    ref
        .read(supervisorCenterProvider.notifier)
        .approveEntry(entry.id, 'Aprovado pelo supervisor.');
''',
    '''    ref.read(supervisorCenterProvider.notifier).approveEntry(entry.id);
''',
    'approve without justification',
)
# Insert dialogs before reject helper.
marker = '''Future<void> _rejectSupervisorEntry(
'''
insert = '''Future<void> _questionSupervisor(
  BuildContext context,
  WidgetRef ref,
  TimeEntry entry,
) async {
  final question = await _supervisorTextDialog(
    context,
    'Questionar supervisor',
    'Digite a pergunta sobre esta aprovação.',
  );
  if (question?.trim().isEmpty != false) return;
  try {
    ref.read(supervisorCenterProvider.notifier).questionSupervisor(entry.id, question!);
  } on StateError catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

Future<void> _respondDirector(
  BuildContext context,
  WidgetRef ref,
  TimeEntry entry,
) async {
  final response = await _supervisorTextDialog(
    context,
    'Responder diretor',
    'Digite a resposta ao questionamento.',
  );
  if (response?.trim().isEmpty != false) return;
  try {
    ref.read(supervisorCenterProvider.notifier).respondDirectorQuestion(entry.id, response!);
  } on StateError catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

'''
text = path.read_text()
if marker not in text:
    raise RuntimeError('timesheet helper insertion marker not found')
path.write_text(text.replace(marker, insert + marker, 1))

# 4) Management wording requested by owner.
path = Path('lib/src/supervisor_center/supervisor_center_screen.dart')
text = path.read_text()
text = text.replace("label: context.tr('supervisor.pendingHours'),", "label: 'Aprovação de horas',", 1)
text = text.replace("label: context.tr('supervisor.activeJobs'),", "label: 'Obras em andamento',", 1)
text = text.replace("title: context.tr('supervisor.approveTime'),", "title: 'Aprovação de horas',", 1)
text = text.replace("title: context.tr('supervisor.jobs'),\n              subtitle: context.tr('supervisor.jobsAndDetails'),", "title: 'Obras em andamento',\n              subtitle: context.tr('supervisor.jobsAndDetails'),", 1)
path.write_text(text)
