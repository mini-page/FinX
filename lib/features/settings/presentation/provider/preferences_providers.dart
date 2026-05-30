import 'dart:convert';
import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:workmanager/workmanager.dart';

import '../../data/datasource/preferences_local_datasource.dart';
import '../../data/models/app_preferences_model.dart';
import 'package:xpens/features/categories/data/models/custom_category_model.dart';
import '../../data/repositories/hive_preferences_repository.dart';
import '../../domain/repositories/preferences_repository.dart';
import 'package:xpens/features/categories/presentation/widgets/expense_category.dart';

const String backupTaskTag = 'xpens_offline_backup';

final preferencesLocalDatasourceProvider = Provider<PreferencesLocalDatasource>(
  (ref) {
    return PreferencesLocalDatasource();
  },
);

final preferencesRepositoryProvider = Provider<PreferencesRepository>((ref) {
  return HivePreferencesRepository(
    ref.watch(preferencesLocalDatasourceProvider),
  );
});

final appPreferencesProvider =
    AsyncNotifierProvider<AppPreferencesNotifier, AppPreferencesModel>(
  AppPreferencesNotifier.new,
);

final appPreferencesControllerProvider = Provider<AppPreferencesController>((
  ref,
) {
  return AppPreferencesController(ref);
});

final privacyModeEnabledProvider = Provider<bool>((ref) {
  return ref.watch(appPreferencesProvider).value?.privacyModeEnabled ??
      AppPreferencesModel.defaults.privacyModeEnabled;
});

final localeProvider = Provider<String>((ref) {
  return ref.watch(appPreferencesProvider).value?.locale ??
      AppPreferencesModel.defaults.locale;
});

final currencySymbolProvider = Provider<String>((ref) {
  return ref.watch(appPreferencesProvider).value?.currencySymbol ??
      AppPreferencesModel.defaults.currencySymbol;
});

final disabledExpenseCategoriesProvider = Provider<Set<String>>((ref) {
  return ref
          .watch(appPreferencesProvider)
          .value
          ?.disabledExpenseCategories
          .toSet() ??
      AppPreferencesModel.defaults.disabledExpenseCategories.toSet();
});

final disabledIncomeCategoriesProvider = Provider<Set<String>>((ref) {
  return ref
          .watch(appPreferencesProvider)
          .value
          ?.disabledIncomeCategories
          .toSet() ??
      AppPreferencesModel.defaults.disabledIncomeCategories.toSet();
});

final disabledAccountIdsProvider = Provider<Set<String>>((ref) {
  return ref.watch(appPreferencesProvider).value?.disabledAccountIds.toSet() ??
      AppPreferencesModel.defaults.disabledAccountIds.toSet();
});

/// A [NumberFormat] pre-configured with the user's locale and currency symbol,
/// using 0 decimal digits. Use this for displaying whole-number currency amounts.
final currencyFormatProvider = Provider<NumberFormat>((ref) {
  return NumberFormat.currency(
    locale: ref.watch(localeProvider),
    symbol: ref.watch(currencySymbolProvider),
    decimalDigits: 0,
  );
});

final displayNameProvider = Provider<String>((ref) {
  return ref.watch(appPreferencesProvider).value?.displayName ??
      AppPreferencesModel.defaults.displayName;
});

final isPinEnabledProvider = Provider<bool>((ref) {
  return ref.watch(appPreferencesProvider).value?.isPinEnabled ?? false;
});

final biometricLockEnabledProvider = Provider<bool>((ref) {
  return ref.watch(appPreferencesProvider).value?.biometricLockEnabled ??
      AppPreferencesModel.defaults.biometricLockEnabled;
});

final savingsGoalsJsonProvider = Provider<String>((ref) {
  return ref.watch(appPreferencesProvider).value?.savingsGoalsJson ?? '';
});

final customQuickAmountsProvider = Provider<List<double>>((ref) {
  final json =
      ref.watch(appPreferencesProvider).value?.customQuickAmountsJson ?? '';
  if (json.isEmpty) return const <double>[];
  try {
    final list = jsonDecode(json) as List<dynamic>;
    return list.map((e) => (e as num).toDouble()).toList();
  } catch (_) {
    return const <double>[];
  }
});

