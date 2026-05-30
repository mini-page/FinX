import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';

import '../../../../../core/theme/app_tokens.dart';
import '../../../../../shared/widgets/app_filter_sheet.dart';

/// Section header label used to group settings rows.
class SettingsSectionHeader extends StatelessWidget {
  const SettingsSectionHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppColors.primaryBlue,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

/// White rounded card that groups settings list tiles.
class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: children.map((child) {
          final index = children.indexOf(child);
          final isLast = index == children.length - 1;
          if (isLast) return child;
          return Column(
            children: <Widget>[
              child,
              const Divider(height: 1, indent: 70, endIndent: 20),
            ],
          );
        }).toList(),
      ),
    );
  }
}

/// Small rounded icon container used as the leading widget in settings tiles.
class SettingsTileIcon extends StatelessWidget {
  const SettingsTileIcon({super.key, required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.lightBlueBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: AppColors.primaryBlue, size: 22),
    );
  }
}

class SettingsToggleTile extends StatelessWidget {
  const SettingsToggleTile({
    super.key,
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
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primaryBlue,
      ),
    );
  }
}

class SettingsActionTile extends StatelessWidget {
  const SettingsActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
      trailing: trailing ??
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
      onTap: onTap,
    );
  }
}

class SettingsDangerTile extends StatelessWidget {
  const SettingsDangerTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
      onTap: onTap,
    );
  }
}

class SettingsChoiceMenu extends StatelessWidget {
  const SettingsChoiceMenu({
    super.key,
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


