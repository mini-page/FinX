import 'package:hive_flutter/hive_flutter.dart';

import 'package:xpens/features/accounts/data/datasource/account_local_datasource.dart';
import 'package:xpens/features/categories/data/datasource/budget_local_datasource.dart';
import 'package:xpens/features/expense/data/datasource/expense_local_datasource.dart';
import 'package:xpens/features/categories/data/datasource/month_budget_local_datasource.dart';
import 'package:xpens/features/settings/data/datasource/preferences_local_datasource.dart';
import 'package:xpens/features/recurring/data/datasource/recurring_subscription_local_datasource.dart';
import 'package:xpens/features/accounts/data/models/account_model.dart';
import 'package:xpens/features/settings/data/models/app_preferences_model.dart';
import 'package:xpens/features/categories/data/models/budget_model.dart';
import 'package:xpens/features/expense/data/models/expense_model.dart';
import 'package:xpens/features/recurring/data/models/recurring_subscription_model.dart';

abstract final class HiveBootstrap {
  static Future<void> initialize() async {
    await Hive.initFlutter();

    if (!Hive.isAdapterRegistered(ExpenseModelAdapter.typeIdValue)) {
      Hive.registerAdapter(ExpenseModelAdapter());
    }
    if (!Hive.isAdapterRegistered(BudgetModelAdapter.typeIdValue)) {
      Hive.registerAdapter(BudgetModelAdapter());
    }
    if (!Hive.isAdapterRegistered(AccountModelAdapter.typeIdValue)) {
      Hive.registerAdapter(AccountModelAdapter());
    }
    if (!Hive.isAdapterRegistered(AppPreferencesModelAdapter.typeIdValue)) {
      Hive.registerAdapter(AppPreferencesModelAdapter());
    }
    if (!Hive.isAdapterRegistered(
      RecurringSubscriptionModelAdapter.typeIdValue,
    )) {
      Hive.registerAdapter(RecurringSubscriptionModelAdapter());
    }

    if (!Hive.isBoxOpen(ExpenseLocalDatasource.boxName)) {
      await Hive.openBox<ExpenseModel>(ExpenseLocalDatasource.boxName);
    }
    if (!Hive.isBoxOpen(BudgetLocalDatasource.boxName)) {
      await Hive.openBox<BudgetModel>(BudgetLocalDatasource.boxName);
    }
    if (!Hive.isBoxOpen(AccountLocalDatasource.boxName)) {
      await Hive.openBox<AccountModel>(AccountLocalDatasource.boxName);
    }
    if (!Hive.isBoxOpen(PreferencesLocalDatasource.boxName)) {
      await Hive.openBox<AppPreferencesModel>(
        PreferencesLocalDatasource.boxName,
      );
    }
    if (!Hive.isBoxOpen(RecurringSubscriptionLocalDatasource.boxName)) {
      await Hive.openBox<RecurringSubscriptionModel>(
        RecurringSubscriptionLocalDatasource.boxName,
      );
    }
    if (!Hive.isBoxOpen(MonthBudgetLocalDatasource.boxName)) {
      await Hive.openBox<double>(MonthBudgetLocalDatasource.boxName);
    }
  }
}
