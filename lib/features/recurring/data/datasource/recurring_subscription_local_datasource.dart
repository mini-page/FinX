import 'package:hive/hive.dart';

import '../models/recurring_subscription_model.dart';

class RecurringSubscriptionLocalDatasource {
  static const String boxName = 'subscriptions';

  final Box<RecurringSubscriptionModel>? _injectedBox;

  RecurringSubscriptionLocalDatasource([this._injectedBox]);

  Box<RecurringSubscriptionModel> get _box =>
      _injectedBox ?? Hive.box<RecurringSubscriptionModel>(boxName);

  Future<List<RecurringSubscriptionModel>> getAllSubscriptions() async {
    final subscriptions = _box.values.toList(growable: false)
      ..sort((left, right) => left.nextBillDate.compareTo(right.nextBillDate));
    return subscriptions;
  }

  Future<void> saveSubscription(RecurringSubscriptionModel subscription) async {
    await _box.put(subscription.id, subscription);
  }

  Future<void> deleteSubscription(String id) async {
    await _box.delete(id);
  }
}
