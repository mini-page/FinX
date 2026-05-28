import '../../data/models/budget_model.dart';

abstract class BudgetRepository {
  Future<List<BudgetModel>> getAllBudgets();
  Future<void> saveBudget(BudgetModel budget);
}
