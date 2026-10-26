import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasource/week_budget_local_datasource.dart';

// ── helpers ───────────────────────────────────────────────────────────────────

String weekKeyOf(DateTime dt) {
  final isoWeek = isoWeekNumber(dt);
  return '${dt.year}-W${isoWeek.toString().padLeft(2, '0')}';
}

int isoWeekNumber(DateTime date) {
  final d = DateTime.utc(date.year, date.month, date.day);
  final weekday = d.weekday;
  final nearestThursday = d.add(Duration(days: (4 - weekday) % 7));
  final yearStart = DateTime.utc(nearestThursday.year, 1, 1);
  final weekNum = 1 + ((nearestThursday.difference(yearStart).inDays) ~/ 7);
  return weekNum;
}

DateTime weekStartDate(DateTime dt) {
  final d = DateTime(dt.year, dt.month, dt.day);
  return d.subtract(Duration(days: d.weekday - 1));
}

DateTime weekEndDate(DateTime dt) {
  final start = weekStartDate(dt);
  return start.add(const Duration(days: 6));
}

// ── selected week ────────────────────────────────────────────────────────────

final selectedWeekProvider =
    NotifierProvider<SelectedWeekNotifier, DateTime>(
  SelectedWeekNotifier.new,
);

class SelectedWeekNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    return weekStartDate(DateTime.now());
  }

  void setWeek(DateTime dt) {
    state = weekStartDate(dt);
  }
}

// ── datasource provider ───────────────────────────────────────────────────────

final weekBudgetDatasourceProvider =
    Provider<WeekBudgetLocalDatasource>((ref) {
  return WeekBudgetLocalDatasource();
});

// ── state model ───────────────────────────────────────────────────────────────

class WeekBudgetState {
  const WeekBudgetState({
    this.totalBudgets = const {},
    this.categoryBudgets = const {},
  });

  final Map<String, double> totalBudgets;
  final Map<String, Map<String, double>> categoryBudgets;

  double? totalForWeek(String weekKey) => totalBudgets[weekKey];

  Map<String, double> categoriesForWeek(String weekKey) =>
      categoryBudgets[weekKey] ?? const {};

  WeekBudgetState copyWith({
    Map<String, double>? totalBudgets,
    Map<String, Map<String, double>>? categoryBudgets,
  }) =>
      WeekBudgetState(
        totalBudgets: totalBudgets ?? this.totalBudgets,
        categoryBudgets: categoryBudgets ?? this.categoryBudgets,
      );
}

// ── notifier ──────────────────────────────────────────────────────────────────

class WeekBudgetNotifier extends AsyncNotifier<WeekBudgetState> {
  WeekBudgetLocalDatasource get _ds =>
      ref.read(weekBudgetDatasourceProvider);

  @override
  Future<WeekBudgetState> build() async {
    try {
      final raw = _ds.loadAll();
      return WeekBudgetState(
        totalBudgets: Map<String, double>.from(raw.totalBudgets),
        categoryBudgets: {
          for (final entry in raw.categoryBudgets.entries)
            entry.key: Map<String, double>.from(entry.value),
        },
      );
    } catch (e, st) {
      if (kDebugMode) {
        dev.log('WeekBudgetNotifier.build failed',
            error: e, stackTrace: st, name: 'WeekBudgetNotifier');
      }
      return const WeekBudgetState();
    }
  }

  Future<void> saveWeekTotal(DateTime weekStart, double amount) async {
    try {
      final key = weekKeyOf(weekStart);
      await _ds.saveWeekTotalBudget(key, amount);
      final current = state.value ?? const WeekBudgetState();
      final updatedTotals = Map<String, double>.from(current.totalBudgets)
        ..[key] = amount;
      state = AsyncData(current.copyWith(totalBudgets: updatedTotals));
    } catch (e, st) {
      if (kDebugMode) {
        dev.log('saveWeekTotal failed',
            error: e, stackTrace: st, name: 'WeekBudgetNotifier');
      }
    }
  }
}

final weekBudgetProvider =
    AsyncNotifierProvider<WeekBudgetNotifier, WeekBudgetState>(
  WeekBudgetNotifier.new,
);

// ── derived providers ─────────────────────────────────────────────────────────

final weekTotalBudgetProvider = Provider<double?>((ref) {
  final week = ref.watch(selectedWeekProvider);
  final budgetState = ref.watch(weekBudgetProvider).value;
  return budgetState?.totalForWeek(weekKeyOf(week));
});

final weekBudgetControllerProvider = Provider<WeekBudgetController>((ref) {
  return WeekBudgetController(ref);
});

class WeekBudgetController {
  WeekBudgetController(this._ref);

  final Ref _ref;

  Future<void> saveWeekTotal(DateTime week, double amount) =>
      _ref.read(weekBudgetProvider.notifier).saveWeekTotal(week, amount);
}
