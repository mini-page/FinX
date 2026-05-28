import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/biometric_service.dart';
import '../../../../core/services/update_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import 'settings/settings_widgets.dart';
import '../../../../core/utils/context_extensions.dart';
import '../../../../shared/widgets/app_filter_sheet.dart';
import '../../../../shared/widgets/app_toggle_switch.dart';
import 'package:xpens/features/accounts/accounts.dart';
import '../provider/backup_providers.dart';
import 'package:xpens/features/categories/presentation/provider/budget_providers.dart';
import 'package:xpens/features/expense/presentation/provider/expense_providers.dart';
import '../provider/preferences_providers.dart';
import 'package:xpens/features/recurring/presentation/provider/recurring_subscription_providers.dart';
import 'package:xpens/features/expense/presentation/widgets/ui_feedback.dart';
import 'about_screen.dart';
import 'pin_entry_screen.dart';
import 'support_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(appPreferencesControllerProvider);
    final backupController = ref.read(backupControllerProvider);

    final smartReminders = ref.watch(smartRemindersEnabledProvider);
    final isPinEnabled = ref.watch(isPinEnabledProvider);
    final themeMode = ref.watch(appThemeModeProvider);
    final locale = ref.watch(localeProvider);
    final currencySymbol = ref.watch(currencySymbolProvider);

    // Backup states
    final autoBackup = ref.watch(autoBackupEnabledProvider);
    final backupFrequency = ref.watch(backupFrequencyProvider);
    final backupPath = ref.watch(backupDirectoryPathProvider);
    final lastBackup = ref.watch(lastBackupDateTimeProvider);

    final aiApiKey = ref.watch(aiApiKeyProvider);
    final aiEnabled = ref.watch(aiEnabledProvider);
    final aiModelId = ref.watch(aiModelIdProvider);
    final aiSmartSearch = ref.watch(aiSmartSearchEnabledProvider);
    final aiVoice = ref.watch(aiVoiceEnabledProvider);
    final aiScanner = ref.watch(aiScannerEnabledProvider);
    final aiSmsAi = ref.watch(aiSmsAiEnabledProvider);
    final biometricEnabled = ref.watch(biometricLockEnabledProvider);

    // Update check state
    final updateState = ref.watch(updateCheckerProvider);

    final lastBackupText = lastBackup != null
        ? DateFormat('MMM d, yyyy HH:mm').format(lastBackup)
        : 'Never';

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.textDark,
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── General ──────────────────────────────────────────────────
            const SettingsSectionHeader(title: 'General'),
            SettingsCard(
              children: [
                _buildThemeTile(context, themeMode, controller),
                _buildCurrencyTile(context, currencySymbol, controller),
                _buildLanguageTile(context, locale, controller),
              ],
            ),
            const SizedBox(height: 24),

            // ── Notifications ─────────────────────────────────────────────
            const SettingsSectionHeader(title: 'Notifications'),
            SettingsCard(
              children: [
                _buildToggleTile(
                  icon: Icons.notifications_none_rounded,
                  title: 'Smart Reminders',
                  subtitle: 'Gentle nudges for pending bills',
                  value: smartReminders,
                  onChanged: controller.setSmartReminders,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Security & Privacy ────────────────────────────────────────
            const SettingsSectionHeader(title: 'Security & Privacy'),
            SettingsCard(
              children: [
                _buildToggleTile(
                  icon: Icons.pin_outlined,
                  title: 'PIN Lock',
                  subtitle: isPinEnabled
                      ? 'Tap to change or disable PIN'
                      : 'Protect the app with a 4-digit PIN',
                  value: isPinEnabled,
                  onChanged: (enabled) =>
                      _handlePinToggle(context, ref, enabled),
                ),
                if (isPinEnabled)
                  _buildActionTile(
                    icon: Icons.lock_reset_rounded,
                    title: 'Change PIN',
                    subtitle: 'Set a new 4-digit PIN',
                    onTap: () async {
                      await Navigator.of(context).push<bool>(
                        MaterialPageRoute<bool>(
                          builder: (_) => const PinEntryScreen(
                            isSetup: true,
                            isChange: true,
                          ),
                        ),
                      );
                    },
                  ),
                _buildToggleTile(
                  icon: Icons.fingerprint_rounded,
                  title: 'Biometric Lock',
                  subtitle: isPinEnabled
                      ? 'Use fingerprint / face-ID in addition to PIN'
                      : 'Enable PIN Lock first to use Biometric Lock',
                  value: biometricEnabled,
                  onChanged: isPinEnabled
                      ? (enabled) =>
                          _handleBiometricToggle(context, ref, enabled)
                      : (_) => context.showSnackBar(
                            'Please enable PIN Lock first.',
                          ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Data Management ───────────────────────────────────────────
            const SettingsSectionHeader(title: 'Data Management'),
            SettingsCard(
              children: [
                // ── Backup Now (always visible) ─────────────────────────
                _buildActionTile(
                  icon: Icons.backup_rounded,
                  title: 'Backup Now',
                  subtitle: 'Save a backup to the current backup location',
                  onTap: () => _backupNow(context, ref),
                ),
                _buildActionTile(
                  icon: Icons.cloud_upload_outlined,
                  title: 'Export Data',
                  subtitle: 'Share as .xpens, CSV, or JSON',
                  onTap: () => _showExportFormatSheet(context, ref),
                ),
                _buildActionTile(
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
                _buildToggleTile(
                  icon: Icons.history_rounded,
                  title: 'Auto Backup',
                  subtitle: 'Scheduled offline backups',
                  value: autoBackup,
                  onChanged: (val) => controller.setAutoBackup(val),
                ),
                if (autoBackup)
                  _buildSelectionTile(
                    icon: Icons.timer_outlined,
                    title: 'Backup Frequency',
                    subtitle: 'Current: ${backupFrequency.toUpperCase()}',
                    value: backupFrequency,
                    onChanged: (val) {
                      if (val != null) controller.setBackupFrequency(val);
                    },
                    items: const [
                      DropdownMenuItem(value: 'daily', child: Text('Daily')),
                      DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                      DropdownMenuItem(
                          value: 'monthly', child: Text('Monthly')),
                    ],
                  ),
                // ── Backup Location (always visible & tappable) ─────────
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
            const SizedBox(height: 24),

            // ── AI Features ───────────────────────────────────────────────
            const SettingsSectionHeader(title: 'AI Features'),
            _AiFeaturesCard(
              apiKey: aiApiKey,
              aiEnabled: aiEnabled,
              aiModelId: aiModelId,
              aiSmartSearch: aiSmartSearch,
              aiVoice: aiVoice,
              aiScanner: aiScanner,
              aiSmsAi: aiSmsAi,
              controller: controller,
              onAddKey: () => _showAddApiKeyDialog(context, controller),
              onDeleteKey: () async {
                final confirmed = await confirmDestructiveAction(
                  context,
                  title: 'Remove AI Key?',
                  message:
                      'The Gemini API key will be deleted. AI-powered features '
                      'will be unavailable until you add a new key.',
                  confirmLabel: 'Remove',
                );
                if (confirmed) {
                  await controller.setAiApiKey('');
                  if (context.mounted) {
                    context.showSnackBar('AI API key removed.');
                  }
                }
              },
            ),
            const SizedBox(height: 24),

            // ── About ─────────────────────────────────────────────────────
            const SettingsSectionHeader(title: 'About'),
            SettingsCard(
              children: [
                _buildActionTile(
                  icon: Icons.info_outline_rounded,
                  title: 'About',
                  subtitle: 'About XPens & developer info',
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                        builder: (_) => const AboutScreen()),
                  ),
                ),
                _buildUpdateTile(context, ref, updateState),
                _buildActionTile(
                  icon: Icons.volunteer_activism_outlined,
                  title: 'Support the Project',
                  subtitle: 'Donate or star the repo',
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                        builder: (_) => const SupportScreen()),
                  ),
                ),
                _buildActionTile(
                  icon: Icons.policy_outlined,
                  title: 'Privacy Policy & Terms',
                  subtitle: 'How we handle your data',
                  onTap: () => showPlannedFeatureNotice(
                    context,
                    title: 'Privacy Policy',
                    message:
                        'XPens stores all data locally on your device. No data is ever sent to any server or third party.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ── Danger Zone ────────────────────────────────────────────────
            _buildDangerZone(context, ref),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _handleBiometricToggle(
    BuildContext context,
    WidgetRef ref,
    bool enable,
  ) async {
    final controller = ref.read(appPreferencesControllerProvider);
    if (enable) {
      // First check if the hardware supports biometrics at all.
      final available = await BiometricService.isAvailable();
      if (!available) {
        if (context.mounted) {
          context.showSnackBar(
            'No biometrics enrolled. Please set up fingerprint or face unlock '
            'in your device settings first.',
          );
        }
        return;
      }
      // Require the user to authenticate before enabling, so the feature
      // can't be switched on without proving identity.
      final ok = await BiometricService.authenticate(
        reason: 'Confirm your identity to enable Biometric Lock',
      );
      if (!ok) {
        if (context.mounted) {
          context.showSnackBar(
            'Biometric verification failed. Please try again.',
          );
        }
        return;
      }
    }
    await controller.setBiometricLock(enable);
    if (context.mounted) {
      context.showSnackBar(
        enable ? 'Biometric lock enabled.' : 'Biometric lock disabled.',
      );
    }
  }

  Future<void> _handlePinToggle(
    BuildContext context,
    WidgetRef ref,
    bool enable,
  ) async {
    final controller = ref.read(appPreferencesControllerProvider);
    if (enable) {
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => const PinEntryScreen(isSetup: true),
        ),
      );
      if (result != true && context.mounted) {
        context.showSnackBar('PIN setup cancelled.');
      }
    } else {
      final confirmed = await confirmDestructiveAction(
        context,
        title: 'Disable PIN Lock?',
        message: 'The app will no longer require a PIN to open.',
        confirmLabel: 'Disable',
      );
      if (confirmed) {
        await controller.clearPin();
      }
    }
  }

  Future<void> _resetAppData(BuildContext context, WidgetRef ref) async {
    // Step 1: Standard destructive-action confirmation.
    final step1 = await confirmDestructiveAction(
      context,
      title: 'Reset All Data?',
      message: 'This will permanently delete all transactions, accounts, '
          'subscriptions, and budgets. Your settings will be preserved. '
          'This cannot be undone.',
      confirmLabel: 'Continue',
    );
    if (!step1 || !context.mounted) return;

    // Step 2: Require the user to type "RESET" to prevent accidental taps.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ResetConfirmDialog(),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(backupControllerProvider).resetAllData();
      // Defer invalidations to the next microtask so Riverpod has time to
      // settle any in-progress subscription-count bookkeeping before each
      // subsequent invalidation fires (avoids the
      // "pausedActiveSubscriptionCount" assertion in debug mode).
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

  /// Shows the export format picker and triggers the chosen export type.
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

  /// Triggers an immediate backup to the configured backup directory.
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

  /// Builds the red "Danger Zone" section at the very bottom of the page.
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
              _buildDangerTile(
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

  /// Opens the system folder picker (Android Storage Access Framework) and
  /// saves the chosen path.  No runtime storage permission is required —
  /// SAF grants per-URI access automatically.
  Future<void> _pickBackupDirectory(
      BuildContext context, WidgetRef ref) async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose Backup Location',
      lockParentWindow: true,
    );
    if (path == null) return; // user cancelled

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

  /// Returns `true` when [path] is inside the app-scoped sandbox
  /// (`Android/data/<pkg>/` or `Android/obb/<pkg>/`), which is erased on
  /// app-data clear or uninstall.
  bool _isInsideAppSandbox(String path) {
    return path.contains('/Android/data/') || path.contains('/Android/obb/');
  }

  /// Tappable Backup Location tile that shows the current path and a warning
  /// badge when the location is inside the app sandbox.
  Widget _buildBackupLocationTile(
      BuildContext context, WidgetRef ref, String? backupPath) {
    final isSandbox =
        backupPath != null && _isInsideAppSandbox(backupPath);

    String displayPath;
    if (backupPath == null) {
      displayPath = 'Tap to choose — auto-selected on first backup';
    } else {
      // Show only the last two path segments for readability.
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

  Widget _buildSelectionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    required ValueChanged<String?> onChanged,
    required List<DropdownMenuItem<String>> items,
  }) {
    return ListTile(
      leading: SettingsTileIcon(icon: icon),
      title: Text(
        title,
        style: const TextStyle(
            color: AppColors.textDark, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
      ),
      trailing: _SettingsChoiceMenu(
        value: value,
        sheetTitle: title,
        onChanged: onChanged,
        options: items
            .where((item) => item.value != null)
            .map<({String value, String label, IconData? icon, Color? iconColor})>(
              (item) {
                final labelWidget = item.child;
                final label = labelWidget is Text
                    ? (labelWidget.data ?? item.value!)
                    : item.value!;
                return (
                  value: item.value!,
                  label: label,
                  icon: null,
                  iconColor: null,
                );
              },
            )
            .toList(growable: false),
      ),
    );
  }

  Widget _buildThemeTile(
    BuildContext context,
    ThemeMode currentMode,
    AppPreferencesController controller,
  ) {
    return ListTile(
      leading: const SettingsTileIcon(icon: Icons.palette_outlined),
      title: const Text(
        'Appearance',
        style:
            TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w700),
      ),
      trailing: _SettingsChoiceMenu(
        value: currentMode.name,
        sheetTitle: 'Appearance',
        onChanged: (value) {
          if (value != null) controller.setThemeMode(value);
        },
        options: const <({String value, String label, IconData? icon, Color? iconColor})>[
          (value: 'light', label: 'Light', icon: Icons.wb_sunny_outlined, iconColor: Color(0xFFFFB648)),
          (value: 'dark', label: 'Dark', icon: Icons.nights_stay_outlined, iconColor: Color(0xFF6D8FFF)),
          (value: 'system', label: 'System', icon: Icons.phone_android_outlined, iconColor: AppColors.primaryBlue),
        ],
      ),
    );
  }

  Widget _buildLanguageTile(
    BuildContext context,
    String currentLocale,
    AppPreferencesController controller,
  ) {
    return ListTile(
      leading: const SettingsTileIcon(icon: Icons.language_rounded),
      title: const Text(
        'Language',
        style:
            TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w700),
      ),
      trailing: _SettingsChoiceMenu(
        value: AppConstants.locales.any((l) => l.locale == currentLocale)
            ? currentLocale
            : AppConstants.locales.first.locale,
        sheetTitle: 'Language',
        searchable: true,
        onChanged: (value) {
          if (value != null) controller.setLocale(value);
        },
        options: AppConstants.locales
            .map<({String value, String label, IconData? icon, Color? iconColor})>(
              (l) => (value: l.locale, label: l.label, icon: Icons.language_rounded, iconColor: AppColors.primaryBlue),
            )
            .toList(growable: false),
      ),
    );
  }

  Widget _buildCurrencyTile(
    BuildContext context,
    String currentCurrency,
    AppPreferencesController controller,
  ) {
    return ListTile(
      leading: const SettingsTileIcon(icon: Icons.payments_outlined),
      title: const Text(
        'Currency',
        style:
            TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w700),
      ),
      trailing: _SettingsChoiceMenu(
        value: AppConstants.currencies.any((c) => c.symbol == currentCurrency)
            ? currentCurrency
            : AppConstants.currencies.first.symbol,
        sheetTitle: 'Currency',
        searchable: true,
        onChanged: (value) {
          if (value != null) controller.setCurrencySymbol(value);
        },
        options: AppConstants.currencies
            .map<({String value, String label, IconData? icon, Color? iconColor})>(
              (c) => (value: c.symbol, label: c.label, icon: Icons.payments_outlined, iconColor: AppColors.success),
            )
            .toList(growable: false),
      ),
    );
  }

  Widget _buildToggleTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: SettingsTileIcon(icon: icon),
      title: Text(
        title,
        style: const TextStyle(
            color: AppColors.textDark, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
      ),
      trailing: AppToggleSwitch(
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: SettingsTileIcon(icon: icon),
      title: Text(
        title,
        style: const TextStyle(
            color: AppColors.textDark, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
      ),
      trailing:
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
      onTap: onTap,
    );
  }

  /// A destructive action tile with red accent colours.
  Widget _buildDangerTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: AppColors.danger, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(
            color: AppColors.danger, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
      ),
      trailing:
          const Icon(Icons.chevron_right_rounded, color: AppColors.danger),
      onTap: onTap,
    );
  }

  // ── AI key dialog helper ─────────────────────────────────────────────────

  void _showAddApiKeyDialog(
    BuildContext context,
    AppPreferencesController controller,
  ) {
    showDialog<void>(
      context: context,
      builder: (_) => _ApiKeyAddDialog(
        onSave: (key) async {
          await controller.setAiApiKey(key);
          if (context.mounted) {
            context.showSnackBar('AI API key saved.');
          }
        },
      ),
    );
  }

  // ── Update tile ──────────────────────────────────────────────────────────

  Widget _buildUpdateTile(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<UpdateInfo?> state,
  ) {
    // Loading
    if (state.isLoading) {
      return ListTile(
        leading: const SettingsTileIcon(icon: Icons.system_update_outlined),
        title: const Text(
          'Checking for Updates\u2026',
          style:
              TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w700),
        ),
        subtitle: const Text(
          'Please wait a moment',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        trailing: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    // Update available
    if (state.hasValue && state.value != null) {
      final info = state.value!;
      return ListTile(
        leading: const SettingsTileIcon(icon: Icons.system_update_outlined),
        title: const Text(
          'Update Available',
          style: TextStyle(
              color: AppColors.primaryBlue, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          'v${info.latestVersion} is ready to download',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        trailing: const _UpdateBadge(label: 'Download'),
        onTap: () => _showUpdateDialog(context, ref, info),
      );
    }

    // Error
    if (state.hasError) {
      return ListTile(
        leading: const SettingsTileIcon(icon: Icons.system_update_outlined),
        title: const Text(
          'Check for Updates',
          style:
              TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w700),
        ),
        subtitle: const Text(
          'Could not connect. Tap to retry',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        trailing: const Icon(Icons.refresh_rounded, color: AppColors.textMuted),
        onTap: () => ref.read(updateCheckerProvider.notifier).check(),
      );
    }

    // Default: not yet checked
    return ListTile(
      leading: const SettingsTileIcon(icon: Icons.system_update_outlined),
      title: const Text(
        'Check for Updates',
        style:
            TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        'Current version: v${AppConstants.version}',
        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
      ),
      trailing:
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
      onTap: () => ref.read(updateCheckerProvider.notifier).check(),
    );
  }

  Future<void> _showUpdateDialog(
    BuildContext context,
    WidgetRef ref,
    UpdateInfo info,
  ) async {
    final notes = info.releaseNotes;
    final hasNotes = notes != null && notes.trim().isNotEmpty;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.system_update_outlined, color: AppColors.primaryBlue),
            SizedBox(width: 10),
            Text('Update Available'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A new version of XPens is available.\n\n'
              'v${AppConstants.version}  \u2192  v${info.latestVersion}',
              style: const TextStyle(fontSize: 14),
            ),
            if (hasNotes) ...[
              const SizedBox(height: 12),
              const Text(
                "What's new:",
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                notes.length > _kMaxReleaseNotesLength
                    ? '${notes.substring(0, _kMaxReleaseNotesLength).trimRight()}\u2026'
                    : notes,
                style:
                    const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Later'),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final uri = Uri.parse(info.releaseUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } else if (context.mounted) {
                context.showSnackBar(
                  'Could not open the download link. '
                  'Visit github.com/mini-page/XPens/releases manually.',
                );
              }
            },
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Download'),
          ),
        ],
      ),
    );
  }
}

// ── Private widget ────────────────────────────────────────────────────────────

/// Export format options shown in the export-format bottom sheet.
enum _ExportFormat { native, csv, json }

/// Bottom sheet that lets the user pick an export format.
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

/// Second-step confirmation dialog for Reset App Data that requires the user
/// to type the word "RESET" before the action is permitted.
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

/// Small pill badge used as the trailing widget on the "Update Available" tile.
class _UpdateBadge extends StatelessWidget {
  const _UpdateBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── Constants ─────────────────────────────────────────────────────────────────

/// Maximum number of characters shown for release notes in the update dialog.
const int _kMaxReleaseNotesLength = 280;

// ── AI Features card ──────────────────────────────────────────────────────────

/// Available Gemini models the user can choose from.
const List<({String id, String label, String description})> _kGeminiModels = [
  (
    id: 'gemini-2.0-flash',
    label: 'Gemini 2.0 Flash',
    description: 'Fast & balanced — recommended',
  ),
  (
    id: 'gemini-2.0-flash-lite',
    label: 'Gemini 2.0 Flash Lite',
    description: 'Lightest, lowest latency',
  ),
  (
    id: 'gemini-2.5-flash',
    label: 'Gemini 2.5 Flash',
    description: 'Most capable flash model',
  ),
  (
    id: 'gemini-1.5-flash',
    label: 'Gemini 1.5 Flash',
    description: 'Stable and widely tested',
  ),
  (
    id: 'gemini-1.5-pro',
    label: 'Gemini 1.5 Pro',
    description: 'Highest quality, higher latency',
  ),
];

/// A self-contained card widget that renders the full AI Features section.
///
/// Composed of:
///   • API key status row (compact)
///   • Master "Enable AI Features" toggle (only interactive when key is present)
///   • Gemini model selector (only shown when AI is enabled)
///   • Per-feature toggles (only shown when AI is enabled)
class _AiFeaturesCard extends StatelessWidget {
  const _AiFeaturesCard({
    required this.apiKey,
    required this.aiEnabled,
    required this.aiModelId,
    required this.aiSmartSearch,
    required this.aiVoice,
    required this.aiScanner,
    required this.aiSmsAi,
    required this.controller,
    required this.onAddKey,
    required this.onDeleteKey,
  });

  final String apiKey;
  final bool aiEnabled;
  final String aiModelId;
  final bool aiSmartSearch;
  final bool aiVoice;
  final bool aiScanner;
  final bool aiSmsAi;
  final AppPreferencesController controller;
  final VoidCallback onAddKey;
  final VoidCallback onDeleteKey;

  bool get _hasKey => apiKey.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      children: [
        // ── API Key row ─────────────────────────────────────────────
        _AiKeyRow(
          hasKey: _hasKey,
          onAdd: onAddKey,
          onDelete: onDeleteKey,
        ),

        // ── Master toggle ──────────────────────────────────────────
        ListTile(
          dense: true,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (aiEnabled ? AppColors.primaryBlue : AppColors.textMuted)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              color: aiEnabled ? AppColors.primaryBlue : AppColors.textMuted,
              size: 18,
            ),
          ),
          title: const Text(
            'Enable AI Features',
            style: TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.w700,
                fontSize: 14),
          ),
          subtitle: Text(
            _hasKey
                ? 'Use Gemini to power smart features'
                : 'Add an API key first',
            style: TextStyle(
              color: _hasKey ? AppColors.textMuted : AppColors.danger,
              fontSize: 11,
            ),
          ),
          trailing: AppToggleSwitch(
            value: aiEnabled,
            onChanged: _hasKey ? (v) => controller.setAiEnabled(v) : (_) {},
          ),
        ),

        // ── Model selector ─────────────────────────────────────────
        if (aiEnabled) ...[
          const Divider(height: 1, indent: 16, endIndent: 16),
          _AiModelSelector(
            currentId: aiModelId,
            onChanged: controller.setAiModelId,
          ),

          // ── Per-feature toggles ─────────────────────────────────
          const Divider(height: 1, indent: 16, endIndent: 16),
          _AiFeatureToggle(
            icon: Icons.search_rounded,
            title: 'Smart Search',
            subtitle: 'AI-enhanced transaction search',
            value: aiSmartSearch,
            onChanged: controller.setAiSmartSearchEnabled,
          ),
          _AiFeatureToggle(
            icon: Icons.mic_rounded,
            title: 'Smart Voice Entry',
            subtitle: 'AI parses voice commands',
            value: aiVoice,
            onChanged: controller.setAiVoiceEnabled,
          ),
          _AiFeatureToggle(
            icon: Icons.qr_code_scanner_rounded,
            title: 'Smart Scanner',
            subtitle: 'AI reads receipts & product labels',
            value: aiScanner,
            onChanged: controller.setAiScannerEnabled,
          ),
          _AiFeatureToggle(
            icon: Icons.sms_outlined,
            title: 'AI SMS Parsing',
            subtitle: 'AI extracts amounts from bank SMS',
            value: aiSmsAi,
            onChanged: controller.setAiSmsAiEnabled,
          ),
        ],
      ],
    );
  }
}

