// ignore_for_file: avoid_print
import 'package:expensio/features/expense/presentation/provider/expense_providers.dart';
import 'package:expensio/features/expense/data/models/expense_model.dart';
import 'package:uuid/uuid.dart';

void main() {
  final now = DateTime.now();
  final expenses = <ExpenseModel>[];

  // Generate 100,000 expenses
  for (int i = 0; i < 100000; i++) {
    expenses.add(ExpenseModel(
      id: Uuid().v4(),
      amount: (i % 100) + 1.0,
      category: 'Category ${i % 10}',
      date: i % 2 == 0
          ? now
          : now.subtract(Duration(days: 30)), // Half in this month, half not
      note: 'Note $i',
      type: i % 3 == 0
          ? TransactionType.income
          : TransactionType.expense, // Mix of income and expense
    ));
  }

  print('Generated ${expenses.length} expenses. Running benchmark...');

  // Warmup
  for (int i = 0; i < 10; i++) {
    ExpenseStats.fromExpenses(expenses);
  }

  // Benchmark
  final stopwatch = Stopwatch()..start();
  final iterations = 100;
  for (int i = 0; i < iterations; i++) {
    ExpenseStats.fromExpenses(expenses);
  }
  stopwatch.stop();

  print(
      'Average time per run: ${stopwatch.elapsedMilliseconds / iterations} ms');
}
