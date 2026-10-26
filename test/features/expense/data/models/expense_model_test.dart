import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:expensio/features/expense/data/models/expense_model.dart';

void main() {
  group('ExpenseModel', () {
    final validId = const Uuid().v4();
    const validAmount = 100.0;
    const validCategory = 'Food';
    final validDate = DateTime.now();

    test('should create a valid ExpenseModel', () {
      final expense = ExpenseModel(
        id: validId,
        amount: validAmount,
        category: validCategory,
        date: validDate,
        note: 'Lunch',
      );

      expect(expense.id, validId);
      expect(expense.amount, validAmount);
      expect(expense.category, validCategory);
      expect(expense.date, validDate.toUtc());
      expect(expense.note, 'Lunch');
      expect(expense.type, TransactionType.expense);
    });

    group('Constructor Validations', () {
      test('should throw ArgumentError when id is empty', () {
        expect(
          () => ExpenseModel(
            id: '',
            amount: 100.0,
            category: 'Salary',
            date: DateTime(2023),
            note: '',
          ),
          throwsA(isA<ArgumentError>().having(
              (e) => e.message, 'message', 'Expense id cannot be empty.')),
        );
      });

      test('should throw ArgumentError when amount is zero or negative', () {
        expect(
          () => ExpenseModel(
            id: 'test-id',
            amount: 0.0,
            category: 'Salary',
            date: DateTime(2023),
            note: '',
          ),
          throwsA(isA<ArgumentError>().having(
              (e) => e.message, 'message', 'Expense amount must be positive.')),
        );

        expect(
          () => ExpenseModel(
            id: 'test-id',
            amount: -10.0,
            category: 'Salary',
            date: DateTime(2023),
            note: '',
          ),
          throwsA(isA<ArgumentError>().having(
              (e) => e.message, 'message', 'Expense amount must be positive.')),
        );
      });

      test(
          'should throw ArgumentError when category is empty or only whitespace',
          () {
        expect(
          () => ExpenseModel(
            id: 'test-id',
            amount: 100.0,
            category: '',
            date: DateTime(2023),
            note: '',
          ),
          throwsA(isA<ArgumentError>().having((e) => e.message, 'message',
              'Expense category cannot be empty.')),
        );

        expect(
          () => ExpenseModel(
            id: 'test-id',
            amount: 100.0,
            category: '   ',
            date: DateTime(2023),
            note: '',
          ),
          throwsA(isA<ArgumentError>().having((e) => e.message, 'message',
              'Expense category cannot be empty.')),
        );
      });

      test('should convert date to UTC', () {
        final localDate = DateTime(2023, 1, 1, 12, 0, 0); // Local time
        final model = ExpenseModel(
          id: 'test-id',
          amount: 100.0,
          category: 'Salary',
          date: localDate,
          note: '',
        );

        expect(model.date.isUtc, isTrue);
        expect(model.date, localDate.toUtc());
      });
      group('Getters: signedAmount and isIncome', () {
        test('should return positive amount and true for income', () {
          final model = ExpenseModel(
            id: 'test-id',
            amount: 100.0,
            category: 'Salary',
            date: DateTime(2023),
            note: '',
            type: TransactionType.income,
          );

          expect(model.signedAmount, 100.0);
          expect(model.isIncome, isTrue);
        });

        test('should return negative amount and false for expense', () {
          final model = ExpenseModel(
            id: 'test-id',
            amount: 50.0,
            category: 'Food',
            date: DateTime(2023),
            note: '',
            type: TransactionType.expense,
          );

          expect(model.signedAmount, -50.0);
          expect(model.isIncome, isFalse);
        });
      });
    });

    group('Factory: create', () {
      test('should generate UUID and trim fields', () {
        final date = DateTime(2023);
        final model = ExpenseModel.create(
          amount: 100.0,
          category: '  Salary  ',
          date: date,
          note: '  Bonus  ',
          accountId: '  acc-123  ',
        );

        expect(model.id, isNotEmpty);
        expect(model.category, 'Salary');
        expect(model.note, 'Bonus');
        expect(model.accountId, 'acc-123');
        expect(model.type, TransactionType.expense); // default
      });

      test('should set accountId to null if it is empty or whitespace', () {
        final date = DateTime(2023);

        final model1 = ExpenseModel.create(
          amount: 100.0,
          category: 'Salary',
          date: date,
          accountId: '',
        );
        expect(model1.accountId, isNull);

        final model2 = ExpenseModel.create(
          amount: 100.0,
          category: 'Salary',
          date: date,
          accountId: '   ',
        );
        expect(model2.accountId, isNull);
      });
    });

    group('copyWith', () {
      test('should return a new instance with updated values', () {
        final original = ExpenseModel(
          id: 'test-id',
          amount: 100.0,
          category: 'Salary',
          date: DateTime.utc(2023),
          note: 'Initial note',
          type: TransactionType.income,
          accountId: 'acc-1',
        );

        final newDate = DateTime.utc(2024);
        final updated = original.copyWith(
          amount: 200.0,
          category: 'Bonus',
          date: newDate,
          note: 'Updated note',
          type: TransactionType.expense,
        );

        expect(updated.id, original.id); // unchanged
        expect(updated.amount, 200.0);
        expect(updated.category, 'Bonus');
        expect(updated.date, newDate);
        expect(updated.note, 'Updated note');
        expect(updated.type, TransactionType.expense);
        expect(updated.accountId, 'acc-1'); // unchanged
      });

      test('should clear accountId when clearAccountId is true', () {
        final original = ExpenseModel(
          id: 'test-id',
          amount: 100.0,
          category: 'Salary',
          date: DateTime.utc(2023),
          note: '',
          accountId: 'acc-1',
        );

        final updated = original.copyWith(clearAccountId: true);

        expect(updated.accountId, isNull);
      });
    });
  });
}
