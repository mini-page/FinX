import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_page_header.dart';
import 'settings/settings_widgets.dart';
import 'settings/general_settings_screen.dart';
import 'settings/notification_settings_screen.dart';
import 'settings/security_settings_screen.dart';
import 'settings/data_settings_screen.dart';
import 'settings/ai_settings_screen.dart';
import 'settings/permissions_settings_screen.dart';
import 'about_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: const GradientAppBar(
        title: 'Settings',
        showBackButton: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SettingsSectionHeader(title: 'App Configuration'),
            SettingsCard(
              children: [
                SettingsActionTile(
                  icon: Icons.tune_rounded,
                  title: 'General',
                  subtitle: 'Appearance, currency, locale preferences',
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const GeneralSettingsScreen(),
                    ),
                  ),
                ),
                SettingsActionTile(
                  icon: Icons.notifications_none_rounded,
                  title: 'Notifications & SMS',
                  subtitle: 'Smart reminders, SMS auto-import details',
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const NotificationSettingsScreen(),
                    ),
                  ),
                ),
                SettingsActionTile(
                  icon: Icons.security_rounded,
                  title: 'Security & Privacy',
                  subtitle: 'PIN lock, biometrics, amount masking',
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const SecuritySettingsScreen(),
                    ),
                  ),
                ),
                SettingsActionTile(
                  icon: Icons.storage_rounded,
                  title: 'Data Management',
                  subtitle: 'Backups, export CSV/JSON, data wipe',
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const DataSettingsScreen(),
                    ),
                  ),
                ),
                SettingsActionTile(
                  icon: Icons.auto_awesome_outlined,
                  title: 'AI Features',
                  subtitle: 'Gemini API integration, assistant features',
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const AiSettingsScreen(),
                    ),
                  ),
                ),
                SettingsActionTile(
                  icon: Icons.security_rounded,
                  title: 'System Permissions',
                  subtitle: 'SMS monitoring, GPS maps, camera scanners',
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const PermissionsSettingsScreen(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const SettingsSectionHeader(title: 'Information'),
            SettingsCard(
              children: [
                SettingsActionTile(
                  icon: Icons.info_outline_rounded,
                  title: 'About XPens',
                  subtitle: 'App version, credits, and support options',
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const AboutScreen(),
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
}
