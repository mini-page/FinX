import '../../domain/repositories/account_repository.dart';
import '../datasource/account_local_datasource.dart';
import '../models/account_model.dart';

class HiveAccountRepository implements AccountRepository {
  HiveAccountRepository(this._localDatasource);

  final AccountLocalDatasource _localDatasource;

  @override
  Future<void> deleteAccount(String id) {
    return _localDatasource.deleteAccount(id);
  }

  @override
  Future<List<AccountModel>> getAllAccounts() {
    return _localDatasource.getAllAccounts();
  }

  @override
  Future<void> saveAccount(AccountModel account) {
    return _localDatasource.saveAccount(account);
  }

  @override
  Future<void> saveAccounts(List<AccountModel> accounts) {
    return _localDatasource.saveAccounts(accounts);
  }
}
