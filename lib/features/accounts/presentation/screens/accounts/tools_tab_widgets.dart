import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:xpens/core/theme/app_colors.dart';
import 'package:xpens/core/theme/app_tokens.dart';
import 'package:xpens/routes/app_routes.dart';
import 'package:xpens/features/expense/data/models/expense_model.dart';
import 'package:xpens/features/accounts/presentation/provider/account_providers.dart';
import 'package:xpens/features/categories/presentation/provider/budget_providers.dart';
import 'package:xpens/features/expense/presentation/provider/expense_providers.dart';
import 'package:xpens/features/settings/presentation/provider/preferences_providers.dart';
import 'package:xpens/features/categories/presentation/widgets/expense_category.dart';
import 'package:xpens/features/recurring/presentation/widgets/recurring_tool_view.dart';
import 'package:xpens/features/accounts/presentation/widgets/split_bill_tool_view.dart';

const _maxDisplayedFutureTransactions = 6;

// ---------------------------------------------------------------------------
// Tab Bar & Tab View
// ---------------------------------------------------------------------------

/// Renders the tab views driven by [controller].
class ToolsTabView extends StatelessWidget {
  const ToolsTabView({super.key, required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return TabBarView(
      controller: controller,
      children: const <Widget>[
        _ToolsTabPane(child: BudgetToolView()),
        _ToolsTabPane(child: GoalsToolView()),
        _ToolsTabPane(child: SplitBillToolView()),
        _ToolsTabPane(child: RecurringToolView()),
        _ToolsTabPane(child: FutureTransactionsToolView()),
      ],
    );
  }
}

/// Scroll wrapper used by each tool tab to prevent overflow.
class _ToolsTabPane extends StatelessWidget {
  const _ToolsTabPane({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(child: child);
  }
}

// ---------------------------------------------------------------------------
// Budget Tab
// ---------------------------------------------------------------------------

/// Shows all expense categories with their budget targets + current spend.
class BudgetToolView extends ConsumerWidget {
  const BudgetToolView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgets =
        ref.watch(budgetTargetsProvider).value ?? defaultBudgetTargets;
    final stats = ref.watch(statsProvider);
    final currency = ref.watch(currencyFormatProvider);
    final allExpenseCategories = ref.watch(allExpenseCategoriesProvider);

    // Collect all categories that either have a budget or have been spent in
    final allCategories = {
      ...budgets.keys,
      ...stats.categoryTotals.keys,
    }.toList(growable: false)
      ..sort();

    double totalBudget = budgets.values.fold(0, (a, b) => a + b);
    double totalSpend = stats.monthTotal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text('Budget Overview', style: AppTextStyles.sectionHeading),
        const Text(
          'This month\'s spending vs your targets',
          style: AppTextStyles.sectionSubtitle,
        ),
        const SizedBox(height: AppSpacing.md),

