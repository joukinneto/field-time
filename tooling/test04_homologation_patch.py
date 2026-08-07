from __future__ import annotations

from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected exactly 1 match, found {count}")
    return text.replace(old, new, 1)


def regex_once(text: str, pattern: str, replacement: str, label: str) -> str:
    updated, count = re.subn(pattern, replacement, text, count=1, flags=re.S)
    if count != 1:
        raise RuntimeError(f"{label}: expected exactly 1 regex match, found {count}")
    return updated


def patch_controller() -> None:
    path = ROOT / "lib/src/application/field_time_controller.dart"
    text = path.read_text(encoding="utf-8")

    text = replace_once(
        text,
        "Future<void> saveReceipt(ReceiptDraft draft, XFile file) async {",
        "Future<void> saveReceipt(ReceiptDraft draft, XFile? file) async {",
        "nullable receipt file",
    )
    text = replace_once(
        text,
        "      final attachment =\n          await _attachment(file, draft.job, AttachmentKind.receipt);",
        "      if (file == null) {\n"
        "        throw StateError('receipts.attachPhotoRequired');\n"
        "      }\n"
        "      final attachment =\n"
        "          await _attachment(file, draft.job, AttachmentKind.receipt);",
        "new receipt photo guard",
    )

    update_method = r'''
  Future<void> updateReceipt(
    Receipt receipt,
    ReceiptDraft draft,
    XFile? file,
  ) async {
    await _run('fieldTime.saveReceiptProgress', () async {
      if (receipt.status != ReceiptStatus.draft) {
        throw StateError('receipts.onlyDraftCanBeEdited');
      }

      final snapshot = state.snapshot;
      final now = DateTime.now();
      final nextStatus =
          draft.submit ? ReceiptStatus.submitted : ReceiptStatus.draft;
      Attachment? replacementAttachment;
      if (file != null) {
        replacementAttachment =
            await _attachment(file, draft.job, AttachmentKind.receipt);
      }
      final attachmentIds = replacementAttachment == null
          ? receipt.attachmentIds
          : [replacementAttachment.id];

      final updatedReceipt = Receipt(
        id: receipt.id,
        registrationNumber: receipt.registrationNumber,
        companyId: receipt.companyId,
        subcontractorCompanyId: receipt.subcontractorCompanyId,
        workerId: receipt.workerId,
        jobId: draft.job.id,
        purchaseDate: draft.purchaseDate,
        merchant: draft.merchant.trim(),
        total: draft.total,
        tax: draft.tax,
        receiptNumber: draft.receiptNumber?.trim().isEmpty == true
            ? null
            : draft.receiptNumber?.trim(),
        description: draft.description.trim(),
        notes: draft.notes?.trim().isEmpty == true ? null : draft.notes?.trim(),
        status: nextStatus,
        attachmentIds: attachmentIds,
        extractionResult:
            replacementAttachment == null ? receipt.extractionResult : null,
        userReviewed: draft.userReviewed,
        createdAt: receipt.createdAt,
        updatedAt: now,
      );

      final updatedReimbursements = <ReimbursementRequest>[];
      final changedReimbursementIds = <String>[];
      for (final reimbursement in snapshot.reimbursements) {
        if (!reimbursement.receiptIds.contains(receipt.id)) {
          updatedReimbursements.add(reimbursement);
          continue;
        }
        changedReimbursementIds.add(reimbursement.id);
        updatedReimbursements.add(
          ReimbursementRequest(
            id: reimbursement.id,
            registrationNumber: reimbursement.registrationNumber,
            companyId: reimbursement.companyId,
            subcontractorCompanyId: reimbursement.subcontractorCompanyId,
            workerId: reimbursement.workerId,
            jobId: draft.job.id,
            receiptIds: reimbursement.receiptIds,
            attachmentIds: attachmentIds,
            amount: draft.total,
            status: nextStatus,
            createdAt: reimbursement.createdAt,
            updatedAt: now,
          ),
        );
      }

      final updatedSnapshot = snapshot.copyWith(
        receipts: [
          for (final current in snapshot.receipts)
            if (current.id == receipt.id) updatedReceipt else current,
        ],
        reimbursements: updatedReimbursements,
        attachments: replacementAttachment == null
            ? snapshot.attachments
            : [...snapshot.attachments, replacementAttachment],
        syncQueue: [
          ...snapshot.syncQueue,
          SyncQueueItem(
            id: uuid.v7(),
            companyId: snapshot.companyId,
            subcontractorCompanyId: snapshot.subcontractor.id,
            entityType: 'Receipt',
            entityId: receipt.id,
            operation: SyncOperation.update,
            createdAt: now,
          ),
          for (final reimbursementId in changedReimbursementIds)
            SyncQueueItem(
              id: uuid.v7(),
              companyId: snapshot.companyId,
              subcontractorCompanyId: snapshot.subcontractor.id,
              entityType: 'ReimbursementRequest',
              entityId: reimbursementId,
              operation: SyncOperation.update,
              createdAt: now,
            ),
        ],
      );
      await repository.save(updatedSnapshot);
      return updatedSnapshot;
    }, draft.submit ? 'fieldTime.reimbursementSubmitted' : 'fieldTime.draftSaved');
  }

'''
    text = replace_once(
        text,
        "  Future<void> addObservation(String notes) async {",
        update_method + "  Future<void> addObservation(String notes) async {",
        "insert draft receipt update method",
    )
    path.write_text(text, encoding="utf-8")


