import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasource/month_budget_local_datasource.dart';
import 'package:xpens/features/expense/data/models/expense_model.dart';
import 'budget_providers.dart';
import 'package:xpens/features/expense/presentation/provider/expense_providers.dart';

// ── helpers ───────────────────────────────────────────────────────────────────

/// Normalised "YYYY-MM" string for a given month.
String monthKeyOf(DateTime dt) =>
    '${dt.year}-${dt.month.toString().padLeft(2, '0')}';

// ── selected month ────────────────────────────────────────────────────────────

/// The currently-viewed month (always normalised to the 1st of that month).
final selectedMonthProvider =
    NotifierProvider<SelectedMonthNotifier, DateTime>(
  SelectedMonthNotifier.new,
);

class SelectedMonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  void setMonth(DateTime dt) {
    state = dt;
  }
}

// ── datasource provider ───────────────────────────────────────────────────────

final monthBudgetDatasourceProvider =
    Provider<MonthBudgetLocalDatasource>((ref) {
  return MonthBudgetLocalDatasource();
});

// ── state model ───────────────────────────────────────────────────────────────

class MonthBudgetState {
  const MonthBudgetState({
    this.totalBudgets = const {},
    this.categoryBudgets = const {},
  });

  /// monthKey → total spending budget for that month.
  final Map<String, double> totalBudgets;

  /// monthKey → { categoryName → monthly limit }.
  final Map<String, Map<String, double>> categoryBudgets;

  double? totalForMonth(String monthKey) => totalBudgets[monthKey];

  Map<String, double> categoriesForMonth(String monthKey) =>
      categoryBudgets[monthKey] ?? const {};

  MonthBudgetState copyWith({
    Map<String, double>? totalBudgets,
    Map<String, Map<String, double>>? categoryBudgets,
  }) =>
      MonthBudgetState(
        totalBudgets: totalBudgets ?? this.totalBudgets,
        categoryBudgets: categoryBudgets ?? this.categoryBudgets,
      );
}

// ── notifier ──────────────────────────────────────────────────────────────────

class MonthBudgetNotifier extends AsyncNotifier<MonthBudgetState> {
  MonthBudgetLocalDatasource get _ds =>
      ref.read(monthBudgetDatasourceProvider);

  @override
  Future<MonthBudgetState> build() async {
    try {
      final raw = _ds.loadAll();
      return MonthBudgetState(
        totalBudgets: Map<String, double>.from(raw.totalBudgets),
        categoryBudgets: {
          for (final entry in raw.categoryBudgets.entries)
            entry.key: Map<String, double>.from(entry.value),
        },
      );
    } catch (e, st) {
      if (kDebugMode) {
        dev.log('MonthBudgetNotifier.build failed',
            error: e, stackTrace: st, name: 'MonthBudgetNotifier');
      }
      return const MonthBudgetState();
    }
  }

  Future<void> saveMonthTotal(DateTime month, double amount) async {
    try {
      final key = monthKeyOf(month);
      await _ds.saveMonthTotalBudget(key, amount);
      final current = state.value ?? const MonthBudgetState();
      final updatedTotals = Map<String, double>.from(current.totalBudgets)
        ..[key] = amount;
      state = AsyncData(current.copyWith(totalBudgets: updatedTotals));
    } catch (e, st) {
      if (kDebugMode) {
        dev.log('saveMonthTotal failed',
            error: e, stackTrace: st, name: 'MonthBudgetNotifier');
      }
    }
  }

