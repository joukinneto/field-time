import 'package:flutter_test/flutter_test.dart';
import 'package:jkdd_field_time_records_production/src/auth/auth_session.dart';
import 'package:jkdd_field_time_records_production/src/supervisor_center/supervisor_center_models.dart';

void main() {
  test('test session exposes authenticated collaborator without credentials', () {
    final controller = AuthSessionController.test(
      user: AuthSessionController.testWorker,
    );

    expect(controller.state.authenticated, isTrue);
    expect(controller.state.user?.name, 'Santana');
    expect(controller.state.user?.role, PilotRole.employee);
    expect(controller.state.user?.username, 'collaborator@test.jkdd');
  });

  test('test session can start signed out', () {
    final controller = AuthSessionController.test();

    expect(controller.state.loading, isFalse);
    expect(controller.state.authenticated, isFalse);
  });

  test('logout clears injected test session', () async {
    final controller = AuthSessionController.test(
      user: AuthSessionController.testWorker,
    );

    await controller.logout();

    expect(controller.state.authenticated, isFalse);
    expect(controller.state.errorKey, isNull);
  });
}
