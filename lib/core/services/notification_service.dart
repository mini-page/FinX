import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Singleton service that bridges in-app [AppNotificationItem]s to the
/// device's system notification tray via `flutter_local_notifications`.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  late final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  // ------------------------------------------------------------------
  // Initialization
  // ------------------------------------------------------------------

  /// Call once during app startup (after `WidgetsFlutterBinding`).
  Future<void> initialize() async {
    if (_initialized) return;

    _plugin = FlutterLocalNotificationsPlugin();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create channels
    await _createChannels();

    _initialized = true;
  }

  Future<void> _createChannels() async {
    await _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(
      const AndroidNotificationChannel(
        'budget_alerts',
        'Budget Alerts',
        description: 'Notifications when spending reaches budget thresholds',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );

    await _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(
      const AndroidNotificationChannel(
        'recurring_due',
        'Upcoming Payments',
        description: 'Reminders for recurring subscriptions due soon',
        importance: Importance.defaultImportance,
        playSound: true,
      ),
    );
  }

  // ------------------------------------------------------------------
  // Notification tap handler
  // ------------------------------------------------------------------

  void _onNotificationTap(NotificationResponse response) {
    // Deep-link handling can be added here.
    // For now, tapping a notification simply opens the app.
  }

  // ------------------------------------------------------------------
  // Public API
  // ------------------------------------------------------------------

  /// Shows a local notification in the system tray.
  Future<void> showNotification({
    required String id,
    required String title,
    required String body,
    String? channelId,
  }) async {
    if (!_initialized) return;

    final resolvedChannelId = channelId ?? 'budget_alerts';

    await _plugin.show(
      id.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          resolvedChannelId,
          resolvedChannelId == 'budget_alerts'
              ? 'Budget Alerts'
              : 'Upcoming Payments',
          importance: resolvedChannelId == 'budget_alerts'
              ? Importance.high
              : Importance.defaultImportance,
          priority: resolvedChannelId == 'budget_alerts'
              ? Priority.high
              : Priority.defaultPriority,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  /// Cancels a specific notification by its ID.
  Future<void> cancel(String id) async {
    if (!_initialized) return;
    await _plugin.cancel(id.hashCode);
  }

  /// Cancels all notifications from the system tray.
  Future<void> cancelAll() async {
    if (!_initialized) return;
    await _plugin.cancelAll();
  }
}
