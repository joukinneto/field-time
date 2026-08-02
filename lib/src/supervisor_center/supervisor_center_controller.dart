import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jkdd_field_time_records_production/src/supervisor_center/supervisor_center_models.dart';

final supervisorCenterProvider =
    StateNotifierProvider<SupervisorCenterController, SupervisorCenterState>(
  (ref) => SupervisorCenterController(),
);

final class SupervisorCenterController
    extends StateNotifier<SupervisorCenterState> {
  SupervisorCenterController() : super(SupervisorCenterState.seeded());

  void setRole(PilotRole role) {
    state = state.copyWith(
      currentRole: role,
      message: 'Modo de teste alterado para ${roleLabel(role)}.',
    );
  }

  void setSupervisorCreateJobs(bool value) {
    _require(PilotPermission.editJob);
    state = state.copyWith(
      allowSupervisorCreateJobs: value,
      message: value
          ? 'Supervisor pode cadastrar obras no piloto.'
          : 'Cadastro de obras por Supervisor bloqueado.',
    );
  }

  void addJob(SupervisorJob job) {
    _require(PilotPermission.createJob);
    state = state.copyWith(
      jobs: [...state.jobs, job],
      message: 'Nova obra ${job.number} criada no piloto.',
    );
  }

  void updateJob(SupervisorJob job) {
    _require(PilotPermission.editJob);
    state = state.copyWith(
      jobs: [
        for (final current in state.jobs)
          if (current.id == job.id) job else current,
      ],
      message: 'Obra ${job.number} atualizada.',
    );
  }

  void submitOwnTime({required String clockOut, required String note}) {
    _require(PilotPermission.clockOwnTime);
    final user = state.currentUser;
    if (!user.isWorker) {
      throw StateError('Apenas Employee ou Contractor registram horas.');
    }
    final existing = state.timeEntries
        .where((entry) => entry.userId == user.id)
        .cast<TimeEntry?>()
        .firstOrNull;
    final jobId = existing?.jobId ??
        state.assignments
            .firstWhere((assignment) => assignment.userId == user.id)
            .jobId;
    final entry = existing == null
        ? TimeEntry(
            id: 'entry-${user.id}-${DateTime.now().millisecondsSinceEpoch}',
            userId: user.id,
            jobId: jobId,
            date: DateTime.now(),
            clockIn: '7:00 AM',
            clockOut: clockOut,
            breakMinutes: 30,
            employeeNote: note,
            status: TimeReviewStatus.pending,
          )
        : existing.copyWith(
            clockOut: clockOut,
            status: TimeReviewStatus.pending,
            supervisorNote: note,
          );
    state = state.copyWith(
      timeEntries: existing == null
          ? [...state.timeEntries, entry]
          : [
              for (final current in state.timeEntries)
                if (current.id == entry.id) entry else current,
            ],
      message: 'Horas enviadas para aprovacao.',
    );
  }

  void requestCorrection(String entryId, String justification) {
    _require(PilotPermission.requestCorrection);
    if (justification.trim().isEmpty) {
      throw StateError('Informe o motivo da solicitacao.');
    }
    _mutateEntry(
      entryId,
      status: TimeReviewStatus.correctionRequested,
      note: justification,
      success: 'Solicitacao de correcao enviada.',
    );
  }

  void approveEntry(String entryId, String justification) {
    _review(
      entryId,
      TimeReviewStatus.approved,
      justification,
      'Registro aprovado.',
    );
  }

  void rejectEntry(String entryId, String justification) {
    _review(
      entryId,
      TimeReviewStatus.rejected,
      justification,
      'Registro rejeitado.',
    );
  }

  void correctionRequestedBySupervisor(String entryId, String justification) {
    _review(
      entryId,
      TimeReviewStatus.correctionRequested,
      justification,
      'Correcao solicitada.',
    );
  }

  void updateTimeEntry({
    required String entryId,
    required String clockIn,
    required String? clockOut,
    required int breakMinutes,
    required double travelBonusHours,
    required String supervisorNote,
    required String justification,
  }) {
    _require(PilotPermission.approveTime);
    if (justification.trim().isEmpty) {
      throw StateError('Toda alteracao precisa de justificativa.');
    }
    final entry = state.timeEntries.firstWhere((item) => item.id == entryId);
    final updated = entry.copyWith(
      clockIn: clockIn,
      clockOut: clockOut,
      clearClockOut: clockOut == null,
      breakMinutes: breakMinutes,
      travelBonusHours: travelBonusHours,
      supervisorNote: supervisorNote,
      status: TimeReviewStatus.underReview,
    );
    final logs = <AuditLog>[];
    void addLog(String field, String original, String next) {
      if (original == next) return;
      logs.add(AuditLog(
        id: 'audit-${DateTime.now().microsecondsSinceEpoch}-$field',
        entityId: entryId,
        fieldName: field,
        originalValue: original,
        newValue: next,
        changedBy: state.currentUser.name,
        changedAt: DateTime.now(),
        justification: justification,
      ));
    }

    addLog('clockIn', entry.clockIn, updated.clockIn);
    addLog(
        'clockOut', entry.clockOut ?? 'Aberto', updated.clockOut ?? 'Aberto');
    addLog('breakMinutes', '${entry.breakMinutes}', '${updated.breakMinutes}');
    addLog(
      'travelBonusHours',
      entry.travelBonusHours.toStringAsFixed(2),
      updated.travelBonusHours.toStringAsFixed(2),
    );
    if (logs.isEmpty && supervisorNote.trim().isNotEmpty) {
      addLog('supervisorNote', entry.supervisorNote, supervisorNote.trim());
    }

    state = state.copyWith(
      timeEntries: [
        for (final current in state.timeEntries)
          if (current.id == entryId) updated else current,
      ],
      auditLogs: [...state.auditLogs, ...logs],
      message: 'Revisao salva com registro de auditoria.',
    );
  }

  void approveAllValidForJob(String jobId, String justification) {
    _require(PilotPermission.approveTime);
    if (justification.trim().isEmpty) {
      throw StateError('Informe uma justificativa para aprovar em lote.');
    }
    final validIds = state.timeEntries
        .where((entry) =>
            entry.jobId == jobId &&
            entry.clockOut != null &&
            entry.status != TimeReviewStatus.approved)
        .map((entry) => entry.id)
        .toSet();
    state = state.copyWith(
      timeEntries: [
        for (final entry in state.timeEntries)
          if (validIds.contains(entry.id))
            entry.copyWith(status: TimeReviewStatus.approved)
          else
            entry,
      ],
      reviews: [
        ...state.reviews,
        for (final id in validIds)
          TimeEntryReview(
            id: 'review-${DateTime.now().microsecondsSinceEpoch}-$id',
            timeEntryId: id,
            reviewerId: state.currentUser.id,
            status: TimeReviewStatus.approved,
            note: justification,
            reviewedAt: DateTime.now(),
          ),
      ],
      message: '${validIds.length} registros validos aprovados.',
    );
  }

  void _review(
    String entryId,
    TimeReviewStatus status,
    String justification,
    String success,
  ) {
    _require(PilotPermission.approveTime);
    if (justification.trim().isEmpty) {
      throw StateError('Informe a justificativa da revisao.');
    }
    final review = TimeEntryReview(
      id: 'review-${DateTime.now().microsecondsSinceEpoch}',
      timeEntryId: entryId,
      reviewerId: state.currentUser.id,
      status: status,
      note: justification.trim(),
      reviewedAt: DateTime.now(),
    );
    _mutateEntry(
      entryId,
      status: status,
      note: justification,
      success: success,
      review: review,
    );
  }

  void _mutateEntry(
    String entryId, {
    required TimeReviewStatus status,
    required String note,
    required String success,
    TimeEntryReview? review,
  }) {
    state = state.copyWith(
      timeEntries: [
        for (final entry in state.timeEntries)
          if (entry.id == entryId)
            entry.copyWith(status: status, supervisorNote: note.trim())
          else
            entry,
      ],
      reviews: review == null ? state.reviews : [...state.reviews, review],
      message: success,
    );
  }

  void _require(PilotPermission permission) {
    if (!state.hasPermission(permission)) {
      throw StateError('Perfil sem permissao para executar esta acao.');
    }
  }
}
