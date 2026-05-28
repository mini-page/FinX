import 'package:hive/hive.dart';

import '../models/budget_model.dart';

class BudgetLocalDatasource {
  static const String boxName = 'category_budgets';

  Box<BudgetModel> get _box => Hive.box<BudgetModel>(boxName);

  Future<List<BudgetModel>> getAllBudgets() async {
    final budgets = _box.values.toList(growable: false)
      ..sort((left, right) => left.category.compareTo(right.category));
    return budgets;
  }

  Future<void> saveBudget(BudgetModel budget) async {
    await _box.put(budget.category, budget);
  }
}
