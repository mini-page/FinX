import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/widget_sync_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../routes/app_routes.dart';
import '../../../../shared/widgets/floating_nav_bar.dart';
import '../../data/models/expense_model.dart';
import '../provider/expense_providers.dart';
import 'package:xpens/features/settings/presentation/provider/preferences_providers.dart';
import '../widgets/power_pill_menu.dart';
import 'package:xpens/features/accounts/accounts.dart';
import 'package:xpens/features/categories/presentation/screens/categories_screen.dart';
import 'home_screen.dart';
import 'package:xpens/features/analytics/presentation/screens/stats_screen.dart';
import 'voice_entry_screen.dart';
import '../../../sms_parser/presentation/screens/sms_settings_sheet.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _selectedIndex = 0;
  bool _navBarVisible = true;
  double _lastScrollOffset = 0;
  StreamSubscription<Uri?>? _widgetClickedSub;

  void _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      final metrics = notification.metrics;
      final delta = metrics.pixels - _lastScrollOffset;
      _lastScrollOffset = metrics.pixels;
      if (delta > 3 && _navBarVisible) {
        setState(() => _navBarVisible = false);
      } else if (delta < -3 && !_navBarVisible) {
        setState(() => _navBarVisible = true);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // Listen for widget taps while the app is running (foreground/background).
    _widgetClickedSub = HomeWidget.widgetClicked.listen(_handleWidgetUri);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkWhatsNew();
      // Handle the case where the app was cold-launched by a widget tap.
      HomeWidget.initiallyLaunchedFromHomeWidget().then(_handleWidgetUri);
      // Perform an initial widget sync now that providers are available.
      _syncWidgetDataNow();
    });
  }

  @override
  void dispose() {
    _widgetClickedSub?.cancel();
    super.dispose();
  }

  void _checkWhatsNew() {
    final prefs = ref.read(appPreferencesProvider).value;
    if (prefs == null) return;
    if (prefs.whatsNewShownVersion == AppConstants.version) return;

    ref
        .read(appPreferencesControllerProvider)
        .setWhatsNewShownVersion(AppConstants.version);

    _showWhatsNewModal();
  }

  void _showWhatsNewModal() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle + close button row
            Row(
              children: [
                const Spacer(),
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAccent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: const Icon(Icons.close_rounded,
                      color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.new_releases_rounded,
                    color: AppColors.primaryBlue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "What's New",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        'Version ${AppConstants.version}',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...const [
              _WhatsNewItem(
                emoji: '🔒',
                title: 'PIN Lock',
                detail: 'Secure your app with a 4-digit PIN',
              ),
              _WhatsNewItem(
                emoji: '🏷️',
                title: 'Transaction Tags',
                detail: 'Add #tags to notes and filter by them in Records',
              ),
              _WhatsNewItem(
                emoji: '🎯',
                title: 'Savings Goals',
                detail: 'Track milestones in the new Goals tab under Tools',
              ),
              _WhatsNewItem(
                emoji: '📊',
                title: 'Budget Progress Bar',
                detail: 'See your top budget right on the home header',
              ),
              _WhatsNewItem(
                emoji: '📅',
                title: 'Date Range Filter',
                detail: 'Custom date ranges for Records and Stats',
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  "Let's go!",
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPages() {
    return [
      const HomeScreen(),
      StatsScreen(),
      const CategoriesScreen(),
      const AccountsScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final pages = _buildPages();

    // ── Sync widget data whenever accounts / expenses / currency change ──
    ref.listen<WidgetDataPayload?>(
      widgetDataPayloadProvider,
      (_, payload) {
        if (payload != null) {
          WidgetSyncService.syncData(payload);
        }
      },
    );

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              _onScrollNotification(notification);
              return false;
            },
            child: IndexedStack(index: _selectedIndex, children: pages),
          ),
          // Bottom Gradient Overlay for Navbar Contrast
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            left: 0,
            right: 0,
            bottom: _navBarVisible ? 0 : -100,
            height: 120,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.backgroundLight.withValues(alpha: 0.0),
                      AppColors.backgroundLight.withValues(alpha: 0.8),
                      AppColors.backgroundLight,
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Power FAB — direct add expense
          Positioned(
            right: 16,
            bottom: 96,
            child: PowerFab(
              onQuickAdd: _openAddExpenseScreen,
            ),
          ),
          // NavBar — auto-hides on scroll down
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            left: 0,
            right: 0,
            bottom: _navBarVisible ? 0 : -100,
            child: FloatingNavBar(
              selectedIndex: _selectedIndex,
              onTap: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openAddExpenseScreen() async {
    await AppRoutes.pushAddExpense(context);
  }

  /// Push the current widget payload (if available) once on startup so the
  /// widget shows data immediately without waiting for a state change.
  void _syncWidgetDataNow() {
    final payload = ref.read(widgetDataPayloadProvider);
    if (payload != null) {
      WidgetSyncService.syncData(payload);
    }
  }

  // ── Widget action routing ────────────────────────────────────────────

  /// Handles a widget-click URI emitted by [HomeWidget.widgetClicked] or
  /// returned by [HomeWidget.initiallyLaunchedFromHomeWidget].
  ///
  /// Expected URI format: `xpens://widget?action=<action>`
  void _handleWidgetUri(Uri? uri) {
    if (uri == null || !mounted) return;
    final action = uri.queryParameters['action'];
    if (action == null) return;
    _routeWidgetAction(action);
  }

  Future<void> _routeWidgetAction(String action) async {
    switch (action) {
      case 'add_expense':
        await AppRoutes.pushAddExpense(
          context,
          initialType: TransactionType.expense,
        );
      case 'add_income':
        await AppRoutes.pushAddExpense(
          context,
          initialType: TransactionType.income,
        );
      case 'add_transfer':
        await AppRoutes.pushAddExpense(
          context,
          initialType: TransactionType.transfer,
        );
      case 'scanner':
        if (mounted) await AppRoutes.pushScanner(context);
      case 'voice':
        if (mounted) await _showVoiceEntry();
      case 'sms':
        if (mounted) await showSmsSettingsSheet(context);
      // 'open_app' — just bring app to foreground, no extra navigation needed
    }
  }

  Future<void> _showVoiceEntry() async {
    await showVoiceEntrySheet(context);
  }
}

class _WhatsNewItem extends StatelessWidget {
  const _WhatsNewItem({
    required this.emoji,
    required this.title,
    required this.detail,
  });

  final String emoji;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
