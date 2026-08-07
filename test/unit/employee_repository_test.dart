import 'package:flutter_test/flutter_test.dart';
import 'package:jkdd_field_time_records_production/features/employees/data/employee_asset_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads official employees asset with Test 04 homologation workforce',
      () async {
    const repository = EmployeeAssetRepository();

    final catalog = await repository.loadCatalog();

    expect(catalog.employees, hasLength(7));
    expect(catalog.activeEmployees, hasLength(7));

    final santana = catalog.employees.singleWhere(
      (employee) => employee.employeeId == 'TER-0001',
    );
    expect(santana.displayName, 'Santana');
    expect(santana.company, 'JKDD Finish & Remodeling Corp.');

    final testEmployee = catalog.employees.singleWhere(
      (employee) => employee.employeeId == 'TST-0002',
    );
    expect(testEmployee.displayName, contains('TESTE'));
  });

  test('filters employees by name and Employee ID', () async {
    const repository = EmployeeAssetRepository();
    final catalog = await repository.loadCatalog();

    expect(
      repository.filter(
          catalog.employees, const EmployeeFilters(query: 'TER-0001')),
      hasLength(1),
    );
    expect(
      repository.filter(
          catalog.employees, const EmployeeFilters(query: 'Santana')),
      hasLength(1),
    );
    expect(
      repository.filter(
          catalog.employees, const EmployeeFilters(query: 'TST-0002')),
      hasLength(1),
    );
  });
}
