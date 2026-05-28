import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:xpens/features/recurring/data/datasource/recurring_subscription_local_datasource.dart';
import 'package:xpens/features/recurring/data/models/recurring_subscription_model.dart';

// Manual Mock for Box
class MockBox<T> implements Box<T> {
  final Map<dynamic, T> _values = {};

  @override
  Iterable<T> get values => _values.values;

  @override
  Future<void> put(dynamic key, T value) async {
    _values[key] = value;
  }

  @override
  Future<void> delete(dynamic key) async {
    _values.remove(key);
  }

  // Add other necessary overrides with default implementations
  @override
  T? get(dynamic key, {T? defaultValue}) => _values[key] ?? defaultValue;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('RecurringSubscriptionLocalDatasource', () {
    late MockBox<RecurringSubscriptionModel> mockBox;
    late RecurringSubscriptionLocalDatasource datasource;

    setUp(() {
      mockBox = MockBox<RecurringSubscriptionModel>();
      datasource = RecurringSubscriptionLocalDatasource(mockBox);
    });

    test(
        'getAllSubscriptions should return sorted subscriptions by nextBillDate',
        () async {
      final sub1 = RecurringSubscriptionModel(
        id: '1',
        name: 'A',
        amount: 10,
        nextBillDate: DateTime(2023, 10, 20),
        iconKey: 'icon',
      );
      final sub2 = RecurringSubscriptionModel(
        id: '2',
        name: 'B',
        amount: 20,
        nextBillDate: DateTime(2023, 10, 10),
        iconKey: 'icon',
      );

      await datasource.saveSubscription(sub1);
      await datasource.saveSubscription(sub2);

      final result = await datasource.getAllSubscriptions();

      expect(result.length, 2);
      expect(result[0].id, '2'); // Earlier date first
      expect(result[1].id, '1');
    });

    test('saveSubscription should store subscription in box', () async {
      final sub = RecurringSubscriptionModel(
        id: '1',
        name: 'A',
        amount: 10,
        nextBillDate: DateTime(2023, 10, 20),
        iconKey: 'icon',
      );

      await datasource.saveSubscription(sub);

      expect(mockBox.get('1'), sub);
    });

    test('deleteSubscription should remove subscription from box', () async {
      final sub = RecurringSubscriptionModel(
        id: '1',
        name: 'A',
        amount: 10,
        nextBillDate: DateTime(2023, 10, 20),
        iconKey: 'icon',
      );

      await datasource.saveSubscription(sub);
      await datasource.deleteSubscription('1');

      expect(mockBox.get('1'), isNull);
    });
  });
}
