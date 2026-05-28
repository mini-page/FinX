import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasource/account_local_datasource.dart';
import '../../data/models/account_model.dart';
import '../../data/repositories/hive_account_repository.dart';
import '../../domain/repositories/account_repository.dart';

const List<AccountSeed> defaultAccounts = <AccountSeed>[
  AccountSeed(name: 'HDFC Bank', iconKey: 'card', balance: 41479),
  AccountSeed(name: 'Cash', iconKey: 'tag', balance: 52696),
  AccountSeed(name: 'PayTM Wallet', iconKey: 'wallet', balance: 1250),
  AccountSeed(name: 'Amazon Pay', iconKey: 'gift', balance: 850),
];

final accountLocalDatasourceProvider = Provider<AccountLocalDatasource>((ref) {
  return AccountLocalDatasource();
});

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return HiveAccountRepository(ref.watch(accountLocalDatasourceProvider));
});

final accountListProvider =
    AsyncNotifierProvider<AccountListNotifier, List<AccountModel>>(
  AccountListNotifier.new,
);

final accountControllerProvider = Provider<AccountController>((ref) {
  return AccountController(ref);
});

final accountSummaryProvider = Provider<AccountSummary>((ref) {
  final accounts =
      ref.watch(accountListProvider).value ?? const <AccountModel>[];
  final totalBalance = accounts.fold<double>(
    0,
    (sum, account) => sum + account.balance,
  );
  return AccountSummary(
    totalBalance: totalBalance,
    accountCount: accounts.length,
  );
});

class AccountListNotifier extends AsyncNotifier<List<AccountModel>> {
  AccountRepository get _repository => ref.read(accountRepositoryProvider);

  @override
  Future<List<AccountModel>> build() async {
    try {
      final accounts = await _repository.getAllAccounts();
      if (accounts.isNotEmpty) {
        return accounts;
      }

      final seededAccounts = defaultAccounts.map((seed) {
        return AccountModel.create(
          name: seed.name,
          iconKey: seed.iconKey,
          balance: seed.balance,
        );
      }).toList(growable: false);

      await _repository.saveAccounts(seededAccounts);

      return seededAccounts;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        dev.log(
          'Failed to fetch or seed accounts',
          error: e,
          stackTrace: stackTrace,
          name: 'AccountListNotifier',
        );
      }
      return defaultAccounts.map((seed) {
        return AccountModel.create(
          name: seed.name,
          iconKey: seed.iconKey,
          balance: seed.balance,
        );
      }).toList(growable: false);
    }
  }

  Future<void> saveAccount(AccountModel account) async {
    final currentAccounts = state.value ?? const <AccountModel>[];
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repository.saveAccount(account);
      final updated = <AccountModel>[
        for (final item in currentAccounts)
          if (item.id != account.id) item,
        account,
      ]..sort((left, right) => left.name.compareTo(right.name));
      return updated;
    });
  }

  Future<void> deleteAccount(String id) async {
    final currentAccounts = state.value ?? const <AccountModel>[];
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repository.deleteAccount(id);
      return currentAccounts
          .where((account) => account.id != id)
          .toList(growable: false);
    });
  }
}

class AccountController {
  AccountController(this._ref);

  final Ref _ref;

  Future<void> saveAccount({
    String? id,
    required String name,
    required String iconKey,
    required double balance,
  }) async {
    final account = id == null
        ? AccountModel.create(name: name, iconKey: iconKey, balance: balance)
        : AccountModel(id: id, name: name, iconKey: iconKey, balance: balance);

    await _ref.read(accountListProvider.notifier).saveAccount(account);
  }

  Future<void> deleteAccount(String id) async {
    await _ref.read(accountListProvider.notifier).deleteAccount(id);
  }
}

class AccountSummary {
  const AccountSummary({
    required this.totalBalance,
    required this.accountCount,
  });

  final double totalBalance;
  final int accountCount;
}

class AccountSeed {
  const AccountSeed({
    required this.name,
    required this.iconKey,
    required this.balance,
  });

  final String name;
  final String iconKey;
  final double balance;
}
