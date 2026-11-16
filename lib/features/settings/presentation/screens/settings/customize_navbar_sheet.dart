import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../shared/widgets/app_bottom_sheet.dart';
import '../../../../../shared/widgets/floating_nav_bar.dart';
import '../../provider/preferences_providers.dart';

/// Bottom sheet allowing users to customize, reorder, add, and remove navigation bar tabs.
/// Rules enforced:
/// 1. Home cannot be disabled, removed, or reordered; always first (index 0).
/// 2. Tools tab cannot be removed or disabled, but can be reordered (indices 1..N).
/// 3. Minimum 3 tabs; maximum can include any available tools without restriction.
class CustomizeNavBarSheet extends ConsumerStatefulWidget {
  const CustomizeNavBarSheet({super.key});

  @override
  ConsumerState<CustomizeNavBarSheet> createState() =>
      _CustomizeNavBarSheetState();
}

class _CustomizeNavBarSheetState extends ConsumerState<CustomizeNavBarSheet> {
  late List<String> _tabs;
  int _previewIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabs = List<String>.from(ref.read(navbarTabsProvider));
    _ensureRules();
  }

  void _ensureRules() {
    _tabs.remove('home');
    _tabs.insert(0, 'home');
    if (!_tabs.contains('tools')) {
      _tabs.add('tools');
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
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
      _previewIndex = 0;
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

    return AppBottomSheetContainer(
      title: 'Customize Navigation Bar',
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Home is locked first. Drag to reorder other tabs, and add any finance tools to access directly from your bottom bar.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),

            // Pinned preview
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: FloatingNavBar(
                tabs: previewTabs,
                selectedIndex: _previewIndex.clamp(0, previewTabs.length - 1),
                onTap: (index) {
                  setState(() {
                    _previewIndex = index;
                  });
                },
              ),
            ),
            const SizedBox(height: 20),

            // Section header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Active Tabs (${_tabs.length})',
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextButton(
                  onPressed: _resetDefaults,
                  child: const Text(
                    'Reset Default',
                    style: TextStyle(
                      color: AppColors.primaryBlue,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

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
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isHome
                          ? AppColors.primaryBlue.withValues(alpha: 0.25)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (isHome)
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.lock_rounded,
                            color: AppColors.primaryBlue,
                            size: 16,
                          ),
                        )
                      else
                        ReorderableDragStartListener(
                          index: index,
                          child: const Icon(
                            Icons.drag_handle_rounded,
                            color: Color(0xFF94A3B8),
                            size: 20,
                          ),
                        ),
                      const SizedBox(width: 12),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: data.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          data.activeIcon,
                          color: data.color,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Row(
                          children: [
                            Text(
                              data.label,
                              style: const TextStyle(
                                color: AppColors.textDark,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (isHome) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryBlue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Locked',
                                  style: TextStyle(
                                    color: AppColors.primaryBlue,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ] else if (isTools) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Required',
                                  style: TextStyle(
                                    color: Color(0xFF0EA5E9),
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (isHome)
                        const SizedBox(width: 36)
                      else if (isTools)
                        const Tooltip(
                          message: 'Tools cannot be removed',
                          child: Icon(
                            Icons.verified_user_outlined,
                            color: Color(0xFF94A3B8),
                            size: 18,
                          ),
                        )
                      else
                        IconButton(
                          icon: Icon(
                            Icons.remove_circle_outline_rounded,
                            color: _tabs.length > 3 ? AppColors.danger : const Color(0xFFCBD5E1),
                            size: 20,
                          ),
                          tooltip: 'Remove',
                          onPressed: _tabs.length > 3 ? () => _removeTab(tabId) : null,
                        ),
                    ],
                  ),
                );
              },
            ),

            if (availableToAdd.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                'Add from Finance Hub & Tools',
                style: TextStyle(
                  color: AppColors.textDark,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: availableToAdd.length,
                itemBuilder: (context, index) {
                  final tabId = availableToAdd[index];
                  final data = kAllAvailableNavBarTabs[tabId];
                  if (data == null) return const SizedBox.shrink();

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: data.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(data.icon, color: data.color, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            data.label,
                            style: const TextStyle(
                              color: AppColors.textDark,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _addTab(tabId),
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('Add'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primaryBlue,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
