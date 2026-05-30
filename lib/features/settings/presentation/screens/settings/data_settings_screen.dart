import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../shared/widgets/app_page_header.dart';
import '../../../../../core/utils/context_extensions.dart';
import '../../provider/backup_providers.dart';
import '../../provider/preferences_providers.dart';
import 'package:xpens/features/accounts/accounts.dart';
import 'package:xpens/features/categories/presentation/provider/budget_providers.dart';
import 'package:xpens/features/expense/presentation/provider/expense_providers.dart';
import 'package:xpens/features/recurring/presentation/provider/recurring_subscription_providers.dart';
import 'settings_widgets.dart';

class DataSettingsScreen extends ConsumerWidget {
  const DataSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(appPreferencesControllerProvider);
    final backupController = ref.read(backupControllerProvider);

    final autoBackup = ref.watch(autoBackupEnabledProvider);
    final backupFrequency = ref.watch(backupFrequencyProvider);
    final backupPath = ref.watch(backupDirectoryPathProvider);
    final lastBackup = ref.watch(lastBackupDateTimeProvider);

    final lastBackupText = lastBackup != null
        ? DateFormat('MMM d, yyyy HH:mm').format(lastBackup)
        : 'Never';

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: const GradientAppBar(
        title: 'Data Management',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SettingsSectionHeader(title: 'Backup & Restore'),
            SettingsCard(
              children: [
                SettingsActionTile(
                  icon: Icons.backup_rounded,
                  title: 'Backup Now',
                  subtitle: 'Save a backup to the current backup location',
                  onTap: () => _backupNow(context, ref),
                ),
                SettingsActionTile(
                  icon: Icons.cloud_upload_outlined,
                  title: 'Export Data',
                  subtitle: 'Share as .xpens, CSV, or JSON',
                  onTap: () => _showExportFormatSheet(context, ref),
                ),
                SettingsActionTile(
                  icon: Icons.cloud_download_outlined,
                  title: 'Import Data',
                  subtitle: 'Restore from a .xpens backup file',
                  onTap: () async {
                    final confirmed = await confirmDestructiveAction(
                      context,
                      title: 'Restore Data?',
                      message:
                          'This will overwrite your current transactions. This action cannot be undone.',
                      confirmLabel: 'Restore',
                    );

                    if (confirmed) {
                      try {
                        final success = await backupController.importData();
                        if (success && context.mounted) {
                          context.showSnackBar('Data restored successfully!');
                        }
                      } catch (e) {
                        if (context.mounted) {
                          context.showSnackBar('Import failed: $e');
                        }
                      }
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            const SettingsSectionHeader(title: 'Auto Backup Settings'),
            SettingsCard(
              children: [
                SettingsToggleTile(
                  icon: Icons.history_rounded,
                  title: 'Auto Backup',
                  subtitle: 'Scheduled offline backups',
                  value: autoBackup,
                  onChanged: (val) => controller.setAutoBackup(val),
                ),
                if (autoBackup)
                  ListTile(
                    leading: const SettingsTileIcon(icon: Icons.timer_outlined),
                    title: const Text(
                      'Backup Frequency',
                      style: TextStyle(
                          color: AppColors.textDark, fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      'Current: ${backupFrequency.toUpperCase()}',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                    trailing: SettingsChoiceMenu(
                      value: backupFrequency,
                      sheetTitle: 'Backup Frequency',
                      onChanged: (val) {
                        if (val != null) controller.setBackupFrequency(val);
                      },
                      options: const [
                        (value: 'daily', label: 'Daily', icon: Icons.today_outlined, iconColor: AppColors.primaryBlue),
                        (value: 'weekly', label: 'Weekly', icon: Icons.date_range_outlined, iconColor: AppColors.primaryBlue),
                        (value: 'monthly', label: 'Monthly', icon: Icons.calendar_month_outlined, iconColor: AppColors.primaryBlue),
                      ],
                    ),
                  ),
                _buildBackupLocationTile(context, ref, backupPath),
                ListTile(
                  leading: const SettingsTileIcon(icon: Icons.update_rounded),
                  title: const Text(
                    'Last Backup',
                    style: TextStyle(
                        color: AppColors.textDark, fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    lastBackupText,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildDangerZone(context, ref),
          ],
        ),
      ),
    );
  }

  Future<void> _backupNow(BuildContext context, WidgetRef ref) async {
    final backupController = ref.read(backupControllerProvider);
    try {
      context.showSnackBar('Creating backup…');
      await backupController.backupNow();
      if (context.mounted) {
        context.showSnackBar('Backup saved successfully.');
      }
    } catch (e) {
      if (context.mounted) {
        context.showSnackBar('Backup failed: $e');
      }
    }
  }

  Future<void> _showExportFormatSheet(
      BuildContext context, WidgetRef ref) async {
    final backupController = ref.read(backupControllerProvider);

    final chosen = await showModalBottomSheet<_ExportFormat>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => const _ExportFormatSheet(),
    );

    if (chosen == null || !context.mounted) return;

    try {
      switch (chosen) {
        case _ExportFormat.native:
          await backupController.exportData();
        case _ExportFormat.csv:
          await backupController.exportAsCSV();
        case _ExportFormat.json:
          await backupController.exportAsJSON();
      }
    } catch (e) {
      if (context.mounted) {
        context.showSnackBar('Export failed: $e');
      }
    }
  }

  Widget _buildBackupLocationTile(
      BuildContext context, WidgetRef ref, String? backupPath) {
    final isSandbox =
        backupPath != null && _isInsideAppSandbox(backupPath);

    String displayPath;
    if (backupPath == null) {
      displayPath = 'Tap to choose — auto-selected on first backup';
    } else {
      final parts = backupPath.split('/').where((s) => s.isNotEmpty).toList();
      displayPath = parts.length >= 2
          ? '…/${parts[parts.length - 2]}/${parts.last}'
          : backupPath;
    }

    return ListTile(
      leading: const SettingsTileIcon(icon: Icons.folder_open_rounded),
      title: Row(
        children: [
          const Text(
            'Backup Location',
            style: TextStyle(
                color: AppColors.textDark, fontWeight: FontWeight.w700),
          ),
          if (isSandbox) ...[
            const SizedBox(width: 6),
            Tooltip(
              message:
                  'This location is inside app storage and may be lost on uninstall.',
              child: Icon(Icons.warning_amber_rounded,
                  size: 16, color: Colors.orange.shade700),
            ),
          ],
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            displayPath,
            style:
                const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          if (isSandbox)
            Text(
              'Tap to choose a safer location (e.g. Downloads)',
              style: TextStyle(
                  color: Colors.orange.shade700,
                  fontSize: 11,
                  fontWeight: FontWeight.w500),
            ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right_rounded,
          color: AppColors.textMuted),
      onTap: () => _pickBackupDirectory(context, ref),
    );
  }

  bool _isInsideAppSandbox(String path) {
    return path.contains('/Android/data/') || path.contains('/Android/obb/');
  }

  Future<void> _pickBackupDirectory(
      BuildContext context, WidgetRef ref) async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose Backup Location',
      lockParentWindow: true,
    );
    if (path == null) return;

    await ref
        .read(appPreferencesControllerProvider)
        .setBackupDirectory(path);

    if (context.mounted && _isInsideAppSandbox(path)) {
      context.showSnackBar(
        'This location is inside app storage and will be lost if the app is '
        'uninstalled or its data is cleared. Tap "Backup Location" to choose '
        'a safer folder (e.g. Downloads).',
        type: AppFeedbackType.warning,
      );
    }
  }

  Widget _buildDangerZone(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            'DANGER ZONE',
            style: TextStyle(
              color: AppColors.danger,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.danger.withValues(alpha: 0.25),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.danger.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: AppColors.danger, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Destructive Actions',
                      style: TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  'The action below permanently deletes data and cannot be '
                  'undone. Export a backup before proceeding.',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              SettingsDangerTile(
                icon: Icons.delete_sweep_outlined,
                title: 'Reset App Data',
                subtitle:
                    'Permanently erase all transactions, accounts, budgets & subscriptions',
                onTap: () => _resetAppData(context, ref),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _resetAppData(BuildContext context, WidgetRef ref) async {
    final step1 = await confirmDestructiveAction(
      context,
      title: 'Reset All Data?',
      message: 'This will permanently delete all transactions, accounts, '
          'subscriptions, and budgets. Your settings will be preserved. '
          'This cannot be undone.',
      confirmLabel: 'Continue',
    );
    if (!step1 || !context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ResetConfirmDialog(),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(backupControllerProvider).resetAllData();
      await Future.microtask(() {
        ref.invalidate(expenseListProvider);
        ref.invalidate(accountListProvider);
        ref.invalidate(budgetTargetsProvider);
        ref.invalidate(recurringSubscriptionListProvider);
      });
      if (context.mounted) {
        context.showSnackBar('All data has been reset.');
      }
    } catch (e) {
      if (context.mounted) {
        context.showSnackBar('Reset failed: $e');
      }
    }
  }

  Future<bool> confirmDestructiveAction(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  foregroundColor: Colors.white,
                ),
                child: Text(confirmLabel),
              ),
            ],
          ),
        ) ??
        false;
  }
}

enum _ExportFormat { native, csv, json }

class _ExportFormatSheet extends StatelessWidget {
  const _ExportFormatSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Export Format',
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Choose how to export your data.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            _FormatOption(
              icon: Icons.folder_zip_outlined,
              iconColor: AppColors.primaryBlue,
              title: 'Native Backup (.xpens)',
              subtitle:
                  'Full backup — includes all app data. Use to restore XPens.',
              onTap: () =>
                  Navigator.of(context).pop(_ExportFormat.native),
            ),
            const Divider(height: 16),
            _FormatOption(
              icon: Icons.table_chart_outlined,
              iconColor: AppColors.success,
              title: 'CSV Spreadsheet',
              subtitle: 'Transactions only — open in Excel, Sheets, etc.',
              onTap: () =>
                  Navigator.of(context).pop(_ExportFormat.csv),
            ),
            const Divider(height: 16),
            _FormatOption(
              icon: Icons.data_object_rounded,
              iconColor: const Color(0xFFE07B39),
              title: 'JSON',
              subtitle:
                  'Transactions as structured JSON — for developers / archiving.',
              onTap: () =>
                  Navigator.of(context).pop(_ExportFormat.json),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _FormatOption extends StatelessWidget {
  const _FormatOption({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

class _ResetConfirmDialog extends StatefulWidget {
  @override
  State<_ResetConfirmDialog> createState() => _ResetConfirmDialogState();
}

class _ResetConfirmDialogState extends State<_ResetConfirmDialog> {
  final TextEditingController _ctrl = TextEditingController();
  bool _matches = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.danger),
          SizedBox(width: 10),
          Text(
            'Final Confirmation',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Type RESET below to confirm you want to permanently delete all '
            'transactions, accounts, budgets, and subscriptions.',
            style: TextStyle(fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'Type RESET',
              isDense: true,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.danger, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 12),
            ),
            onChanged: (val) {
              final matches = val.trim() == 'RESET';
              if (matches != _matches) setState(() => _matches = matches);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _matches ? () => Navigator.of(context).pop(true) : null,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.danger.withValues(alpha: 0.35),
          ),
          child: const Text('Reset Everything'),
        ),
      ],
    );
  }
}
