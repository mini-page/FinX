import '../../data/models/account_model.dart';

abstract class AccountRepository {
  Future<List<AccountModel>> getAllAccounts();
  Future<void> saveAccount(AccountModel account);
  Future<void> saveAccounts(List<AccountModel> accounts);
  Future<void> deleteAccount(String id);
}
