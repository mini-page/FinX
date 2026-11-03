import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:expensio/core/theme/app_colors.dart';
import 'package:expensio/core/theme/app_tokens.dart';
import 'package:expensio/shared/widgets/app_page_header.dart';
import 'package:expensio/features/categories/presentation/provider/budget_state.dart';
import 'package:expensio/features/categories/presentation/provider/week_budget_providers.dart';
import 'package:expensio/features/expense/presentation/provider/expense_providers.dart';
import 'package:expensio/features/expense/data/models/expense_model.dart';
import 'package:expensio/features/settings/presentation/provider/preferences_providers.dart';
import 'package:expensio/features/categories/presentation/screens/categories/budget_popup.dart';

enum _BudgetTab { monthly, weekly }

class BudgetingHubScreen extends ConsumerStatefulWidget {
  const BudgetingHubScreen({super.key, this.showBackButton = true});

  final bool showBackButton;

  @override
  ConsumerState<BudgetingHubScreen> createState() => _BudgetingHubScreenState();
}

class _BudgetingHubScreenState extends ConsumerState<BudgetingHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  _BudgetTab _activeTab = _BudgetTab.monthly;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _activeTab = _BudgetTab.values[_tabController.index];
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(currencyFormatProvider);
    final privacy = ref.watch(privacyModeEnabledProvider);
    final allExpenses =
        ref.watch(expenseListProvider).value ?? const <ExpenseModel>[];

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: GradientAppBar(
        title: 'Budgeting',
        showBackButton: widget.showBackButton,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _TabBar(
              selected: _activeTab,
              onChanged: (tab) {
                setState(() => _activeTab = tab);
                _tabController.animateTo(tab.index);
              },
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _MonthlyBudgetTab(
            currency: currency,
            privacy: privacy,
            allExpenses: allExpenses,
          ),
          _WeeklyBudgetTab(
            currency: currency,
            privacy: privacy,
            allExpenses: allExpenses,
          ),
        ],
      ),
    );
  }
}

// ── Tab Bar ───────────────────────────────────────────────────────────────────

