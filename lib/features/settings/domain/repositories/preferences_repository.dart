import '../../data/models/app_preferences_model.dart';

abstract class PreferencesRepository {
  Future<AppPreferencesModel> getPreferences();
  Future<void> savePreferences(AppPreferencesModel preferences);
}
