import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../shared/widgets/app_page_header.dart';
import 'package:xpens/features/accounts/presentation/provider/account_providers.dart';
import '../../provider/preferences_providers.dart';
import 'package:xpens/features/sms_parser/presentation/provider/sms_providers.dart';
import 'settings_widgets.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(appPreferencesControllerProvider);
    final smartReminders = ref.watch(smartRemindersEnabledProvider);
    final smsParsingEnabled = ref.watch(smsParsingEnabledProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: const GradientAppBar(
        title: 'Notifications & SMS',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SettingsSectionHeader(title: 'App Notifications'),
            SettingsCard(
              children: [
                SettingsToggleTile(
                  icon: Icons.notifications_none_rounded,
                  title: 'Smart Reminders',
                  subtitle: 'Gentle nudges for pending bills',
                  value: smartReminders,
                  onChanged: controller.setSmartReminders,
                ),
              ],
            ),
            const SizedBox(height: 24),
            const SettingsSectionHeader(title: 'Auto-Transaction Detection'),
            SettingsCard(
              children: [
                SettingsToggleTile(
                  icon: Icons.sms_outlined,
                  title: 'SMS Parsing',
                  subtitle: 'Detect bank transactions from incoming SMS',
                  value: smsParsingEnabled,
                  onChanged: (val) => _handleSmsToggle(context, ref, val),
                ),
                if (smsParsingEnabled) ...[
                  _buildDefaultsSection(context, ref),
                ],
              ],
            ),
            const SizedBox(height: 24),
            const SettingsSectionHeader(title: 'Simulate System Alerts'),
            SettingsCard(
              children: [
                ListTile(
                  leading: const SettingsTileIcon(
                    icon: Icons.notifications_active_outlined,
                  ),
                  title: const Text(
                    'Push Test Transaction Notification',
                    style: TextStyle(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: const Text(
                    'Simulates an auto-detected bank transaction SMS notification to test deep-linking.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11, height: 1.3),
                  ),
                  trailing: const Icon(
                    Icons.send_rounded,
                    color: AppColors.primaryBlue,
                    size: 18,
                  ),
                  onTap: () => _triggerTestNotification(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _triggerTestNotification(BuildContext context) async {
    try {
      const channel = MethodChannel('app.xpens.finance/widget');
      await channel.invokeMethod('triggerMockNotification', {
        'amount': 1250.0,
        'merchant': 'Mock Retail Shop',
        'isDebit': true,
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test notification triggered! Check your notification drawer.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to trigger notification: $e')),
        );
      }
    }
  }

  Future<void> _handleSmsToggle(
    BuildContext context,
    WidgetRef ref,
    bool enable,
  ) async {
    final controller = ref.read(appPreferencesControllerProvider);
    if (enable) {
      // 1. Request notifications permission
      final notifyStatus = await Permission.notification.request();
      if (!notifyStatus.isGranted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notifications are highly recommended to view transaction alerts.'),
            duration: Duration(seconds: 4),
          ),
        );
      }

      // 2. Request SMS permission
      final smsGranted = await SmsPermissionHelper.request();
      if (!smsGranted) {
        if (context.mounted) {
          _showPermissionDialog(context);
        }
        return;
      }

      await controller.setSmsParsingEnabled(true);
    } else {
      await controller.setSmsParsingEnabled(false);
    }
  }

  void _showPermissionDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('SMS Permission Required'),
        content: const Text(
          'XPens requires SMS read and receive permissions to detect transaction messages automatically.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultsSection(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountListProvider).value ?? const [];
    final defaultAccountId = ref.watch(smsDefaultAccountIdProvider);
    final defaultCategory = ref.watch(smsDefaultCategoryProvider);
    final controller = ref.read(appPreferencesControllerProvider);
    final allExpenseCategories = ref.watch(allExpenseCategoriesProvider);

    final selectedAccountName = accounts
            .where((a) => a.id == defaultAccountId)
            .map((a) => a.name)
            .firstOrNull ??
        'App Default';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          ListTile(
            leading: const SettingsTileIcon(icon: Icons.account_balance_wallet_outlined),
            title: const Text(
              'Default Account',
              style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              'Inbound SMS logs into: $selectedAccountName',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            onTap: accounts.isEmpty
                ? null
                : () => _pickAccount(context, accounts, defaultAccountId, controller),
          ),
          const Divider(height: 1, indent: 70, endIndent: 20),
          ListTile(
            leading: const SettingsTileIcon(icon: Icons.category_outlined),
            title: const Text(
              'Default Category',
              style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              'Fallback category: ${defaultCategory.isNotEmpty ? defaultCategory : 'Other'}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            onTap: () => _pickCategory(context, allExpenseCategories, defaultCategory, controller),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAccount(
    BuildContext context,
    List accounts,
    String current,
    AppPreferencesController controller,
  ) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Default Account'),
        children: <Widget>[
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(''),
            child: const Text('App Default'),
          ),
          ...accounts.map(
            (a) => SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(a.id as String),
              child: Text(a.name as String),
            ),
          ),
        ],
      ),
    );
    if (selected != null) {
      await controller.setSmsDefaultAccountId(selected);
    }
  }

  Future<void> _pickCategory(
    BuildContext context,
    List categories,
    String current,
    AppPreferencesController controller,
  ) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Default Category'),
        children: categories
            .map(
              (c) => SimpleDialogOption(
                onPressed: () => Navigator.of(ctx).pop(c.name),
                child: Text(c.name),
              ),
            )
            .toList(growable: false),
      ),
    );
    if (selected != null) {
      await controller.setSmsDefaultCategory(selected);
    }
  }
}
