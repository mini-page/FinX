import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/widgets/app_page_header.dart';
import 'package:expensio/features/accounts/presentation/provider/account_providers.dart';
import 'package:expensio/features/categories/presentation/provider/budget_state.dart';
import 'package:expensio/features/expense/data/models/expense_model.dart';
import 'package:expensio/features/expense/presentation/provider/expense_providers.dart';
import 'package:expensio/features/expense/presentation/widgets/ui_feedback.dart';
import 'package:expensio/features/settings/presentation/provider/preferences_providers.dart';
import 'package:expensio/routes/app_routes.dart';
import 'stats/stats_widgets.dart';

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  String _selectedRange = 'This Month';

  /*
  static const List<({String label, String value})> _rangeOptions = [
    (label: 'Month', value: 'This Month'),
    (label: 'Year', value: 'This Year'),
    (label: 'Lifetime', value: 'All Time'),
  ];
  */

  Future<void> _openEditExpenseScreen(
    BuildContext context,
    ExpenseModel expense,
  ) {
    return AppRoutes.pushEditExpense(
      context,
      expenseId: expense.id,
      initialAmount: expense.amount,
      initialCategory: expense.category,
      initialDate: expense.date.toLocal(),
      initialNote: expense.note,
      initialAccountId: expense.accountId,
      initialToAccountId: expense.toAccountId,
      initialType: expense.type,
      initialSubcategory: expense.subcategory,
      initialLatitude: expense.latitude,
      initialLongitude: expense.longitude,
    );
  }

  Future<void> _confirmDeleteExpense(ExpenseModel expense) async {
    final label = expense.note.isEmpty ? expense.category : expense.note;
    final confirmed = await confirmDestructiveAction(
      context,
      title: 'Delete transaction?',
      message: 'Remove "$label" from your records? This cannot be undone.',
      confirmLabel: 'Delete txn',
    );
    if (!confirmed || !mounted) {
      return;
    }

    await ref.read(expenseControllerProvider).deleteExpense(expense.id);

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Transaction removed.')));
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(analyticsSnapshotProvider(_selectedRange));
    final privacyModeEnabled = ref.watch(privacyModeEnabledProvider);
    final currencyFormat = ref.watch(currencyFormatProvider);
    final accounts = ref.watch(accountListProvider).value ?? const [];
    final accountsMap = {for (final a in accounts) a.id: a};
    final budgets = ref.watch(effectiveMonthBudgetsProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: GradientAppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Analytics',
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                snapshot.periodLabel,
                style: const TextStyle(
                  color: AppColors.primaryBlue,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        showBackButton: false,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.tune_rounded,
              color: AppColors.textDark,
            ),
            onPressed: () async {
              final selected = await showStatsRangePicker(
                context,
                _selectedRange,
              );
              if (selected != null && selected != _selectedRange) {
                setState(() => _selectedRange = selected);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: AppSpacing.sm),

            /*
            // 1. Time Range Selector Tabs (Month, Year, Lifetime)
            Container(
              height: 40,
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: _rangeOptions.map((opt) {
                  final isSelected = _selectedRange == opt.value;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedRange = opt.value),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primaryBlue : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          opt.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // 2. Date Picker Navigation Capsule
            Center(
              child: OutlinedButton(
                onPressed: () async {
                  final selected = await showStatsRangePicker(
                    context,
                    _selectedRange,
                  );
                  if (selected != null && selected != _selectedRange) {
                    setState(() => _selectedRange = selected);
                  }
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryBlue,
                  side: BorderSide(
                    color: AppColors.primaryBlue.withValues(alpha: 0.2),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  backgroundColor: Colors.white,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      snapshot.periodLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            */

            // 3. Overview Card (Income, Expense, Net Flow + 3 sub-metrics)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: StatsOverviewMetrics(
                snapshot: snapshot,
                currencyFormat: currencyFormat,
                privacyModeEnabled: privacyModeEnabled,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // 4. Salary Progress Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: StatsSalaryInsights(
                snapshot: snapshot,
                currencyFormat: currencyFormat,
                privacyModeEnabled: privacyModeEnabled,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // 5. Spending Trend Card (Line Chart)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: SpendingTrendCard(
                snapshot: snapshot,
                currencyFormat: currencyFormat,
                privacyModeEnabled: privacyModeEnabled,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // 6. Breakdown Analysis Card (Donut Chart + share percentages list)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: StatsBreakdownAnalysis(
                snapshot: snapshot,
                currencyFormat: currencyFormat,
                privacyModeEnabled: privacyModeEnabled,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // 7. Budget Utilization Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: StatsBudgetUtilization(
                snapshot: snapshot,
                categoryBudgets: budgets,
                currencyFormat: currencyFormat,
                privacyModeEnabled: privacyModeEnabled,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // 8. Top Transactions Card
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                140,
              ),
              child: StatsTopTransactions(
                snapshot: snapshot,
                accountsMap: accountsMap,
                currencyFormat: currencyFormat,
                privacyModeEnabled: privacyModeEnabled,
                onEdit: (exp) => _openEditExpenseScreen(context, exp),
                onDelete: (exp) => _confirmDeleteExpense(exp),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
