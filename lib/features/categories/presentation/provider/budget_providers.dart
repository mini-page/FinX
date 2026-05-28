import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasource/budget_local_datasource.dart';
import '../../data/models/budget_model.dart';
import '../../data/repositories/hive_budget_repository.dart';
import '../../domain/repositories/budget_repository.dart';

const Map<String, double> defaultBudgetTargets = <String, double>{
  'Food & Dining': 5000,
  'Transportation': 3000,
  'Shopping': 5000,
  'Beauty & Care': 2000,
  'Social': 2000,
  'Travel': 7000,
};

final budgetLocalDatasourceProvider = Provider<BudgetLocalDatasource>((ref) {
  return BudgetLocalDatasource();
});

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return HiveBudgetRepository(ref.watch(budgetLocalDatasourceProvider));
});

final budgetTargetsProvider =
    AsyncNotifierProvider<BudgetTargetsNotifier, Map<String, double>>(
  BudgetTargetsNotifier.new,
);

final budgetControllerProvider = Provider<BudgetController>((ref) {
  return BudgetController(ref);
});

class BudgetTargetsNotifier extends AsyncNotifier<Map<String, double>> {
  BudgetRepository get _repository => ref.read(budgetRepositoryProvider);

  @override
  Future<Map<String, double>> build() async {
    try {
      final savedBudgets = await _repository.getAllBudgets();
      final merged = <String, double>{...defaultBudgetTargets};
      for (final budget in savedBudgets) {
        merged[budget.category] = budget.monthlyLimit;
      }
      return merged;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        dev.log(
          'Failed to fetch or merge budgets',
          error: e,
          stackTrace: stackTrace,
          name: 'BudgetTargetsNotifier',
        );
      }
      return <String, double>{...defaultBudgetTargets};
    }
  }

  Future<void> saveBudget({
    required String category,
    required double monthlyLimit,
  }) async {
    final currentBudgets =
        state.value ?? <String, double>{...defaultBudgetTargets};
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repository.saveBudget(
        BudgetModel(category: category, monthlyLimit: monthlyLimit),
      );
      return <String, double>{...currentBudgets, category: monthlyLimit};
    });
  }
}

class BudgetController {
  BudgetController(this._ref);

  final Ref _ref;

  Future<void> saveBudget({
    required String category,
    required double monthlyLimit,
  }) async {
    await _ref
        .read(budgetTargetsProvider.notifier)
        .saveBudget(category: category, monthlyLimit: monthlyLimit);
  }
}
