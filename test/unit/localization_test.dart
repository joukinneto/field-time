import 'package:flutter_test/flutter_test.dart';
import 'package:jkdd_field_time_records_production/time_records.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('supports English Portuguese and Spanish translations', () {
    expect(const AppStrings(AppLanguage.en).t('approval.approve'), 'Approve');
    expect(const AppStrings(AppLanguage.pt).t('approval.approve'), 'Aprovar');
    expect(const AppStrings(AppLanguage.es).t('approval.approve'), 'Aprobar');
  });

  test('fallback uses default language and never exposes empty technical key',
      () {
    expect(const AppStrings(AppLanguage.pt).t('missingExampleKey'),
        'Missing Example Key');
    expect(const AppStrings(AppLanguage.es).t('timesheet.generatePdf'),
        'Generar PDF');
  });

  test('language preference persists locally', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = AppLanguageController();

    await controller.setLanguage(AppLanguage.es);

    final restored = AppLanguageController();
    await restored.load();
    expect(restored.state, AppLanguage.es);
  });
}
