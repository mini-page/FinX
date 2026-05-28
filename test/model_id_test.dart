import 'package:flutter_test/flutter_test.dart';
import 'package:xpens/features/expense/data/models/expense_model.dart';
import 'package:xpens/features/accounts/data/models/account_model.dart';
import 'package:xpens/features/recurring/data/models/recurring_subscription_model.dart';

void main() {
  group('Model ID Generation Tests', () {
    final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      caseSensitive: false,
    );

    test('ExpenseModel should generate a valid UUID v4', () {
      final expense = ExpenseModel.create(
        amount: 100.0,
        category: 'Food',
        date: DateTime.now(),
      );
      expect(expense.id, matches(uuidRegex));
    });

    test('AccountModel should generate a valid UUID v4', () {
      final account = AccountModel.create(
        name: 'Bank',
        iconKey: 'bank',
        balance: 1000.0,
      );
      expect(account.id, matches(uuidRegex));
    });

    test('RecurringSubscriptionModel should generate a valid UUID v4', () {
      final subscription = RecurringSubscriptionModel.create(
        name: 'Netflix',
        amount: 15.0,
        nextBillDate: DateTime.now(),
        iconKey: 'movie',
      );
      expect(subscription.id, matches(uuidRegex));
    });

    test('Each generated ID should be unique', () {
      final id1 = ExpenseModel.create(
        amount: 10.0,
        category: 'A',
        date: DateTime.now(),
      ).id;
      final id2 = ExpenseModel.create(
        amount: 10.0,
        category: 'A',
        date: DateTime.now(),
      ).id;
      expect(id1, isNot(equals(id2)));
    });
  });
}
