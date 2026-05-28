import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:xpens/features/recurring/data/models/recurring_subscription_model.dart';
import 'package:xpens/features/categories/presentation/provider/budget_providers.dart';
import 'expense_providers.dart';
import 'package:xpens/features/settings/presentation/provider/preferences_providers.dart';
import 'package:xpens/features/recurring/presentation/provider/recurring_subscription_providers.dart';

// ---------------------------------------------------------------------------
// Domain model
// ---------------------------------------------------------------------------

/// The category a notification belongs to.
enum AppNotificationType {
  /// Spending has reached or exceeded a budget threshold.
  budgetAlert,

  /// A recurring subscription is due within the next 7 days.
  recurringDue,

  /// A user-created reminder (future: user-scheduled reminders).
  reminder,
}

/// An immutable notification item derived from live app data.
class AppNotificationItem {
  const AppNotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.timestamp,
    this.isRead = false,
    this.metadata,
  });

  /// Stable ID used to track read / dismissed state.
  final String id;
  final AppNotificationType type;
  final String title;
  final String body;
  final DateTime timestamp;
  final bool isRead;

  /// Optional extra info (e.g. category name for budget alerts).
  final String? metadata;

  AppNotificationItem copyWith({bool? isRead}) {
    return AppNotificationItem(
      id: id,
      type: type,
      title: title,
      body: body,
      timestamp: timestamp,
      isRead: isRead ?? this.isRead,
      metadata: metadata,
    );
  }
}

// ---------------------------------------------------------------------------
// Raw notifications — derived from live providers (no read/dismiss state)
// ---------------------------------------------------------------------------

final _rawNotificationsProvider = Provider<List<AppNotificationItem>>((ref) {
  final stats = ref.watch(statsProvider);
  final budgets =
      ref.watch(budgetTargetsProvider).value ?? const <String, double>{};
  final subscriptions = ref.watch(recurringSubscriptionListProvider).value ??
      const <RecurringSubscriptionModel>[];
  final currencyFormat = ref.watch(currencyFormatProvider);

  final items = <AppNotificationItem>[];
  final now = DateTime.now();
  final today = DateUtils.dateOnly(now);

  // ── Budget alerts ───────────────────────────────────────────────────────
  for (final entry in budgets.entries) {
    final limit = entry.value;
    if (limit <= 0) continue;

    final spend = stats.categoryTotals[entry.key] ?? 0;
    if (spend <= 0) continue;

    final ratio = spend / limit;
    if (ratio < 0.8) continue;

    final isOver = ratio > 1.0;
    final percent = (ratio * 100).round();

    items.add(AppNotificationItem(
      id: 'budget_${entry.key.toLowerCase().replaceAll(' ', '_')}',
      type: AppNotificationType.budgetAlert,
      title: isOver
          ? '${entry.key} budget exceeded'
          : '${entry.key} budget at $percent%',
      body: isOver
          ? "You've exceeded your ${entry.key} budget by "
              '${currencyFormat.format(spend - limit)} this month.'
          : "You've used $percent% of your ${entry.key} "
              'budget (${currencyFormat.format(spend)} / '
              '${currencyFormat.format(limit)}).',
      timestamp: now,
      metadata: entry.key,
    ));
  }

  // ── Recurring payments due within 7 days ───────────────────────────────
  for (final sub in subscriptions) {
    if (!sub.isActive) continue;

    final daysUntilDue = sub.nextBillDate.difference(today).inDays;
    if (daysUntilDue < 0 || daysUntilDue > 7) continue;

    final dueLabel = daysUntilDue == 0
        ? 'today'
        : daysUntilDue == 1
            ? 'tomorrow'
            : 'in $daysUntilDue days';

    items.add(AppNotificationItem(
      id: 'recurring_${sub.id}',
      type: AppNotificationType.recurringDue,
      title: '${sub.name} due $dueLabel',
      body: '${currencyFormat.format(sub.amount)} will be charged on '
          '${DateFormat('MMM d').format(sub.nextBillDate)}.',
      timestamp: sub.nextBillDate,
      metadata: sub.id,
    ));
  }

  // Sort: budget alerts first (by category name), then recurring by due date.
  items.sort((a, b) {
    if (a.type.index != b.type.index) {
      return a.type.index.compareTo(b.type.index);
    }
    return a.timestamp.compareTo(b.timestamp);
  });

  return items;
});

// ---------------------------------------------------------------------------
// Mutable state — which items have been read / dismissed this session
// ---------------------------------------------------------------------------

class _NotifInteractionState {
  const _NotifInteractionState({
    this.readIds = const <String>{},
    this.dismissedIds = const <String>{},
  });

  final Set<String> readIds;
  final Set<String> dismissedIds;

  _NotifInteractionState copyWith({
    Set<String>? readIds,
    Set<String>? dismissedIds,
  }) {
    return _NotifInteractionState(
      readIds: readIds ?? this.readIds,
      dismissedIds: dismissedIds ?? this.dismissedIds,
    );
  }
}

class _NotifInteractionNotifier extends Notifier<_NotifInteractionState> {
  @override
  _NotifInteractionState build() => const _NotifInteractionState();

  void markRead(String id) {
    state = state.copyWith(readIds: {...state.readIds, id});
  }

  void markAllRead(List<String> ids) {
    state = state.copyWith(readIds: {...state.readIds, ...ids});
  }

  void dismiss(String id) {
    state = state.copyWith(
      dismissedIds: {...state.dismissedIds, id},
      readIds: {...state.readIds, id},
    );
  }

  void dismissAll(List<String> ids) {
    state = state.copyWith(
      dismissedIds: {...state.dismissedIds, ...ids},
      readIds: {...state.readIds, ...ids},
    );
  }
}

final _notifInteractionProvider =
    NotifierProvider<_NotifInteractionNotifier, _NotifInteractionState>(
  _NotifInteractionNotifier.new,
);

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// The combined list of notification items with read/dismissed state applied.
final notificationsProvider = Provider<List<AppNotificationItem>>((ref) {
  final raw = ref.watch(_rawNotificationsProvider);
  final interactions = ref.watch(_notifInteractionProvider);

  return raw
      .where((item) => !interactions.dismissedIds.contains(item.id))
      .map((item) =>
          item.copyWith(isRead: interactions.readIds.contains(item.id)))
      .toList(growable: false);
});

/// Number of unread (non-dismissed) notifications — drives the bell badge.
final unreadNotificationCountProvider = Provider<int>((ref) {
  return ref.watch(notificationsProvider).where((n) => !n.isRead).length;
});

/// Controller that exposes mutation operations to the UI.
class NotificationsController {
  const NotificationsController(this._ref);

  final Ref _ref;

  void markRead(String id) =>
      _ref.read(_notifInteractionProvider.notifier).markRead(id);

  void markAllRead() {
    final ids = _ref
        .read(notificationsProvider)
        .map((n) => n.id)
        .toList(growable: false);
    _ref.read(_notifInteractionProvider.notifier).markAllRead(ids);
  }

  void dismiss(String id) =>
      _ref.read(_notifInteractionProvider.notifier).dismiss(id);

  void clearAll() {
    final ids = _ref
        .read(notificationsProvider)
        .map((n) => n.id)
        .toList(growable: false);
    _ref.read(_notifInteractionProvider.notifier).dismissAll(ids);
  }
}

final notificationsControllerProvider = Provider<NotificationsController>(
  (ref) => NotificationsController(ref),
);