// ── Compact API key row ───────────────────────────────────────────────────────

class _AiKeyRow extends StatelessWidget {
  const _AiKeyRow({
    required this.hasKey,
    required this.onAdd,
    required this.onDelete,
  });

  final bool hasKey;
  final VoidCallback onAdd;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (hasKey ? AppColors.success : AppColors.primaryBlue)
              .withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          hasKey ? Icons.check_circle_outline_rounded : Icons.vpn_key_outlined,
          color: hasKey ? AppColors.success : AppColors.primaryBlue,
          size: 18,
        ),
      ),
      title: const Text(
        'Gemini API Key',
        style: TextStyle(
          color: AppColors.textDark,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        hasKey ? 'Connected  •  tap 🗑 to remove' : 'Not configured',
        style: TextStyle(
          color: hasKey ? AppColors.success : AppColors.textMuted,
          fontSize: 11,
        ),
      ),
      trailing: hasKey
          ? IconButton(
              iconSize: 20,
              icon: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.danger),
              tooltip: 'Remove key',
              onPressed: onDelete,
            )
          : TextButton(
              onPressed: onAdd,
              child: const Text(
                'Add Key',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
      onTap: hasKey
          ? () => context.showSnackBar(
                'Delete the key first to add a new one.',
                type: AppFeedbackType.warning,
              )
          : onAdd,
    );
  }
}

