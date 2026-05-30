import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/widget_sync_service.dart';
import '../../data/datasource/expense_local_datasource.dart';
import 'package:xpens/features/accounts/data/models/account_model.dart';
import '../../data/models/expense_model.dart';
import '../../data/repositories/hive_expense_repository.dart';
import 'package:xpens/features/accounts/domain/repositories/account_repository.dart';
import '../../domain/repositories/expense_repository.dart';
import 'package:xpens/features/analytics/presentation/screens/stats/stats_widgets.dart';
import 'package:xpens/features/accounts/presentation/provider/account_providers.dart';
import 'package:xpens/features/settings/presentation/provider/preferences_providers.dart';

final expenseLocalDatasourceProvider = Provider<ExpenseLocalDatasource>((ref) {
  return ExpenseLocalDatasource();
});

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return HiveExpenseRepository(ref.watch(expenseLocalDatasourceProvider));
});

final expenseListProvider =
    AsyncNotifierProvider<ExpenseListNotifier, List<ExpenseModel>>(
  ExpenseListNotifier.new,
);

final expenseControllerProvider = Provider<ExpenseController>((ref) {
  return ExpenseController(ref);
});

final statsProvider = Provider<ExpenseStats>((ref) {
  final expenses =
      ref.watch(expenseListProvider).value ?? const <ExpenseModel>[];
  return ExpenseStats.fromExpenses(expenses);
});

final analyticsSnapshotProvider =
    Provider.family<AnalyticsSnapshot, String>((ref, rangeLabel) {
  final expenses =
      ref.watch(expenseListProvider).value ?? const <ExpenseModel>[];
  final allExpenseCategories = ref.watch(allExpenseCategoriesProvider);
  return AnalyticsSnapshot.fromExpenses(
    expenses,
    rangeLabel: rangeLabel,
    extraExpenseCategories: allExpenseCategories,
  );
});

class ExpenseListNotifier extends AsyncNotifier<List<ExpenseModel>> {
  ExpenseRepository get _repository => ref.read(expenseRepositoryProvider);

  @override
  Future<List<ExpenseModel>> build() async {
    try {
      return _repository.getAllExpenses();
    } catch (e, stackTrace) {
      if (kDebugMode) {
        dev.log(
          'Failed to fetch all expenses',
          error: e,
          stackTrace: stackTrace,
          name: 'ExpenseListNotifier',
        );
      }
      return <ExpenseModel>[];
    }
  }
}

class ExpenseController {
  ExpenseController(this._ref);

  final Ref _ref;

  ExpenseRepository get _expenseRepository =>
      _ref.read(expenseRepositoryProvider);
  AccountRepository get _accountRepository =>
      _ref.read(accountRepositoryProvider);

  Future<void> addExpense({
    required double amount,
    required String category,
    required DateTime date,
    required String note,
    String? accountId,
    TransactionType type = TransactionType.expense,
    String? subcategory,
    double? latitude,
    double? longitude,
  }) async {
    final expense = ExpenseModel.create(
      amount: amount,
      category: category,
      date: date,
      note: note.trim(),
      accountId: accountId,
      type: type,
      subcategory: subcategory,
      latitude: latitude,
      longitude: longitude,
    );

    await _applyBalanceAdjustments(nextExpense: expense);
    await _expenseRepository.saveExpense(expense);
    _refreshState();
  }

  Future<void> addTransfer({
    required double amount,
    required String fromAccountId,
    required String toAccountId,
    required DateTime date,
    required String note,
    double? latitude,
    double? longitude,
  }) async {
    final transfer = ExpenseModel.create(
      amount: amount,
      category: 'Transfer',
      date: date,
      note: note.trim(),
      accountId: fromAccountId,
      toAccountId: toAccountId,
      type: TransactionType.transfer,
      latitude: latitude,
      longitude: longitude,
    );

    await _applyBalanceAdjustments(nextExpense: transfer);
    await _expenseRepository.saveExpense(transfer);
    _refreshState();
  }

