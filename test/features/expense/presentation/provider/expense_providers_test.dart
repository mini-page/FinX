import 'package:flutter_test/flutter_test.dart';
import 'package:expensio/features/expense/data/models/expense_model.dart';
import 'package:expensio/features/expense/presentation/provider/expense_providers.dart';

void main() {
  group('ExpenseStats.fromExpenses', () {
    test('should return all zeros and empty maps when given an empty list', () {
      final stats = ExpenseStats.fromExpenses([]);

      expect(stats.monthTotal, 0.0);
      expect(stats.monthIncomeTotal, 0.0);
      expect(stats.monthNetTotal, 0.0);
      expect(stats.todayTotal, 0.0);
      expect(stats.todayIncomeTotal, 0.0);
      expect(stats.transactionCount, 0);
      expect(stats.categoryTotals, <String, double>{});
      expect(stats.incomeCategoryTotals, <String, double>{});
    });

    test(
      'should correctly calculate totals for a non-empty list of expenses',
      () {
        final now = DateTime.now().toUtc();
        final today = DateTime(now.year, now.month, now.day, 12).toUtc();

        final expenses = [
          ExpenseModel.create(
            amount: 100.0,
            category: 'Food & Dining',
            date: today,
            type: TransactionType.expense,
          ),
          ExpenseModel.create(
            amount: 50.0,
            category: 'Food & Dining',
            date: today,
            type: TransactionType.expense,
          ),
          ExpenseModel.create(
            amount: 200.0,
            category: 'Transportation',
            date: today,
            type: TransactionType.expense,
          ),
          ExpenseModel.create(
            amount: 1000.0,
            category: 'Salary',
            date: today,
            type: TransactionType.income,
          ),
        ];

        final stats = ExpenseStats.fromExpenses(expenses);

        expect(stats.monthTotal, 350.0);
        expect(stats.monthIncomeTotal, 1000.0);
        expect(stats.monthNetTotal, 650.0); // 1000 - 350
        expect(stats.todayTotal, 350.0);
        expect(stats.todayIncomeTotal, 1000.0);
        expect(stats.transactionCount, 4);
        expect(stats.categoryTotals,
            {'Transportation': 200.0, 'Food & Dining': 150.0});
        expect(stats.incomeCategoryTotals, {'Salary': 1000.0});
      },
    );
  });
}
