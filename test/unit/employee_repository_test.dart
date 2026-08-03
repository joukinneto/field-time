import 'package:flutter_test/flutter_test.dart';
import 'package:jkdd_field_time_records_production/features/employees/data/employee_asset_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads official employees asset with Santana as imported collaborator',
      () async {
    const repository = EmployeeAssetRepository();

    final catalog = await repository.loadCatalog();

    expect(catalog.employees, hasLength(1));
    expect(catalog.activeEmployees, hasLength(1));
    expect(catalog.employees.single.employeeId, 'TER-0001');
    expect(catalog.employees.single.displayName, 'Santana');
    expect(catalog.employees.single.company, 'JKDD Finish & Remodeling Corp.');
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
  });
}