final hiddenDefaultAmountsProvider = Provider<List<double>>((ref) {
  final json =
      ref.watch(appPreferencesProvider).value?.hiddenDefaultAmountsJson ?? '';
  if (json.isEmpty) return const <double>[];
  try {
    final list = jsonDecode(json) as List<dynamic>;
    return list.map((e) => (e as num).toDouble()).toList();
  } catch (_) {
    return const <double>[];
  }
});

final customExpenseCategoryListProvider =
    Provider<List<CustomCategoryModel>>((ref) {
  final json =
      ref.watch(appPreferencesProvider).value?.customExpenseCategoriesJson ??
          '';
  return customCategoriesFromJson(json);
});

final customIncomeCategoryListProvider =
    Provider<List<CustomCategoryModel>>((ref) {
  final json =
      ref.watch(appPreferencesProvider).value?.customIncomeCategoriesJson ?? '';
  return customCategoriesFromJson(json);
});

final builtInExpenseCategoryOverridesProvider =
    Provider<List<BuiltInCategoryOverride>>((ref) {
  final json = ref
          .watch(appPreferencesProvider)
          .value
          ?.builtInExpenseCategoryOverridesJson ??
      '';
  return builtInOverridesFromJson(json);
});

final builtInIncomeCategoryOverridesProvider =
    Provider<List<BuiltInCategoryOverride>>((ref) {
  final json = ref
          .watch(appPreferencesProvider)
          .value
          ?.builtInIncomeCategoryOverridesJson ??
      '';
  return builtInOverridesFromJson(json);
});

/// All expense categories: built-in list (with user overrides) + user-defined custom categories.
final allExpenseCategoriesProvider = Provider<List<ExpenseCategory>>((ref) {
  final custom = ref.watch(customExpenseCategoryListProvider);
  final overrides = ref.watch(builtInExpenseCategoryOverridesProvider);
  final overridesMap = <String, BuiltInCategoryOverride>{
    for (final o in overrides) o.name: o,
  };
  return <ExpenseCategory>[
    ...expenseCategories.map((c) {
      final override = overridesMap[c.name];
      if (override == null) return c;
      return ExpenseCategory(
        name: c.name,
        icon: categoryIconFromKey(override.iconKey),
        color: Color(int.parse('FF${override.colorHex}', radix: 16)),
        iconKey: override.iconKey,
      );
    }),
    ...custom.map(
      (c) => ExpenseCategory(
        name: c.name,
        icon: categoryIconFromKey(c.iconKey),
        color: c.color,
        iconKey: c.iconKey,
      ),
    ),
  ];
});

/// All income categories: built-in list (with user overrides) + user-defined custom categories.
final allIncomeCategoriesProvider = Provider<List<ExpenseCategory>>((ref) {
  final custom = ref.watch(customIncomeCategoryListProvider);
  final overrides = ref.watch(builtInIncomeCategoryOverridesProvider);
  final overridesMap = <String, BuiltInCategoryOverride>{
    for (final o in overrides) o.name: o,
  };
  return <ExpenseCategory>[
    ...incomeCategories.map((c) {
      final override = overridesMap[c.name];
      if (override == null) return c;
      return ExpenseCategory(
        name: c.name,
        icon: categoryIconFromKey(override.iconKey),
        color: Color(int.parse('FF${override.colorHex}', radix: 16)),
        iconKey: override.iconKey,
      );
    }),
    ...custom.map(
      (c) => ExpenseCategory(
        name: c.name,
        icon: categoryIconFromKey(c.iconKey),
        color: c.color,
        iconKey: c.iconKey,
      ),
    ),
  ];
});

