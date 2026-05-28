import '../../domain/repositories/budget_repository.dart';
import '../datasource/budget_local_datasource.dart';
import '../models/budget_model.dart';

class HiveBudgetRepository implements BudgetRepository {
  HiveBudgetRepository(this._localDatasource);

  final BudgetLocalDatasource _localDatasource;

  @override
  Future<List<BudgetModel>> getAllBudgets() {
    return _localDatasource.getAllBudgets();
  }

  @override
  Future<void> saveBudget(BudgetModel budget) {
    return _localDatasource.saveBudget(budget);
  }
}