class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.selected,
    required this.onChanged,
  });

  final _BudgetTab selected;
  final ValueChanged<_BudgetTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        children: List.generate(_BudgetTab.values.length, (index) {
          final tab = _BudgetTab.values[index];
          final isSelected = tab == selected;
          final label = tab == _BudgetTab.monthly ? 'Monthly' : 'Weekly';
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(tab),
              child: Container(
                margin:
                    const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected
                        ? AppColors.textDark
                        : AppColors.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Monthly Budget Tab ────────────────────────────────────────────────────────

class _MonthlyBudgetTab extends ConsumerWidget {
  const _MonthlyBudgetTab({
    required this.currency,
    required this.privacy,
    required this.allExpenses,
  });

  final NumberFormat currency;
  final bool privacy;
  final List<ExpenseModel> allExpenses;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMonth = ref.watch(selectedMonthProvider);
    final monthStats =
        ExpenseStats.fromExpenses(allExpenses, forMonth: selectedMonth);
    final totalBudget = ref.watch(monthTotalBudgetProvider);
    final effectiveBudgets = ref.watch(effectiveMonthBudgetsProvider);
    final remaining = ref.watch(monthRemainingBudgetProvider);

    final now = DateTime.now();
    final canSetBudget = selectedMonth.year > now.year ||
        (selectedMonth.year == now.year &&
            selectedMonth.month >= now.month);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MonthNavigator(selectedMonth: selectedMonth),
          const SizedBox(height: 20),
          _BudgetSummaryCard(
            totalBudget: totalBudget,
            spent: monthStats.monthTotal,
            remaining: remaining,
            currency: currency,
            privacy: privacy,
            onSetBudget: canSetBudget
                ? () => _openSetBudget(context, ref, selectedMonth)
                : null,
          ),
          const SizedBox(height: 24),
          if (effectiveBudgets.isNotEmpty) ...[
            Text(
              'Category Budgets',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 12),
            ...effectiveBudgets.entries.map((entry) {
              final spent = monthStats.categoryTotals[entry.key] ?? 0;
              return _CategoryBudgetTile(
                category: entry.key,
                budget: entry.value,
                spent: spent,
                currency: currency,
                privacy: privacy,
              );
            }),
          ],
          if (totalBudget == null && effectiveBudgets.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Center(
                child: Text(
                  'No budgets set yet.\nTap "Set Budget" to get started.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openSetBudget(
      BuildContext context, WidgetRef ref, DateTime month) async {
    final currentTotal = ref.read(monthTotalBudgetProvider);
    await showSetBudgetPopup(
      context,
      selectedMonth: month,
      currencySymbol: ref.read(currencySymbolProvider),
      currentTotal: currentTotal,
      onManual: (amount) =>
          ref.read(monthBudgetControllerProvider).saveMonthTotal(month, amount),
      onCopyPrevious: () => ref
          .read(monthBudgetControllerProvider)
          .copyFromPreviousMonth(month),
    );
  }
}

// ── Weekly Budget Tab ────────────────────────────────────────────────────────

class _WeeklyBudgetTab extends ConsumerWidget {
  const _WeeklyBudgetTab({
    required this.currency,
    required this.privacy,
    required this.allExpenses,
  });

  final NumberFormat currency;
  final bool privacy;
  final List<ExpenseModel> allExpenses;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedWeek = ref.watch(selectedWeekProvider);
    final weekKey = weekKeyOf(selectedWeek);
    final totalBudget = ref.watch(weekTotalBudgetProvider);
    final budgetState = ref.watch(weekBudgetProvider).value;

    final weekStart = selectedWeek;
    final weekEnd = weekEndDate(selectedWeek);
    final weekExpenses = allExpenses.where((e) {
      final d = e.date;
      return !d.isBefore(weekStart) && !d.isAfter(weekEnd);
    }).toList();
    final weekStats = ExpenseStats.fromExpenses(weekExpenses);
    final spent = weekStats.monthTotal;

    final categoryBudgets =
        budgetState?.categoriesForWeek(weekKey) ?? const {};

    final now = DateTime.now();
    final canSetBudget = !weekEnd.isBefore(DateTime(now.year, now.month, now.day));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _WeekNavigator(
            selectedWeek: selectedWeek,
            canGoNext: weekEnd.isBefore(DateTime.now()) ||
                weekStart.isBefore(weekStartDate(DateTime.now())),
          ),
          const SizedBox(height: 20),
          _BudgetSummaryCard(
            totalBudget: totalBudget,
            spent: spent,
            remaining: totalBudget != null ? totalBudget - spent : null,
            currency: currency,
            privacy: privacy,
            onSetBudget: canSetBudget
                ? () => _openSetWeekBudget(context, ref, selectedWeek)
                : null,
          ),
          const SizedBox(height: 24),
          if (categoryBudgets.isNotEmpty) ...[
            Text(
              'Category Budgets',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 12),
            ...categoryBudgets.entries.map((entry) {
              final categorySpent = weekStats.categoryTotals[entry.key] ?? 0;
              return _CategoryBudgetTile(
                category: entry.key,
                budget: entry.value,
                spent: categorySpent,
                currency: currency,
                privacy: privacy,
              );
            }),
          ],
          if (totalBudget == null && categoryBudgets.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Center(
                child: Text(
                  'No weekly budget set yet.\nTap "Set Budget" to get started.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openSetWeekBudget(
      BuildContext context, WidgetRef ref, DateTime week) async {
    final currentTotal = ref.read(weekTotalBudgetProvider);
    final currencySymbol = ref.read(currencySymbolProvider);
    final controller = TextEditingController(
      text: currentTotal?.toStringAsFixed(0) ?? '',
    );
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        title: Text(
          'Set Weekly Budget',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: AppColors.textDark,
          ),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            prefixText: '$currencySymbol ',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            hintText: 'Enter amount',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final amount = double.tryParse(controller.text);
              if (amount != null && amount > 0) {
                Navigator.of(ctx).pop(amount);
              }
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && context.mounted) {
      await ref
          .read(weekBudgetControllerProvider)
          .saveWeekTotal(week, result);
    }
  }
}

// ── Month Navigator ───────────────────────────────────────────────────────────

class _MonthNavigator extends ConsumerWidget {
  const _MonthNavigator({required this.selectedMonth});

  final DateTime selectedMonth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = DateFormat('MMMM yyyy').format(selectedMonth);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _NavButton(
          icon: Icons.chevron_left_rounded,
          onTap: () {
            final current = ref.read(selectedMonthProvider);
            ref.read(selectedMonthProvider.notifier).setMonth(
                  DateTime(current.year, current.month - 1),
                );
          },
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(width: 12),
        _NavButton(
          icon: Icons.chevron_right_rounded,
          onTap: () {
            final current = ref.read(selectedMonthProvider);
            ref.read(selectedMonthProvider.notifier).setMonth(
                  DateTime(current.year, current.month + 1),
                );
          },
        ),
      ],
    );
  }
}

// ── Week Navigator ────────────────────────────────────────────────────────────

class _WeekNavigator extends ConsumerWidget {
  const _WeekNavigator({
    required this.selectedWeek,
    required this.canGoNext,
  });

  final DateTime selectedWeek;
  final bool canGoNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekStart = selectedWeek;
    final weekEnd = weekEndDate(selectedWeek);
    final fmt = DateFormat('d MMM');
    final label = '${fmt.format(weekStart)} - ${fmt.format(weekEnd)}';
    final weekNumber = isoWeekNumber(selectedWeek);
    final year = selectedWeek.year;

    return Column(
      children: [
        Text(
          'Week $weekNumber, $year',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryBlue,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _NavButton(
              icon: Icons.chevron_left_rounded,
              onTap: () {
                final current = ref.read(selectedWeekProvider);
                ref.read(selectedWeekProvider.notifier).setWeek(
                      current.subtract(const Duration(days: 7)),
                    );
              },
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(width: 12),
            _NavButton(
              icon: Icons.chevron_right_rounded,
              onTap: () {
                final current = ref.read(selectedWeekProvider);
                ref.read(selectedWeekProvider.notifier).setWeek(
                      current.add(const Duration(days: 7)),
                    );
              },
            ),
          ],
        ),
      ],
    );
  }
}

// ── Nav Button ────────────────────────────────────────────────────────────────

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.lightBlueBg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: AppColors.primaryBlue, size: 20),
        ),
      ),
    );
  }
}

