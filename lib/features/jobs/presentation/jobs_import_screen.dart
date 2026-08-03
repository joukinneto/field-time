import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jkdd_field_time_records_production/core/theme/app_colors.dart';
import 'package:jkdd_field_time_records_production/core/theme/app_spacing.dart';
import 'package:jkdd_field_time_records_production/features/jobs/data/job_asset_repository.dart';
import 'package:jkdd_field_time_records_production/src/localization/app_language.dart';
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
      appBar: AppBar(title: Text(context.tr('import.title'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            JkddSectionHeader(
              title: context.tr('import.title'),
              subtitle: context.tr('import.subtitle'),
            ),
            const SizedBox(height: AppSpacing.xl),
            catalog.when(
              data: (value) => _ImportSummary(catalog: value),
              error: (error, stackTrace) => JkddEmptyState(
                icon: Icons.error_outline,
                title: context.tr('import.databaseUnavailable'),
                message: context.tr('import.loadError'),
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
                  label: Text(context.tr('import.updateJobs')),
                ),
                OutlinedButton.icon(
                  onPressed: () => _showReportInstructions(context),
                  icon: const Icon(Icons.description_outlined),
                  label: Text(context.tr('import.viewReport')),
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
        title: Text(context.tr('import.updateJobs')),
        content: Text(context.tr('import.updateInstructions')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('common.ok')),
          ),
        ],
      ),
    );
  }

  void _showReportInstructions(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('import.reportTitle')),
        content: Text(context.tr('import.reportInstructions')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('common.ok')),
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
            Text(
              context.tr('import.summary'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.lg),
            JkddInfoRow(
              icon: Icons.insert_drive_file_outlined,
              label: context.tr('import.lastFile'),
              value:
                  metadata.sourceFile ?? context.tr('import.noFileProcessed'),
            ),
            JkddInfoRow(
              icon: Icons.schedule_outlined,
              label: context.tr('import.lastUpdate'),
              value: metadata.processedAt == null
                  ? context.tr('import.pending')
                  : _dateTime(metadata.processedAt!),
            ),
            JkddInfoRow(
              icon: Icons.apartment_outlined,
              label: context.tr('import.jobsCount'),
              value: catalog.jobs.length.toString(),
            ),
            JkddInfoRow(
              icon: Icons.error_outline,
              label: context.tr('import.errorCount'),
              value: metadata.errors.toString(),
            ),
            if (metadata.errors > 0) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                context.tr('import.reviewReport'),
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
