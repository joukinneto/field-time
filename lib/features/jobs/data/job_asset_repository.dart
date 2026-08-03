import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jkdd_field_time_records_production/features/jobs/domain/job.dart'
    as imported;
import 'package:jkdd_field_time_records_production/src/domain/field_time_models.dart'
    as field_time;

final jobAssetRepositoryProvider =
    Provider((ref) => const JobAssetRepository());

final class JobAssetRepositoryException implements Exception {
  const JobAssetRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class JobCatalogMetadata {
  const JobCatalogMetadata({
    this.sourceFile,
    this.sourceSheet,
    this.processedAt,
    this.totalRows = 0,
    this.validJobs = 0,
    this.activeJobs = 0,
    this.inactiveJobs = 0,
    this.errors = 0,
    this.reportPath = 'data_import/reports/JOBS_IMPORT_REPORT.md',
  });

  final String? sourceFile;
  final String? sourceSheet;
  final DateTime? processedAt;
  final int totalRows;
  final int validJobs;
  final int activeJobs;
  final int inactiveJobs;
  final int errors;
  final String reportPath;

  factory JobCatalogMetadata.fromJson(Map<String, dynamic> json) {
    final processedAtText = json['processedAt']?.toString();
    return JobCatalogMetadata(
      sourceFile: _nullableString(json['sourceFile']),
      sourceSheet: _nullableString(json['sourceSheet']),
      processedAt: processedAtText == null || processedAtText.trim().isEmpty
          ? null
          : DateTime.tryParse(processedAtText),
      totalRows: _int(json['totalRows']),
      validJobs: _int(json['validJobs']),
      activeJobs: _int(json['activeJobs']),
      inactiveJobs: _int(json['inactiveJobs']),
      errors: _int(json['errors']),
      reportPath: _string(
        json['reportPath'],
        fallback: 'data_import/reports/JOBS_IMPORT_REPORT.md',
      ),
    );
  }
}

final class JobCatalog {
  const JobCatalog({required this.metadata, required this.jobs});

  final JobCatalogMetadata metadata;
  final List<imported.Job> jobs;

  List<imported.Job> get activeJobs =>
      jobs.where((job) => job.isActive).toList(growable: false);
}

final class JobAssetRepository {
  const JobAssetRepository({this.assetPath = 'assets/data/jobs.json'});

  final String assetPath;

  Future<JobCatalog> loadCatalog() async {
    final raw = await _loadRawJson();
    final decoded = _decode(raw);
    final metadata = decoded['metadata'] is Map<String, dynamic>
        ? JobCatalogMetadata.fromJson(
            decoded['metadata'] as Map<String, dynamic>,
          )
        : const JobCatalogMetadata();
    final rows = decoded['jobs'];
    if (rows is! List) {
      throw JobAssetRepositoryException(
        'Jobs database asset is invalid: expected a "jobs" list in $assetPath.',
      );
    }
    try {
      final jobs = rows
          .cast<Map<String, dynamic>>()
          .map(imported.Job.fromJson)
          .toList(growable: false)
        ..sort((left, right) => _compareJobNumbers(
              left.jobNumber,
              right.jobNumber,
            ));
      return JobCatalog(metadata: metadata, jobs: jobs);
    } on Object catch (error) {
      throw JobAssetRepositoryException(
        'Jobs database asset is invalid at $assetPath: $error',
      );
    }
  }

  Future<List<imported.Job>> listJobs() async => (await loadCatalog()).jobs;

  Future<List<imported.Job>> activeJobs() async =>
      (await loadCatalog()).activeJobs;

  Future<List<imported.Job>> search(String query) async {
    final normalized = query.trim().toLowerCase();
    final jobs = await listJobs();
    if (normalized.isEmpty) return jobs;
    return jobs
        .where((job) => job.searchableText.contains(normalized))
        .toList(growable: false);
  }

  Future<List<field_time.Job>> loadFieldTimeJobs() async {
    final catalog = await loadCatalog();
    return toFieldTimeJobs(catalog.jobs);
  }

  List<field_time.Job> toFieldTimeJobs(List<imported.Job> jobs) => [
        for (final job in jobs)
          field_time.Job(
            id: job.jobId,
            companyId: field_time.FieldTimeSnapshot.companyIdEww,
            subcontractorCompanyId:
                field_time.FieldTimeSnapshot.subcontractorIdJkdd,
            number: job.jobNumber,
            name: job.jobName,
            address: job.fullAddress,
            city: job.city,
            status: job.status,
            travelBonusHours: job.travelBonusHours ?? 0,
            active: job.isActive,
          ),
      ];

  Future<String> _loadRawJson() async {
    try {
      return await rootBundle.loadString(assetPath);
    } on FlutterError catch (error) {
      throw JobAssetRepositoryException(
        'Jobs database asset was not found at $assetPath. '
        'Run tool/import_jobs_from_excel.dart after placing the Excel file in '
        'data_import/input/. Details: ${error.message}',
      );
    }
  }

  Map<String, dynamic> _decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      throw const FormatException('Root value is not a JSON object.');
    } on FormatException catch (error) {
      throw JobAssetRepositoryException(
        'Jobs database asset is not valid JSON at $assetPath: $error',
      );
    }
  }
}

String _string(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String? _nullableString(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int _compareJobNumbers(String left, String right) {
  final leftNumber = int.tryParse(left);
  final rightNumber = int.tryParse(right);
  if (leftNumber != null && rightNumber != null) {
    final numeric = leftNumber.compareTo(rightNumber);
    if (numeric != 0) return numeric;
  }
  return left.compareTo(right);
}
