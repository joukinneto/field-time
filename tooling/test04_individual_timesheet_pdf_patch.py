from pathlib import Path

# 1) Domain: support Payroll and richer worker profile metadata.
models = Path('lib/src/domain/field_time_models.dart')
text = models.read_text()
text = text.replace('enum LaborType { subcontractor }', 'enum LaborType { subcontractor, payroll }', 1)
text = text.replace(
"""    required this.displayName,\n    required this.laborType,\n    this.registrationNumber = '',\n""",
"""    required this.displayName,\n    required this.laborType,\n    this.registrationNumber = '',\n    this.role = '',\n    this.employmentTypeLabel = '',\n""",
1,
)
text = text.replace(
"""  final LaborType laborType;\n  final String registrationNumber;\n\n  bool get isSubcontractor => laborType == LaborType.subcontractor;\n""",
"""  final LaborType laborType;\n  final String registrationNumber;\n  final String role;\n  final String employmentTypeLabel;\n\n  bool get isSubcontractor => laborType == LaborType.subcontractor;\n  bool get isPayroll => laborType == LaborType.payroll;\n""",
1,
)
text = text.replace(
"""    'laborType': laborType.name,\n    'registrationNumber': registrationNumber,\n""",
"""    'laborType': laborType.name,\n    'registrationNumber': registrationNumber,\n    'role': role,\n    'employmentTypeLabel': employmentTypeLabel,\n""",
1,
)
text = text.replace(
"""    laborType: LaborType.values.byName(json['laborType'] as String),\n    registrationNumber: json['registrationNumber'] as String? ?? '',\n  );\n""",
"""    laborType: LaborType.values.byName(json['laborType'] as String),\n    registrationNumber: json['registrationNumber'] as String? ?? '',\n    role: json['role'] as String? ?? '',\n    employmentTypeLabel: json['employmentTypeLabel'] as String? ?? '',\n  );\n""",
1,
)
models.write_text(text)

# 2) Employee mapping: preserve employee metadata and map explicit Payroll/W-2 types.
repo = Path('lib/features/employees/data/employee_asset_repository.dart')
text = repo.read_text()
old = """        displayName: employee.displayName,\n        laborType: field_time.LaborType.subcontractor,\n        registrationNumber: employee.registrationNumber.isNotEmpty\n            ? employee.registrationNumber\n            : employee.employeeId,\n      );\n}\n"""
new = """        displayName: employee.displayName,\n        laborType: _laborTypeFor(employee.employmentType),\n        registrationNumber: employee.registrationNumber.isNotEmpty\n            ? employee.registrationNumber\n            : employee.employeeId,\n        role: employee.role ?? '',\n        employmentTypeLabel: employee.employmentType ?? '',\n      );\n\n  field_time.LaborType _laborTypeFor(String? employmentType) {\n    final value = employmentType?.trim().toLowerCase() ?? '';\n    if (value.contains('payroll') ||\n        value.contains('w-2') ||\n        value.contains('w2') ||\n        value.contains('employee')) {\n      return field_time.LaborType.payroll;\n    }\n    return field_time.LaborType.subcontractor;\n  }\n}\n"""
if old not in text:
    raise SystemExit('employee worker mapping block not found')
text = text.replace(old, new, 1)
repo.write_text(text)

# 3) PDF: hard-filter workdays/receipts to the current worker and show worker classification.
pdf = Path('lib/src/timesheet/timesheet_pdf_service.dart')
text = pdf.read_text()
text = text.replace(
"""    final days =\n        snapshot.workDays\n            .where((day) => week.contains(day.workDate))\n            .toList(growable: false)\n          ..sort((left, right) => left.workDate.compareTo(right.workDate));\n""",
"""    final days = reportDays(\n      snapshot: snapshot,\n      range: week,\n    );\n""",
1,
)
text = text.replace(
"""          final linkedJob = snapshot.jobs.any((job) => job.id == receipt.jobId);\n          return linkedJob && week.contains(receipt.purchaseDate);\n""",
"""          final linkedJob = snapshot.jobs.any((job) => job.id == receipt.jobId);\n          return receipt.workerId == snapshot.worker.id &&\n              linkedJob &&\n              week.contains(receipt.purchaseDate);\n""",
1,
)
insert_after = """  String decimalHoursText(Duration duration) =>\n      '${decimalHours(duration).toStringAsFixed(2)} h';\n\n"""
method = """  List<WorkDay> reportDays({\n    required FieldTimeSnapshot snapshot,\n    required TimesheetRange range,\n  }) =>\n      snapshot.workDays\n          .where(\n            (day) =>\n                day.workerId == snapshot.worker.id && range.contains(day.workDate),\n          )\n          .toList(growable: false)\n        ..sort((left, right) => left.workDate.compareTo(right.workDate));\n\n"""
if insert_after not in text:
    raise SystemExit('pdf insertion anchor not found')
