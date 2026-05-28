import 'package:flutter_test/flutter_test.dart';
import 'package:xpens/features/recurring/data/models/recurring_subscription_model.dart';

void main() {
  group('RecurringSubscriptionModel', () {
    final DateTime mockDate = DateTime(2023, 10, 15);

    test('should create a valid model successfully', () {
      final model = RecurringSubscriptionModel(
        id: 'sub-123',
        name: 'Netflix',
        amount: 15.99,
        nextBillDate: mockDate,
        iconKey: 'netflix-icon',
      );

      expect(model.id, 'sub-123');
      expect(model.name, 'Netflix');
      expect(model.amount, 15.99);
      expect(model.nextBillDate, DateTime(2023, 10, 15));
      expect(model.iconKey, 'netflix-icon');
      expect(model.note, '');
      expect(model.isActive, true);
    });

    group('amount validation', () {
      test('should throw ArgumentError when amount is zero', () {
        expect(
          () => RecurringSubscriptionModel(
            id: 'sub-123',
            name: 'Netflix',
            amount: 0.0,
            nextBillDate: mockDate,
            iconKey: 'netflix-icon',
          ),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              'Subscription amount must be positive.',
            ),
          ),
        );
      });

      test('should throw ArgumentError when amount is negative', () {
        expect(
          () => RecurringSubscriptionModel(
            id: 'sub-123',
            name: 'Netflix',
            amount: -15.99,
            nextBillDate: mockDate,
            iconKey: 'netflix-icon',
          ),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              'Subscription amount must be positive.',
            ),
          ),
        );
      });
    });

    group('id validation', () {
      test('should throw ArgumentError when id is empty', () {
        expect(
          () => RecurringSubscriptionModel(
            id: '',
            name: 'Netflix',
            amount: 15.99,
            nextBillDate: mockDate,
            iconKey: 'netflix-icon',
          ),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              'Subscription id cannot be empty.',
            ),
          ),
        );
      });
    });

    group('name validation', () {
      test('should throw ArgumentError when name is empty', () {
        expect(
          () => RecurringSubscriptionModel(
            id: 'sub-123',
            name: '',
            amount: 15.99,
            nextBillDate: mockDate,
            iconKey: 'netflix-icon',
          ),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              'Subscription name cannot be empty.',
            ),
          ),
        );
      });

      test('should throw ArgumentError when name contains only whitespace', () {
        expect(
          () => RecurringSubscriptionModel(
            id: 'sub-123',
            name: '   ',
            amount: 15.99,
            nextBillDate: mockDate,
            iconKey: 'netflix-icon',
          ),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              'Subscription name cannot be empty.',
            ),
          ),
        );
      });
    });

    group('factory create', () {
      test('should create model with generated id and trimmed properties', () {
        final model = RecurringSubscriptionModel.create(
          name: '  Spotify  ',
          amount: 9.99,
          nextBillDate: mockDate,
          iconKey: 'spotify-icon',
          note: '  Family Plan  ',
        );

        expect(model.id, isNotEmpty);
        expect(model.name, 'Spotify');
        expect(model.amount, 9.99);
        expect(model.nextBillDate, DateTime(2023, 10, 15));
        expect(model.iconKey, 'spotify-icon');
        expect(model.note, 'Family Plan');
        expect(model.isActive, true);
      });
    });

    group('copyWith', () {
      test('should correctly update properties', () {
        final original = RecurringSubscriptionModel(
          id: 'sub-123',
          name: 'Netflix',
          amount: 15.99,
          nextBillDate: mockDate,
          iconKey: 'netflix-icon',
        );

        final newDate = DateTime(2024, 1, 1);
        final updated = original.copyWith(
          name: 'Netflix Premium',
          amount: 19.99,
          nextBillDate: newDate,
          isActive: false,
        );

        expect(updated.id, 'sub-123'); // Unchanged
        expect(updated.name, 'Netflix Premium'); // Changed
        expect(updated.amount, 19.99); // Changed
        expect(updated.nextBillDate, DateTime(2024, 1, 1)); // Changed
        expect(updated.iconKey, 'netflix-icon'); // Unchanged
        expect(updated.note, ''); // Unchanged
        expect(updated.isActive, false); // Changed
      });
    });
  });
}
