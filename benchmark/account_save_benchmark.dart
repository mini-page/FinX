import 'dart:io';

import 'package:xpens/features/accounts/data/datasource/account_local_datasource.dart';
import 'package:xpens/features/accounts/data/models/account_model.dart';
import 'package:hive/hive.dart';

// ignore_for_file: avoid_print

void main() async {
  final path = Directory.systemTemp.createTempSync('hive_benchmark_').path;
  Hive.init(path);
  Hive.registerAdapter(AccountModelAdapter());

  final box = await Hive.openBox<AccountModel>(AccountLocalDatasource.boxName);

  // Generate 1000 accounts
  final accounts = List.generate(
    1000,
    (index) => AccountModel.create(
      name: 'Account $index',
      iconKey: 'icon_$index',
      balance: index * 10.0,
    ),
  );

  print('--- Benchmarking Sequential Save vs Bulk Save ---');
  print('Number of accounts: ${accounts.length}');

  // 1. Benchmark Sequential Save (Current implementation)
  final sequentialWatch = Stopwatch()..start();
  for (final account in accounts) {
    await box.put(account.id, account);
  }
  sequentialWatch.stop();
  print('Sequential Save Time: ${sequentialWatch.elapsedMilliseconds} ms');

  // Clear box
  await box.clear();

  // 2. Benchmark Bulk Save (Proposed implementation)
  final bulkWatch = Stopwatch()..start();
  final entries = {for (var account in accounts) account.id: account};
  await box.putAll(entries);
  bulkWatch.stop();
  print('Bulk Save Time: ${bulkWatch.elapsedMilliseconds} ms');

  print('---');
  if (bulkWatch.elapsedMilliseconds > 0) {
    final improvement =
        sequentialWatch.elapsedMilliseconds / bulkWatch.elapsedMilliseconds;
    print('Improvement: ${improvement.toStringAsFixed(2)}x faster');
  }

  // Cleanup
  await box.close();
  Directory(path).deleteSync(recursive: true);
}
