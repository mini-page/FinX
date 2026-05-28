import '../../data/models/recurring_subscription_model.dart';

abstract class RecurringSubscriptionRepository {
  Future<List<RecurringSubscriptionModel>> getAllSubscriptions();
  Future<void> saveSubscription(RecurringSubscriptionModel subscription);
  Future<void> deleteSubscription(String id);
}
