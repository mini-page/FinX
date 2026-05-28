import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:workmanager/workmanager.dart';
import 'package:xpens/features/settings/data/datasource/preferences_local_datasource.dart';
import 'package:xpens/features/settings/data/models/app_preferences_model.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await Hive.initFlutter();

      if (!Hive.isAdapterRegistered(AppPreferencesModelAdapter.typeIdValue)) {
        Hive.registerAdapter(AppPreferencesModelAdapter());
      }

      final box = await Hive.openBox<AppPreferencesModel>(
          PreferencesLocalDatasource.boxName);
      final preferences = box.get(PreferencesLocalDatasource.boxName);

      if (preferences == null || !preferences.autoBackupEnabled) {
        await box.close();
        return Future.value(true);
      }

      final appDir = await getApplicationDocumentsDirectory();

      // Resolve backup directory.  Prefer the user's saved path if it still
      // exists; otherwise fall back to the app-scoped external storage dir
      // which requires zero runtime permissions.
      Directory targetDir;
      final savedPath = preferences.backupDirectoryPath;
      if (savedPath != null) {
        final saved = Directory(savedPath);
        if (await saved.exists()) {
          targetDir = saved;
        } else {
          targetDir = await _resolveDefaultBackupDir();
        }
      } else {
        targetDir = await _resolveDefaultBackupDir();
      }

      // Create a timestamped .xpens backup file in the target directory.
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final backupFile =
          File(p.join(targetDir.path, 'xpens_backup_$timestamp.xpens'));

      final encoder = ZipFileEncoder();
      encoder.create(backupFile.path);

      final sourceDir = Directory(appDir.path);
      await for (final entity in sourceDir.list()) {
        if (entity is File &&
            (entity.path.endsWith('.hive') ||
                entity.path.endsWith('.lock'))) {
          encoder.addFile(entity);
        }
      }
      encoder.close();

      // Update last backup time
      await box.put(
          PreferencesLocalDatasource.boxName,
          preferences.copyWith(
            lastBackupDateTime: DateTime.now(),
          ));

      await box.close();
      return Future.value(true);
    } catch (e) {
      return Future.value(false);
    }
  });
}

/// Returns the app-scoped external backup directory, creating it if needed.
/// Falls back to the internal docs dir if external storage is unavailable.
/// No runtime storage permission is required.
Future<Directory> _resolveDefaultBackupDir() async {
  Directory base;
  try {
    final ext = await getExternalStorageDirectory();
    base = ext ?? await getApplicationDocumentsDirectory();
  } catch (_) {
    base = await getApplicationDocumentsDirectory();
  }
  final dir = Directory(p.join(base.path, 'XPens', 'Backups'));
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  return dir;
}