final categorySubcategoriesProvider = Provider<Map<String, List<String>>>((ref) {
  final json = ref.watch(appPreferencesProvider).value?.categorySubcategoriesJson ?? '';
  if (json.isEmpty) {
    return const {
      'Food & Dining': ['breakfast', 'lunch', 'dinner', 'coffee', 'tea', 'snacks', 'cold drink'],
      'Transportation': ['bus', 'train', 'ola', 'uber'],
      'Shopping': ['clothes', 'electronics', 'groceries', 'gifts', 'shoes'],
      'Beauty & Care': ['haircut', 'cosmetics', 'skincare', 'spa'],
      'Social': ['drinks', 'movies', 'party', 'restaurant'],
      'Travel': ['flight', 'hotel', 'sightseeing', 'taxi'],
      'Accessories': ['watch', 'jewelry', 'bag'],
      'Other': ['misc'],
      'Salary': ['monthly', 'bonus', 'freelance'],
      'Award': ['cash prize', 'certificate'],
      'Coupon': ['discount', 'gift card'],
      'Grant': ['scholarship', 'subsidy'],
      'Lottery': ['jackpot', 'scratch card'],
    };
  }
  try {
    final parsed = jsonDecode(json) as Map<String, dynamic>;
    return parsed.map((key, value) {
      final list = (value as List<dynamic>).map((e) => e.toString()).toList();
      return MapEntry(key, list);
    });
  } catch (_) {
    return const {};
  }
});

final isOnboardingCompletedProvider = Provider<bool>((ref) {
  return ref.watch(appPreferencesProvider).value?.isOnboardingCompleted ??
      AppPreferencesModel.defaults.isOnboardingCompleted;
});

final smartRemindersEnabledProvider = Provider<bool>((ref) {
  return ref.watch(appPreferencesProvider).value?.smartRemindersEnabled ??
      AppPreferencesModel.defaults.smartRemindersEnabled;
});

final aiApiKeyProvider = Provider<String>((ref) {
  return ref.watch(appPreferencesProvider).value?.aiApiKey ??
      AppPreferencesModel.defaults.aiApiKey;
});

final aiEnabledProvider = Provider<bool>((ref) {
  return ref.watch(appPreferencesProvider).value?.aiEnabled ??
      AppPreferencesModel.defaults.aiEnabled;
});

final aiModelIdProvider = Provider<String>((ref) {
  return ref.watch(appPreferencesProvider).value?.aiModelId ??
      AppPreferencesModel.defaults.aiModelId;
});

final aiSmartSearchEnabledProvider = Provider<bool>((ref) {
  return ref.watch(appPreferencesProvider).value?.aiSmartSearchEnabled ??
      AppPreferencesModel.defaults.aiSmartSearchEnabled;
});

final aiVoiceEnabledProvider = Provider<bool>((ref) {
  return ref.watch(appPreferencesProvider).value?.aiVoiceEnabled ??
      AppPreferencesModel.defaults.aiVoiceEnabled;
});

final aiScannerEnabledProvider = Provider<bool>((ref) {
  return ref.watch(appPreferencesProvider).value?.aiScannerEnabled ??
      AppPreferencesModel.defaults.aiScannerEnabled;
});

final aiSmsAiEnabledProvider = Provider<bool>((ref) {
  return ref.watch(appPreferencesProvider).value?.aiSmsAiEnabled ??
      AppPreferencesModel.defaults.aiSmsAiEnabled;
});

final autoBackupEnabledProvider = Provider<bool>((ref) {
  return ref.watch(appPreferencesProvider).value?.autoBackupEnabled ??
      AppPreferencesModel.defaults.autoBackupEnabled;
});

final backupFrequencyProvider = Provider<String>((ref) {
  return ref.watch(appPreferencesProvider).value?.backupFrequency ??
      AppPreferencesModel.defaults.backupFrequency;
});

final backupDirectoryPathProvider = Provider<String?>((ref) {
  return ref.watch(appPreferencesProvider).value?.backupDirectoryPath;
});

final lastBackupDateTimeProvider = Provider<DateTime?>((ref) {
  return ref.watch(appPreferencesProvider).value?.lastBackupDateTime;
});

final appThemeModeProvider = Provider<ThemeMode>((ref) {
  final key = ref.watch(appPreferencesProvider).value?.themeModeKey ??
      AppPreferencesModel.defaults.themeModeKey;
  switch (key) {
    case 'dark':
      return ThemeMode.dark;
    case 'system':
      return ThemeMode.system;
    default:
      return ThemeMode.light;
  }
});