        // Monthly summary card
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.primaryBlue,
            borderRadius: BorderRadius.circular(AppRadii.xl),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TOTAL BUDGET',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currency.format(totalBudget),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'TOTAL SPENT',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currency.format(totalSpend),
                      style: TextStyle(
                        color: totalSpend > totalBudget && totalBudget > 0
                            ? const Color(0xFFFFA2A2)
                            : Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        if (allCategories.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadii.xl),
            ),
            child: const Column(
              children: [
                Icon(Icons.pie_chart_outline_rounded,
                    size: 48, color: AppColors.textMuted),
                SizedBox(height: AppSpacing.sm),
                Text(
                  'No budgets set yet',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Go to Categories to set monthly budget targets.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ],
            ),
          )
        else
          ...allCategories.map((category) {
            final budget = budgets[category] ?? 0;
            final spend = stats.categoryTotals[category] ?? 0;
            final progress =
                budget > 0 ? (spend / budget).clamp(0.0, 1.0) : 0.0;
            final isOverBudget = budget > 0 && spend > budget;
            final catInfo =
                resolveExpenseCategory(category, allExpenseCategories);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.cardShadow,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: catInfo.color.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(catInfo.icon,
                              color: catInfo.color, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            category,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              currency.format(spend),
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: isOverBudget
                                    ? AppColors.danger
                                    : AppColors.textDark,
                                fontSize: 15,
                              ),
                            ),
                            if (budget > 0)
                              Text(
                                'of ${currency.format(budget)}',
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    if (budget > 0) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: AppColors.surfaceAccent,
                          color:
                              isOverBudget ? AppColors.danger : catInfo.color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isOverBudget
                            ? 'Over budget by ${currency.format(spend - budget)}'
                            : '${currency.format(budget - spend)} remaining',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isOverBudget
                              ? AppColors.danger
                              : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Goals / Savings Tab
// ---------------------------------------------------------------------------

/// Simple data class for a savings goal.
class _SavingsGoal {
  _SavingsGoal({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
  });

  factory _SavingsGoal.fromJson(Map<String, dynamic> map) => _SavingsGoal(
        id: map['id'] as String? ?? '',
        name: map['name'] as String? ?? 'Goal',
        targetAmount: (map['targetAmount'] as num?)?.toDouble() ?? 0,
        currentAmount: (map['currentAmount'] as num?)?.toDouble() ?? 0,
      );

  final String id;
  String name;
  double targetAmount;
  double currentAmount;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'targetAmount': targetAmount,
        'currentAmount': currentAmount,
      };
}

List<_SavingsGoal> _parseGoals(String json) {
  if (json.isEmpty) return [];
  try {
    final list = jsonDecode(json) as List<dynamic>;
    return list
        .cast<Map<String, dynamic>>()
        .map(_SavingsGoal.fromJson)
        .toList();
  } catch (_) {
    return [];
  }
}

String _encodeGoals(List<_SavingsGoal> goals) =>
    jsonEncode(goals.map((g) => g.toJson()).toList());

class GoalsToolView extends ConsumerWidget {
  const GoalsToolView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsJson = ref.watch(savingsGoalsJsonProvider);
    final goals = _parseGoals(goalsJson);
    final currency = ref.watch(currencyFormatProvider);
    final accounts = ref.watch(accountListProvider).value ?? [];
    final totalBalance = accounts.fold<double>(0, (s, a) => s + a.balance);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Savings Goals', style: AppTextStyles.sectionHeading),
                  Text(
                    'Track your financial milestones',
                    style: AppTextStyles.sectionSubtitle,
                  ),
                ],
              ),
            ),
            IconButton.filled(
              onPressed: () => _addGoal(context, ref, goals, currency),
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Add savings goal',
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        // Net worth hint
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: AppColors.lightBlueBg,
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.account_balance_wallet_outlined,
                color: AppColors.primaryBlue,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Available balance: ${currency.format(totalBalance)}',
                style: const TextStyle(
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        if (goals.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadii.xl),
            ),
            child: const Column(
              children: [
                Icon(Icons.flag_outlined, size: 48, color: AppColors.textMuted),
                SizedBox(height: AppSpacing.sm),
                Text(
                  'No goals yet',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Tap + to create your first savings goal.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ],
            ),
          )
        else
          ...goals.asMap().entries.map((entry) {
            final idx = entry.key;
            final goal = entry.value;
            final progress = goal.targetAmount > 0
                ? (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0)
                : 0.0;
            final remaining = goal.targetAmount - goal.currentAmount;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.cardShadow,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            goal.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                        PopupMenuButton<String>(
                          color: Colors.white,
                          icon: const Icon(Icons.more_horiz_rounded,
                              color: AppColors.textMuted),
                          onSelected: (v) {
                            if (v == 'edit') {
                              _editGoal(context, ref, goals, idx, currency);
                            } else if (v == 'delete') {
                              _deleteGoal(ref, goals, idx);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(
                                value: 'delete', child: Text('Delete')),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          currency.format(goal.currentAmount),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                        Text(
                          'Target: ${currency.format(goal.targetAmount)}',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: AppColors.surfaceAccent,
                        color: progress >= 1.0
                            ? AppColors.success
                            : AppColors.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${(progress * 100).toStringAsFixed(0)}% saved',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (remaining > 0)
                          Text(
                            '${currency.format(remaining)} to go',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        else
                          const Text(
                            '🎉 Goal reached!',
                            style: TextStyle(
                              color: AppColors.success,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Quick add saved amount button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _addToGoal(context, ref, goals, idx, currency),
                        icon: const Icon(
                          Icons.add_circle_outline_rounded,
                          size: 18,
                        ),
                        label: const Text('Add to savings'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryBlue,
                          side: const BorderSide(
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Future<void> _addGoal(
    BuildContext context,
    WidgetRef ref,
    List<_SavingsGoal> goals,
    NumberFormat currency,
  ) async {
    await _showGoalDialog(context, ref, goals, null, currency);
  }

  Future<void> _editGoal(
    BuildContext context,
    WidgetRef ref,
    List<_SavingsGoal> goals,
    int idx,
    NumberFormat currency,
  ) async {
    await _showGoalDialog(context, ref, goals, idx, currency);
  }

  void _deleteGoal(WidgetRef ref, List<_SavingsGoal> goals, int idx) {
    final updated = List<_SavingsGoal>.from(goals)..removeAt(idx);
    ref.read(appPreferencesControllerProvider).setSavingsGoalsJson(
          _encodeGoals(updated),
        );
  }

  Future<void> _addToGoal(
    BuildContext context,
    WidgetRef ref,
    List<_SavingsGoal> goals,
    int idx,
    NumberFormat currency,
  ) async {
    final amountController = TextEditingController();
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add to "${goals[idx].name}"'),
        content: TextField(
          controller: amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(hintText: 'Amount to add'),
          autofocus: true,
         ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              ctx,
              double.tryParse(amountController.text),
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (result != null && result > 0) {
      final updated = List<_SavingsGoal>.from(goals);
      updated[idx] = _SavingsGoal(
        id: goals[idx].id,
        name: goals[idx].name,
        targetAmount: goals[idx].targetAmount,
        currentAmount: goals[idx].currentAmount + result,
      );
      await ref
          .read(appPreferencesControllerProvider)
          .setSavingsGoalsJson(_encodeGoals(updated));
    }
  }

  Future<void> _showGoalDialog(
    BuildContext context,
    WidgetRef ref,
    List<_SavingsGoal> goals,
    int? editIndex,
    NumberFormat currency,
  ) async {
    final existing = editIndex != null ? goals[editIndex] : null;
    final nameController = TextEditingController(text: existing?.name ?? '');
    final targetController = TextEditingController(
      text: existing != null ? existing.targetAmount.toStringAsFixed(0) : '',
    );
    final savedController = TextEditingController(
      text: existing != null ? existing.currentAmount.toStringAsFixed(0) : '',
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'New Goal' : 'Edit Goal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Goal name'),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: targetController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Target amount'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: savedController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Already saved'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(existing == null ? 'Create' : 'Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      final name = nameController.text.trim();
      final target = double.tryParse(targetController.text) ?? 0;
      final saved = double.tryParse(savedController.text) ?? 0;

      if (name.isEmpty) return;

      final updated = List<_SavingsGoal>.from(goals);
      if (editIndex != null) {
        updated[editIndex] = _SavingsGoal(
          id: goals[editIndex].id,
          name: name,
          targetAmount: target,
          currentAmount: saved,
        );
      } else {
        updated.add(_SavingsGoal(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: name,
          targetAmount: target,
          currentAmount: saved,
        ));
      }

      await ref
          .read(appPreferencesControllerProvider)
          .setSavingsGoalsJson(_encodeGoals(updated));
    }
  }
}

// ---------------------------------------------------------------------------
// Future Transactions Tab
// ---------------------------------------------------------------------------

/// Upcoming transactions that are dated after today.
class FutureTransactionsToolView extends ConsumerWidget {
  const FutureTransactionsToolView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses =
        ref.watch(expenseListProvider).value ?? const <ExpenseModel>[];
    final currency = ref.watch(currencyFormatProvider);
    final today = DateUtils.dateOnly(DateTime.now());

    final futureTransactions = expenses
        .where(
          (expense) =>
              DateUtils.dateOnly(expense.date.toLocal()).isAfter(today),
        )
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final hasMore = futureTransactions.length > _maxDisplayedFutureTransactions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Header row — title + add button (mirrors RecurringToolView pattern)
        Row(
          children: <Widget>[
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Future Transactions',
                    style: AppTextStyles.sectionHeading,
                  ),
                  Text(
                    'Review and plan upcoming entries',
                    style: AppTextStyles.sectionSubtitle,
                  ),
                ],
              ),
            ),
            IconButton.filled(
              onPressed: () => AppRoutes.pushAddExpense(
                context,
                initialDate: today.add(const Duration(days: 1)),
              ),
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Add future transaction',
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // Empty state — icon + message (no separate floating CTA)
        if (futureTransactions.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xl,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadii.xl),
            ),
            child: Column(
              children: <Widget>[
                const Icon(
                  Icons.event_note_rounded,
                  size: 48,
                  color: AppColors.textMuted,
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'No upcoming transactions',
                  style: TextStyle(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                const Text(
                  'Add a transaction with a future date to plan ahead.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          )
        else ...<Widget>[
          ...futureTransactions
              .take(_maxDisplayedFutureTransactions)
              .map((expense) {
            final signedAmount =
                expense.isIncome ? expense.amount : -expense.amount;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            expense.note.isEmpty
                                ? expense.category
                                : expense.note,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textDark,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('EEE, d MMM')
                                .format(expense.date.toLocal()),
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      currency.format(signedAmount),
                      style: TextStyle(
                        color: expense.isIncome
                            ? AppColors.success
                            : AppColors.primaryBlue,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          // "View all (N)" escape when the list is capped
          if (hasMore)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => AppRoutes.pushRecordsHistory(context),
                child: Text(
                  'View all (${futureTransactions.length})',
                  style: const TextStyle(
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}