  Future<void> updateExpense({
    required String id,
    required double amount,
    required String category,
    required DateTime date,
    required String note,
    String? accountId,
    String? toAccountId,
    TransactionType type = TransactionType.expense,
    String? subcategory,
    double? latitude,
    double? longitude,
  }) async {
    final existingExpense = await _findExpenseById(id);
    if (existingExpense == null) {
      return;
    }

    final updatedExpense = existingExpense.copyWith(
      amount: amount,
      category: category.trim(),
      date: date,
      note: note.trim(),
      accountId: accountId,
      clearAccountId: accountId == null,
      toAccountId: type == TransactionType.transfer ? toAccountId : null,
      clearToAccountId: type != TransactionType.transfer || toAccountId == null,
      type: type,
      subcategory: subcategory,
      clearSubcategory: subcategory == null,
      latitude: latitude,
      clearLatitude: latitude == null,
      longitude: longitude,
      clearLongitude: longitude == null,
    );

    await _applyBalanceAdjustments(
      previousExpense: existingExpense,
      nextExpense: updatedExpense,
    );
    await _expenseRepository.saveExpense(updatedExpense);
    _refreshState();
  }

  Future<void> deleteExpense(String id) async {
    final existingExpense = await _findExpenseById(id);
    if (existingExpense == null) {
      return;
    }

    await _applyBalanceAdjustments(previousExpense: existingExpense);
    await _expenseRepository.deleteExpense(id);
    _refreshState();
  }

  Future<void> _applyBalanceAdjustments({
    ExpenseModel? previousExpense,
    ExpenseModel? nextExpense,
  }) async {
    final accounts = await _loadAccounts();
    if (accounts.isEmpty) {
      return;
    }

    final accountsById = <String, AccountModel>{
      for (final account in accounts) account.id: account,
    };
    final pendingUpdates = <String, AccountModel>{};

    void adjustBalance(String accountId, double delta) {
      final account = pendingUpdates[accountId] ?? accountsById[accountId];
      if (account != null) {
        pendingUpdates[accountId] =
            account.copyWith(balance: account.balance + delta);
      }
    }

    // Reverse the effect of the previous transaction.
    if (previousExpense != null) {
      if (previousExpense.type == TransactionType.transfer) {
        if (previousExpense.accountId case final String fromId) {
          adjustBalance(fromId, previousExpense.amount);
        }
        if (previousExpense.toAccountId case final String toId) {
          adjustBalance(toId, -previousExpense.amount);
        }
      } else if (previousExpense.accountId case final String accountId) {
        adjustBalance(
          accountId,
          previousExpense.isIncome
              ? -previousExpense.amount
              : previousExpense.amount,
        );
      }
    }

    // Apply the effect of the next (new/updated) transaction.
    if (nextExpense != null) {
      if (nextExpense.type == TransactionType.transfer) {
        if (nextExpense.accountId case final String fromId) {
          adjustBalance(fromId, -nextExpense.amount);
        }
        if (nextExpense.toAccountId case final String toId) {
          adjustBalance(toId, nextExpense.amount);
        }
      } else if (nextExpense.accountId case final String accountId) {
        adjustBalance(
          accountId,
          nextExpense.isIncome ? nextExpense.amount : -nextExpense.amount,
        );
      }
    }

    if (pendingUpdates.isNotEmpty) {
      await _accountRepository.saveAccounts(
        pendingUpdates.values.toList(growable: false),
      );
    }
  }

  Future<List<AccountModel>> _loadAccounts() async {
    final currentAccounts = _ref.read(accountListProvider).value;
    if (currentAccounts != null) {
      return currentAccounts;
    }

    try {
      return await _accountRepository.getAllAccounts();
    } catch (e, stackTrace) {
      if (kDebugMode) {
        dev.log(
          'Failed to load accounts for balance adjustments',
          error: e,
          stackTrace: stackTrace,
          name: 'ExpenseController',
        );
      }
      return <AccountModel>[];
    }
  }

  Future<ExpenseModel?> _findExpenseById(String id) async {
    final currentExpenses = _ref.read(expenseListProvider).value;
    final cachedExpense =
        currentExpenses?.where((expense) => expense.id == id).firstOrNull;
    if (cachedExpense != null) {
      return cachedExpense;
    }

    try {
      return await _expenseRepository.getExpenseById(id);
    } catch (e, stackTrace) {
      if (kDebugMode) {
        dev.log(
          'Failed to find expense by id: $id',
          error: e,
          stackTrace: stackTrace,
          name: 'ExpenseController',
        );
      }
      return null;
    }
  }

  void _refreshState() {
    _ref.invalidate(expenseListProvider);
    _ref.invalidate(accountListProvider);
  }
}

