import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/universal_top_bar.dart';
import 'settings/settings_widgets.dart';
import 'settings/general_settings_screen.dart';
import 'settings/notification_settings_screen.dart';
import 'settings/security_settings_screen.dart';
import 'settings/data_settings_screen.dart';
import 'settings/ai_settings_screen.dart';
import 'settings/permissions_settings_screen.dart';
import 'settings/labs_screen.dart';
import 'about_screen.dart';

class _SettingItem {
  const _SettingItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.section = 'App Configuration',
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final void Function(BuildContext context) onTap;
  final String section;
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, this.showBackButton});

  final bool? showBackButton;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearchOpen = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final q = _searchController.text.trim().toLowerCase();
      if (q != _searchQuery) {
        setState(() {
          _searchQuery = q;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_SettingItem> _getItems() {
    return [
      _SettingItem(
        icon: Icons.tune_rounded,
        title: 'General',
        subtitle: 'Appearance, currency, locale preferences',
        onTap: (ctx) => Navigator.of(ctx).push<void>(
          MaterialPageRoute<void>(builder: (_) => const GeneralSettingsScreen()),
        ),
      ),
      _SettingItem(
        icon: Icons.notifications_none_rounded,
        title: 'Notifications & SMS',
        subtitle: 'Smart reminders, SMS auto-import details',
        onTap: (ctx) => Navigator.of(ctx).push<void>(
          MaterialPageRoute<void>(builder: (_) => const NotificationSettingsScreen()),
        ),
      ),
      _SettingItem(
        icon: Icons.security_rounded,
        title: 'Security & Privacy',
        subtitle: 'PIN lock, biometrics, amount masking',
        onTap: (ctx) => Navigator.of(ctx).push<void>(
          MaterialPageRoute<void>(builder: (_) => const SecuritySettingsScreen()),
        ),
      ),
      _SettingItem(
        icon: Icons.storage_rounded,
        title: 'Data Management',
        subtitle: 'Backups, export CSV/JSON, data wipe',
        onTap: (ctx) => Navigator.of(ctx).push<void>(
          MaterialPageRoute<void>(builder: (_) => const DataSettingsScreen()),
        ),
      ),
      _SettingItem(
        icon: Icons.auto_awesome_outlined,
        title: 'AI Features',
        subtitle: 'Gemini API integration, assistant features',
        onTap: (ctx) => Navigator.of(ctx).push<void>(
          MaterialPageRoute<void>(builder: (_) => const AiSettingsScreen()),
        ),
      ),
      _SettingItem(
        icon: Icons.security_rounded,
        title: 'System Permissions',
        subtitle: 'SMS monitoring, GPS maps, camera scanners',
        onTap: (ctx) => Navigator.of(ctx).push<void>(
          MaterialPageRoute<void>(builder: (_) => const PermissionsSettingsScreen()),
        ),
      ),
      _SettingItem(
        icon: Icons.science_rounded,
        title: 'Labs',
        subtitle: 'Experimental features — map, recurring, SMS, voice',
        onTap: (ctx) => Navigator.of(ctx).push<void>(
          MaterialPageRoute<void>(builder: (_) => const LabsScreen()),
        ),
      ),
      _SettingItem(
        icon: Icons.info_outline_rounded,
        title: 'About Expensio',
        subtitle: 'App version, credits, and support options',
        section: 'Information',
        onTap: (ctx) => Navigator.of(ctx).push<void>(
          MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final allItems = _getItems();
    final filtered = allItems.where((item) {
      if (_searchQuery.isEmpty) return true;
      return item.title.toLowerCase().contains(_searchQuery) ||
          item.subtitle.toLowerCase().contains(_searchQuery);
    }).toList();

    return UniversalScreenScaffold(
      topBar: UniversalTopBar(
        title: 'Settings',
        showBackButton: widget.showBackButton,
        showSearchToggle: true,
        isSearchOpen: _isSearchOpen,
        onSearchToggle: (open) {
          setState(() {
            _isSearchOpen = open;
            if (!open) {
              _searchQuery = '';
              _searchController.clear();
            }
          });
        },
        searchController: _searchController,
        searchHint: 'Search settings...',
        onSearchChanged: (val) {
          setState(() {
            _searchQuery = val.trim().toLowerCase();
          });
        },
        onSearchClear: () {
          setState(() {
            _searchQuery = '';
          });
        },
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 160),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (filtered.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    'No settings match your search.',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              )
            else ...[
              const SettingsSectionHeader(title: 'App Configuration'),
              SettingsCard(
                children: filtered
                    .where((i) => i.section == 'App Configuration')
                    .map(
                      (item) => SettingsActionTile(
                        icon: item.icon,
                        title: item.title,
                        subtitle: item.subtitle,
                        onTap: () => item.onTap(context),
                      ),
                    )
                    .toList(),
              ),
              if (filtered.any((i) => i.section == 'Information')) ...[
                const SizedBox(height: 24),
                const SettingsSectionHeader(title: 'Information'),
                SettingsCard(
                  children: filtered
                      .where((i) => i.section == 'Information')
                      .map(
                        (item) => SettingsActionTile(
                          icon: item.icon,
                          title: item.title,
                          subtitle: item.subtitle,
                          onTap: () => item.onTap(context),
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
