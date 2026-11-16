import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../shared/widgets/app_page_header.dart';
import '../../../../../shared/widgets/responsive_settings_tile.dart';
import '../../provider/preferences_providers.dart';
import '../../../../../shared/widgets/currency_selector_sheet.dart';
import 'navigation_gestures_settings_screen.dart';
import 'settings_widgets.dart';

class GeneralSettingsScreen extends ConsumerWidget {
  const GeneralSettingsScreen({super.key});

  static const _fabActionOptions = <({String value, String label, IconData? icon, Color? iconColor})>[
    (value: 'scanner', label: 'Scan (QR & Bill)', icon: Icons.qr_code_scanner_rounded, iconColor: Color(0xFF00B0FF)),
    (value: 'voice', label: 'Voice Entry', icon: Icons.mic_none_rounded, iconColor: Color(0xFF7B2FF7)),
    (value: 'add', label: 'Add Transaction', icon: Icons.add_circle_outline_rounded, iconColor: AppColors.primaryBlue),
    (value: 'subscriptions', label: 'Subscriptions & Bills', icon: Icons.autorenew_rounded, iconColor: Color(0xFF10B981)),
    (value: 'split', label: 'Split Bill', icon: Icons.call_split_rounded, iconColor: Color(0xFFF59E0B)),
    (value: 'goals', label: 'Financial Goals', icon: Icons.emoji_events_outlined, iconColor: Color(0xFFEC4899)),
    (value: 'budget', label: 'Budgeting Hub', icon: Icons.account_balance_wallet_outlined, iconColor: Color(0xFF6366F1)),
    (value: 'radar', label: 'Location Radar', icon: Icons.radar_rounded, iconColor: Color(0xFF0EA5E9)),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(appPreferencesControllerProvider);
    final themeMode = ref.watch(appThemeModeProvider);
    final locale = ref.watch(localeProvider);
    final currencySymbol = ref.watch(currencySymbolProvider);
    final fabDoubleTap = ref.watch(fabDoubleTapActionProvider);
    final fabLongPress = ref.watch(fabLongPressActionProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: const GradientAppBar(
        title: 'General Settings',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SettingsSectionHeader(title: 'Appearance & Locale'),
            SettingsCard(
              children: [
                _buildThemeTile(themeMode, controller),
                _buildCurrencyTile(context, currencySymbol, controller),
                _buildLanguageTile(locale, controller),
              ],
            ),
            const SizedBox(height: 24),

            // ── Quick Add (+) Button Gestures ─────────────────────────────────
            const SettingsSectionHeader(title: 'Quick Add (+) Button Gestures'),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                'Configure shortcuts triggered by interacting with the floating Quick Add button on Home.',
                style: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.8),
                  fontSize: 13,
                ),
              ),
            ),
            SettingsCard(
              children: [
                ResponsiveSettingsTile(
                  icon: Icons.touch_app_rounded,
                  title: 'Single Tap',
                  subtitle: 'Open new transaction logging form.',
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF5FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.2)),
                    ),
                    child: const Text(
                      'Add Transaction',
                      style: TextStyle(
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                ResponsiveSettingsTile(
                  icon: Icons.gesture_rounded,
                  title: 'Double Tap Action',
                  subtitle: 'Action triggered on double-tapping + button.',
                  trailing: SettingsChoiceMenu(
                    value: fabDoubleTap,
                    sheetTitle: 'Double Tap Action',
                    onChanged: (val) {
                      if (val != null) controller.setFabDoubleTapAction(val);
                    },
                    options: _fabActionOptions,
                  ),
                ),
                ResponsiveSettingsTile(
                  icon: Icons.pan_tool_rounded,
                  title: 'Long Press Action',
                  subtitle: 'Action triggered on holding + button.',
                  trailing: SettingsChoiceMenu(
                    value: fabLongPress,
                    sheetTitle: 'Long Press Action',
                    onChanged: (val) {
                      if (val != null) controller.setFabLongPressAction(val);
                    },
                    options: _fabActionOptions,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Navigation Bar Customization ──────────────────────────────────
            const SettingsSectionHeader(title: 'Navigation Bar Customization'),
            SettingsCard(
              children: [
                ListTile(
                  leading: const SettingsTileIcon(icon: Icons.view_carousel_rounded),
                  title: const Text(
                    'Customize Navigation Tabs',
                    style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Reorder, add, or remove tabs from your bottom bar',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const NavigationGesturesSettingsScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeTile(
    ThemeMode currentMode,
    AppPreferencesController controller,
  ) {
    return ListTile(
      leading: const SettingsTileIcon(icon: Icons.palette_outlined),
      title: const Text(
        'Appearance',
        style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w700),
      ),
      trailing: SettingsChoiceMenu(
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
    String currentLocale,
    AppPreferencesController controller,
  ) {
    return ListTile(
      leading: const SettingsTileIcon(icon: Icons.language_rounded),
      title: const Text(
        'Language',
        style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w700),
      ),
      trailing: SettingsChoiceMenu(
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
      leading: const SettingsTileIcon(icon: Icons.attach_money_rounded),
      title: const Text(
        'Currency',
        style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w700),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            currentCurrency,
            style: const TextStyle(
              color: AppColors.primaryBlue,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textMuted,
            size: 20,
          ),
        ],
      ),
      onTap: () async {
        final selected = await showCurrencySelectorSheet(context, currentCurrency);
        if (selected != null) {
          controller.setCurrencySymbol(selected);
        }
      },
    );
  }
}
