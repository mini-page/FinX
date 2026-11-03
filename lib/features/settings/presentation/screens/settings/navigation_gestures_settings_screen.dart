import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../shared/widgets/app_page_header.dart';
import '../../../../../shared/widgets/floating_nav_bar.dart';
import '../../provider/preferences_providers.dart';
import 'settings_widgets.dart';

/// Dedicated Settings page for customizing the bottom navigation bar (3 to 8 tabs)
/// and configuring Quick Add (+) button gestures (Tap, Double Tap, Long Press).
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
  void initState() {
    super.initState();
    _tabs = List<String>.from(ref.read(navbarTabsProvider));
  }

  void _onReorder(int oldIndex, int newIndex) {
    HapticFeedback.selectionClick();
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _tabs.removeAt(oldIndex);
      _tabs.insert(newIndex, item);
      _previewIndex = 0;
    });
    ref.read(appPreferencesControllerProvider).setNavbarTabs(_tabs);
  }

  void _removeTab(String tabId) {
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
      if (_previewIndex >= _tabs.length) {
        _previewIndex = 0;
      }
    });
    ref.read(appPreferencesControllerProvider).setNavbarTabs(_tabs);
  }

  void _addTab(String tabId) {
    if (_tabs.length >= 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum 8 navigation tabs allowed.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() {
      _tabs.add(tabId);
      _previewIndex = _tabs.length - 1;
    });
    ref.read(appPreferencesControllerProvider).setNavbarTabs(_tabs);
  }

  void _resetDefaults() {
    HapticFeedback.mediumImpact();
    setState(() {
      _tabs = List<String>.from(defaultNavBarTabIds);
      _previewIndex = 0;
    });
    ref.read(appPreferencesControllerProvider).setNavbarTabs(_tabs);
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(appPreferencesControllerProvider);
    final fabDoubleTap = ref.watch(fabDoubleTapActionProvider);
    final fabLongPress = ref.watch(fabLongPressActionProvider);

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
        title: 'Navigation & Gestures',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 60),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. PINNED NAVBAR LIVE PREVIEW CARD ─────────────────────────────
            _buildPinnedPreviewCard(previewTabs),
            const SizedBox(height: 28),

            // ── 2. QUICK ADD (+) BUTTON GESTURES ──────────────────────────────
            const SettingsSectionHeader(title: 'Quick Add (+) Button Gestures'),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                'Configure shortcuts triggered by interacting with the floating Quick Add button on Home.',
                style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.8), fontSize: 13),
              ),
            ),
            SettingsCard(
              children: [
                ListTile(
                  leading: const SettingsTileIcon(icon: Icons.touch_app_rounded),
                  title: const Text(
                    'Single Tap',
                    style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Open new transaction logging form',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Add Transaction',
                      style: TextStyle(
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                ListTile(
                  leading: const SettingsTileIcon(icon: Icons.gesture_rounded),
                  title: const Text(
                    'Double Tap Action',
                    style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Action triggered on double-tapping + button',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                  trailing: SettingsChoiceMenu(
                    value: fabDoubleTap,
                    sheetTitle: 'Double Tap Action',
                    onChanged: (val) {
                      if (val != null) controller.setFabDoubleTapAction(val);
                    },
                    options: _fabActionOptions,
                  ),
                ),
                ListTile(
                  leading: const SettingsTileIcon(icon: Icons.pan_tool_rounded),
                  title: const Text(
                    'Long Press Action',
                    style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Action triggered on holding + button',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
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
            const SizedBox(height: 28),

            // ── 3. BOTTOM NAVIGATION TABS (3 TO 8) ────────────────────────────
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
                'Drag handles to reorder. You can add between 3 and 8 tools to your bottom bar. Tabs display without top back buttons when active.',
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

                return Container(
                  key: ValueKey(tabId),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
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
                            Text(
                              data.label,
                              style: const TextStyle(
                                color: AppColors.textDark,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
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

            // ── 4. ADD TOOLS TO NAVIGATION BAR ────────────────────────────────
            if (availableToAdd.isNotEmpty && _tabs.length < 8) ...[
              const SizedBox(height: 24),
              const SettingsSectionHeader(title: 'Add from Finance Tools & Hub'),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 12),
                child: Text(
                  'Tap "+ Add" to include any tool directly into your bottom bar (up to 8 total):',
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
            ] else if (_tabs.length >= 8) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: AppColors.primaryBlue, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Maximum of 8 tabs reached. Remove a tab above to add a different tool.',
                        style: TextStyle(
                          color: Color(0xFF1E3A8A),
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
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
                    '${previewTabs.length} of 8 Tabs',
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