// ── Budget Summary Card ───────────────────────────────────────────────────────

class _BudgetSummaryCard extends StatelessWidget {
  const _BudgetSummaryCard({
    required this.totalBudget,
    required this.spent,
    required this.remaining,
    required this.currency,
    required this.privacy,
    this.onSetBudget,
  });

  final double? totalBudget;
  final double spent;
  final double? remaining;
  final NumberFormat currency;
  final bool privacy;
  final VoidCallback? onSetBudget;

  @override
  Widget build(BuildContext context) {
    final hasBudget = totalBudget != null && totalBudget! > 0;
    final progress = hasBudget
        ? (spent / totalBudget!).clamp(0.0, 1.0)
        : 0.0;
    final isOver = remaining != null && remaining! < 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Budget',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (onSetBudget != null)
                GestureDetector(
                  onTap: onSetBudget,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    child: Text(
                      totalBudget == null ? 'Set Budget' : 'Edit',
                      style: TextStyle(
                        color: AppColors.primaryBlue,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hasBudget
                ? '${_maskAmount(currency.format(totalBudget!), privacy)}'
                : 'Not set',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: hasBudget ? AppColors.textDark : AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          if (hasBudget) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: AppColors.lightBlueBg,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isOver ? AppColors.danger : AppColors.success,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Spent: ${_maskAmount(currency.format(spent), privacy)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isOver ? AppColors.danger : AppColors.textDark,
                  ),
                ),
                if (remaining != null)
                  Text(
                    isOver
                        ? 'Over by ${_maskAmount(currency.format(remaining!.abs()), privacy)}'
                        : 'Remaining: ${_maskAmount(currency.format(remaining!), privacy)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isOver ? AppColors.danger : AppColors.success,
                    ),
                  ),
              ],
            ),
          ] else
            Text(
              'Set a budget to track your spending',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  String _maskAmount(String formatted, bool masked) {
    if (!masked) return formatted;
    return '·' * formatted.length;
  }
}

// ── Category Budget Tile ──────────────────────────────────────────────────────

class _CategoryBudgetTile extends StatelessWidget {
  const _CategoryBudgetTile({
    required this.category,
    required this.budget,
    required this.spent,
    required this.currency,
    required this.privacy,
  });

  final String category;
  final double budget;
  final double spent;
  final NumberFormat currency;
  final bool privacy;

  @override
  Widget build(BuildContext context) {
    final progress = (spent / budget).clamp(0.0, 1.0);
    final isOver = spent > budget;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.md),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  category,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  '${_maskAmount(currency.format(spent), privacy)} / ${_maskAmount(currency.format(budget), privacy)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isOver ? AppColors.danger : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: AppColors.lightBlueBg,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isOver ? AppColors.danger : AppColors.primaryBlue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _maskAmount(String formatted, bool masked) {
    if (!masked) return formatted;
    return '·' * formatted.length;
  }
}