def patch_time_records() -> None:
    path = ROOT / "lib/src/presentation/screens/time_records_screen.dart"
    text = path.read_text(encoding="utf-8")

    text = text.replace(
        "\nenum _EndDayReceiptChoice { attachNow, noReceipts, back }\n", "\n"
    )
    text = replace_once(
        text,
        "        _Destination.receipts => _ReceiptsView(\n"
        "            snapshot: state.snapshot,\n"
        "            onReceipt: _receipt,\n"
        "          ),",
        "        _Destination.receipts => _ReceiptsView(\n"
        "            snapshot: state.snapshot,\n"
        "            onReceipt: _receipt,\n"
        "            onEditReceipt: _editReceipt,\n"
        "          ),",
        "wire receipt edit callback",
    )
    text = replace_once(
        text,
        "            currentVersion: 'v1.1.0-test3',",
        "            currentVersion: 'v1.1.0-test4',",
        "settings Test 04 version",
    )

    new_end_day = r'''  Future<void> _endDay() async {
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
        content: Text('${context.tr('endDay.success')}. ${context.tr('endDay.rest')}!'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('common.done')),
          ),
        ],
      ),
    );
  }

  Future<void> _receipt() async {'''
    text = regex_once(
        text,
        r"  Future<void> _endDay\(\) async \{.*?\n  Future<void> _receipt\(\) async \{",
        new_end_day,
        "simplify collaborator end-day flow",
    )

    old_receipt_block = r'''  Future<void> _receipt() async {
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
'''
    new_receipt_block = old_receipt_block + r'''
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
'''
    text = replace_once(
        text,
        old_receipt_block,
        new_receipt_block,
        "insert receipt edit handler",
    )

    text = regex_once(
        text,
        r"  Future<void> _showDaySummary\(WorkDay day, FieldTimeSnapshot snapshot\) async \{.*?\n  void _message\(String value\)",
        "  void _message(String value)",
        "remove obsolete end-day summary dialog",
    )

    new_receipts_view = r'''final class _ReceiptsView extends StatelessWidget {
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
    final total = snapshot.reimbursements
        .fold<double>(0, (sum, item) => sum + item.amount);
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
                  leading: const Icon(Icons.receipt_long_outlined,
                      color: AppColors.amber),
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

final class _SettingsView'''
    text = regex_once(
        text,
        r"final class _ReceiptsView extends StatelessWidget \{.*?\nfinal class _SettingsView",
        new_receipts_view,
        "make receipt drafts editable",
    )

    text = regex_once(
        text,
        r"\nfinal class _SummaryLine extends StatelessWidget \{.*?\n\}\n\nbool _sameDate",
        "\nbool _sameDate",
        "remove obsolete summary line widget",
    )

    path.write_text(text, encoding="utf-8")


def main() -> None:
    patch_controller()
    patch_time_records()
    print("Test 04 homologation patch applied successfully.")


if __name__ == "__main__":
    main()
