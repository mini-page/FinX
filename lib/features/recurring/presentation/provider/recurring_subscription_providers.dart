import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasource/recurring_subscription_local_datasource.dart';
import '../../data/models/recurring_subscription_model.dart';
import '../../data/repositories/hive_recurring_subscription_repository.dart';
import '../../domain/repositories/recurring_subscription_repository.dart';

final List<RecurringSeed> defaultSubscriptions = <RecurringSeed>[
  RecurringSeed(
    name: 'Netflix',
    amount: 499,
    iconKey: 'tv',
    nextBillDate: DateTime.utc(2026, 4, 25),
  ),
  RecurringSeed(
    name: 'Spotify',
    amount: 119,
    iconKey: 'music',
    nextBillDate: DateTime.utc(2026, 4, 1),
  ),
  RecurringSeed(
    name: 'YouTube',
    amount: 129,
    iconKey: 'video',
    nextBillDate: DateTime.utc(2026, 4, 8),
  ),
];

final recurringSubscriptionLocalDatasourceProvider =
    Provider<RecurringSubscriptionLocalDatasource>((ref) {
  return RecurringSubscriptionLocalDatasource();
});

final recurringSubscriptionRepositoryProvider =
    Provider<RecurringSubscriptionRepository>((ref) {
  return HiveRecurringSubscriptionRepository(
    ref.watch(recurringSubscriptionLocalDatasourceProvider),
  );
});

final recurringSubscriptionListProvider = AsyncNotifierProvider<
    RecurringSubscriptionListNotifier,
    List<RecurringSubscriptionModel>>(RecurringSubscriptionListNotifier.new);

final recurringSubscriptionControllerProvider =
    Provider<RecurringSubscriptionController>((ref) {
  return RecurringSubscriptionController(ref);
});

class RecurringSubscriptionListNotifier
    extends AsyncNotifier<List<RecurringSubscriptionModel>> {
  RecurringSubscriptionRepository get _repository =>
      ref.read(recurringSubscriptionRepositoryProvider);

  @override
  Future<List<RecurringSubscriptionModel>> build() async {
    try {
      final subscriptions = await _repository.getAllSubscriptions();
      if (subscriptions.isNotEmpty) {
        return subscriptions;
      }

      final seeded = defaultSubscriptions
          .map(
            (seed) => RecurringSubscriptionModel.create(
              name: seed.name,
              amount: seed.amount,
              nextBillDate: seed.nextBillDate,
              iconKey: seed.iconKey,
            ),
          )
          .toList(growable: false);

      for (final subscription in seeded) {
        await _repository.saveSubscription(subscription);
      }

      return seeded;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        dev.log(
          'Failed to fetch or seed subscriptions',
          error: e,
          stackTrace: stackTrace,
          name: 'RecurringSubscriptionListNotifier',
        );
      }
      return defaultSubscriptions
          .map(
            (seed) => RecurringSubscriptionModel.create(
              name: seed.name,
              amount: seed.amount,
              nextBillDate: seed.nextBillDate,
              iconKey: seed.iconKey,
            ),
          )
          .toList(growable: false);
    }
  }

  Future<void> saveSubscription(RecurringSubscriptionModel subscription) async {
    final currentSubscriptions =
        state.value ?? const <RecurringSubscriptionModel>[];
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repository.saveSubscription(subscription);
      final updated = <RecurringSubscriptionModel>[
        for (final item in currentSubscriptions)
          if (item.id != subscription.id) item,
        subscription,
      ]..sort((left, right) => left.nextBillDate.compareTo(right.nextBillDate));
      return updated;
    });
  }

  Future<void> deleteSubscription(String id) async {
    final currentSubscriptions =
        state.value ?? const <RecurringSubscriptionModel>[];
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repository.deleteSubscription(id);
      return currentSubscriptions
          .where((subscription) => subscription.id != id)
          .toList(growable: false);
    });
  }
}

class RecurringSubscriptionController {
  RecurringSubscriptionController(this._ref);

  final Ref _ref;

  Future<void> saveSubscription({
    String? id,
    required String name,
    required double amount,
    required DateTime nextBillDate,
    required String iconKey,
    String note = '',
    bool isActive = true,
  }) async {
    final subscription = id == null
        ? RecurringSubscriptionModel.create(
            name: name,
            amount: amount,
            nextBillDate: nextBillDate,
            iconKey: iconKey,
            note: note,
            isActive: isActive,
          )
        : RecurringSubscriptionModel(
            id: id,
            name: name,
            amount: amount,
            nextBillDate: nextBillDate,
            iconKey: iconKey,
            note: note,
            isActive: isActive,
          );

    await ref
        .read(recurringSubscriptionListProvider.notifier)
        .saveSubscription(subscription);
  }

  Ref get ref => _ref;

  Future<void> deleteSubscription(String id) async {
    await ref
        .read(recurringSubscriptionListProvider.notifier)
        .deleteSubscription(id);
  }
}

class RecurringSeed {
  const RecurringSeed({
    required this.name,
    required this.amount,
    required this.iconKey,
    required this.nextBillDate,
  });

  final String name;
  final double amount;
  final String iconKey;
  final DateTime nextBillDate;
}
