import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart';

const _inputWorkbook = '002_EMPLOYEES_DATABASE.xlsx';
const _assetWorkbook = 'assets/data/002_EMPLOYEES_DATABASE.xlsx';
const _employeesJsonPath = 'assets/data/employees.json';
const _reportPath = 'assets/data/EMPLOYEES_IMPORT_REPORT.md';

const _fieldAliases = {
  'employeeid': 'employee_id',
  'employee': 'employee_id',
  'full_name': 'full_name',
  'fullname': 'full_name',
  'name': 'full_name',
  'nome': 'full_name',
  'preferred_name': 'preferred_name',
  'preferredname': 'preferred_name',
  'company': 'company',
  'empresa': 'company',
  'category': 'category',
  'categoria': 'category',
  'employment_type': 'employment_type',
  'role': 'role',
  'funcao': 'role',
  'specialty': 'specialty',
  'status': 'status',
  'supervisor': 'supervisor',
  'phone': 'phone',
  'telefone': 'phone',
  'email': 'email',
  'default_start_time': 'default_start_time',
  'default_end_time': 'default_end_time',
  'notes': 'notes',
  'observacoes': 'notes',
};

void main() {
  final source = _findWorkbook();
  if (source == null) {
    _writeReport(
      processedAt: DateTime.now(),
      errors: const ['002_EMPLOYEES_DATABASE.xlsx was not found.'],
    );
    stderr.writeln('002_EMPLOYEES_DATABASE.xlsx was not found.');
    exitCode = 1;
    return;
  }

  final excel = Excel.decodeBytes(source.readAsBytesSync());
  final sheet = _findEmployeesSheet(excel);
  if (sheet == null) {
    _writeReport(
      processedAt: DateTime.now(),
      sourceFile: source.path,
      errors: ['No sheet with Employee_ID headers was found.'],
    );
    stderr.writeln('No employees sheet was found.');
    exitCode = 1;
    return;
  }

  final employees = <Map<String, dynamic>>[];
  final seen = <String>{};
  final duplicates = <String>[];
  final ignoredRows = <String>[];

  for (var index = 1; index < sheet.rows.length; index++) {
    final row = sheet.rows[index];
    if (_isBlankRow(row)) continue;
    final employee = _employeeFromRow(sheet.headers, row);
    final employeeId = employee['employee_id']?.toString().trim() ?? '';
    if (employeeId.isEmpty) {
      ignoredRows.add('Row ${index + 1}: missing Employee_ID.');
      continue;
    }
    if (!seen.add(employeeId)) {
      duplicates.add(employeeId);
      continue;
    }
    employees.add(employee);
  }

  employees.sort((left, right) => left['employee_id']
      .toString()
      .compareTo(right['employee_id'].toString()));
  final activeCount =
      employees.where((employee) => employee['active'] == true).length;
  final payload = {
    'schema_version': '1.0.0',
    'generated_at': DateTime.now().toUtc().toIso8601String(),
    'source_workbook': source.uri.pathSegments.last,
    'company': employees.isEmpty ? null : employees.first['company'],
    'record_count': employees.length,
    'active_count': activeCount,
    'inactive_count': employees.length - activeCount,
    'employees': employees,
  };
  File(_employeesJsonPath).writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(payload),
  );
  _writeReport(
    processedAt: DateTime.now(),
    sourceFile: source.path,
    sheetName: sheet.name,
    totalRows: sheet.rows.length - 1,
    imported: employees.length,
    duplicates: duplicates,
    ignoredRows: ignoredRows,
  );
  stdout.writeln('Employees imported: ${employees.length}');
}

File? _findWorkbook() {
  final candidates = [
    File(_assetWorkbook),
    File('data_import/input/$_inputWorkbook'),
  ];
  for (final file in candidates) {
    if (file.existsSync()) return file;
  }
  return null;
}