class AppPreferencesNotifier extends AsyncNotifier<AppPreferencesModel> {
  PreferencesRepository get _repository =>
      ref.read(preferencesRepositoryProvider);

  @override
  Future<AppPreferencesModel> build() async {
    try {
      return await _repository.getPreferences();
    } catch (e, stackTrace) {
      if (kDebugMode) {
        dev.log(
          'Failed to fetch preferences',
          error: e,
          stackTrace: stackTrace,
          name: 'AppPreferencesNotifier',
        );
      }
      return AppPreferencesModel.defaults;
    }
  }

  Future<void> save(AppPreferencesModel preferences) async {
    state = await AsyncValue.guard(() async {
      await _repository.savePreferences(preferences);
      return preferences;
    });
  }
}

class AppPreferencesController {
  AppPreferencesController(this._ref);

  final Ref _ref;

  AppPreferencesModel get _current =>
      _ref.read(appPreferencesProvider).value ?? AppPreferencesModel.defaults;

  Future<void> setDisplayName(String name) async {
    await _ref
        .read(appPreferencesProvider.notifier)
        .save(_current.copyWith(displayName: name));
  }

  Future<void> setPin(String pinHash) async {
    await _ref
        .read(appPreferencesProvider.notifier)
        .save(_current.copyWith(pinHash: pinHash));
  }

  Future<void> clearPin() async {
    await _ref
        .read(appPreferencesProvider.notifier)
        .save(_current.copyWith(clearPin: true));
  }

  Future<void> setBiometricLock(bool enabled) async {
    await _ref
        .read(appPreferencesProvider.notifier)
        .save(_current.copyWith(biometricLockEnabled: enabled));
  }

  Future<void> setWhatsNewShownVersion(String version) async {
    await _ref
        .read(appPreferencesProvider.notifier)
        .save(_current.copyWith(whatsNewShownVersion: version));
  }

  Future<void> setSavingsGoalsJson(String json) async {
    await _ref
        .read(appPreferencesProvider.notifier)
        .save(_current.copyWith(savingsGoalsJson: json));
  }

  Future<void> setThemeMode(String themeModeKey) async {
    await _ref
        .read(appPreferencesProvider.notifier)
        .save(_current.copyWith(themeModeKey: themeModeKey));
  }

  Future<void> setPrivacyMode(bool enabled) async {
    await _ref
        .read(appPreferencesProvider.notifier)
        .save(_current.copyWith(privacyModeEnabled: enabled));
  }

  Future<void> setSmartReminders(bool enabled) async {
    await _ref
        .read(appPreferencesProvider.notifier)
        .save(_current.copyWith(smartRemindersEnabled: enabled));
  }

  Future<void> setOnboardingCompleted(bool completed) async {
    await _ref
        .read(appPreferencesProvider.notifier)
        .save(_current.copyWith(isOnboardingCompleted: completed));
  }

  Future<void> setLocale(String locale) async {
    await _ref
        .read(appPreferencesProvider.notifier)
        .save(_current.copyWith(locale: locale));
  }

  Future<void> setCurrencySymbol(String currencySymbol) async {
    await _ref
        .read(appPreferencesProvider.notifier)
        .save(_current.copyWith(currencySymbol: currencySymbol));
  }

  Future<void> setAutoBackup(bool enabled) async {
    final next = _current.copyWith(autoBackupEnabled: enabled);
    await _ref.read(appPreferencesProvider.notifier).save(next);

    if (enabled) {
      _scheduleBackup(next.backupFrequency);
    } else {
      Workmanager().cancelByTag(backupTaskTag);
    }
  }

  Future<void> setBackupFrequency(String frequency) async {
    final next = _current.copyWith(backupFrequency: frequency);
    await _ref.read(appPreferencesProvider.notifier).save(next);

    if (next.autoBackupEnabled) {
      _scheduleBackup(frequency);
    }
  }

