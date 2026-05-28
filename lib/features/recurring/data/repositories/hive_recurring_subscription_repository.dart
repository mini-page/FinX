import '../../domain/repositories/recurring_subscription_repository.dart';
import '../datasource/recurring_subscription_local_datasource.dart';
import '../models/recurring_subscription_model.dart';

class HiveRecurringSubscriptionRepository
    implements RecurringSubscriptionRepository {
  HiveRecurringSubscriptionRepository(this._localDatasource);

  final RecurringSubscriptionLocalDatasource _localDatasource;

  @override
  Future<void> deleteSubscription(String id) {
    return _localDatasource.deleteSubscription(id);
  }

  @override
  Future<List<RecurringSubscriptionModel>> getAllSubscriptions() {
    return _localDatasource.getAllSubscriptions();
  }

  @override
  Future<void> saveSubscription(RecurringSubscriptionModel subscription) {
    return _localDatasource.saveSubscription(subscription);
  }
}
