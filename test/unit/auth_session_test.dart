import 'package:flutter_test/flutter_test.dart';
import 'package:jkdd_field_time_records_production/src/auth/auth_session.dart';
import 'package:jkdd_field_time_records_production/src/supervisor_center/supervisor_center_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('valid collaborator login persists session', () async {
    final controller = AuthSessionController();

    await controller.login('collaborator@test.jkdd', 'Test123!');

    expect(controller.state.authenticated, isTrue);
    expect(controller.state.user?.name, 'Santana');
    expect(controller.state.user?.role, PilotRole.employee);
  });

  test('valid supervisor login uses supervisor permissions role', () async {
    final controller = AuthSessionController();

    await controller.login('supervisor@test.jkdd', 'Test123!');

    expect(controller.state.user?.name, 'Supervisor Test');
    expect(controller.state.user?.role, PilotRole.supervisor);
  });

  test('valid director login uses director role', () async {
    final controller = AuthSessionController();

    await controller.login('director@test.jkdd', 'Test123!');

    expect(controller.state.user?.name, 'Director Test');
    expect(controller.state.user?.role, PilotRole.owner);
  });

  test('invalid login keeps user signed out', () async {
    final controller = AuthSessionController();

    await controller.login('collaborator@test.jkdd', 'wrong');

    expect(controller.state.authenticated, isFalse);
    expect(controller.state.errorKey, 'auth.invalidCredentials');
  });

  test('session loads again and logout clears it', () async {
    final controller = AuthSessionController();
    await controller.login('supervisor@test.jkdd', 'Test123!');

    final restored = AuthSessionController();
    await restored.load();

    expect(restored.state.user?.username, 'supervisor@test.jkdd');

    await restored.logout();
    final afterLogout = AuthSessionController();
    await afterLogout.load();

    expect(afterLogout.state.authenticated, isFalse);
  });
}