  Future<void> copyFromPreviousMonth(DateTime targetMonth) async {
    try {
      final prevMonth =
          DateTime(targetMonth.year, targetMonth.month - 1);
      final prevKey = monthKeyOf(prevMonth);
      final targetKey = monthKeyOf(targetMonth);

      final current = state.value ?? const MonthBudgetState();

      // Copy total budget
      final prevTotal = current.totalForMonth(prevKey);

      // Copy category budgets: month-specific overrides take precedence over
      // global defaults; if no previous month-specific budgets exist, fall
      // back to the global budgets.
      final globalBudgets =
          ref.read(budgetTargetsProvider).value ?? defaultBudgetTargets;
      final prevCategoryOverrides = current.categoriesForMonth(prevKey);
      final sourceBudgets = <String, double>{
        ...globalBudgets,
        ...prevCategoryOverrides,
      };

      // Persist to Hive
      if (prevTotal != null) {
        await _ds.saveMonthTotalBudget(targetKey, prevTotal);
      }
      for (final entry in sourceBudgets.entries) {
        await _ds.saveCategoryBudgetForMonth(
            targetKey, entry.key, entry.value);
      }

      // Update in-memory state
      final updatedTotals = Map<String, double>.from(current.totalBudgets);
      if (prevTotal != null) updatedTotals[targetKey] = prevTotal;

      final updatedCategories = {
        for (final e in current.categoryBudgets.entries)
          e.key: Map<String, double>.from(e.value),
      };
      updatedCategories[targetKey] = Map<String, double>.from(sourceBudgets);

      state = AsyncData(current.copyWith(
        totalBudgets: updatedTotals,
        categoryBudgets: updatedCategories,
      ));
    } catch (e, st) {
      if (kDebugMode) {
        dev.log('copyFromPreviousMonth failed',
            error: e, stackTrace: st, name: 'MonthBudgetNotifier');
      }
    }
  }
}

final monthBudgetProvider =
    AsyncNotifierProvider<MonthBudgetNotifier, MonthBudgetState>(
  MonthBudgetNotifier.new,
);

// ── derived providers ─────────────────────────────────────────────────────────

/// Expense + income stats scoped to the selected month.
final monthlyStatsForMonthProvider = Provider<ExpenseStats>((ref) {
  final expenses =
      ref.watch(expenseListProvider).value ?? const <ExpenseModel>[];
  final month = ref.watch(selectedMonthProvider);
  return ExpenseStats.fromExpenses(expenses, forMonth: month);
});

/// Total spending budget set for the selected month (may be null if not set).
final monthTotalBudgetProvider = Provider<double?>((ref) {
  final month = ref.watch(selectedMonthProvider);
  final budgetState = ref.watch(monthBudgetProvider).value;
  return budgetState?.totalForMonth(monthKeyOf(month));
});

/// How much remains in the selected month's total budget.
/// Returns null when no total budget has been set.
final monthRemainingBudgetProvider = Provider<double?>((ref) {
  final total = ref.watch(monthTotalBudgetProvider);
  if (total == null) return null;
  final stats = ref.watch(monthlyStatsForMonthProvider);
  return total - stats.monthTotal;
});

/// Effective category budgets for the selected month.
/// Month-specific overrides shadow the global per-category limits.
final effectiveMonthBudgetsProvider = Provider<Map<String, double>>((ref) {
  final globalBudgets =
      ref.watch(budgetTargetsProvider).value ?? defaultBudgetTargets;
  final month = ref.watch(selectedMonthProvider);
  final budgetState = ref.watch(monthBudgetProvider).value;
  final monthOverrides =
      budgetState?.categoriesForMonth(monthKeyOf(month)) ?? const {};
  return <String, double>{...globalBudgets, ...monthOverrides};
});

// ── controller ────────────────────────────────────────────────────────────────

class MonthBudgetController {
  MonthBudgetController(this._ref);

  final Ref _ref;

  Future<void> saveMonthTotal(DateTime month, double amount) =>
      _ref.read(monthBudgetProvider.notifier).saveMonthTotal(month, amount);

  Future<void> copyFromPreviousMonth(DateTime targetMonth) => _ref
      .read(monthBudgetProvider.notifier)
      .copyFromPreviousMonth(targetMonth);
}

final monthBudgetControllerProvider = Provider<MonthBudgetController>((ref) {
  return MonthBudgetController(ref);
});
