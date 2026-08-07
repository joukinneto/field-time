import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jkdd_field_time_records_production/core/theme/app_colors.dart';
import 'package:jkdd_field_time_records_production/core/theme/app_radius.dart';
import 'package:jkdd_field_time_records_production/core/theme/app_spacing.dart';
import 'package:jkdd_field_time_records_production/src/application/field_time_controller.dart';
import 'package:jkdd_field_time_records_production/src/domain/field_time_models.dart';
import 'package:jkdd_field_time_records_production/src/localization/app_language.dart';

final class ReceiptSubmission {
  const ReceiptSubmission({required this.draft, this.file});

  final ReceiptDraft draft;
  final XFile? file;
}

final class ReceiptDialog extends StatefulWidget {
  const ReceiptDialog({
    super.key,
    required this.jobs,
    this.initialJob,
    this.initialReceipt,
    this.imagePicker,
  });

  final List<Job> jobs;
  final Job? initialJob;
  final Receipt? initialReceipt;
  final ImagePicker? imagePicker;

  @override
  State<ReceiptDialog> createState() => _ReceiptDialogState();
}

final class _ReceiptDialogState extends State<ReceiptDialog> {
  final _formKey = GlobalKey<FormState>();
  final _merchant = TextEditingController();
  final _total = TextEditingController();
  final _tax = TextEditingController(text: '0.00');
  final _receiptNumber = TextEditingController();
  final _description = TextEditingController();
  final _notes = TextEditingController();
  late final ImagePicker _picker;
  late Job _job;
  DateTime _purchaseDate = DateTime.now();
  XFile? _file;
  bool _reviewed = false;

  bool get _editing => widget.initialReceipt != null;

  @override
  void initState() {
    super.initState();
    _picker = widget.imagePicker ?? ImagePicker();
    final receipt = widget.initialReceipt;
    _job = widget.initialJob ??
        (receipt == null
            ? widget.jobs.first
            : widget.jobs.firstWhere(
                (job) => job.id == receipt.jobId,
                orElse: () => widget.jobs.first,
              ));
    if (receipt != null) {
      _merchant.text = receipt.merchant;
      _total.text = receipt.total.toStringAsFixed(2);
      _tax.text = receipt.tax.toStringAsFixed(2);
      _receiptNumber.text = receipt.receiptNumber ?? '';
      _description.text = receipt.description;
      _notes.text = receipt.notes ?? '';
      _purchaseDate = receipt.purchaseDate;
      _reviewed = receipt.userReviewed;
    }
  }

  @override
  void dispose() {
    _merchant.dispose();
    _total.dispose();
    _tax.dispose();
    _receiptNumber.dispose();
    _description.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.infoSoft,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(
                  Icons.receipt_long_outlined,
                  color: AppColors.blue,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  _editing
                      ? 'Editar recibo em rascunho'
                      : context.tr('home.requestReimbursement'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                tooltip: context.tr('common.close'),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.infoSoft,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: const Color(0xffbfdbfe)),
            ),
            child: Text(_editing
                ? 'Você pode alterar os dados do rascunho, trocar a foto e depois salvar ou enviar.'
                : context.tr('receipts.mockNotice')),
          ),
          const SizedBox(height: AppSpacing.lg),
          DropdownButtonFormField<Job>(
            initialValue: _job,
            decoration: InputDecoration(labelText: context.tr('timesheet.job')),
            items: [
              for (final job in widget.jobs)
                DropdownMenuItem(value: job, child: Text(job.displayName)),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _job = value);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pick(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(context.tr('receipts.takePhoto')),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pick(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(_editing
                      ? 'Trocar imagem'
                      : context.tr('receipts.selectImage')),
                ),
              ),
            ],
          ),
          if (_file != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(context.tr('receipts.file', {'name': _file!.name})),
          ] else if (_editing) ...[
            const SizedBox(height: AppSpacing.sm),
            const Text('A imagem já anexada será mantida.'),
          ],
          const SizedBox(height: AppSpacing.md),
          _ResponsiveFormRow(
            children: [
              TextFormField(
                controller: _merchant,
                decoration:
                    InputDecoration(labelText: context.tr('receipts.merchant')),
                validator: _required,
              ),
              TextFormField(
                controller: _receiptNumber,
                decoration: InputDecoration(
                  labelText: context.tr('receipts.receiptNumber'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _ResponsiveFormRow(
            children: [
              TextFormField(
                controller: _total,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: context.tr('receipts.amount'),
                  prefixText: r'$ ',
                ),
                validator: _money,
              ),
              TextFormField(
                controller: _tax,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: context.tr('receipts.tax'),
                  prefixText: r'$ ',
                ),
                validator: _money,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: _selectDate,
            icon: const Icon(Icons.calendar_today_outlined),
            label:
                Text('${context.tr('receipts.date')}: ${_date(_purchaseDate)}'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _description,
            decoration:
                InputDecoration(labelText: context.tr('receipts.description')),
            validator: _required,
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _notes,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: context.tr('receipts.notes'),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          CheckboxListTile(
            value: _reviewed,
            contentPadding: EdgeInsets.zero,
            title: Text(context.tr('receipts.reviewConfirm')),
            onChanged: (value) => setState(() => _reviewed = value ?? false),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _submit(false),
                  child: Text(context.tr('receipts.saveDraft')),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _reviewed ? () => _submit(true) : null,
                  icon: const Icon(Icons.send_outlined),
                  label: Text(context.tr('receipts.submit')),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 820),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: content,
        ),
      ),
    );
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 72,
        maxWidth: 1600,
      );
      if (file != null && mounted) setState(() => _file = file);
    } on Exception {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('receipts.cameraUnavailable')),
        ),
      );
    }
  }

  Future<void> _selectDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _purchaseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (selected != null && mounted) setState(() => _purchaseDate = selected);
  }

  void _submit(bool submit) {
    if (!_formKey.currentState!.validate()) return;
    if (_file == null && !_editing) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('receipts.attachPhotoRequired'))),
      );
      return;
    }
    Navigator.pop(
      context,
      ReceiptSubmission(
        file: _file,
        draft: ReceiptDraft(
          job: _job,
          merchant: _merchant.text,
          purchaseDate: _purchaseDate,
          total: double.parse(_total.text.replaceAll(',', '.')),
          tax: double.parse(_tax.text.replaceAll(',', '.')),
          receiptNumber: _receiptNumber.text,
          description: _description.text,
          notes: _notes.text,
          submit: submit,
          userReviewed: _reviewed,
        ),
      ),
    );
  }

  String? _required(String? value) => value == null || value.trim().isEmpty
      ? context.tr('receipts.requiredField')
      : null;

  String? _money(String? value) {
    final number = double.tryParse((value ?? '').replaceAll(',', '.'));
    return number == null || number < 0
        ? context.tr('receipts.invalidAmount')
        : null;
  }

  String _date(DateTime value) => '${value.month.toString().padLeft(2, '0')}/'
      '${value.day.toString().padLeft(2, '0')}/${value.year}';
}

final class _ResponsiveFormRow extends StatelessWidget {
  const _ResponsiveFormRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 520) {
            return Column(
              children: [
                children.first,
                const SizedBox(height: AppSpacing.md),
                children.last,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: children.first),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: children.last),
            ],
          );
        },
      );
}
