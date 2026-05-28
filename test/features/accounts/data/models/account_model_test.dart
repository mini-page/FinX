import 'package:flutter_test/flutter_test.dart';
import 'package:xpens/features/accounts/data/models/account_model.dart';

void main() {
  group('AccountModel Validation', () {
    test('throws ArgumentError when id is empty', () {
      expect(
        () => AccountModel(id: '', name: 'Bank', iconKey: 'bank', balance: 0),
        throwsA(isA<ArgumentError>().having(
            (e) => e.message, 'message', 'Account id cannot be empty.')),
      );
    });

    test('throws ArgumentError when name is empty string', () {
      expect(
        () => AccountModel(id: '123', name: '', iconKey: 'bank', balance: 0),
        throwsA(isA<ArgumentError>().having(
            (e) => e.message, 'message', 'Account name cannot be empty.')),
      );
    });

    test('throws ArgumentError when name is whitespace only', () {
      expect(
        () => AccountModel(id: '123', name: '   ', iconKey: 'bank', balance: 0),
        throwsA(isA<ArgumentError>().having(
            (e) => e.message, 'message', 'Account name cannot be empty.')),
      );
    });

    test('create throws ArgumentError when name is empty string', () {
      expect(
        () => AccountModel.create(name: '', iconKey: 'bank', balance: 0),
        throwsA(isA<ArgumentError>().having(
            (e) => e.message, 'message', 'Account name cannot be empty.')),
      );
    });

    test('creates AccountModel successfully with valid name', () {
      final account = AccountModel(
          id: '123', name: 'Checking', iconKey: 'bank', balance: 100);
      expect(account.id, '123');
      expect(account.name, 'Checking');
      expect(account.iconKey, 'bank');
      expect(account.balance, 100);
    });

    test('creates AccountModel successfully with valid name via create', () {
      final account = AccountModel.create(
          name: ' Savings ', iconKey: 'wallet', balance: 50);
      expect(account.id, isNotEmpty);
      expect(account.name, 'Savings'); // Should be trimmed
      expect(account.iconKey, 'wallet');
      expect(account.balance, 50);
    });

    group('copyWith', () {
      final baseAccount = AccountModel(
        id: 'base-id',
        name: 'Base Account',
        iconKey: 'wallet',
        balance: 0.0,
      );

      test('updates specified fields', () {
        final updatedAccount = baseAccount.copyWith(
          name: 'Updated Account',
          balance: 150.0,
        );

        expect(updatedAccount.id, 'base-id'); // Unchanged
        expect(updatedAccount.iconKey, 'wallet'); // Unchanged
        expect(updatedAccount.name, 'Updated Account'); // Changed
        expect(updatedAccount.balance, 150.0); // Changed
      });

      test('throws ArgumentError if updated name is empty', () {
        expect(
          () => baseAccount.copyWith(name: '  '),
          throwsA(isA<ArgumentError>()),
        );
      });
    });
  });
}
