import 'package:flutter_test/flutter_test.dart';
import 'package:xpens/features/categories/data/models/budget_model.dart';

void main() {
  group('BudgetModel', () {
    test('creates successfully with valid parameters', () {
      final budget = BudgetModel(category: 'Groceries', monthlyLimit: 500.0);
      expect(budget.category, 'Groceries');
      expect(budget.monthlyLimit, 500.0);
    });

    test('throws ArgumentError when category is empty', () {
      expect(
        () => BudgetModel(category: '', monthlyLimit: 500.0),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          'Budget category cannot be empty.',
        )),
      );
    });

    test('throws ArgumentError when category is only whitespace', () {
      expect(
        () => BudgetModel(category: '   ', monthlyLimit: 500.0),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          'Budget category cannot be empty.',
        )),
      );
    });

    test('throws ArgumentError when monthlyLimit is negative', () {
      expect(
        () => BudgetModel(category: 'Groceries', monthlyLimit: -100.0),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          'Budget amount cannot be negative.',
        )),
      );
    });
  });
}