_EmployeeSheet? _findEmployeesSheet(Excel excel) {
  for (final entry in excel.tables.entries) {
    final rows = entry.value.rows;
    if (rows.isEmpty) continue;
    final headers = _headers(rows.first);
    if (headers.containsValue('employee_id')) {
      return _EmployeeSheet(entry.key, rows, headers);
    }
  }
  return null;
}

Map<int, String> _headers(List<dynamic> row) {
  final headers = <int, String>{};
  for (var index = 0; index < row.length; index++) {
    final normalized = _normalize(_cellText(row[index]));
    final field = _fieldAliases[normalized];
    if (field != null) headers[index] = field;
  }
  return headers;
}

Map<String, dynamic> _employeeFromRow(
    Map<int, String> headers, List<dynamic> row) {
  final values = <String, String>{};
  for (final entry in headers.entries) {
    values[entry.value] =
        entry.key < row.length ? _cellText(row[entry.key]) : '';
  }
  final status = _normalizeStatus(values['status']);
  return {
    'employee_id': values['employee_id'] ?? '',
    'full_name': values['full_name'] ?? '',
    'preferred_name': values['preferred_name'],
    'photo': null,
    'phone': values['phone'],
    'email': values['email'],
    'company': values['company'] ?? 'JKDD Finish & Remodeling Corp.',
    'category': values['category'],
    'employment_type': values['employment_type'],
    'role': values['role'],
    'specialty': values['specialty'],
    'admission_date': null,
    'status': status,
    'preferred_language': 'pt',
    'supervisor': values['supervisor'],
    'default_start_time': values['default_start_time'],
    'default_end_time': values['default_end_time'],
    'allowed_jobs': const ['*'],
    'address': {
      'street': null,
      'city': null,
      'state': null,
      'zip_code': null,
      'country': 'US',
    },
    'emergency_contact': {
      'name': null,
      'phone': null,
    },
    'notes': values['notes'],
    'active': status == 'active',
  };
}

void _writeReport({
  required DateTime processedAt,
  String? sourceFile,
  String? sheetName,
  int totalRows = 0,
  int imported = 0,
  List<String> duplicates = const [],
  List<String> ignoredRows = const [],
  List<String> errors = const [],
}) {
  final buffer = StringBuffer()
    ..writeln('# JKDD Field — Employees Import Report')
    ..writeln()
    ..writeln('- Processed at: ${processedAt.toIso8601String()}')
    ..writeln('- Source file: ${sourceFile ?? 'N/A'}')
    ..writeln('- Sheet: ${sheetName ?? 'N/A'}')
    ..writeln('- Total rows: $totalRows')
    ..writeln('- Imported employees: $imported')
    ..writeln('- Duplicates: ${duplicates.length}')
    ..writeln('- Ignored rows: ${ignoredRows.length}')
    ..writeln('- Output: $_employeesJsonPath')
    ..writeln()
    ..writeln('## Duplicates')
    ..writeln(duplicates.isEmpty
        ? '- None'
        : duplicates.map((item) => '- $item').join('\n'))
    ..writeln()
    ..writeln('## Ignored rows')
    ..writeln(ignoredRows.isEmpty
        ? '- None'
        : ignoredRows.map((item) => '- $item').join('\n'))
    ..writeln()
    ..writeln('## Errors')
    ..writeln(
        errors.isEmpty ? '- None' : errors.map((item) => '- $item').join('\n'));
  File(_reportPath).writeAsStringSync(buffer.toString());
}

String _normalizeStatus(String? value) {
  final text = value?.trim().toLowerCase() ?? '';
  if (text.isEmpty) return 'active';
  if (['inactive', 'inativo', 'inactiva', 'disabled', 'desativado']
      .contains(text)) {
    return 'inactive';
  }
  return 'active';
}

String _cellText(dynamic cell) => cell?.value?.toString().trim() ?? '';

bool _isBlankRow(List<dynamic> row) =>
    row.every((cell) => _cellText(cell).isEmpty);

String _normalize(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '').trim();

final class _EmployeeSheet {
  const _EmployeeSheet(this.name, this.rows, this.headers);

  final String name;
  final List<List<dynamic>> rows;
  final Map<int, String> headers;
}
