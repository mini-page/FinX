import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../shared/widgets/app_page_header.dart';
import '../../provider/preferences_providers.dart';
import '../../../../../shared/widgets/currency_selector_sheet.dart';
import 'navigation_gestures_settings_screen.dart';
import 'settings_widgets.dart';

class GeneralSettingsScreen extends ConsumerWidget {
  const GeneralSettingsScreen({super.key});



  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(appPreferencesControllerProvider);
    final themeMode = ref.watch(appThemeModeProvider);
    final locale = ref.watch(localeProvider);
    final currencySymbol = ref.watch(currencySymbolProvider);


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
            const SettingsSectionHeader(title: 'Navigation & Gestures'),
            SettingsCard(
              children: [
                ListTile(
                  leading: const SettingsTileIcon(icon: Icons.view_carousel_rounded),
                  title: const Text(
                    'Navigation & Gestures',
                    style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Customize navbar tabs (3-8) & Quick Add button gestures',
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
