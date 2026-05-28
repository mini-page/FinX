import 'package:hive/hive.dart';

import '../models/account_model.dart';

class AccountLocalDatasource {
  static const String boxName = 'accounts';

  Box<AccountModel> get _box => Hive.box<AccountModel>(boxName);

  Future<List<AccountModel>> getAllAccounts() async {
    final accounts = _box.values.toList(growable: false)
      ..sort((left, right) => left.name.compareTo(right.name));
    return accounts;
  }

  Future<void> saveAccount(AccountModel account) async {
    await _box.put(account.id, account);
  }

  Future<void> saveAccounts(List<AccountModel> accounts) async {
    final entries = {for (final account in accounts) account.id: account};
    await _box.putAll(entries);
  }

  Future<void> deleteAccount(String id) async {
    await _box.delete(id);
  }
}
