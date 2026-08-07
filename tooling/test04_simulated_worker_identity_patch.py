from pathlib import Path


def replace_once(path, old, new, label):
    text = path.read_text()
    if old not in text:
        raise RuntimeError(f'Pattern not found: {label}')
    path.write_text(text.replace(old, new, 1))

path = Path('lib/src/application/field_time_controller.dart')
old = """  Future<void> clockIn(Job job, String? notes) => _withLocation(\n"""
new = """  Future<void> setSimulatedWorker(String userId) async {
    try {
      final catalog = await employeeRepository.loadCatalog();
      final employee = catalog.activeEmployees.firstWhere(
        (item) =>
            item.id == userId ||
            item.employeeId == userId ||
            item.registrationNumber == userId,
      );
      final snapshot = state.snapshot.copyWith(
        worker: employeeRepository.toWorkerProfile(employee),
      );
      await repository.save(snapshot);
      state = FieldTimeState(
        snapshot: snapshot,
        loading: state.loading,
        message: 'fieldTime.simulatedWorkerChanged',
        messageValues: {'worker': employee.displayName},
        jobsImportMetadata: state.jobsImportMetadata,
        jobsImportError: state.jobsImportError,
        lastLocation: state.lastLocation,
        lastCompletedDay: state.lastCompletedDay,
      );
    } on Object {
      // Test-mode profile changes must not break the clock screen if the
      // employee catalog is temporarily unavailable.
    }
  }

  Future<void> clockIn(Job job, String? notes) => _withLocation(
"""
replace_once(path, old, new, 'insert simulated worker setter')

path = Path('lib/src/presentation/screens/time_records_screen.dart')
old = """        ref
            .read(supervisorCenterProvider.notifier)
            .setSimulation(role, userId: userId);
        setState(() {
"""
new = """        ref
            .read(supervisorCenterProvider.notifier)
            .setSimulation(role, userId: userId);
        if ({PilotRole.employee, PilotRole.contractor}.contains(role) &&
            userId != null) {
          unawaited(
            ref
                .read(fieldTimeControllerProvider.notifier)
                .setSimulatedWorker(userId),
          );
        }
        setState(() {
"""
replace_once(path, old, new, 'simulation changes active worker')

path = Path('lib/src/supervisor_center/field_time_supervisor_sync.dart')
old = """    final sessionUser = ref.read(authSessionProvider).user;
    final userId = sessionUser?.id ?? day.workerId;

    unawaited(
"""
new = """    final userId = day.workerId;

    unawaited(
"""
replace_once(path, old, new, 'sync completed day using actual worker')
text = path.read_text()
text = text.replace("import 'package:jkdd_field_time_records_production/src/auth/auth_session.dart';\n", '')
path.write_text(text)
