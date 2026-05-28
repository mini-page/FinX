import '../../domain/repositories/preferences_repository.dart';
import '../datasource/preferences_local_datasource.dart';
import '../models/app_preferences_model.dart';

class HivePreferencesRepository implements PreferencesRepository {
  HivePreferencesRepository(this._localDatasource);

  final PreferencesLocalDatasource _localDatasource;

  @override
  Future<AppPreferencesModel> getPreferences() {
    return _localDatasource.getPreferences();
  }

  @override
  Future<void> savePreferences(AppPreferencesModel preferences) {
    return _localDatasource.savePreferences(preferences);
  }
}
