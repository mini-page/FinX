import 'package:hive/hive.dart';

/// Hive-backed store for **per-week** budget data using a plain [Box<double>].
///
/// Key conventions:
///   * Total weekly budget    → `"__total__::YYYY-Www"`
///   * Category override      → `"YYYY-Www::CategoryName"`
class WeekBudgetLocalDatasource {
  static const String boxName = 'week_budgets';
  static const String _kTotalPrefix = '__total__::';

  Box<double> get _box => Hive.box<double>(boxName);

  double? getWeekTotalBudget(String weekKey) =>
      _box.get('$_kTotalPrefix$weekKey');

  Future<void> saveWeekTotalBudget(String weekKey, double amount) =>
      _box.put('$_kTotalPrefix$weekKey', amount);

  Map<String, double> getCategoryBudgetsForWeek(String weekKey) {
    final prefix = '$weekKey::';
    final result = <String, double>{};
    for (final rawKey in _box.keys) {
      final key = rawKey as String;
      if (key.startsWith(prefix)) {
        final value = _box.get(key);
        if (value != null) {
          result[key.substring(prefix.length)] = value;
        }
      }
    }
    return result;
  }

  Future<void> saveCategoryBudgetForWeek(
    String weekKey,
    String category,
    double amount,
  ) =>
      _box.put('$weekKey::$category', amount);

  ({
    Map<String, double> totalBudgets,
    Map<String, Map<String, double>> categoryBudgets,
  }) loadAll() {
    final totalBudgets = <String, double>{};
    final categoryBudgets = <String, Map<String, double>>{};

    for (final rawKey in _box.keys) {
      final key = rawKey as String;
      final value = _box.get(key);
      if (value == null) continue;

      if (key.startsWith(_kTotalPrefix)) {
        totalBudgets[key.substring(_kTotalPrefix.length)] = value;
      } else {
        final sep = key.indexOf('::');
        if (sep == -1) continue;
        final weekKey = key.substring(0, sep);
        final category = key.substring(sep + 2);
        (categoryBudgets[weekKey] ??= {})[category] = value;
      }
    }

    return (totalBudgets: totalBudgets, categoryBudgets: categoryBudgets);
  }
}
