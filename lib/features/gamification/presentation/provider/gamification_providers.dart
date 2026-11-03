import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:expensio/features/expense/data/models/expense_model.dart';
import 'package:expensio/features/expense/presentation/provider/expense_providers.dart';
import 'package:expensio/features/recurring/presentation/provider/recurring_subscription_providers.dart';
import 'package:expensio/features/categories/presentation/provider/budget_providers.dart';
import 'package:expensio/features/categories/presentation/provider/budget_state.dart';
import '../../data/models/achievement_model.dart';

/// Computes gamification state from expense data.
final gamificationProvider = Provider<GamificationState>((ref) {
  final expenses =
      ref.watch(expenseListProvider).value ?? const <ExpenseModel>[];
  final subscriptions =
      ref.watch(recurringSubscriptionListProvider).value ?? const <dynamic>[];
  final budgetState = ref.watch(monthBudgetProvider).value;

  // ── Streak computation ──────────────────────────────────────────────────────

  final dateSet = <int>{};
  for (final e in expenses) {
    if (e.type == TransactionType.expense) {
      final d = DateTime(e.date.year, e.date.month, e.date.day);
      dateSet.add(d.millisecondsSinceEpoch);
    }
  }

  final sortedDates = dateSet.toList()..sort();
  final today = DateTime.now();
  final todayKey = DateTime(today.year, today.month, today.day)
      .millisecondsSinceEpoch;

  // Current streak: count consecutive days backwards from today
  int currentStreak = 0;
  if (dateSet.contains(todayKey)) {
    currentStreak = 1;
    var check = today.subtract(const Duration(days: 1));
    while (dateSet.contains(
        DateTime(check.year, check.month, check.day).millisecondsSinceEpoch)) {
      currentStreak++;
      check = check.subtract(const Duration(days: 1));
    }
  }

  // Longest streak
  int longestStreak = 0;
  int tempStreak = 0;
  DateTime? prev;
  for (final ms in sortedDates) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    if (prev == null) {
      tempStreak = 1;
    } else {
      final diff = d.difference(prev).inDays;
      if (diff == 1) {
        tempStreak++;
      } else {
        tempStreak = 1;
      }
    }
    prev = d;
    if (tempStreak > longestStreak) longestStreak = tempStreak;
  }

  // ── Category usage ─────────────────────────────────────────────────────────

  final expenseCategories = <String>{};
  for (final e in expenses) {
    if (e.type == TransactionType.expense && e.category.isNotEmpty) {
      expenseCategories.add(e.category);
    }
  }

  // ── Split / night owl / early bird ─────────────────────────────────────────

  bool hasSplit = false;
  bool hasNightOwl = false;
  bool hasEarlyBird = false;
  for (final e in expenses) {
    if (e.splitMethod != null) hasSplit = true;
    if (e.date.hour >= 22) hasNightOwl = true;
    if (e.date.hour < 7) hasEarlyBird = true;
  }

  // ── Month saved / budget check ──────────────────────────────────────────────

  final now = DateTime.now();
  final monthStats = ExpenseStats.fromExpenses(expenses, forMonth: now);
  final monthSaved = monthStats.monthIncomeTotal > monthStats.monthTotal;

  final totalBudget = budgetState?.totalForMonth(
      '${now.year}-${now.month.toString().padLeft(2, '0')}');
  final monthWithinBudget =
      totalBudget != null ? monthStats.monthTotal <= totalBudget : false;

  // ── Achievements ────────────────────────────────────────────────────────────

  final unlocked = <AchievementId>{};

  if (expenses.isNotEmpty) unlocked.add(AchievementId.firstExpense);
  if (longestStreak >= 3) unlocked.add(AchievementId.streak3);
  if (longestStreak >= 7) unlocked.add(AchievementId.streak7);
  if (longestStreak >= 30) unlocked.add(AchievementId.streak30);
  if (monthWithinBudget) unlocked.add(AchievementId.budgetMaster);
  if (expenseCategories.length >= 5) unlocked.add(AchievementId.categoryExplorer);
  if (monthSaved) unlocked.add(AchievementId.saver);
  if (hasSplit) unlocked.add(AchievementId.splitter);
  if (subscriptions.length >= 3) unlocked.add(AchievementId.subscriptionTracker);
  if (hasNightOwl) unlocked.add(AchievementId.nightOwl);
  if (hasEarlyBird) unlocked.add(AchievementId.earlyBird);

  return GamificationState(
    streak: currentStreak,
    longestStreak: longestStreak,
    totalExpenses: expenses.length,
    categoriesUsed: expenseCategories.length,
    hasSplitExpense: hasSplit,
    hasScannedReceipt: false,
    subscriptionCount: subscriptions.length,
    unlockedAchievements: unlocked,
    hasNightOwl: hasNightOwl,
    hasEarlyBird: hasEarlyBird,
    monthSaved: monthSaved,
    monthWithinBudget: monthWithinBudget,
  );
});