  void _scheduleBackup(String frequency) {
    Duration duration;
    switch (frequency) {
      case 'weekly':
        duration = const Duration(days: 7);
        break;
      case 'monthly':
        duration = const Duration(days: 30);
        break;
      default:
        duration = const Duration(days: 1);
    }

    Workmanager().registerPeriodicTask(
      'xpens-periodic-backup',
      'xpens-periodic-backup-task',
      tag: backupTaskTag,
      frequency: duration,
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
      constraints: Constraints(
        networkType: NetworkType.notRequired,
        requiresStorageNotLow: true,
      ),
    );
  }

  Future<void> setBackupDirectory(String? path) async {
    await _ref.read(appPreferencesProvider.notifier).save(
          _current.copyWith(
            backupDirectoryPath: path,
            clearBackupDirectory: path == null,
          ),
        );
  }

  Future<void> setLastBackup(DateTime dateTime) async {
    await _ref
        .read(appPreferencesProvider.notifier)
        .save(_current.copyWith(lastBackupDateTime: dateTime));
  }

  Future<void> setCustomQuickAmounts(List<double> amounts) async {
    await _ref.read(appPreferencesProvider.notifier).save(
          _current.copyWith(
            customQuickAmountsJson: jsonEncode(amounts),
          ),
        );
  }

  Future<void> setHiddenDefaultAmounts(List<double> amounts) async {
    await _ref.read(appPreferencesProvider.notifier).save(
          _current.copyWith(
            hiddenDefaultAmountsJson: jsonEncode(amounts),
          ),
        );
  }

  Future<void> addExpenseCategory(CustomCategoryModel category) async {
    final list = customCategoriesFromJson(_current.customExpenseCategoriesJson);
    list.add(category);
    await _ref.read(appPreferencesProvider.notifier).save(
          _current.copyWith(
            customExpenseCategoriesJson: customCategoriesToJson(list),
          ),
        );
  }

  Future<void> updateExpenseCategory(CustomCategoryModel category) async {
    final list = customCategoriesFromJson(_current.customExpenseCategoriesJson);
    final index = list.indexWhere((c) => c.id == category.id);
    if (index != -1) {
      list[index] = category;
    }
    await _ref.read(appPreferencesProvider.notifier).save(
          _current.copyWith(
            customExpenseCategoriesJson: customCategoriesToJson(list),
          ),
        );
  }

  Future<void> removeExpenseCategory(String id) async {
    final list = customCategoriesFromJson(_current.customExpenseCategoriesJson);
    list.removeWhere((c) => c.id == id);
    await _ref.read(appPreferencesProvider.notifier).save(
          _current.copyWith(
            customExpenseCategoriesJson: customCategoriesToJson(list),
          ),
        );
  }

  Future<void> addIncomeCategory(CustomCategoryModel category) async {
    final list = customCategoriesFromJson(_current.customIncomeCategoriesJson);
    list.add(category);
    await _ref.read(appPreferencesProvider.notifier).save(
          _current.copyWith(
            customIncomeCategoriesJson: customCategoriesToJson(list),
          ),
        );
  }

  Future<void> updateIncomeCategory(CustomCategoryModel category) async {
    final list = customCategoriesFromJson(_current.customIncomeCategoriesJson);
    final index = list.indexWhere((c) => c.id == category.id);
    if (index != -1) {
      list[index] = category;
    }
    await _ref.read(appPreferencesProvider.notifier).save(
          _current.copyWith(
            customIncomeCategoriesJson: customCategoriesToJson(list),
          ),
        );
  }

  Future<void> removeIncomeCategory(String id) async {
    final list = customCategoriesFromJson(_current.customIncomeCategoriesJson);
    list.removeWhere((c) => c.id == id);
    await _ref.read(appPreferencesProvider.notifier).save(
          _current.copyWith(
            customIncomeCategoriesJson: customCategoriesToJson(list),
          ),
        );
  }

  Future<void> setExpenseCategoryEnabled(
    String categoryName,
    bool enabled,
  ) async {
    await _saveAndEnsure(
      _current.copyWith(
        disabledExpenseCategories: _toggleDisabledValue(
          _current.disabledExpenseCategories,
          categoryName,
          enabled,
        ),
      ),
    );
  }

