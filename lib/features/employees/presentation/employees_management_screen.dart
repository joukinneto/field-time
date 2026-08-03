import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jkdd_field_time_records_production/core/theme/app_colors.dart';
import 'package:jkdd_field_time_records_production/core/theme/app_spacing.dart';
import 'package:jkdd_field_time_records_production/features/employees/data/employee_asset_repository.dart';
import 'package:jkdd_field_time_records_production/features/employees/domain/employee.dart';
import 'package:jkdd_field_time_records_production/src/application/field_time_controller.dart';
import 'package:jkdd_field_time_records_production/src/domain/registration_number.dart';
import 'package:jkdd_field_time_records_production/src/localization/app_language.dart';
import 'package:jkdd_field_time_records_production/src/supervisor_center/supervisor_center_controller.dart';
import 'package:jkdd_field_time_records_production/shared/widgets/jkdd_empty_state.dart';
import 'package:jkdd_field_time_records_production/shared/widgets/jkdd_info_row.dart';
import 'package:jkdd_field_time_records_production/shared/widgets/jkdd_section_header.dart';

final class EmployeesManagementScreen extends ConsumerStatefulWidget {
  const EmployeesManagementScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<EmployeesManagementScreen> createState() =>
      _EmployeesManagementScreenState();
}

final class _EmployeesManagementScreenState
    extends ConsumerState<EmployeesManagementScreen> {
  final _searchController = TextEditingController();
  List<Employee>? _employees;
  String? _status;
  String? _company;
  String? _category;
  String? _supervisor;
  String? _role;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(employeeCatalogProvider);
    final body = catalog.when(
      data: (catalog) {
        _employees ??= catalog.employees;
        return _EmployeesContent(
          employees: _filteredEmployees,
          allEmployees: _employees!,
          searchController: _searchController,
          status: _status,
          company: _company,
          category: _category,
          supervisor: _supervisor,
          role: _role,
          onSearchChanged: (_) => setState(() {}),
          onStatusChanged: (value) => setState(() => _status = value),
          onCompanyChanged: (value) => setState(() => _company = value),
          onCategoryChanged: (value) => setState(() => _category = value),
          onSupervisorChanged: (value) => setState(() => _supervisor = value),
          onRoleChanged: (value) => setState(() => _role = value),
          onAdd: _addEmployee,
          onEdit: _editEmployee,
          onToggleStatus: _toggleEmployeeStatus,
          onDelete: _deleteEmployee,
          onOpenDetails: _openDetails,
          hasHistory: _hasHistory,
        );
      },
      error: (error, stackTrace) => JkddEmptyState(
        icon: Icons.badge_outlined,
        title: context.tr('employees.unavailable'),
        message: context.tr('employees.loadError'),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('employees.management'))),
      body: body,
    );
  }

  List<Employee> get _filteredEmployees {
    final filters = EmployeeFilters(
      query: _searchController.text,
      status: _status,
      company: _company,
      category: _category,
      supervisor: _supervisor,
      role: _role,
    );
    return ref
        .read(employeeAssetRepositoryProvider)
        .filter(_employees ?? const [], filters);
  }

  bool _hasHistory(Employee employee) {
    final snapshot = ref.read(fieldTimeControllerProvider).snapshot;
    final knownIds = {
      employee.id,
      employee.registrationNumber,
      employee.employeeId,
    }.where((value) => value.trim().isNotEmpty).toSet();
    final hasFieldHistory =
        snapshot.workDays.any((day) => knownIds.contains(day.workerId));
    final supervisorState = ref.read(supervisorCenterProvider);
    final hasSupervisorHistory = supervisorState.timeEntries
            .any((entry) => knownIds.contains(entry.userId)) ||
        supervisorState.assignments
            .any((assignment) => knownIds.contains(assignment.userId));
    return hasFieldHistory || hasSupervisorHistory;
  }

  Future<void> _addEmployee() async {
    final registrationNumber = RegistrationNumberPolicy.next(
      RegistrationRecordType.subcontractorWorker,
      (_employees ?? const <Employee>[]).map(
        (employee) => employee.registrationNumber.isNotEmpty
            ? employee.registrationNumber
            : employee.employeeId,
      ),
    );
    final employee = await showDialog<Employee>(
      context: context,
      builder: (context) => _EmployeeEditorDialog(
          generatedRegistrationNumber: registrationNumber),
    );
    if (employee == null) return;
    if ((_employees ?? const <Employee>[]).any((current) =>
        current.id == employee.id ||
        current.registrationNumber == employee.registrationNumber ||
        current.employeeId == employee.employeeId)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('fieldTime.duplicateRegistration'))),
      );
      return;
    }
    await _saveEmployees([...?_employees, employee]);
  }

  Future<void> _editEmployee(Employee employee) async {
    final updated = await showDialog<Employee>(
      context: context,
      builder: (context) => _EmployeeEditorDialog(employee: employee),
    );
    if (updated == null) return;
    await _saveEmployees([
      for (final current in _employees ?? const <Employee>[])
        if (current.employeeId == employee.employeeId) updated else current,
    ]);
  }

  Future<void> _toggleEmployeeStatus(Employee employee) async {
    final activate = !employee.active;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(activate
            ? context.tr('employees.setActive')
            : context.tr('employees.setInactive')),
        content: Text(activate
            ? context.tr('employees.confirmActive')
            : context.tr('employees.confirmInactive')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('common.save')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _saveEmployees([
      for (final current in _employees ?? const <Employee>[])
        if (current.employeeId == employee.employeeId)
          current.copyWith(
            status: activate ? 'active' : 'inactive',
            active: activate,
            notes: [
              current.notes,
              '${DateTime.now().toIso8601String()} - ${employee.displayName}: ${employee.status} -> ${activate ? 'active' : 'inactive'}',
            ].where((value) => value?.trim().isNotEmpty == true).join('\n'),
          )
        else
          current,
    ]);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr('employees.statusSaved'))),
    );
  }

  void _deleteEmployee(Employee employee) {
    if (_hasHistory(employee)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(context.tr('employees.deleteBlocked'))),
        );
      return;
    }
    _saveEmployees([
      for (final current in _employees ?? const <Employee>[])
        if (current.employeeId != employee.employeeId) current,
    ]);
  }

  void _openDetails(Employee employee) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EmployeeDetailsScreen(
          employee: employee,
          hasHistory: _hasHistory(employee),
          onEdit: () => _editEmployee(employee),
          onToggleStatus: () => _toggleEmployeeStatus(employee),
          onDelete: () => _deleteEmployee(employee),
        ),
      ),
    );
  }

  Future<void> _saveEmployees(List<Employee> employees) async {
    await ref
        .read(employeeAssetRepositoryProvider)
        .saveLocalEmployees(employees);
    if (!mounted) return;
    setState(() => _employees = employees);
  }
}

