import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasource/recurring_subscription_local_datasource.dart';
import '../../data/models/recurring_subscription_model.dart';
import '../../data/repositories/hive_recurring_subscription_repository.dart';
import '../../domain/repositories/recurring_subscription_repository.dart';

final List<RecurringSeed> defaultSubscriptions = <RecurringSeed>[];

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
      
      // Purge legacy dummy seeds if present
      final cleaned = <RecurringSubscriptionModel>[];
      for (final s in subscriptions) {
        final isLegacySeed = (s.name == 'Netflix' && s.amount == 499) ||
            (s.name == 'Spotify' && s.amount == 119) ||
            (s.name == 'YouTube' && s.amount == 129);
        if (isLegacySeed) {
          await _repository.deleteSubscription(s.id);
        } else {
          cleaned.add(s);
        }
      }
      return cleaned;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        dev.log(
          'Failed to fetch subscriptions',
          error: e,
          stackTrace: stackTrace,
          name: 'RecurringSubscriptionListNotifier',
        );
      }
      return const <RecurringSubscriptionModel>[];
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
    String billingPeriod = '1:month',
    String category = '',
    DateTime? lastPaymentDate,
    List<double>? priceHistory,
    int notifyDaysBefore = 7,
    String? cancellationNote,
    DateTime? cancelledAt,
  }) async {
    final subscription = id == null
        ? RecurringSubscriptionModel.create(
            name: name,
            amount: amount,
            nextBillDate: nextBillDate,
            iconKey: iconKey,
            note: note,
            isActive: isActive,
            billingPeriod: billingPeriod,
            category: category,
            lastPaymentDate: lastPaymentDate,
            priceHistory: priceHistory ?? const [],
            notifyDaysBefore: notifyDaysBefore,
            cancellationNote: cancellationNote,
            cancelledAt: cancelledAt,
          )
        : RecurringSubscriptionModel(
            id: id,
            name: name,
            amount: amount,
            nextBillDate: nextBillDate,
            iconKey: iconKey,
            note: note,
            isActive: isActive,
            billingPeriod: billingPeriod,
            category: category,
            lastPaymentDate: lastPaymentDate,
            priceHistory: priceHistory ?? const [],
            notifyDaysBefore: notifyDaysBefore,
            cancellationNote: cancellationNote,
            cancelledAt: cancelledAt,
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
