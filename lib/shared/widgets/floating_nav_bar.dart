import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';

/// Data representing a single navigation bar tab item.
class NavBarTabData {
  const NavBarTabData({
    required this.id,
    required this.label,
    required this.icon,
    required this.activeIcon,
    this.subtitle,
    this.color = AppColors.primaryBlue,
  });

  final String id;
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String? subtitle;
  final Color color;
}

/// Available catalog of customizable tabs in Expensio.
const Map<String, NavBarTabData> kAllAvailableNavBarTabs = {
  'home': NavBarTabData(
    id: 'home',
    label: 'Home',
    icon: Icons.home_outlined,
    activeIcon: Icons.home_rounded,
    subtitle: 'Overview, date strip & logs',
    color: AppColors.primaryBlue,
  ),
  'charts': NavBarTabData(
    id: 'charts',
    label: 'Charts',
    icon: Icons.pie_chart_outline_rounded,
    activeIcon: Icons.pie_chart_rounded,
    subtitle: 'Cash flow trends & analysis',
    color: Color(0xFF6366F1),
  ),
  'category': NavBarTabData(
    id: 'category',
    label: 'Category',
    icon: Icons.grid_view_outlined,
    activeIcon: Icons.grid_view_rounded,
    subtitle: 'Category limits & distribution',
    color: Color(0xFF8B5CF6),
  ),
  'tools': NavBarTabData(
    id: 'tools',
    label: 'Tools',
    icon: Icons.tune_outlined,
    activeIcon: Icons.tune_rounded,
    subtitle: 'Finance tools & 16 utilities',
    color: Color(0xFF0EA5E9),
  ),
  'subscriptions': NavBarTabData(
    id: 'subscriptions',
    label: 'Recurring',
    icon: Icons.autorenew_outlined,
    activeIcon: Icons.autorenew_rounded,
    subtitle: 'Subscriptions & scheduled bills',
    color: Color(0xFF10B981),
  ),
  'split_bill': NavBarTabData(
    id: 'split_bill',
    label: 'Split Bill',
    icon: Icons.call_split_rounded,
    activeIcon: Icons.call_split_rounded,
    subtitle: 'Split expenses & settlements',
    color: Color(0xFFF59E0B),
  ),
  'budget': NavBarTabData(
    id: 'budget',
    label: 'Budget',
    icon: Icons.account_balance_wallet_outlined,
    activeIcon: Icons.account_balance_wallet_rounded,
    subtitle: 'Monthly targets & limits',
    color: Color(0xFF22C55E),
  ),
  'goals': NavBarTabData(
    id: 'goals',
    label: 'Goals',
    icon: Icons.emoji_events_outlined,
    activeIcon: Icons.emoji_events_rounded,
    subtitle: 'Savings targets & progress',
    color: Color(0xFFEC4899),
  ),
  'radar': NavBarTabData(
    id: 'radar',
    label: 'Radar',
    icon: Icons.radar_outlined,
    activeIcon: Icons.radar_rounded,
    subtitle: 'Location-based expense sonar',
    color: Color(0xFF06B6D4),
  ),
  'accounts': NavBarTabData(
    id: 'accounts',
    label: 'Accounts',
    icon: Icons.account_balance_outlined,
    activeIcon: Icons.account_balance_rounded,
    subtitle: 'Bank & wallet balances',
    color: Color(0xFF3B82F6),
  ),
  'settings': NavBarTabData(
    id: 'settings',
    label: 'Settings',
    icon: Icons.settings_outlined,
    activeIcon: Icons.settings_rounded,
    subtitle: 'Preferences & system security',
    color: Color(0xFF64748B),
  ),
};

final List<NavBarTabData> defaultNavBarTabsList = [
  kAllAvailableNavBarTabs['home']!,
  kAllAvailableNavBarTabs['charts']!,
  kAllAvailableNavBarTabs['category']!,
  kAllAvailableNavBarTabs['tools']!,
  kAllAvailableNavBarTabs['settings']!,
];

/// A pill-shaped floating bottom navigation bar with perfect curved containment.
class FloatingNavBar extends StatefulWidget {
  const FloatingNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
    this.tabs,
  });

  final int selectedIndex;
  final ValueChanged<int> onTap;
  final List<NavBarTabData>? tabs;

  @override
  State<FloatingNavBar> createState() => _FloatingNavBarState();
}

class _FloatingNavBarState extends State<FloatingNavBar> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoScroll());
  }

  @override
  void didUpdateWidget(covariant FloatingNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _autoScroll());
    }
  }

  void _autoScroll() {
    if (!_scrollController.hasClients) return;
    final activeTabs = widget.tabs != null && widget.tabs!.isNotEmpty
        ? widget.tabs!
        : defaultNavBarTabsList;
    if (activeTabs.length <= 5) return;

    double target = 0;
    for (int i = 0; i < widget.selectedIndex; i++) {
      target += 48.0;
    }
    target -= 36.0;
    if (target < 0) target = 0;
    if (target > _scrollController.position.maxScrollExtent) {
      target = _scrollController.position.maxScrollExtent;
    }
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeTabs = widget.tabs != null && widget.tabs!.isNotEmpty
        ? widget.tabs!
        : defaultNavBarTabsList;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Container(
          height: 62,
          clipBehavior: Clip.antiAlias,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x18000000),
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isScrollable = activeTabs.length > 5;

              Widget content = Row(
                mainAxisAlignment: isScrollable
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.spaceEvenly,
                mainAxisSize:
                    isScrollable ? MainAxisSize.min : MainAxisSize.max,
                children: [
                  for (int i = 0; i < activeTabs.length; i++) ...[
                    NavBarItem(
                      label: activeTabs[i].label,
                      icon: activeTabs[i].icon,
                      activeIcon: activeTabs[i].activeIcon,
                      isSelected: widget.selectedIndex == i,
                      onTap: () => widget.onTap(i),
                    ),
                    if (isScrollable && i < activeTabs.length - 1)
                      const SizedBox(width: 4),
                  ],
                ],
              );

              if (isScrollable) {
                return SingleChildScrollView(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: content,
                );
              }
              return content;
            },
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
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        padding: isSelected
            ? const EdgeInsets.symmetric(horizontal: 13, vertical: 7)
            : const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? Colors.white : AppColors.textMuted,
              size: 22,
            ),
            if (isSelected) ...<Widget>[
              const SizedBox(width: 6),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
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
