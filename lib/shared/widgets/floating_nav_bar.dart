import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';

/// A pill-shaped floating bottom navigation bar.
///
/// Used by [AppShell] as the app-wide tab switcher.
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.md,
        ),
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Row(
              children: <Widget>[
                NavBarItem(
                  label: 'Home',
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  isSelected: selectedIndex == 0,
                  onTap: () => onTap(0),
                ),
                const SizedBox(width: AppSpacing.xs),
                NavBarItem(
                  label: 'Charts',
                  icon: Icons.pie_chart_outline_rounded,
                  activeIcon: Icons.pie_chart_rounded,
                  isSelected: selectedIndex == 1,
                  onTap: () => onTap(1),
                ),
                const SizedBox(width: AppSpacing.xs),
                NavBarItem(
                  label: 'Category',
                  icon: Icons.grid_view_outlined,
                  activeIcon: Icons.grid_view_rounded,
                  isSelected: selectedIndex == 2,
                  onTap: () => onTap(2),
                ),
                const SizedBox(width: AppSpacing.xs),
                NavBarItem(
                  label: 'Tools',
                  icon: Icons.tune_outlined,
                  activeIcon: Icons.tune_rounded,
                  isSelected: selectedIndex == 3,
                  onTap: () => onTap(3),
                ),
                const SizedBox(width: AppSpacing.xs),
                NavBarItem(
                  label: 'Settings',
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings_rounded,
                  isSelected: selectedIndex == 4,
                  onTap: () => onTap(4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A single animated tab item inside [FloatingNavBar].
class NavBarItem extends StatelessWidget {
  const NavBarItem({
    super.key,
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.fastOutSlowIn,
        padding: isSelected
            ? const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 10,
              )
            : const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? Colors.white : AppColors.textMuted,
              size: 24,
            ),
            if (isSelected) ...<Widget>[
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