text = text.replace(insert_after, insert_after + method, 1)
old_header = """                pw.Text('Subcontractor:'),\n                pw.Text(snapshot.subcontractor.displayName),\n                pw.Text('Responsible:'),\n                pw.Text(snapshot.worker.displayName),\n"""
new_header = """                if (snapshot.worker.isSubcontractor) ...[\n                  pw.Text('Subcontractor Company:'),\n                  pw.Text(snapshot.subcontractor.displayName),\n                ],\n                pw.Text('Collaborator:'),\n                pw.Text(snapshot.worker.displayName),\n                if (snapshot.worker.registrationNumber.trim().isNotEmpty)\n                  pw.Text('Collaborator ID: ${snapshot.worker.registrationNumber}'),\n                if (snapshot.worker.role.trim().isNotEmpty)\n                  pw.Text('Role: ${snapshot.worker.role}'),\n                pw.Text(\n                  'Employment Type: ${_employmentTypeLabel(snapshot.worker)}',\n                ),\n"""
if old_header not in text:
    raise SystemExit('pdf header block not found')
text = text.replace(old_header, new_header, 1)
anchor = """  pw.Widget _recordsTable(\n"""
helper = """  String _employmentTypeLabel(WorkerProfile worker) {\n    if (worker.isPayroll) return 'Payroll';\n    if (worker.isSubcontractor) return 'Subcontractor';\n    return worker.employmentTypeLabel.trim().isNotEmpty\n        ? worker.employmentTypeLabel.trim()\n        : 'Not defined';\n  }\n\n"""
if anchor not in text:
    raise SystemExit('pdf helper anchor not found')
text = text.replace(anchor, helper + anchor, 1)
pdf.write_text(text)

# 4) Unit coverage: report must not mix another worker's workday.
test = Path('test/unit/timesheet_pdf_service_test.dart')
text = test.read_text()
anchor = """  test('minute conversion uses decimal hours for grand total', () {\n"""
new_test = """  test('reportDays isolates the current collaborator', () {\n    final snapshot = _snapshotWithJobs();\n    final range = service.rangeFor(TimesheetPeriod.week, DateTime(2026, 8, 5));\n    final currentDay = WorkDay(\n      id: 'current-worker-day',\n      companyId: snapshot.companyId,\n      subcontractorCompanyId: snapshot.subcontractor.id,\n      workerId: snapshot.worker.id,\n      workDate: DateTime(2026, 8, 4),\n      status: WorkDayStatus.completed,\n      segments: const [],\n      createdAt: DateTime(2026, 8, 4),\n      updatedAt: DateTime(2026, 8, 4),\n    );\n    final otherDay = WorkDay(\n      id: 'other-worker-day',\n      companyId: snapshot.companyId,\n      subcontractorCompanyId: snapshot.subcontractor.id,\n      workerId: 'another-worker',\n      workDate: DateTime(2026, 8, 4),\n      status: WorkDayStatus.completed,\n      segments: const [],\n      createdAt: DateTime(2026, 8, 4),\n      updatedAt: DateTime(2026, 8, 4),\n    );\n    final mixed = snapshot.copyWith(workDays: [currentDay, otherDay]);\n\n    final days = service.reportDays(snapshot: mixed, range: range);\n\n    expect(days, hasLength(1));\n    expect(days.single.workerId, snapshot.worker.id);\n  });\n\n"""
if anchor not in text:
    raise SystemExit('test insertion anchor not found')
text = text.replace(anchor, new_test + anchor, 1)
test.write_text(text)
