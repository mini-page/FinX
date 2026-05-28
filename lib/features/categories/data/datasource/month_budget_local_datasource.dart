import 'package:hive/hive.dart';

/// Hive-backed store for **per-month** budget data using a plain [Box<double>].
///
/// Key conventions:
///   * Total monthly budget → `"__total__::YYYY-MM"`
///   * Category override    → `"YYYY-MM::CategoryName"`
class MonthBudgetLocalDatasource {
  static const String boxName = 'month_budgets';
  static const String _kTotalPrefix = '__total__::';

  Box<double> get _box => Hive.box<double>(boxName);

  // ── total budget ──────────────────────────────────────────────────────────

  double? getMonthTotalBudget(String monthKey) =>
      _box.get('$_kTotalPrefix$monthKey');

  Future<void> saveMonthTotalBudget(String monthKey, double amount) =>
      _box.put('$_kTotalPrefix$monthKey', amount);

  // ── per-category overrides ─────────────────────────────────────────────────

  /// Returns category budget overrides stored for [monthKey].
  ///
  /// This scans all box keys, so prefer calling [loadAll] once at startup to
  /// build a complete in-memory snapshot rather than calling this repeatedly.
  Map<String, double> getCategoryBudgetsForMonth(String monthKey) {
    final prefix = '$monthKey::';
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

  Future<void> saveCategoryBudgetForMonth(
    String monthKey,
    String category,
    double amount,
  ) =>
      _box.put('$monthKey::$category', amount);

  // ── bulk load ──────────────────────────────────────────────────────────────

  /// Returns every stored entry as two maps so the provider layer can build
  /// its in-memory state without scanning the box again later.
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
        final monthKey = key.substring(0, sep);
        final category = key.substring(sep + 2);
        (categoryBudgets[monthKey] ??= {})[category] = value;
      }
    }

    return (totalBudgets: totalBudgets, categoryBudgets: categoryBudgets);
  }
}