final class _EmployeesContent extends StatelessWidget {
  const _EmployeesContent({
    required this.employees,
    required this.allEmployees,
    required this.searchController,
    required this.status,
    required this.company,
    required this.category,
    required this.supervisor,
    required this.role,
    required this.onSearchChanged,
    required this.onStatusChanged,
    required this.onCompanyChanged,
    required this.onCategoryChanged,
    required this.onSupervisorChanged,
    required this.onRoleChanged,
    required this.onAdd,
    required this.onEdit,
    required this.onToggleStatus,
    required this.onDelete,
    required this.onOpenDetails,
    required this.hasHistory,
  });

  final List<Employee> employees;
  final List<Employee> allEmployees;
  final TextEditingController searchController;
  final String? status;
  final String? company;
  final String? category;
  final String? supervisor;
  final String? role;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onCompanyChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onSupervisorChanged;
  final ValueChanged<String?> onRoleChanged;
  final VoidCallback onAdd;
  final ValueChanged<Employee> onEdit;
  final ValueChanged<Employee> onToggleStatus;
  final ValueChanged<Employee> onDelete;
  final ValueChanged<Employee> onOpenDetails;
  final bool Function(Employee employee) hasHistory;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                JkddSectionHeader(
                  title: context.tr('employees.management'),
                  subtitle: context.tr('employees.subtitle'),
                  trailing: FilledButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    label: Text(context.tr('employees.add')),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _EmployeeFilters(
                  allEmployees: allEmployees,
                  searchController: searchController,
                  status: status,
                  company: company,
                  category: category,
                  supervisor: supervisor,
                  role: role,
                  onSearchChanged: onSearchChanged,
                  onStatusChanged: onStatusChanged,
                  onCompanyChanged: onCompanyChanged,
                  onCategoryChanged: onCategoryChanged,
                  onSupervisorChanged: onSupervisorChanged,
                  onRoleChanged: onRoleChanged,
                ),
                const SizedBox(height: AppSpacing.lg),
                if (employees.isEmpty)
                  JkddEmptyState(
                    icon: Icons.search_off_outlined,
                    title: context.tr('employees.noneFound'),
                    message: context.tr('employees.noneFoundHelp'),
                  )
                else
                  for (final employee in employees)
                    _EmployeeCard(
                      employee: employee,
                      onOpenDetails: () => onOpenDetails(employee),
                    ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

final class _EmployeeFilters extends StatelessWidget {
  const _EmployeeFilters({
    required this.allEmployees,
    required this.searchController,
    required this.status,
    required this.company,
    required this.category,
    required this.supervisor,
    required this.role,
    required this.onSearchChanged,
    required this.onStatusChanged,
    required this.onCompanyChanged,
    required this.onCategoryChanged,
    required this.onSupervisorChanged,
    required this.onRoleChanged,
  });

  final List<Employee> allEmployees;
  final TextEditingController searchController;
  final String? status;
  final String? company;
  final String? category;
  final String? supervisor;
  final String? role;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onCompanyChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onSupervisorChanged;
  final ValueChanged<String?> onRoleChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            SizedBox(
              width: 280,
              child: TextField(
                controller: searchController,
                onChanged: onSearchChanged,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  labelText: context.tr('employees.search'),
                ),
              ),
            ),
            _FilterDropdown(
              label: context.tr('employees.status'),
              value: status,
              values: [
                context.tr('employees.activeStatus'),
                context.tr('employees.inactiveStatus'),
              ],
              rawValues: const ['active', 'inactive'],
              onChanged: onStatusChanged,
            ),
            _FilterDropdown(
              label: context.tr('employees.company'),
              value: company,
              values: _unique(allEmployees.map((item) => item.company)),
              onChanged: onCompanyChanged,
            ),
            _FilterDropdown(
              label: context.tr('employees.category'),
              value: category,
              values: _unique(allEmployees.map((item) => item.category)),
              onChanged: onCategoryChanged,
            ),
            _FilterDropdown(
              label: context.tr('employees.supervisor'),
              value: supervisor,
              values: _unique(allEmployees.map((item) => item.supervisor)),
              onChanged: onSupervisorChanged,
            ),
            _FilterDropdown(
              label: context.tr('employees.role'),
              value: role,
              values: _unique(allEmployees.map((item) => item.role)),
              onChanged: onRoleChanged,
            ),
          ],
        ),
      ),
    );
  }
}

