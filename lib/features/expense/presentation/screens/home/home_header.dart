import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/constants/app_assets.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../routes/app_routes.dart';
import 'package:xpens/features/accounts/presentation/provider/account_providers.dart';
import '../../provider/expense_providers.dart';
import '../../widgets/amount_visibility.dart';

// ---------------------------------------------------------------------------
// HomeTopBar — sticky slim app-bar (menu · logo · name · search · bell)
// ---------------------------------------------------------------------------

/// The sticky top application bar shown on the Home screen.
///
/// Only this widget is pinned; the blue hero balance card below it scrolls.
class HomeTopBar extends StatelessWidget {
  const HomeTopBar({
    super.key,
    required this.onSearchPressed,
    required this.onNotificationPressed,
    this.unreadCount = 0,
  });

  final VoidCallback onSearchPressed;
  final VoidCallback onNotificationPressed;

  /// Number of unread notifications — drives the red badge.
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      color: AppColors.primaryBlue,
      padding: EdgeInsets.fromLTRB(16, topPadding + 8, 8, 8),
      child: Row(
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.all(5),
            child: Image.asset(AppAssets.logo),
          ),
          const SizedBox(width: 10),
          const Text(
            'XPens',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Search transactions',
            onPressed: onSearchPressed,
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.search_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          Stack(
            children: <Widget>[
              IconButton(
                tooltip: 'Notifications',
                onPressed: onNotificationPressed,
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.notifications_none_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              if (unreadCount > 0)
                Positioned(
                  top: 10,
                  right: 12,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primaryBlue,
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),

        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// HomeHeader — scrollable blue hero card (balance, metrics, budget bar)
// ---------------------------------------------------------------------------

/// Blue hero section showing the net total and monthly metrics.
///
/// This widget is NOT sticky — it scrolls with the page content.
class HomeHeader extends StatefulWidget {
  const HomeHeader({
    super.key,
    required this.stats,
    required this.accountSummary,
    required this.currencyFormat,
    required this.privacyModeEnabled,
    required this.onTogglePrivacy,
    required this.quickAmounts,
    required this.onAmountTap,
    required this.onAmountLongPress,
    required this.onAddAmountTap,
  });

  final ExpenseStats stats;
  final AccountSummary accountSummary;
  final NumberFormat currencyFormat;
  final bool privacyModeEnabled;
  final VoidCallback onTogglePrivacy;
  final List<double> quickAmounts;
  final ValueChanged<double> onAmountTap;
  final ValueChanged<double> onAmountLongPress;
  final VoidCallback onAddAmountTap;

  @override
  State<HomeHeader> createState() => _HomeHeaderState();
}

class _HomeHeaderState extends State<HomeHeader> {
  bool _netWorthRevealed = false;

  @override
  Widget build(BuildContext context) {
    final stats = widget.stats;
    final netTotal = formatSignedCurrencyForHome(
      stats.monthNetTotal,
      widget.currencyFormat,
      masked: widget.privacyModeEnabled,
    );
    final bool isDeficit = stats.monthNetTotal < 0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Blue background banner at the top of the header extending the TopBar background
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 60,
          child: Container(
            color: AppColors.primaryBlue,
          ),
        ),
        // Main floating white card overlapping the blue banner
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.cardShadow,
                  blurRadius: 22,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left side: All Accounts, Balance, Net Worth button
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'All Accounts',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Semantics(
                                button: true,
                                label: 'Toggle privacy mode',
                                child: GestureDetector(
                                  onTap: widget.onTogglePrivacy,
                                  child: Icon(
                                    widget.privacyModeEnabled
                                        ? Icons.visibility_off_rounded
                                        : Icons.visibility_rounded,
                                    color: AppColors.textTertiary,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                if (isDeficit) ...[
                                  const Text(
                                    '−',
                                    style: TextStyle(
                                      color: AppColors.textDark,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                      height: 1,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                ],
                                Text(
                                  netTotal,
                                  style: const TextStyle(
                                    color: AppColors.textDark,
                                    fontSize: 38,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1,
                                    height: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          GestureDetector(
                            onTap: () => setState(() => _netWorthRevealed = !_netWorthRevealed),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlue.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppColors.primaryBlue.withValues(alpha: 0.15),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.account_balance_wallet_rounded,
                                        color: AppColors.primaryBlue,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 6),
                                      const Text(
                                        'Net Worth',
                                        style: TextStyle(
                                          color: AppColors.primaryBlue,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const Spacer(),
                                      Icon(
                                        _netWorthRevealed
                                            ? Icons.visibility_off_rounded
                                            : Icons.visibility_rounded,
                                        color: AppColors.primaryBlue.withValues(alpha: 0.6),
                                        size: 14,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _netWorthRevealed
                                        ? widget.currencyFormat.format(widget.accountSummary.totalBalance)
                                        : '• • •',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: AppColors.primaryBlue,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Thin Vertical Divider
                    Container(
                      height: 110,
                      width: 1.2,
                      color: const Color(0xFFE8EEF8),
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    // Right side: Expense / Income Stacked Card Tiles
                    Expanded(
                      flex: 5,
                      child: Column(
                        children: [
                          _MetricCard(
                            label: 'Expense',
                            amount: maskAmount(
                              widget.currencyFormat.format(stats.monthTotal),
                              masked: widget.privacyModeEnabled,
                            ),
                            isExpense: true,
                            onTap: () => AppRoutes.pushRecordsHistory(context),
                          ),
                          const SizedBox(height: 10),
                          _MetricCard(
                            label: 'Income',
                            amount: maskAmount(
                              widget.currencyFormat.format(stats.monthIncomeTotal),
                              masked: widget.privacyModeEnabled,
                            ),
                            isExpense: false,
                            onTap: () => AppRoutes.pushRecordsHistory(context),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (widget.quickAmounts.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: Color(0xFFE8EEF8)),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            onTap: widget.onAddAmountTap,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F4F9),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFFD1DAEA),
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.add_rounded,
                                    size: 16,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'Add',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        ...widget.quickAmounts.map((amount) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _QuickAmountChip(
                              label: widget.currencyFormat.format(amount),
                              onTap: () => widget.onAmountTap(amount),
                              onLongPress: () => widget.onAmountLongPress(amount),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.amount,
    required this.isExpense,
    required this.onTap,
  });

  final String label;
  final String amount;
  final bool isExpense;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color bgColor = isExpense
        ? const Color(0xFFFFF2F2)
        : const Color(0xFFF0FFF5);
    final Color iconBgColor = isExpense
        ? const Color(0xFFFFE3E3)
        : const Color(0xFFD6FCDD);
    final Color iconColor = isExpense
        ? AppColors.danger
        : AppColors.success;
    final Color textColor = isExpense
        ? AppColors.danger
        : AppColors.success;
    final IconData iconData = isExpense
        ? Icons.arrow_downward_rounded
        : Icons.arrow_upward_rounded;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                iconData,
                color: iconColor,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      amount,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAmountChip extends StatelessWidget {
  const _QuickAmountChip({
    required this.label,
    required this.onTap,
    required this.onLongPress,
  });

  final String label;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.primaryBlue.withValues(alpha: 0.6),
            width: 1.2,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.primaryBlue,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

/// Formats [amount] as an absolute currency string optionally masked.
String formatSignedCurrencyForHome(
  double amount,
  NumberFormat currencyFormat, {
  required bool masked,
}) {
  if (amount == 0) {
    return maskAmount(currencyFormat.format(0), masked: masked);
  }

  // Return the absolute amount for display, dropping the +/- sign.
  return maskAmount(
    currencyFormat.format(amount.abs()),
    masked: masked,
  );
}
