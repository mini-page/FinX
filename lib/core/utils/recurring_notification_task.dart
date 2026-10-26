import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:expensio/features/recurring/data/datasource/recurring_subscription_local_datasource.dart';
import 'package:expensio/features/recurring/data/models/recurring_subscription_model.dart';
import 'package:expensio/features/settings/data/datasource/preferences_local_datasource.dart';
import 'package:expensio/features/settings/data/models/app_preferences_model.dart';

/// Task name registered with Workmanager.
const kRecurringCheckTask = 'recurring_due_check';

/// Minimum interval between the same subscription's notifications (24 h).
const _notifyInterval = Duration(hours: 24);

/// Runs in the background Isolate created by Workmanager.
///
/// Opens the subscriptions box, iterates active subscriptions,
/// fires a system notification for any that are due today or overdue
/// (and haven't been notified within the last 24 h).
Future<bool> runRecurringNotificationTask() async {
  try {
    await Hive.initFlutter();

    // Register adapters if not already registered in this isolate.
    if (!Hive.isAdapterRegistered(RecurringSubscriptionModelAdapter.typeIdValue)) {
      Hive.registerAdapter(RecurringSubscriptionModelAdapter());
    }
    if (!Hive.isAdapterRegistered(AppPreferencesModelAdapter.typeIdValue)) {
      Hive.registerAdapter(AppPreferencesModelAdapter());
    }

    final subBox = await Hive.openBox<RecurringSubscriptionModel>(
      RecurringSubscriptionLocalDatasource.boxName,
    );
    final prefBox = await Hive.openBox<AppPreferencesModel>(
      PreferencesLocalDatasource.boxName,
    );

    // If notifications are disabled in preferences, bail out.
    final prefs = prefBox.get(PreferencesLocalDatasource.boxName);
    final notificationsEnabled =
        prefs == null || prefs.notificationsEnabled;
    if (!notificationsEnabled) {
      await _closeBoxes([subBox, prefBox]);
      return true;
    }

    final plugin = FlutterLocalNotificationsPlugin();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await plugin.initialize(
      const InitializationSettings(android: androidInit),
    );

    // Ensure the recurring_due channel exists in this isolate too.
    await plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'recurring_due',
            'Upcoming Payments',
            description: 'Reminders for recurring subscriptions due soon',
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
          ),
        );

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Box to track last-notified timestamps per subscription id.
    // We reuse the preferences box key space with a prefix.
    final notifiedBox = await Hive.openBox<int>('_recurring_notified_ts');

    for (final sub in subBox.values) {
      if (!sub.isActive) continue;

      final dueDate = DateTime(
        sub.nextBillDate.year,
        sub.nextBillDate.month,
        sub.nextBillDate.day,
      );

      // Notify if due today, overdue, or within notifyDaysBefore window.
      final daysUntil = dueDate.difference(today).inDays;
      if (daysUntil > sub.notifyDaysBefore) continue;

      // Rate-limit: don't fire the same notification twice within 24 h.
      final lastNotifiedTs = notifiedBox.get(sub.id) ?? 0;
      final lastNotified =
          DateTime.fromMillisecondsSinceEpoch(lastNotifiedTs);
      if (now.difference(lastNotified) < _notifyInterval) continue;

      final title = _buildTitle(sub, daysUntil);
      final body = _buildBody(sub, daysUntil);

      await plugin.show(
        sub.id.hashCode,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'recurring_due',
            'Upcoming Payments',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            // Action buttons: Log Now / Skip
            actions: [
              AndroidNotificationAction(
                'action_log',
                'Log Now',
                showsUserInterface: true,
                cancelNotification: true,
              ),
              AndroidNotificationAction(
                'action_skip',
                'Skip',
                cancelNotification: true,
              ),
            ],
          ),
        ),
      );

      // Record that we notified this subscription now.
      await notifiedBox.put(sub.id, now.millisecondsSinceEpoch);
    }

    await _closeBoxes([subBox, prefBox, notifiedBox]);
    return true;
  } catch (_) {
    return false;
  }
}

String _buildTitle(RecurringSubscriptionModel sub, int daysUntil) {
  if (daysUntil < 0) return '⚠️ Overdue: ${sub.name}';
  if (daysUntil == 0) return '🔔 Due Today: ${sub.name}';
  if (daysUntil == 1) return '⏰ Due Tomorrow: ${sub.name}';
  return '📅 Due in $daysUntil days: ${sub.name}';
}

String _buildBody(RecurringSubscriptionModel sub, int daysUntil) {
  final amount = sub.amount.toStringAsFixed(0);
  final dateStr =
      '${sub.nextBillDate.day}/${sub.nextBillDate.month}/${sub.nextBillDate.year}';
  if (daysUntil < 0) {
    return '₹$amount was due on $dateStr. Tap to log it now.';
  }
  if (daysUntil == 0) {
    return '₹$amount is due today. Tap to log or skip.';
  }
  return '₹$amount is scheduled for $dateStr.';
}

Future<void> _closeBoxes(List<dynamic> boxes) async {
  for (final b in boxes) {
    try {
      if (b.isOpen == true) await (b as dynamic).close();
    } catch (_) {}
  }
}