final class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
    this.rawValues,
  });

  final String label;
  final String? value;
  final List<String> values;
  final List<String>? rawValues;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: [
          DropdownMenuItem(
              value: null, child: Text(context.tr('employees.all'))),
          for (var index = 0; index < values.length; index++)
            DropdownMenuItem(
              value: rawValues == null ? values[index] : rawValues![index],
              child: Text(values[index]),
            ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

final class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({
    required this.employee,
    required this.onOpenDetails,
  });

  final Employee employee;
  final VoidCallback onOpenDetails;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.blue.withValues(alpha: 0.12),
          foregroundColor: AppColors.blue,
          child: const Icon(Icons.badge_outlined),
        ),
        title: Text(
          employee.displayName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text('${employee.role ?? '-'}\n${employee.company}'),
        isThreeLine: true,
        trailing: TextButton(
          onPressed: onOpenDetails,
          child: Text(context.tr('employees.details')),
        ),
      ),
    );
  }
}

final class EmployeeDetailsScreen extends StatelessWidget {
  const EmployeeDetailsScreen({
    super.key,
    required this.employee,
    required this.hasHistory,
    required this.onEdit,
    required this.onToggleStatus,
    required this.onDelete,
  });

  final Employee employee;
  final bool hasHistory;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('employees.details'))),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      JkddSectionHeader(
                        title: employee.displayName,
                        subtitle: employee.registrationNumber.isNotEmpty
                            ? employee.registrationNumber
                            : employee.employeeId,
                        trailing: Wrap(
                          spacing: AppSpacing.sm,
                          children: [
                            OutlinedButton.icon(
                              onPressed: onEdit,
                              icon: const Icon(Icons.edit_outlined),
                              label: Text(context.tr('employees.edit')),
                            ),
                            OutlinedButton.icon(
                              onPressed: onToggleStatus,
                              icon: Icon(employee.active
                                  ? Icons.person_off_outlined
                                  : Icons.person_add_alt_1_outlined),
                              label: Text(employee.active
                                  ? context.tr('employees.setInactive')
                                  : context.tr('employees.setActive')),
                            ),
                            OutlinedButton.icon(
                              onPressed: hasHistory ? null : onDelete,
                              icon: const Icon(Icons.delete_outline),
                              label: Text(context.tr('employees.delete')),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      JkddInfoRow(
                          label: context.tr('common.registrationNumber'),
                          value: employee.registrationNumber.isNotEmpty
                              ? employee.registrationNumber
                              : employee.employeeId),
                      JkddInfoRow(
                          label: context.tr('employees.company'),
                          value: employee.company),
                      JkddInfoRow(
                          label: context.tr('employees.category'),
                          value: employee.category ?? '-'),
                      JkddInfoRow(
                          label: context.tr('employees.role'),
                          value: employee.role ?? '-'),
                      JkddInfoRow(
                          label: context.tr('employees.supervisor'),
                          value: employee.supervisor ?? '-'),
                      JkddInfoRow(
                          label: context.tr('employees.phone'),
                          value: employee.phone ?? '-'),
                      JkddInfoRow(
                          label: context.tr('employees.email'),
                          value: employee.email ?? '-'),
                      JkddInfoRow(
                          label: context.tr('employees.address'),
                          value: employee.address.displayAddress.isEmpty
                              ? '-'
                              : employee.address.displayAddress),
                      JkddInfoRow(
                          label: context.tr('employees.emergencyContact'),
                          value:
                              '${employee.emergencyContact.name ?? '-'} / ${employee.emergencyContact.phone ?? '-'}'),
                      JkddInfoRow(
                          label: context.tr('employees.notes'),
                          value: employee.notes ?? '-'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final class _EmployeeEditorDialog extends StatefulWidget {
  _EmployeeEditorDialog(
      {Employee? employee, String? generatedRegistrationNumber})
      : employee = employee,
        employeeId = TextEditingController(
            text: employee?.registrationNumber.isNotEmpty == true
                ? employee!.registrationNumber
                : employee?.employeeId ?? generatedRegistrationNumber ?? ''),
        fullName = TextEditingController(text: employee?.fullName ?? ''),
        company = TextEditingController(
          text: employee?.company ?? 'JKDD Finish & Remodeling Corp.',
        ),
        category = TextEditingController(text: employee?.category ?? ''),
        role = TextEditingController(text: employee?.role ?? ''),
        supervisor = TextEditingController(text: employee?.supervisor ?? ''),
        phone = TextEditingController(text: employee?.phone ?? '');

  final Employee? employee;
  final TextEditingController employeeId;
  final TextEditingController fullName;
  final TextEditingController company;
  final TextEditingController category;
  final TextEditingController role;
  final TextEditingController supervisor;
  final TextEditingController phone;

  @override
  State<_EmployeeEditorDialog> createState() => _EmployeeEditorDialogState();
}

final class _EmployeeEditorDialogState extends State<_EmployeeEditorDialog> {
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    widget.employeeId.dispose();
    widget.fullName.dispose();
    widget.company.dispose();
    widget.category.dispose();
    widget.role.dispose();
    widget.supervisor.dispose();
    widget.phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.employee == null
          ? context.tr('employees.add')
          : context.tr('employees.edit')),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: widget.employeeId,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: context.tr('common.registrationNumber'),
                    helperText: context.tr('common.generatedAutomatically'),
                  ),
                  validator: _required,
                ),
                TextFormField(
                  controller: widget.fullName,
                  decoration:
                      InputDecoration(labelText: context.tr('employees.name')),
                  validator: _required,
                ),
                TextFormField(
                  controller: widget.company,
                  decoration: InputDecoration(
                      labelText: context.tr('employees.company')),
                  validator: _required,
                ),
                TextFormField(
                  controller: widget.category,
                  decoration: InputDecoration(
                      labelText: context.tr('employees.category')),
                ),
                TextFormField(
                  controller: widget.role,
                  decoration:
                      InputDecoration(labelText: context.tr('employees.role')),
                ),
                TextFormField(
                  controller: widget.supervisor,
                  decoration: InputDecoration(
                      labelText: context.tr('employees.supervisor')),
                ),
                TextFormField(
                  controller: widget.phone,
                  decoration:
                      InputDecoration(labelText: context.tr('employees.phone')),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr('common.cancel')),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(context.tr('common.save')),
        ),
      ],
    );
  }

  String? _required(String? value) =>
      value?.trim().isEmpty == false ? null : context.tr('employees.required');

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final previous = widget.employee;
    Navigator.of(context).pop(
      Employee(
        id: previous?.id.isNotEmpty == true
            ? previous!.id
            : RegistrationNumberPolicy.newUuid(),
        registrationNumber: widget.employeeId.text.trim(),
        employeeId: widget.employeeId.text.trim(),
        fullName: widget.fullName.text.trim(),
        preferredName: widget.fullName.text.trim(),
        company: widget.company.text.trim(),
        category: _optional(widget.category.text),
        role: _optional(widget.role.text),
        supervisor: _optional(widget.supervisor.text),
        phone: _optional(widget.phone.text),
        status: previous?.status ?? 'active',
        active: previous?.active ?? true,
        employmentType: previous?.employmentType,
        specialty: previous?.specialty,
        admissionDate: previous?.admissionDate,
        preferredLanguage: previous?.preferredLanguage,
        allowedJobs: previous?.allowedJobs ?? const ['*'],
        address: previous?.address ?? const EmployeeAddress(),
        emergencyContact:
            previous?.emergencyContact ?? const EmployeeEmergencyContact(),
        notes: previous?.notes,
      ),
    );
  }
}

List<String> _unique(Iterable<String?> values) {
  final unique = values
      .where((value) => value?.trim().isNotEmpty == true)
      .cast<String>()
      .toSet()
      .toList();
  unique.sort();
  return unique;
}

String? _optional(String value) {
  final text = value.trim();
  return text.isEmpty ? null : text;
}
