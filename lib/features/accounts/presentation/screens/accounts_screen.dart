import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../routes/app_routes.dart';
import '../../../tags/presentation/screens/tags_screen.dart';
import '../../../expense/presentation/screens/voice_entry_screen.dart';
import '../../../expense/presentation/screens/notifications_screen.dart';
import '../../../settings/presentation/screens/support_screen.dart';
import '../../../settings/presentation/screens/settings/permissions_settings_screen.dart';
import '../../../settings/presentation/screens/settings/ai_settings_screen.dart';
import '../../../sms_parser/presentation/screens/sms_settings_sheet.dart';
import 'tools_pages/savings_goals_screen.dart';
import 'tools_pages/split_bill_screen.dart';
import 'tools_pages/subscriptions_screen.dart';
import 'tools_pages/location_map_screen.dart';
import '../../../../shared/widgets/app_search_bar.dart';

class _ToolItem {
  const _ToolItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final void Function(BuildContext context) onTap;
}

class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_ToolItem> _getTools() {
    return [
      _ToolItem(
        icon: Icons.add_rounded,
        label: 'Add',
        color: const Color(0xFF6366F1), // Indigo
        onTap: (context) => AppRoutes.pushAddExpense(context),
      ),
      _ToolItem(
        icon: Icons.receipt_long_rounded,
        label: 'History',
        color: const Color(0xFF0EA5E9), // Sky Blue
        onTap: (context) => AppRoutes.pushRecordsHistory(context),
      ),
      _ToolItem(
        icon: Icons.calendar_month_rounded,
        label: 'Calendar',
        color: const Color(0xFF8B5CF6), // Purple
        onTap: (context) => AppRoutes.pushCalendarView(context),
      ),
      _ToolItem(
        icon: Icons.map_rounded,
        label: 'Map',
        color: const Color(0xFF10B981), // Emerald Green
        onTap: (context) => Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => const LocationMapScreen(),
          ),
        ),
      ),
      _ToolItem(
        icon: Icons.call_split_rounded,
        label: 'Split',
        color: const Color(0xFFF59E0B), // Amber
        onTap: (context) => Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => const SplitBillScreen(),
          ),
        ),
      ),
      _ToolItem(
        icon: Icons.emoji_events_rounded,
        label: 'Goals',
        color: const Color(0xFFEF4444), // Rose Red
        onTap: (context) => Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => const SavingsGoalsScreen(),
          ),
        ),
      ),
      _ToolItem(
        icon: Icons.repeat_rounded,
        label: 'Recurring',
        color: const Color(0xFFEC4899), // Pink
        onTap: (context) => Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => const SubscriptionsScreen(),
          ),
        ),
      ),
      _ToolItem(
        icon: Icons.label_rounded,
        label: 'Tags',
        color: const Color(0xFF3B82F6), // Blue
        onTap: (context) => Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => const TagsScreen(),
          ),
        ),
      ),
      _ToolItem(
        icon: Icons.qr_code_scanner_rounded,
        label: 'Scan',
        color: const Color(0xFF14B8A6), // Teal
        onTap: (context) => AppRoutes.pushUnifiedScanner(context),
      ),
      _ToolItem(
        icon: Icons.qr_code_rounded,
        label: 'Pay',
        color: const Color(0xFF06B6D4), // Cyan
        onTap: (context) => AppRoutes.pushUpiScanner(context),
      ),
      _ToolItem(
        icon: Icons.mic_rounded,
        label: 'Voice',
        color: const Color(0xFFD946EF), // Fuchsia
        onTap: (context) => showVoiceEntrySheet(context),
      ),
      _ToolItem(
        icon: Icons.sms_rounded,
        label: 'SMS Sync',
        color: const Color(0xFF10B981), // Emerald Green
        onTap: (context) => showSmsSettingsSheet(context),
      ),
      _ToolItem(
        icon: Icons.notifications_rounded,
        label: 'Alerts',
        color: const Color(0xFFF43F5E), // Rose/Pink
        onTap: (context) => AppRoutes.pushNotifications(context),
      ),
      _ToolItem(
        icon: Icons.auto_awesome_rounded,
        label: 'AI Setup',
        color: const Color(0xFF8B5CF6), // Violet/Indigo
        onTap: (context) => Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => const AiSettingsScreen(),
          ),
        ),
      ),
      _ToolItem(
        icon: Icons.security_rounded,
        label: 'Security',
        color: const Color(0xFF0EA5E9), // Sky Blue
        onTap: (context) => Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => const PermissionsSettingsScreen(),
          ),
        ),
      ),
      _ToolItem(
        icon: Icons.favorite_rounded,
        label: 'Support',
        color: const Color(0xFFF43F5E), // Ruby/Rose
        onTap: (context) => Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => const SupportScreen(),
          ),
        ),
      ),
      _ToolItem(
        icon: Icons.settings_rounded,
        label: 'Settings',
        color: const Color(0xFF64748B), // Slate/Gray
        onTap: (context) => AppRoutes.pushSettings(context),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final allTools = _getTools();
    final filteredTools = allTools.where((t) {
      if (_searchQuery.isEmpty) return true;
      return t.label.toLowerCase().contains(_searchQuery);
    }).toList();

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient matching the mock theme
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFEDE9FE), // Soft Lavender/Purple
                    Color(0xFFFAF5FF), // Lighter Purple
                    Colors.white,      // Pure White at bottom
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.25, 0.6],
                ),
              ),
            ),
          ),
          
          // Main Body
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header (mock Select Category style)
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 24, 20, 16),
                  child: Center(
                    child: Text(
                      'Finance Tools',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textDark,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ),

                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: AppSearchBar(
                    controller: _searchController,
                    hintText: 'Search for tools...',
                  ),
                ),
                const SizedBox(height: 28),

                // Grid View / Empty State
                Expanded(
                  child: filteredTools.isEmpty
                      ? const Center(
                          child: Text(
                            'No tools match your search.',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisSpacing: 24,
                            crossAxisSpacing: 16,
                            childAspectRatio: 0.68,
                          ),
                          itemCount: filteredTools.length,
                          itemBuilder: (context, index) {
                            return _buildGridItem(context, filteredTools[index]);
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridItem(BuildContext context, _ToolItem item) {
    return GestureDetector(
      onTap: () => item.onTap(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // White Card Icon Container
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(
              item.icon,
              color: item.color,
              size: 28,
            ),
          ),
          const SizedBox(height: 6),
          // Label text
          Text(
            item.label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
