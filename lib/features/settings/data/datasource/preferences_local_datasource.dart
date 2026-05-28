import 'package:hive/hive.dart';

import '../models/app_preferences_model.dart';

class PreferencesLocalDatasource {
  static const String boxName = 'app_preferences';
  static const String recordKey = 'primary';

  Box<AppPreferencesModel> get _box => Hive.box<AppPreferencesModel>(boxName);

  Future<AppPreferencesModel> getPreferences() async {
    return _box.get(recordKey) ?? AppPreferencesModel.defaults;
  }

  Future<void> savePreferences(AppPreferencesModel preferences) async {
    await _box.put(recordKey, preferences);
  }
}
