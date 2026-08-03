import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jkdd_field_time_records_production/core/theme/app_colors.dart';
import 'package:jkdd_field_time_records_production/core/theme/app_spacing.dart';
import 'package:jkdd_field_time_records_production/features/employees/data/employee_asset_repository.dart';
import 'package:jkdd_field_time_records_production/features/employees/domain/employee.dart';
import 'package:jkdd_field_time_records_production/src/application/field_time_controller.dart';
import 'package:jkdd_field_time_records_production/src/localization/app_language.dart';
import 'package:jkdd_field_time_records_production/src/supervisor_center/supervisor_center_controller.dart';
import 'package:jkdd_field_time_records_production/shared/widgets/jkdd_empty_state.dart';
import 'package:jkdd_field_time_records_production/shared/widgets/jkdd_info_row.dart';
import 'package:jkdd_field_time_records_production/shared/widgets/jkdd_section_header.dart';
import 'package:jkdd_field_time_records_production/shared/widgets/jkdd_status_chip.dart';

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
          onDeactivate: _deactivateEmployee,
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
    final hasFieldHistory =
        snapshot.workDays.any((day) => day.workerId == employee.employeeId);
    final supervisorState = ref.read(supervisorCenterProvider);
    final hasSupervisorHistory = supervisorState.timeEntries
            .any((entry) => entry.userId == employee.employeeId) ||
        supervisorState.assignments
            .any((assignment) => assignment.userId == employee.employeeId);
    return hasFieldHistory || hasSupervisorHistory;
  }

  Future<void> _addEmployee() async {
    final employee = await showDialog<Employee>(
      context: context,
      builder: (context) => _EmployeeEditorDialog(),
    );
    if (employee == null) return;
    setState(() => _employees = [...?_employees, employee]);
  }

  Future<void> _editEmployee(Employee employee) async {
    final updated = await showDialog<Employee>(
      context: context,
      builder: (context) => _EmployeeEditorDialog(employee: employee),
    );
    if (updated == null) return;
    setState(() {
      _employees = [
        for (final current in _employees ?? const <Employee>[])
          if (current.employeeId == employee.employeeId) updated else current,
      ];
    });
  }

  void _deactivateEmployee(Employee employee) {
    setState(() {
      _employees = [
        for (final current in _employees ?? const <Employee>[])
          if (current.employeeId == employee.employeeId)
            current.copyWith(status: 'inactive', active: false)
          else
            current,
      ];
    });
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
    setState(() {
      _employees = [
        for (final current in _employees ?? const <Employee>[])
          if (current.employeeId != employee.employeeId) current,
      ];
    });
  }

  void _openDetails(Employee employee) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EmployeeDetailsScreen(
          employee: employee,
          hasHistory: _hasHistory(employee),
          onEdit: () => _editEmployee(employee),
          onDeactivate: () => _deactivateEmployee(employee),
          onDelete: () => _deleteEmployee(employee),
        ),
      ),
    );
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
    required this.onDeactivate,
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
  final ValueChanged<Employee> onDeactivate;
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
                      hasHistory: hasHistory(employee),
                      onEdit: () => onEdit(employee),
                      onDeactivate: () => onDeactivate(employee),
                      onDelete: () => onDelete(employee),
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
    required this.hasHistory,
    required this.onEdit,
    required this.onDeactivate,
    required this.onDelete,
    required this.onOpenDetails,
  });

  final Employee employee;
  final bool hasHistory;
  final VoidCallback onEdit;
  final VoidCallback onDeactivate;
  final VoidCallback onDelete;
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
        title: Text('${employee.employeeId} - ${employee.displayName}'),
        subtitle: Text('${employee.company}\n${employee.role ?? '-'}'),
        isThreeLine: true,
        trailing: Wrap(
          spacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            JkddStatusChip(
              label: employee.active
                  ? context.tr('employees.activeStatus')
                  : context.tr('employees.inactiveStatus'),
              icon: employee.active
                  ? Icons.check_circle_outline
                  : Icons.pause_circle_outline,
              tone: employee.active
                  ? JkddStatusTone.success
                  : JkddStatusTone.warning,
            ),
            IconButton(
              tooltip: context.tr('employees.details'),
              onPressed: onOpenDetails,
              icon: const Icon(Icons.open_in_new),
            ),
            IconButton(
              tooltip: context.tr('employees.edit'),
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: context.tr('employees.deactivate'),
              onPressed: employee.active ? onDeactivate : null,
              icon: const Icon(Icons.person_off_outlined),
            ),
            IconButton(
              tooltip: hasHistory
                  ? context.tr('employees.deleteBlocked')
                  : context.tr('employees.delete'),
              onPressed: hasHistory ? null : onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
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
    required this.onDeactivate,
    required this.onDelete,
  });

  final Employee employee;
  final bool hasHistory;
  final VoidCallback onEdit;
  final VoidCallback onDeactivate;
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
                        subtitle: employee.employeeId,
                        trailing: Wrap(
                          spacing: AppSpacing.sm,
                          children: [
                            OutlinedButton.icon(
                              onPressed: onEdit,
                              icon: const Icon(Icons.edit_outlined),
                              label: Text(context.tr('employees.edit')),
                            ),
                            OutlinedButton.icon(
                              onPressed: employee.active ? onDeactivate : null,
                              icon: const Icon(Icons.person_off_outlined),
                              label: Text(context.tr('employees.deactivate')),
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
  _EmployeeEditorDialog({Employee? employee})
      : employee = employee,
        employeeId = TextEditingController(text: employee?.employeeId ?? ''),
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
                  enabled: widget.employee == null,
                  decoration: InputDecoration(
                      labelText: context.tr('employees.employeeId')),
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
