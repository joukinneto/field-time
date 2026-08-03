import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jkdd_field_time_records_production/features/employees/domain/employee.dart';
import 'package:jkdd_field_time_records_production/src/domain/field_time_models.dart'
    as field_time;

final employeeAssetRepositoryProvider =
    Provider((ref) => const EmployeeAssetRepository());

final employeeCatalogProvider = FutureProvider<EmployeeCatalog>((ref) {
  return ref.watch(employeeAssetRepositoryProvider).loadCatalog();
});

final class EmployeeAssetRepositoryException implements Exception {
  const EmployeeAssetRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class EmployeeCatalogMetadata {
  const EmployeeCatalogMetadata({
    this.schemaVersion,
    this.generatedAt,
    this.sourceWorkbook,
    this.company,
    this.recordCount = 0,
    this.activeCount = 0,
    this.inactiveCount = 0,
  });

  final String? schemaVersion;
  final DateTime? generatedAt;
  final String? sourceWorkbook;
  final String? company;
  final int recordCount;
  final int activeCount;
  final int inactiveCount;

  factory EmployeeCatalogMetadata.fromJson(Map<String, dynamic> json) =>
      EmployeeCatalogMetadata(
        schemaVersion: _nullableString(json['schema_version']),
        generatedAt:
            DateTime.tryParse(_nullableString(json['generated_at']) ?? ''),
        sourceWorkbook: _nullableString(json['source_workbook']),
        company: _nullableString(json['company']),
        recordCount: _int(json['record_count']),
        activeCount: _int(json['active_count']),
        inactiveCount: _int(json['inactive_count']),
      );
}

final class EmployeeCatalog {
  const EmployeeCatalog({required this.metadata, required this.employees});

  final EmployeeCatalogMetadata metadata;
  final List<Employee> employees;

  List<Employee> get activeEmployees =>
      employees.where((employee) => employee.active).toList(growable: false);
}

final class EmployeeFilters {
  const EmployeeFilters({
    this.query = '',
    this.status,
    this.company,
    this.category,
    this.supervisor,
    this.role,
  });

  final String query;
  final String? status;
  final String? company;
  final String? category;
  final String? supervisor;
  final String? role;

  bool matches(Employee employee) {
    final normalizedQuery = query.trim().toLowerCase();
    final matchesQuery = normalizedQuery.isEmpty ||
        employee.searchableText.contains(normalizedQuery);
    return matchesQuery &&
        _matches(status, employee.status) &&
        _matches(company, employee.company) &&
        _matches(category, employee.category) &&
        _matches(supervisor, employee.supervisor) &&
        _matches(role, employee.role);
  }

  bool _matches(String? filter, String? value) =>
      filter == null ||
      filter.isEmpty ||
      filter == value ||
      value?.toLowerCase() == filter.toLowerCase();
}

final class EmployeeAssetRepository {
  const EmployeeAssetRepository(
      {this.assetPath = 'assets/data/employees.json'});

  final String assetPath;

  Future<EmployeeCatalog> loadCatalog() async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Root value is not a JSON object.');
      }
      final rows = decoded['employees'];
      if (rows is! List) {
        throw const FormatException(
            'Employees database must contain an employees list.');
      }
      final employees = rows
          .whereType<Map<String, dynamic>>()
          .map(Employee.fromJson)
          .where((employee) => employee.employeeId.isNotEmpty)
          .toList(growable: false);
      return EmployeeCatalog(
        metadata: EmployeeCatalogMetadata.fromJson(decoded),
        employees: employees,
      );
    } on FlutterError catch (error) {
      throw EmployeeAssetRepositoryException(
        'Employees database asset was not found at $assetPath. Details: ${error.message}',
      );
    } on FormatException catch (error) {
      throw EmployeeAssetRepositoryException(
        'Employees database asset is invalid at $assetPath: $error',
      );
    } on Object catch (error) {
      throw EmployeeAssetRepositoryException(
        'Employees database could not be loaded from $assetPath: $error',
      );
    }
  }

  List<Employee> filter(List<Employee> employees, EmployeeFilters filters) =>
      employees.where(filters.matches).toList(growable: false)
        ..sort((left, right) => left.fullName.compareTo(right.fullName));

  field_time.WorkerProfile toWorkerProfile(Employee employee) =>
      field_time.WorkerProfile(
        id: employee.employeeId,
        companyId: field_time.FieldTimeSnapshot.companyIdEww,
        subcontractorCompanyId:
            field_time.FieldTimeSnapshot.subcontractorIdJkdd,
        displayName: employee.displayName,
        laborType: field_time.LaborType.subcontractor,
      );
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String? _nullableString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
