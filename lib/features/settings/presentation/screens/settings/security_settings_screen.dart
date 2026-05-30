import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/services/biometric_service.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/context_extensions.dart';
import '../../../../../shared/widgets/app_page_header.dart';
import '../../provider/preferences_providers.dart';
import '../pin_entry_screen.dart';
import 'settings_widgets.dart';

class SecuritySettingsScreen extends ConsumerWidget {
  const SecuritySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(appPreferencesControllerProvider);
    final isPinEnabled = ref.watch(isPinEnabledProvider);
    final biometricEnabled = ref.watch(biometricLockEnabledProvider);
    final privacyModeEnabled = ref.watch(privacyModeEnabledProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: const GradientAppBar(
        title: 'Security & Privacy',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SettingsSectionHeader(title: 'App Protection'),
            SettingsCard(
              children: [
                SettingsToggleTile(
                  icon: Icons.pin_outlined,
                  title: 'PIN Lock',
                  subtitle: isPinEnabled
                      ? 'Require a 4-digit PIN to open the app'
                      : 'Protect the app with a 4-digit PIN',
                  value: isPinEnabled,
                  onChanged: (enabled) => _handlePinToggle(context, ref, enabled),
                ),
                if (isPinEnabled)
                  SettingsActionTile(
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
                SettingsToggleTile(
                  icon: Icons.fingerprint_rounded,
                  title: 'Biometric Lock',
                  subtitle: isPinEnabled
                      ? 'Use fingerprint / face-ID in addition to PIN'
                      : 'Enable PIN Lock first to use Biometric Lock',
                  value: biometricEnabled,
                  onChanged: isPinEnabled
                      ? (enabled) => _handleBiometricToggle(context, ref, enabled)
                      : (_) => context.showSnackBar('Please enable PIN Lock first.'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const SettingsSectionHeader(title: 'Privacy & Masking'),
            SettingsCard(
              children: [
                SettingsToggleTile(
                  icon: Icons.visibility_off_outlined,
                  title: 'Hide Amounts',
                  subtitle: 'Mask balance and transaction amounts on home screen',
                  value: privacyModeEnabled,
                  onChanged: controller.setPrivacyMode,
                ),
              ],
            ),
          ],
        ),
      ),
    );
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

  Future<void> _handleBiometricToggle(
    BuildContext context,
    WidgetRef ref,
    bool enable,
  ) async {
    final controller = ref.read(appPreferencesControllerProvider);
    if (enable) {
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
      final ok = await BiometricService.authenticate(
        reason: 'Confirm your identity to enable Biometric Lock',
      );
      if (!ok) {
        if (context.mounted) {
          context.showSnackBar('Biometric verification failed. Please try again.');
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