  Future<void> setIncomeCategoryEnabled(
    String categoryName,
    bool enabled,
  ) async {
    await _saveAndEnsure(
      _current.copyWith(
        disabledIncomeCategories: _toggleDisabledValue(
          _current.disabledIncomeCategories,
          categoryName,
          enabled,
        ),
      ),
    );
  }

  Future<void> setAccountEnabled(String accountId, bool enabled) async {
    await _saveAndEnsure(
      _current.copyWith(
        disabledAccountIds: _toggleDisabledValue(
          _current.disabledAccountIds,
          accountId,
          enabled,
        ),
      ),
    );
  }

  Future<void> updateAll({
    required String themeModeKey,
    required String locale,
    required String currencySymbol,
    required bool smartRemindersEnabled,
    required bool isOnboardingCompleted,
  }) async {
    await _ref.read(appPreferencesProvider.notifier).save(
          _current.copyWith(
            themeModeKey: themeModeKey,
            locale: locale,
            currencySymbol: currencySymbol,
            smartRemindersEnabled: smartRemindersEnabled,
            isOnboardingCompleted: isOnboardingCompleted,
          ),
        );
  }

  Future<void> saveBuiltInExpenseCategoryOverride(
    BuiltInCategoryOverride override,
  ) async {
    final list =
        builtInOverridesFromJson(_current.builtInExpenseCategoryOverridesJson);
    final index = list.indexWhere((o) => o.name == override.name);
    if (index != -1) {
      list[index] = override;
    } else {
      list.add(override);
    }
    await _ref.read(appPreferencesProvider.notifier).save(
          _current.copyWith(
            builtInExpenseCategoryOverridesJson: builtInOverridesToJson(list),
          ),
        );
  }

  Future<void> saveBuiltInIncomeCategoryOverride(
    BuiltInCategoryOverride override,
  ) async {
    final list =
        builtInOverridesFromJson(_current.builtInIncomeCategoryOverridesJson);
    final index = list.indexWhere((o) => o.name == override.name);
    if (index != -1) {
      list[index] = override;
    } else {
      list.add(override);
    }
    await _ref.read(appPreferencesProvider.notifier).save(
          _current.copyWith(
            builtInIncomeCategoryOverridesJson: builtInOverridesToJson(list),
          ),
        );
  }

  List<String> _toggleDisabledValue(
    List<String> currentValues,
    String value,
    bool enabled,
  ) {
    final next = currentValues.toSet();
    if (enabled) {
      next.remove(value);
    } else {
      next.add(value);
    }
    return next.toList()..sort();
  }

  Future<void> _saveAndEnsure(AppPreferencesModel next) async {
    await _ref.read(appPreferencesProvider.notifier).save(next);
    final state = _ref.read(appPreferencesProvider);
    if (state case AsyncError<AppPreferencesModel>(:final error)) {
      throw error;
    }
  }

  // ── SMS Parsing ────────────────────────────────────────────────────────

  Future<void> setSmsParsingEnabled(bool enabled) async {
    await _ref
        .read(appPreferencesProvider.notifier)
        .save(_current.copyWith(smsParsingEnabled: enabled));
  }

  Future<void> setSmsDefaultAccountId(String accountId) async {
    await _ref
        .read(appPreferencesProvider.notifier)
        .save(_current.copyWith(smsDefaultAccountId: accountId));
  }

  Future<void> setSmsDefaultCategory(String category) async {
    await _ref
        .read(appPreferencesProvider.notifier)
        .save(_current.copyWith(smsDefaultCategory: category));
  }

  Future<void> setAiApiKey(String key) async {
    // When key is cleared, also disable AI features so the user can't
    // accidentally leave AI "on" with no key.
    final disableAi = key.isEmpty;
    await _ref.read(appPreferencesProvider.notifier).save(
          _current.copyWith(
            aiApiKey: key,
            aiEnabled: disableAi ? false : _current.aiEnabled,
          ),
        );
  }

