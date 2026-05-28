import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:xpens/features/expense/data/models/expense_model.dart';
import 'package:xpens/features/expense/data/datasource/expense_local_datasource.dart';

class BackupLocalDatasource {
  static const String backupExtension = '.xpens';

  Future<File> createBackup() async {
    final appDir = await getApplicationDocumentsDirectory();
    final backupFile = File(p.join(appDir.path,
        'xpens_backup${DateTime.now().millisecondsSinceEpoch}$backupExtension'));

    final encoder = ZipFileEncoder();
    encoder.create(backupFile.path);

    final directory = Directory(appDir.path);
    final files = directory.listSync();

    for (final file in files) {
      if (file is File &&
          (file.path.endsWith('.hive') || file.path.endsWith('.lock'))) {
        encoder.addFile(file);
      }
    }

    encoder.close();
    return backupFile;
  }

  Future<void> restoreBackup(File backupFile) async {
    final appDir = await getApplicationDocumentsDirectory();

    // Extract archive
    final bytes = await backupFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    for (final file in archive) {
      final filename = file.name;
      if (file.isFile) {
        final data = file.content as List<int>;
        File(p.join(appDir.path, filename))
          ..createSync(recursive: true)
          ..writeAsBytesSync(data);
      }
    }
  }

  Future<Directory> getAppDirectory() async {
    return getApplicationDocumentsDirectory();
  }

  /// Exports all transactions as a CSV file.
  ///
  /// Returns the temporary [File]. The caller is responsible for sharing /
  /// copying the file and then deleting it when done.
  Future<File> createCsvExport() async {
    final appDir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final csvFile =
        File(p.join(appDir.path, 'xpens_export_$timestamp.csv'));

    final box = Hive.box<ExpenseModel>(ExpenseLocalDatasource.boxName);
    final expenses = box.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final buffer = StringBuffer();
    buffer.writeln('id,date,type,category,amount,note,account_id,to_account_id');
    for (final e in expenses) {
      final date = e.date.toLocal().toIso8601String();
      final type = e.type.storageValue;
      final amount = e.amount.toStringAsFixed(2);
      final note = '"${e.note.replaceAll('"', '""')}"';
      final category = '"${e.category.replaceAll('"', '""')}"';
      final accountId = e.accountId ?? '';
      final toAccountId = e.toAccountId ?? '';
      buffer.writeln(
          '${e.id},$date,$type,$category,$amount,$note,$accountId,$toAccountId');
    }

    await csvFile.writeAsString(buffer.toString());
    return csvFile;
  }

  /// Exports all transactions as a pretty-printed JSON file.
  ///
  /// Returns the temporary [File]. The caller is responsible for sharing /
  /// copying the file and then deleting it when done.
  Future<File> createJsonExport() async {
    final appDir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final jsonFile =
        File(p.join(appDir.path, 'xpens_export_$timestamp.json'));

    final box = Hive.box<ExpenseModel>(ExpenseLocalDatasource.boxName);
    final expenses = box.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final data = <String, dynamic>{
      'exported_at': DateTime.now().toIso8601String(),
      'format_version': 1,
      'transaction_count': expenses.length,
      'transactions': expenses
          .map(
            (e) => <String, dynamic>{
              'id': e.id,
              'amount': e.amount,
              'category': e.category,
              'date': e.date.toIso8601String(),
              'note': e.note,
              'type': e.type.storageValue,
              'account_id': e.accountId,
              'to_account_id': e.toAccountId,
            },
          )
          .toList(),
    };

    const encoder = JsonEncoder.withIndent('  ');
    await jsonFile.writeAsString(encoder.convert(data));
    return jsonFile;
  }
}