class _SettingsChoiceMenu extends StatelessWidget {
  const _SettingsChoiceMenu({
    required this.value,
    required this.onChanged,
    required this.options,
    this.sheetTitle = 'Choose',
    this.searchable = false,
  });

  final String value;
  final ValueChanged<String?> onChanged;
  final List<({String value, String label, IconData? icon, Color? iconColor})>
      options;
  final String sheetTitle;
  final bool searchable;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) {
      return const SizedBox.shrink();
    }

    final match = options.where((o) => o.value == value).firstOrNull;
    final selectedLabel = (match ?? options.first).label;

    return IntrinsicWidth(
      child: GestureDetector(
        onTap: () => _openSheet(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: AppColors.surfaceAccent,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(
              color: AppColors.primaryBlue.withValues(alpha: 0.22),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Flexible(
                child: Text(
                  selectedLabel,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.expand_more_rounded,
                color: AppColors.primaryBlue,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openSheet(BuildContext context) async {
    final items = options
        .map(
          (o) => FilterSheetItem<String>(
            value: o.value,
            label: o.label,
            icon: o.icon,
            iconColor: o.iconColor,
          ),
        )
        .toList(growable: false);

    final chosen = await showSingleSelectSheet<String>(
      context: context,
      title: sheetTitle,
      items: items,
      selectedValue: value,
      searchable: searchable,
    );

    if (chosen != null) onChanged(chosen);
  }
}

// ── Model selector row ────────────────────────────────────────────────────────

class _AiModelSelector extends StatelessWidget {
  const _AiModelSelector({
    required this.currentId,
    required this.onChanged,
  });

  final String currentId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    // Fall back gracefully if a previously saved model is not in the list
    final selected = _kGeminiModels.any((m) => m.id == currentId)
        ? currentId
        : _kGeminiModels.first.id;
    final model = _kGeminiModels.firstWhere((m) => m.id == selected);

    return ListTile(
      dense: true,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primaryBlue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.settings_suggest_rounded,
          color: AppColors.primaryBlue,
          size: 18,
        ),
      ),
      title: const Text(
        'Gemini Model',
        style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.w700,
            fontSize: 14),
      ),
      subtitle: Text(
        model.description,
        style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
      ),
      trailing: _SettingsChoiceMenu(
        value: selected,
        sheetTitle: 'Gemini Model',
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
        options: _kGeminiModels
            .map<({String value, String label, IconData? icon, Color? iconColor})>(
              (m) => (
                value: m.id,
                label: m.label,
                icon: Icons.auto_awesome_outlined,
                iconColor: AppColors.primaryBlue,
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

// ── Per-feature toggle row ────────────────────────────────────────────────────

class _AiFeatureToggle extends StatelessWidget {
  const _AiFeatureToggle({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      leading: Icon(icon,
          color: value ? AppColors.primaryBlue : AppColors.textMuted, size: 20),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.textDark,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
      ),
      trailing: AppToggleSwitch(
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

// ── AI Key dialog ─────────────────────────────────────────────────────────────

/// A self-contained dialog for adding a Gemini API key.
///
/// The key can only be added (not edited). Editing is prevented by design to
/// avoid key theft — the user must delete and re-add if they want to change it.
///
/// Manages its own [TextEditingController] lifecycle to avoid the
/// "TextEditingController used after being disposed" error that arises when
/// a controller is created outside a [StatefulBuilder].
class _ApiKeyAddDialog extends StatefulWidget {
  const _ApiKeyAddDialog({required this.onSave});

  /// Called with the validated key when the user taps Save.
  final Future<void> Function(String key) onSave;

  @override
  State<_ApiKeyAddDialog> createState() => _ApiKeyAddDialogState();
}

class _ApiKeyAddDialogState extends State<_ApiKeyAddDialog> {
  late final TextEditingController _ctrl;
  String? _error;
  bool _saving = false;

  /// A valid Gemini API key starts with "AIzaSy" and is 39 characters.
  static bool _isValidKey(String key) =>
      key.startsWith('AIzaSy') && key.length == 39;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final key = _ctrl.text.trim();
    if (!_isValidKey(key)) {
      setState(() =>
          _error = 'Key must start with "AIzaSy" and be 39 characters long.');
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    await widget.onSave(key);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Add Gemini API Key',
        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your key is stored only on this device.\n'
              'To change it later, delete and re-add.',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            // ── Get key link ──────────────────────────────────────────
            InkWell(
              onTap: () async {
                final uri = Uri.parse('https://aistudio.google.com/api-keys');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.open_in_new_rounded,
                        size: 13, color: AppColors.primaryBlue),
                    SizedBox(width: 4),
                    Text(
                      'Get your key at aistudio.google.com',
                      style: TextStyle(
                        color: AppColors.primaryBlue,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // ── Key input (write-once, always obscured) ───────────────
            TextField(
              controller: _ctrl,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              decoration: InputDecoration(
                hintText: 'AIzaSy…',
                errorText: _error,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
