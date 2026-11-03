import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../shared/widgets/app_bottom_sheet.dart';
import '../../../../../shared/widgets/floating_nav_bar.dart';
import '../../provider/preferences_providers.dart';

/// Bottom sheet allowing users to customize, reorder, add, and remove navigation bar tabs.
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
          content: Text('Minimum 3 tabs required in the navigation bar.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() {
      _tabs.remove(tabId);
      _previewIndex = 0;
    });
    ref.read(appPreferencesControllerProvider).setNavbarTabs(_tabs);
  }

  void _addTab(String tabId) {
    if (_tabs.length >= 7) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum 7 tabs allowed in the navigation bar.'),
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
    final availableToAdd = kAllAvailableNavBarTabs.keys
        .where((id) => !_tabs.contains(id))
        .toList();

    final previewTabs = _tabs
        .map((id) => kAllAvailableNavBarTabs[id])
        .whereType<NavBarTabData>()
        .toList();

    return AppBottomSheetContainer(
      title: 'Customize Navigation Bar',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Drag and drop to reorder tabs. Add tools directly from the Finance Hub to access them from the home bar without top back buttons.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),

          // Live Preview Card
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Text(
                    'LIVE PREVIEW',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                FloatingNavBar(
                  selectedIndex: _previewIndex.clamp(0, previewTabs.length - 1),
                  onTap: (index) {
                    setState(() => _previewIndex = index);
                  },
                  tabs: previewTabs,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Active Tabs Header
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

              return Container(
                key: ValueKey(tabId),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
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
                        color: AppColors.primaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        data.activeIcon,
                        color: AppColors.primaryBlue,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        data.label,
                        style: const TextStyle(
                          color: AppColors.textDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.remove_circle_outline_rounded,
                        color: AppColors.danger,
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
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          data.icon,
                          color: const Color(0xFF64748B),
                          size: 20,
                        ),
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
                      IconButton(
                        icon: const Icon(
                          Icons.add_circle_outline_rounded,
                          color: AppColors.success,
                          size: 22,
                        ),
                        tooltip: 'Add to Navbar',
                        onPressed: () => _addTab(tabId),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Save Navigation',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
