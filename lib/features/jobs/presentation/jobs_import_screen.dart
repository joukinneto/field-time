import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jkdd_field_time_records_production/core/theme/app_colors.dart';
import 'package:jkdd_field_time_records_production/core/theme/app_spacing.dart';
import 'package:jkdd_field_time_records_production/features/jobs/data/job_asset_repository.dart';
import 'package:jkdd_field_time_records_production/src/application/field_time_controller.dart';
import 'package:jkdd_field_time_records_production/shared/widgets/jkdd_empty_state.dart';
import 'package:jkdd_field_time_records_production/shared/widgets/jkdd_info_row.dart';
import 'package:jkdd_field_time_records_production/shared/widgets/jkdd_section_header.dart';

final jobsImportCatalogProvider = FutureProvider<JobCatalog>((ref) {
  return ref.watch(jobAssetRepositoryProvider).loadCatalog();
});

class JobsImportScreen extends ConsumerWidget {
  const JobsImportScreen({super.key});

  static const routeName = '/jobs-import';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(jobsImportCatalogProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Importação de Obras')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            const JkddSectionHeader(
              title: 'Importação de Obras',
              subtitle:
                  'Banco local de obras para o Field Time. Funciona offline.',
            ),
            const SizedBox(height: AppSpacing.xl),
            catalog.when(
              data: (value) => _ImportSummary(catalog: value),
              error: (error, stackTrace) => JkddEmptyState(
                icon: Icons.error_outline,
                title: 'Jobs database unavailable',
                message: error.toString(),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
            const SizedBox(height: AppSpacing.xl),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                FilledButton.icon(
                  onPressed: () => _showUpdateInstructions(context),
                  icon: const Icon(Icons.upload_file_outlined),
                  label: const Text('Atualizar Obras'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _showReportInstructions(context),
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('Ver Relatório'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showUpdateInstructions(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Atualizar Obras'),
        content: const Text(
          'Substitua a planilha atualizada em data_import/input/ e execute '
          'dart run tool/import_jobs_from_excel.dart. Upload remoto não foi '
          'implementado nesta etapa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showReportInstructions(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Relatório de Importação'),
        content: const Text(
          'O relatório local é gerado em '
          'data_import/reports/JOBS_IMPORT_REPORT.md.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _ImportSummary extends StatelessWidget {
  const _ImportSummary({required this.catalog});

  final JobCatalog catalog;

  @override
  Widget build(BuildContext context) {
    final metadata = catalog.metadata;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Resumo', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.lg),
            JkddInfoRow(
              icon: Icons.insert_drive_file_outlined,
              label: 'Último arquivo processado',
              value: metadata.sourceFile ?? 'Nenhum arquivo processado',
            ),
            JkddInfoRow(
              icon: Icons.schedule_outlined,
              label: 'Última atualização',
              value: metadata.processedAt == null
                  ? 'Pendente'
                  : _dateTime(metadata.processedAt!),
            ),
            JkddInfoRow(
              icon: Icons.apartment_outlined,
              label: 'Quantidade de obras',
              value: catalog.jobs.length.toString(),
            ),
            JkddInfoRow(
              icon: Icons.error_outline,
              label: 'Quantidade de erros',
              value: metadata.errors.toString(),
            ),
            if (metadata.errors > 0) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'Revise o relatório antes de usar a base no campo.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _dateTime(DateTime value) =>
      '${value.month.toString().padLeft(2, '0')}/'
      '${value.day.toString().padLeft(2, '0')}/${value.year} '
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}
