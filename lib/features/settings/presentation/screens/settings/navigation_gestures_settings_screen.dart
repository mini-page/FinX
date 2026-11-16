import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../shared/widgets/app_page_header.dart';
import '../../../../../shared/widgets/floating_nav_bar.dart';
import '../../provider/preferences_providers.dart';
import 'settings_widgets.dart';

/// Dedicated Settings page for customizing the bottom navigation bar tabs.
/// Rules enforced:
/// 1. Home cannot be disabled, removed, or reordered; always first (index 0).
/// 2. Tools tab cannot be removed or disabled, but can be reordered (indices 1..N).
/// 3. Minimum 3 tabs; maximum can include any available tools without restriction.
class NavigationGesturesSettingsScreen extends ConsumerStatefulWidget {
  const NavigationGesturesSettingsScreen({super.key});

  @override
  ConsumerState<NavigationGesturesSettingsScreen> createState() =>
      _NavigationGesturesSettingsScreenState();
}

class _NavigationGesturesSettingsScreenState
    extends ConsumerState<NavigationGesturesSettingsScreen> {
  late List<String> _tabs;
  int _previewIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabs = List<String>.from(ref.read(navbarTabsProvider));
    _ensureRules();
  }

  void _ensureRules() {
    // Rule 1: Home must be at index 0
    _tabs.remove('home');
    _tabs.insert(0, 'home');
    // Rule 2: Tools must be present
    if (!_tabs.contains('tools')) {
      _tabs.add('tools');
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    // Rule 1: Home cannot be reordered or moved
    if (oldIndex == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Home is permanently fixed as the first tab.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (newIndex <= 0) {
      newIndex = 1;
    }

    HapticFeedback.selectionClick();
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _tabs.removeAt(oldIndex);
      _tabs.insert(newIndex, item);
      _ensureRules();
      _previewIndex = 0;
    });
    ref.read(appPreferencesControllerProvider).setNavbarTabs(_tabs);
  }

  void _removeTab(String tabId) {
    if (tabId == 'home') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Home tab cannot be removed or disabled.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    if (tabId == 'tools') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tools tab is required and cannot be removed.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    if (_tabs.length <= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Minimum 3 navigation tabs required.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() {
      _tabs.remove(tabId);
      _ensureRules();
      if (_previewIndex >= _tabs.length) {
        _previewIndex = 0;
      }
    });
    ref.read(appPreferencesControllerProvider).setNavbarTabs(_tabs);
  }

  void _addTab(String tabId) {
    HapticFeedback.mediumImpact();
    setState(() {
      _tabs.add(tabId);
      _ensureRules();
      _previewIndex = _tabs.length - 1;
    });
    ref.read(appPreferencesControllerProvider).setNavbarTabs(_tabs);
  }

  void _resetDefaults() {
    HapticFeedback.mediumImpact();
    setState(() {
      _tabs = List<String>.from(defaultNavBarTabIds);
      _ensureRules();
      _previewIndex = 0;
    });
    ref.read(appPreferencesControllerProvider).setNavbarTabs(_tabs);
  }

  @override
  Widget build(BuildContext context) {
    final availableToAdd = kAllAvailableNavBarTabs.keys
        .where((id) => !_tabs.contains(id))
        .toList();

    final previewTabs = _tabs
        .map((id) => kAllAvailableNavBarTabs[id])
        .whereType<NavBarTabData>()
        .toList();

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: const GradientAppBar(
        title: 'Navigation Tabs',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 60),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. PINNED NAVBAR LIVE PREVIEW CARD ─────────────────────────────
            _buildPinnedPreviewCard(previewTabs),
            const SizedBox(height: 28),

            // ── 2. ACTIVE NAVIGATION TABS (REORDERABLE) ────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SettingsSectionHeader(title: 'Active Navigation Tabs'),
                TextButton.icon(
                  onPressed: _resetDefaults,
                  icon: const Icon(Icons.refresh_rounded, size: 16, color: AppColors.primaryBlue),
                  label: const Text(
                    'Reset Defaults',
                    style: TextStyle(
                      color: AppColors.primaryBlue,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                'Home is locked first. Drag handles to reorder your other tools (minimum 3 tabs required).',
                style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.8), fontSize: 13),
              ),
            ),

            // Reorderable list of active tabs
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _tabs.length,
              onReorder: _onReorder,
              itemBuilder: (context, index) {
                final tabId = _tabs[index];
                final data = kAllAvailableNavBarTabs[tabId];
                if (data == null) return SizedBox.shrink(key: ValueKey(tabId));

                final isHome = tabId == 'home';
                final isTools = tabId == 'tools';

                return Container(
                  key: ValueKey(tabId),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isHome
                          ? AppColors.primaryBlue.withValues(alpha: 0.25)
                          : const Color(0xFFE2E8F0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      if (isHome)
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.lock_rounded,
                            color: AppColors.primaryBlue,
                            size: 18,
                          ),
                        )
                      else
                        ReorderableDragStartListener(
                          index: index,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.drag_indicator_rounded,
                              color: Color(0xFF64748B),
                              size: 20,
                            ),
                          ),
                        ),
                      const SizedBox(width: 12),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: data.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          data.activeIcon,
                          color: data.color,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  data.label,
                                  style: const TextStyle(
                                    color: AppColors.textDark,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (isHome) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryBlue.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'Locked (First)',
                                      style: TextStyle(
                                        color: AppColors.primaryBlue,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ] else if (isTools) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'Required',
                                      style: TextStyle(
                                        color: Color(0xFF0EA5E9),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (data.subtitle != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                data.subtitle!,
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (isHome)
                        const SizedBox(width: 48)
                      else if (isTools)
                        const Tooltip(
                          message: 'Tools tab cannot be removed',
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Icon(
                              Icons.verified_user_outlined,
                              color: Color(0xFF94A3B8),
                              size: 20,
                            ),
                          ),
                        )
                      else
                        IconButton(
                          icon: Icon(
                            Icons.remove_circle_outline_rounded,
                            color: _tabs.length > 3 ? AppColors.danger : const Color(0xFFCBD5E1),
                            size: 22,
                          ),
                          tooltip: _tabs.length > 3 ? 'Remove Tab' : 'Minimum 3 tabs required',
                          onPressed: _tabs.length > 3 ? () => _removeTab(tabId) : null,
                        ),
                    ],
                  ),
                );
              },
            ),

            // ── 3. ADD TOOLS TO NAVIGATION BAR ────────────────────────────────
            if (availableToAdd.isNotEmpty) ...[
              const SizedBox(height: 24),
              const SettingsSectionHeader(title: 'Add from Finance Tools & Hub'),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 12),
                child: Text(
                  'Tap "+ Add" to include any tool directly into your bottom bar:',
                  style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.8), fontSize: 13),
                ),
              ),
              SettingsCard(
                children: availableToAdd.map((tabId) {
                  final data = kAllAvailableNavBarTabs[tabId];
                  if (data == null) return const SizedBox.shrink();

                  return ListTile(
                    leading: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: data.color.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(data.icon, color: data.color, size: 20),
                    ),
                    title: Text(
                      data.label,
                      style: const TextStyle(
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                      ),
                    ),
                    subtitle: data.subtitle != null
                        ? Text(
                            data.subtitle!,
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                          )
                        : null,
                    trailing: TextButton.icon(
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.08),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                      onPressed: () => _addTab(tabId),
                      icon: const Icon(Icons.add_rounded, size: 16, color: AppColors.primaryBlue),
                      label: const Text(
                        'Add',
                        style: TextStyle(
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPinnedPreviewCard(List<NavBarTabData> previewTabs) {
    final isScrollable = previewTabs.length > 5;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.visibility_rounded,
                        size: 16,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'NAVBAR LIVE PREVIEW',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryBlue,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${previewTabs.length} Tabs Active',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // The actual floating bar rendered inside the card
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Column(
              children: [
                FloatingNavBar(
                  tabs: previewTabs,
                  selectedIndex: _previewIndex.clamp(0, previewTabs.length - 1),
                  onTap: (index) {
                    setState(() {
                      _previewIndex = index;
                    });
                  },
                ),
                if (isScrollable) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.swipe_rounded, size: 13, color: AppColors.textMuted),
                      const SizedBox(width: 5),
                      Text(
                        'Horizontal scrollable row (${previewTabs.length} tabs)',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