  Future<void> setAiEnabled(bool enabled) async {
    await _ref
        .read(appPreferencesProvider.notifier)
        .save(_current.copyWith(aiEnabled: enabled));
  }

  Future<void> setAiModelId(String modelId) async {
    await _ref
        .read(appPreferencesProvider.notifier)
        .save(_current.copyWith(aiModelId: modelId));
  }

  Future<void> setAiSmartSearchEnabled(bool enabled) async {
    await _ref
        .read(appPreferencesProvider.notifier)
        .save(_current.copyWith(aiSmartSearchEnabled: enabled));
  }

  Future<void> setAiVoiceEnabled(bool enabled) async {
    await _ref
        .read(appPreferencesProvider.notifier)
        .save(_current.copyWith(aiVoiceEnabled: enabled));
  }

  Future<void> setAiScannerEnabled(bool enabled) async {
    await _ref
        .read(appPreferencesProvider.notifier)
        .save(_current.copyWith(aiScannerEnabled: enabled));
  }

  Future<void> setAiSmsAiEnabled(bool enabled) async {
    await _ref
        .read(appPreferencesProvider.notifier)
        .save(_current.copyWith(aiSmsAiEnabled: enabled));
  }

  Future<void> addSubcategory(String categoryName, String subcategory) async {
    final rawJson = _current.categorySubcategoriesJson;
    Map<String, List<String>> map = {};
    if (rawJson.isEmpty) {
      map = {
        'Food & Dining': ['breakfast', 'lunch', 'dinner', 'coffee', 'tea', 'snacks', 'cold drink'],
        'Transportation': ['bus', 'train', 'ola', 'uber'],
        'Shopping': ['clothes', 'electronics', 'groceries', 'gifts', 'shoes'],
        'Beauty & Care': ['haircut', 'cosmetics', 'skincare', 'spa'],
        'Social': ['drinks', 'movies', 'party', 'restaurant'],
        'Travel': ['flight', 'hotel', 'sightseeing', 'taxi'],
        'Accessories': ['watch', 'jewelry', 'bag'],
        'Other': ['misc'],
        'Salary': ['monthly', 'bonus', 'freelance'],
        'Award': ['cash prize', 'certificate'],
        'Coupon': ['discount', 'gift card'],
        'Grant': ['scholarship', 'subsidy'],
        'Lottery': ['jackpot', 'scratch card'],
      };
    } else {
      try {
        final parsed = jsonDecode(rawJson) as Map<String, dynamic>;
        map = parsed.map((key, value) {
          final list = (value as List<dynamic>).map((e) => e.toString()).toList();
          return MapEntry(key, list);
        });
      } catch (_) {
        map = {};
      }
    }

    final list = map[categoryName] ?? [];
    final clean = subcategory.trim();
    if (clean.isNotEmpty && !list.contains(clean)) {
      final newList = List<String>.from(list)..add(clean);
      final newMap = Map<String, List<String>>.from(map)..[categoryName] = newList;
      await _ref.read(appPreferencesProvider.notifier).save(
            _current.copyWith(
              categorySubcategoriesJson: jsonEncode(newMap),
            ),
          );
    }
  }

  Future<void> removeSubcategory(String categoryName, String subcategory) async {
    final rawJson = _current.categorySubcategoriesJson;
    Map<String, List<String>> map = {};
    if (rawJson.isNotEmpty) {
      try {
        final parsed = jsonDecode(rawJson) as Map<String, dynamic>;
        map = parsed.map((key, value) {
          final list = (value as List<dynamic>).map((e) => e.toString()).toList();
          return MapEntry(key, list);
        });
      } catch (_) {
        map = {};
      }
    }
    final list = map[categoryName];
    if (list != null && list.contains(subcategory)) {
      final newList = List<String>.from(list)..remove(subcategory);
      final newMap = Map<String, List<String>>.from(map)..[categoryName] = newList;
      await _ref.read(appPreferencesProvider.notifier).save(
            _current.copyWith(
              categorySubcategoriesJson: jsonEncode(newMap),
            ),
          );
    }
  }
}
