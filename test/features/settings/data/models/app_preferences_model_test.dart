import 'package:flutter_test/flutter_test.dart';
import 'package:xpens/features/settings/data/models/app_preferences_model.dart';

void main() {
  group('AppPreferencesModel', () {
    test('defaults start with all management toggles enabled', () {
      expect(
        AppPreferencesModel.defaults.disabledExpenseCategories,
        isEmpty,
      );
      expect(
        AppPreferencesModel.defaults.disabledIncomeCategories,
        isEmpty,
      );
      expect(
        AppPreferencesModel.defaults.disabledAccountIds,
        isEmpty,
      );
    });

    test('copyWith updates disabled category and account lists', () {
      final updated = AppPreferencesModel.defaults.copyWith(
        disabledExpenseCategories: const <String>['Travel'],
        disabledIncomeCategories: const <String>['Salary'],
        disabledAccountIds: const <String>['acc-1'],
      );

      expect(updated.disabledExpenseCategories, const <String>['Travel']);
      expect(updated.disabledIncomeCategories, const <String>['Salary']);
      expect(updated.disabledAccountIds, const <String>['acc-1']);
    });
  });
}