class ExpenseStats {
  const ExpenseStats({
    required this.monthTotal,
    required this.monthIncomeTotal,
    required this.monthNetTotal,
    required this.todayTotal,
    required this.todayIncomeTotal,
    required this.transactionCount,
    required this.categoryTotals,
    required this.incomeCategoryTotals,
  });

  factory ExpenseStats.fromExpenses(
    List<ExpenseModel> expenses, {
    DateTime? forMonth,
  }) {
    final now = DateTime.now();
    final reference = forMonth ?? now;
    final int currentYear = reference.year;
    final int currentMonth = reference.month;
    final bool isCurrentMonth =
        reference.year == now.year && reference.month == now.month;
    final int currentDay = now.day;

    int transactionCount = 0;

    final expenseTotals = <String, double>{};
    final incomeTotals = <String, double>{};

    double monthExpenseTotal = 0;
    double monthIncomeTotal = 0;
    double todayExpenseTotal = 0;
    double todayIncomeTotal = 0;

    for (final expense in expenses) {
      // Transfers are balance-neutral and excluded from income/expense stats.
      if (expense.type == TransactionType.transfer) {
        continue;
      }
      final localDate = expense.date.toLocal();
      if (localDate.year == currentYear && localDate.month == currentMonth) {
        transactionCount++;

        final bool isIncome = expense.isIncome;
        final double amount = expense.amount;

        final Map<String, double> targetMap =
            isIncome ? incomeTotals : expenseTotals;
        targetMap.update(
          expense.category,
          (value) => value + amount,
          ifAbsent: () => amount,
        );

        final bool isToday =
            isCurrentMonth && localDate.day == currentDay;

        if (isIncome) {
          monthIncomeTotal += amount;
          if (isToday) {
            todayIncomeTotal += amount;
          }
        } else {
          monthExpenseTotal += amount;
          if (isToday) {
            todayExpenseTotal += amount;
          }
        }
      }
    }

    final sortedExpenseEntries = expenseTotals.entries.toList()
      ..sort((left, right) => right.value.compareTo(left.value));
    final sortedIncomeEntries = incomeTotals.entries.toList()
      ..sort((left, right) => right.value.compareTo(left.value));

    return ExpenseStats(
      monthTotal: monthExpenseTotal,
      monthIncomeTotal: monthIncomeTotal,
      monthNetTotal: monthIncomeTotal - monthExpenseTotal,
      todayTotal: todayExpenseTotal,
      todayIncomeTotal: todayIncomeTotal,
      transactionCount: transactionCount,
      categoryTotals: Map<String, double>.fromEntries(sortedExpenseEntries),
      incomeCategoryTotals: Map<String, double>.fromEntries(
        sortedIncomeEntries,
      ),
    );
  }

  final double monthTotal;
  final double monthIncomeTotal;
  final double monthNetTotal;
  final double todayTotal;
  final double todayIncomeTotal;
  final int transactionCount;
  final Map<String, double> categoryTotals;
  final Map<String, double> incomeCategoryTotals;
}

// ── Widget sync provider ───────────────────────────────────────────────────

/// Derives the [WidgetDataPayload] from live Riverpod data.
///
/// Returns `null` while either accounts or expenses are still loading.
/// [AppShell] watches this via `ref.listen` and forwards changes to
/// [WidgetSyncService.syncData] which writes them to Android SharedPreferences
/// so the launcher widgets can display fresh data without opening the app.
final widgetDataPayloadProvider = Provider<WidgetDataPayload?>((ref) {
  final accounts = ref.watch(accountListProvider).value;
  final expenses = ref.watch(expenseListProvider).value;
  final symbol = ref.watch(currencySymbolProvider);

  if (accounts == null || expenses == null) return null;

  final totalBalance = accounts.fold<double>(0.0, (sum, a) => sum + a.balance);

  final sorted = (expenses.toList()..sort((a, b) => b.date.compareTo(a.date)))
      .take(20)
      .toList(growable: false);

  final txnList = sorted
      .map(
        (e) => <String, dynamic>{
          'id': e.id,
          'amount': e.amount,
          'category': e.category,
          'type': e.type.storageValue,
          'dateMs': e.date.millisecondsSinceEpoch,
          'note': e.note,
        },
      )
      .toList(growable: false);

  return WidgetDataPayload(
    totalBalance: totalBalance,
    currencySymbol: symbol,
    transactions: txnList,
  );
});
