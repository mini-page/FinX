import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/widgets/app_page_header.dart';
import '../provider/notifications_provider.dart';

/// Production-ready Notifications screen.
///
/// Shows alerts derived from real app data (budget overruns, upcoming
/// recurring payments).  No dummy data — the screen shows an empty state
/// when there is nothing to report.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    final controller = ref.read(notificationsControllerProvider);
    final unreadCount = notifications.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: GradientAppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Notifications',
              style: TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.w900,
                fontSize: 18,
                letterSpacing: -0.5,
              ),
            ),
            if (unreadCount > 0)
              Text(
                '$unreadCount unread',
                style: const TextStyle(
                  color: AppColors.primaryBlue,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
        actions: <Widget>[
          if (notifications.isNotEmpty) ...<Widget>[
            if (unreadCount > 0)
              TextButton(
                onPressed: () {
                  controller.markAllRead();
                },
                child: const Text(
                  'Mark all read',
                  style: TextStyle(
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            IconButton(
              tooltip: 'Clear all',
              icon: const Icon(
                Icons.delete_sweep_rounded,
                color: AppColors.textSecondary,
              ),
              onPressed: () => _confirmClearAll(context, controller),
            ),
          ],
        ],
      ),
      body: notifications.isEmpty
          ? const _EmptyState()
          : _NotificationList(
              notifications: notifications, controller: controller),
    );
  }

  Future<void> _confirmClearAll(
    BuildContext context,
    NotificationsController controller,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl),
        ),
        title: const Text(
          'Clear all notifications?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'All notifications will be removed. They will reappear automatically if the underlying conditions persist.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      controller.clearAll();
    }
  }
}

// ---------------------------------------------------------------------------
// Notification list — grouped by type with swipe-to-dismiss
// ---------------------------------------------------------------------------

class _NotificationList extends StatelessWidget {
  const _NotificationList({
    required this.notifications,
    required this.controller,
  });

  final List<AppNotificationItem> notifications;
  final NotificationsController controller;

  @override
  Widget build(BuildContext context) {
    final groups = <AppNotificationType, List<AppNotificationItem>>{};
    for (final item in notifications) {
      groups.putIfAbsent(item.type, () => <AppNotificationItem>[]).add(item);
    }

    final sections = <Widget>[];
    final orderedTypes = AppNotificationType.values;

    for (final type in orderedTypes) {
      final items = groups[type];
      if (items == null || items.isEmpty) continue;

      sections.add(_SectionHeader(type: type));
      for (final item in items) {
        sections.add(
          _NotificationTile(
            key: ValueKey<String>(item.id),
            item: item,
            onTap: () => controller.markRead(item.id),
            onDismiss: () => controller.dismiss(item.id),
          ),
        );
      }
      sections.add(const SizedBox(height: 8));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      children: sections,
    );
  }
}

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.type});

  final AppNotificationType type;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Text(
        _labelFor(type).toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.textMuted,
          letterSpacing: 1.4,
        ),
      ),
    );
  }

  String _labelFor(AppNotificationType type) {
    switch (type) {
      case AppNotificationType.budgetAlert:
        return 'Budget alerts';
      case AppNotificationType.recurringDue:
        return 'Upcoming payments';
      case AppNotificationType.reminder:
        return 'Reminders';
    }
  }
}

// ---------------------------------------------------------------------------
// Individual notification tile
// ---------------------------------------------------------------------------

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    super.key,
    required this.item,
    required this.onTap,
    required this.onDismiss,
  });

  final AppNotificationItem item;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey<String>('dismissible_${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.danger.withAlpha(20),
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: AppColors.danger,
        ),
      ),
      onDismissed: (_) => onDismiss(),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Type icon
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _typeColor(item.type).withAlpha(18),
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                    child: Icon(
                      _typeIcon(item.type),
                      color: _typeColor(item.type),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Title + body
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                item.title,
                                style: TextStyle(
                                  fontWeight: item.isRead
                                      ? FontWeight.w600
                                      : FontWeight.w800,
                                  fontSize: 14,
                                  color: AppColors.textDark,
                                ),
                              ),
                            ),
                            if (!item.isRead)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.primaryBlue,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.body,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _timeAgo(item),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _typeColor(AppNotificationType type) {
    switch (type) {
      case AppNotificationType.budgetAlert:
        return AppColors.warning;
      case AppNotificationType.recurringDue:
        return AppColors.primaryBlue;
      case AppNotificationType.reminder:
        return AppColors.success;
    }
  }

  IconData _typeIcon(AppNotificationType type) {
    switch (type) {
      case AppNotificationType.budgetAlert:
        return Icons.pie_chart_outline_rounded;
      case AppNotificationType.recurringDue:
        return Icons.autorenew_rounded;
      case AppNotificationType.reminder:
        return Icons.notifications_active_outlined;
    }
  }

  String _timeAgo(AppNotificationItem item) {
    final type = item.type;
    if (type == AppNotificationType.recurringDue) {
      return DateFormat('MMM d').format(item.timestamp);
    }
    return 'This month';
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.surfaceAccent,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 40,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "You're all caught up",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Budget alerts and upcoming payment reminders will appear here automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
