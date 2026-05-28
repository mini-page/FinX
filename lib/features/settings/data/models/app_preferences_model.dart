import 'package:hive/hive.dart';

class AppPreferencesModel {
  const AppPreferencesModel({
    required this.themeModeKey,
    required this.privacyModeEnabled,
    required this.smartRemindersEnabled,
    required this.locale,
    required this.currencySymbol,
    required this.isOnboardingCompleted,
    this.autoBackupEnabled = false,
    this.backupFrequency = 'daily',
    this.backupDirectoryPath,
    this.lastBackupDateTime,
    this.disabledExpenseCategories = const <String>[],
    this.disabledIncomeCategories = const <String>[],
    this.disabledAccountIds = const <String>[],
    this.displayName = '',
    this.pinHash = '',
    this.biometricLockEnabled = false,
    this.whatsNewShownVersion = '',
    this.savingsGoalsJson = '',
    this.customQuickAmountsJson = '',
    this.hiddenDefaultAmountsJson = '',
    this.customExpenseCategoriesJson = '',
    this.customIncomeCategoriesJson = '',
    this.builtInExpenseCategoryOverridesJson = '',
    this.builtInIncomeCategoryOverridesJson = '',
    this.smsParsingEnabled = false,
    this.smsDefaultAccountId = '',
    this.smsDefaultCategory = '',
    this.aiApiKey = '',
    this.aiEnabled = false,
    this.aiModelId = 'gemini-2.0-flash',
    this.aiSmartSearchEnabled = true,
    this.aiVoiceEnabled = true,
    this.aiScannerEnabled = true,
    this.aiSmsAiEnabled = true,
  });

  static const AppPreferencesModel defaults = AppPreferencesModel(
    themeModeKey: 'light',
    privacyModeEnabled: false,
    smartRemindersEnabled: true,
    locale: 'en_IN',
    currencySymbol: '₹',
    isOnboardingCompleted: false,
    autoBackupEnabled: false,
    backupFrequency: 'daily',
    disabledExpenseCategories: <String>[],
    disabledIncomeCategories: <String>[],
    disabledAccountIds: <String>[],
    displayName: '',
    pinHash: '',
    biometricLockEnabled: false,
    whatsNewShownVersion: '',
    savingsGoalsJson: '',
    customQuickAmountsJson: '',
    hiddenDefaultAmountsJson: '',
    customExpenseCategoriesJson: '',
    customIncomeCategoriesJson: '',
    builtInExpenseCategoryOverridesJson: '',
    builtInIncomeCategoryOverridesJson: '',
    smsParsingEnabled: false,
    smsDefaultAccountId: '',
    smsDefaultCategory: '',
    aiApiKey: '',
    aiEnabled: false,
    aiModelId: 'gemini-2.0-flash',
    aiSmartSearchEnabled: true,
    aiVoiceEnabled: true,
    aiScannerEnabled: true,
    aiSmsAiEnabled: true,
  );

  final String themeModeKey;
  final bool privacyModeEnabled;
  final bool smartRemindersEnabled;
  final String locale;
  final String currencySymbol;
  final bool isOnboardingCompleted;
  final bool autoBackupEnabled;
  final String backupFrequency;
  final String? backupDirectoryPath;
  final DateTime? lastBackupDateTime;
  final List<String> disabledExpenseCategories;
  final List<String> disabledIncomeCategories;
  final List<String> disabledAccountIds;

  /// User-defined display name shown in the drawer / profile screen.
  final String displayName;

  /// SHA-256 hash of the 4-digit PIN; empty string means PIN is not set.
  final String pinHash;

  /// Whether biometric lock is enabled (requires OS support).
  final bool biometricLockEnabled;

  /// The app version string at the time the What's New dialog was last shown.
  final String whatsNewShownVersion;

  /// JSON-serialised list of savings goals. Each goal:
  /// `{id, name, targetAmount, currentAmount}`.
  final String savingsGoalsJson;

  /// JSON-encoded list of user-defined quick-add amounts (e.g. [25, 75, 200]).
  final String customQuickAmountsJson;

  /// JSON-encoded list of locale-default amounts hidden by the user.
  final String hiddenDefaultAmountsJson;

  /// JSON-serialised list of user-defined expense categories.
  final String customExpenseCategoriesJson;

  /// JSON-serialised list of user-defined income categories.
  final String customIncomeCategoriesJson;

  /// JSON-serialised list of built-in expense category icon/colour overrides.
  final String builtInExpenseCategoryOverridesJson;

  /// JSON-serialised list of built-in income category icon/colour overrides.
  final String builtInIncomeCategoryOverridesJson;

  // ── SMS Parsing ─────────────────────────────────────────────────────────

  /// Whether SMS transaction parsing is active.
  final bool smsParsingEnabled;

  /// ID of the account to use when auto-confirming a parsed SMS transaction.
  /// Empty string means "use app default".
  final String smsDefaultAccountId;

  /// Category name to use when auto-confirming a parsed SMS transaction.
  /// Empty string means "use app default".
  final String smsDefaultCategory;

  /// AI (Gemini) API key entered by the user. Empty string means not set.
  final String aiApiKey;

  /// Whether the user has enabled AI-powered features (requires [aiApiKey]).
  final bool aiEnabled;

  /// The Gemini model ID selected by the user.
  final String aiModelId;

  /// Whether AI-enhanced search is enabled.
  final bool aiSmartSearchEnabled;

  /// Whether AI-enhanced voice entry is enabled.
  final bool aiVoiceEnabled;

  /// Whether AI product/receipt scanning is enabled.
  final bool aiScannerEnabled;

  /// Whether AI-assisted SMS parsing is enabled.
  final bool aiSmsAiEnabled;

  bool get isPinEnabled => pinHash.isNotEmpty;

  AppPreferencesModel copyWith({
    String? themeModeKey,
    bool? privacyModeEnabled,
    bool? smartRemindersEnabled,
    String? locale,
    String? currencySymbol,
    bool? isOnboardingCompleted,
    bool? autoBackupEnabled,
    String? backupFrequency,
    String? backupDirectoryPath,
    DateTime? lastBackupDateTime,
    List<String>? disabledExpenseCategories,
    List<String>? disabledIncomeCategories,
    List<String>? disabledAccountIds,
    bool clearBackupDirectory = false,
    String? displayName,
    String? pinHash,
    bool? biometricLockEnabled,
    String? whatsNewShownVersion,
    bool clearPin = false,
    String? savingsGoalsJson,
    String? customQuickAmountsJson,
    String? hiddenDefaultAmountsJson,
    String? customExpenseCategoriesJson,
    String? customIncomeCategoriesJson,
    String? builtInExpenseCategoryOverridesJson,
    String? builtInIncomeCategoryOverridesJson,
    bool? smsParsingEnabled,
    String? smsDefaultAccountId,
    String? smsDefaultCategory,
    String? aiApiKey,
    bool? aiEnabled,
    String? aiModelId,
    bool? aiSmartSearchEnabled,
    bool? aiVoiceEnabled,
    bool? aiScannerEnabled,
    bool? aiSmsAiEnabled,
  }) {
    return AppPreferencesModel(
      themeModeKey: themeModeKey ?? this.themeModeKey,
      privacyModeEnabled: privacyModeEnabled ?? this.privacyModeEnabled,
      smartRemindersEnabled:
          smartRemindersEnabled ?? this.smartRemindersEnabled,
      locale: locale ?? this.locale,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      isOnboardingCompleted:
          isOnboardingCompleted ?? this.isOnboardingCompleted,
      autoBackupEnabled: autoBackupEnabled ?? this.autoBackupEnabled,
      backupFrequency: backupFrequency ?? this.backupFrequency,
      backupDirectoryPath: clearBackupDirectory
          ? null
          : (backupDirectoryPath ?? this.backupDirectoryPath),
      lastBackupDateTime: lastBackupDateTime ?? this.lastBackupDateTime,
      disabledExpenseCategories:
          disabledExpenseCategories ?? this.disabledExpenseCategories,
      disabledIncomeCategories:
          disabledIncomeCategories ?? this.disabledIncomeCategories,
      disabledAccountIds: disabledAccountIds ?? this.disabledAccountIds,
      displayName: displayName ?? this.displayName,
      pinHash: clearPin ? '' : (pinHash ?? this.pinHash),
      biometricLockEnabled: biometricLockEnabled ?? this.biometricLockEnabled,
      whatsNewShownVersion: whatsNewShownVersion ?? this.whatsNewShownVersion,
      savingsGoalsJson: savingsGoalsJson ?? this.savingsGoalsJson,
      customQuickAmountsJson:
          customQuickAmountsJson ?? this.customQuickAmountsJson,
      hiddenDefaultAmountsJson:
          hiddenDefaultAmountsJson ?? this.hiddenDefaultAmountsJson,
      customExpenseCategoriesJson:
          customExpenseCategoriesJson ?? this.customExpenseCategoriesJson,
      customIncomeCategoriesJson:
          customIncomeCategoriesJson ?? this.customIncomeCategoriesJson,
      builtInExpenseCategoryOverridesJson:
          builtInExpenseCategoryOverridesJson ??
              this.builtInExpenseCategoryOverridesJson,
      builtInIncomeCategoryOverridesJson: builtInIncomeCategoryOverridesJson ??
          this.builtInIncomeCategoryOverridesJson,
      smsParsingEnabled: smsParsingEnabled ?? this.smsParsingEnabled,
      smsDefaultAccountId: smsDefaultAccountId ?? this.smsDefaultAccountId,
      smsDefaultCategory: smsDefaultCategory ?? this.smsDefaultCategory,
      aiApiKey: aiApiKey ?? this.aiApiKey,
      aiEnabled: aiEnabled ?? this.aiEnabled,
      aiModelId: aiModelId ?? this.aiModelId,
      aiSmartSearchEnabled: aiSmartSearchEnabled ?? this.aiSmartSearchEnabled,
      aiVoiceEnabled: aiVoiceEnabled ?? this.aiVoiceEnabled,
      aiScannerEnabled: aiScannerEnabled ?? this.aiScannerEnabled,
      aiSmsAiEnabled: aiSmsAiEnabled ?? this.aiSmsAiEnabled,
    );
  }
}

class AppPreferencesModelAdapter extends TypeAdapter<AppPreferencesModel> {
  static const int typeIdValue = 3;

  @override
  final int typeId = typeIdValue;

  @override
  AppPreferencesModel read(BinaryReader reader) {
    final themeModeKey = reader.readString();
    final privacyModeEnabled = reader.readBool();
    final smartRemindersEnabled = reader.readBool();

    // Defaults for existing fields
    String locale = AppPreferencesModel.defaults.locale;
    String currencySymbol = AppPreferencesModel.defaults.currencySymbol;
    bool isOnboardingCompleted =
        AppPreferencesModel.defaults.isOnboardingCompleted;
    bool autoBackupEnabled = AppPreferencesModel.defaults.autoBackupEnabled;
    String backupFrequency = AppPreferencesModel.defaults.backupFrequency;
    String? backupDirectoryPath;
    DateTime? lastBackupDateTime;
    List<String> disabledExpenseCategories =
        AppPreferencesModel.defaults.disabledExpenseCategories;
    List<String> disabledIncomeCategories =
        AppPreferencesModel.defaults.disabledIncomeCategories;
    List<String> disabledAccountIds =
        AppPreferencesModel.defaults.disabledAccountIds;
    String displayName = AppPreferencesModel.defaults.displayName;
    String pinHash = AppPreferencesModel.defaults.pinHash;
    bool biometricLockEnabled =
        AppPreferencesModel.defaults.biometricLockEnabled;
    String whatsNewShownVersion =
        AppPreferencesModel.defaults.whatsNewShownVersion;
    String savingsGoalsJson = AppPreferencesModel.defaults.savingsGoalsJson;
    String customQuickAmountsJson =
        AppPreferencesModel.defaults.customQuickAmountsJson;
    String hiddenDefaultAmountsJson =
        AppPreferencesModel.defaults.hiddenDefaultAmountsJson;
    String customExpenseCategoriesJson =
        AppPreferencesModel.defaults.customExpenseCategoriesJson;
    String customIncomeCategoriesJson =
        AppPreferencesModel.defaults.customIncomeCategoriesJson;
    String builtInExpenseCategoryOverridesJson =
        AppPreferencesModel.defaults.builtInExpenseCategoryOverridesJson;
    String builtInIncomeCategoryOverridesJson =
        AppPreferencesModel.defaults.builtInIncomeCategoryOverridesJson;
    bool smsParsingEnabled = AppPreferencesModel.defaults.smsParsingEnabled;
    String smsDefaultAccountId =
        AppPreferencesModel.defaults.smsDefaultAccountId;
    String smsDefaultCategory = AppPreferencesModel.defaults.smsDefaultCategory;
    String aiApiKey = AppPreferencesModel.defaults.aiApiKey;
    bool aiEnabled = AppPreferencesModel.defaults.aiEnabled;
    String aiModelId = AppPreferencesModel.defaults.aiModelId;
    bool aiSmartSearchEnabled =
        AppPreferencesModel.defaults.aiSmartSearchEnabled;
    bool aiVoiceEnabled = AppPreferencesModel.defaults.aiVoiceEnabled;
    bool aiScannerEnabled = AppPreferencesModel.defaults.aiScannerEnabled;
    bool aiSmsAiEnabled = AppPreferencesModel.defaults.aiSmsAiEnabled;

    try {
      if (reader.availableBytes > 0) locale = reader.readString();
      if (reader.availableBytes > 0) currencySymbol = reader.readString();
      if (reader.availableBytes > 0) isOnboardingCompleted = reader.readBool();
      if (reader.availableBytes > 0) autoBackupEnabled = reader.readBool();
      if (reader.availableBytes > 0) backupFrequency = reader.readString();
      if (reader.availableBytes > 0) {
        final path = reader.readString();
        backupDirectoryPath = path.isEmpty ? null : path;
      }
      if (reader.availableBytes > 0) {
        final millis = reader.readInt();
        lastBackupDateTime =
            millis == 0 ? null : DateTime.fromMillisecondsSinceEpoch(millis);
      }
      if (reader.availableBytes > 0) {
        disabledExpenseCategories = _readStringList(reader);
      }
      if (reader.availableBytes > 0) {
        disabledIncomeCategories = _readStringList(reader);
      }
      if (reader.availableBytes > 0) {
        disabledAccountIds = _readStringList(reader);
      }
      if (reader.availableBytes > 0) displayName = reader.readString();
      if (reader.availableBytes > 0) pinHash = reader.readString();
      if (reader.availableBytes > 0) biometricLockEnabled = reader.readBool();
      if (reader.availableBytes > 0) whatsNewShownVersion = reader.readString();
      if (reader.availableBytes > 0) savingsGoalsJson = reader.readString();
      if (reader.availableBytes > 0) {
        customQuickAmountsJson = reader.readString();
      }
      if (reader.availableBytes > 0) {
        hiddenDefaultAmountsJson = reader.readString();
      }
      if (reader.availableBytes > 0) {
        customExpenseCategoriesJson = reader.readString();
      }
      if (reader.availableBytes > 0) {
        customIncomeCategoriesJson = reader.readString();
      }
      if (reader.availableBytes > 0) {
        builtInExpenseCategoryOverridesJson = reader.readString();
      }
      if (reader.availableBytes > 0) {
        builtInIncomeCategoryOverridesJson = reader.readString();
      }
      if (reader.availableBytes > 0) smsParsingEnabled = reader.readBool();
      if (reader.availableBytes > 0) smsDefaultAccountId = reader.readString();
      if (reader.availableBytes > 0) smsDefaultCategory = reader.readString();
      if (reader.availableBytes > 0) aiApiKey = reader.readString();
      if (reader.availableBytes > 0) aiEnabled = reader.readBool();
      if (reader.availableBytes > 0) aiModelId = reader.readString();
      if (reader.availableBytes > 0) aiSmartSearchEnabled = reader.readBool();
      if (reader.availableBytes > 0) aiVoiceEnabled = reader.readBool();
      if (reader.availableBytes > 0) aiScannerEnabled = reader.readBool();
      if (reader.availableBytes > 0) aiSmsAiEnabled = reader.readBool();
    } catch (_) {
      // Fallback if reading fails
    }

    return AppPreferencesModel(
      themeModeKey: themeModeKey,
      privacyModeEnabled: privacyModeEnabled,
      smartRemindersEnabled: smartRemindersEnabled,
      locale: locale,
      currencySymbol: currencySymbol,
      isOnboardingCompleted: isOnboardingCompleted,
      autoBackupEnabled: autoBackupEnabled,
      backupFrequency: backupFrequency,
      backupDirectoryPath: backupDirectoryPath,
      lastBackupDateTime: lastBackupDateTime,
      disabledExpenseCategories: disabledExpenseCategories,
      disabledIncomeCategories: disabledIncomeCategories,
      disabledAccountIds: disabledAccountIds,
      displayName: displayName,
      pinHash: pinHash,
      biometricLockEnabled: biometricLockEnabled,
      whatsNewShownVersion: whatsNewShownVersion,
      savingsGoalsJson: savingsGoalsJson,
      customQuickAmountsJson: customQuickAmountsJson,
      hiddenDefaultAmountsJson: hiddenDefaultAmountsJson,
      customExpenseCategoriesJson: customExpenseCategoriesJson,
      customIncomeCategoriesJson: customIncomeCategoriesJson,
      builtInExpenseCategoryOverridesJson: builtInExpenseCategoryOverridesJson,
      builtInIncomeCategoryOverridesJson: builtInIncomeCategoryOverridesJson,
      smsParsingEnabled: smsParsingEnabled,
      smsDefaultAccountId: smsDefaultAccountId,
      smsDefaultCategory: smsDefaultCategory,
      aiApiKey: aiApiKey,
      aiEnabled: aiEnabled,
      aiModelId: aiModelId,
      aiSmartSearchEnabled: aiSmartSearchEnabled,
      aiVoiceEnabled: aiVoiceEnabled,
      aiScannerEnabled: aiScannerEnabled,
      aiSmsAiEnabled: aiSmsAiEnabled,
    );
  }

  @override
  void write(BinaryWriter writer, AppPreferencesModel obj) {
    writer
      ..writeString(obj.themeModeKey)
      ..writeBool(obj.privacyModeEnabled)
      ..writeBool(obj.smartRemindersEnabled)
      ..writeString(obj.locale)
      ..writeString(obj.currencySymbol)
      ..writeBool(obj.isOnboardingCompleted)
      ..writeBool(obj.autoBackupEnabled)
      ..writeString(obj.backupFrequency)
      ..writeString(obj.backupDirectoryPath ?? '')
      ..writeInt(obj.lastBackupDateTime?.millisecondsSinceEpoch ?? 0);

    _writeStringList(writer, obj.disabledExpenseCategories);
    _writeStringList(writer, obj.disabledIncomeCategories);
    _writeStringList(writer, obj.disabledAccountIds);

    writer
      ..writeString(obj.displayName)
      ..writeString(obj.pinHash)
      ..writeBool(obj.biometricLockEnabled)
      ..writeString(obj.whatsNewShownVersion)
      ..writeString(obj.savingsGoalsJson)
      ..writeString(obj.customQuickAmountsJson)
      ..writeString(obj.hiddenDefaultAmountsJson)
      ..writeString(obj.customExpenseCategoriesJson)
      ..writeString(obj.customIncomeCategoriesJson)
      ..writeString(obj.builtInExpenseCategoryOverridesJson)
      ..writeString(obj.builtInIncomeCategoryOverridesJson)
      ..writeBool(obj.smsParsingEnabled)
      ..writeString(obj.smsDefaultAccountId)
      ..writeString(obj.smsDefaultCategory)
      ..writeString(obj.aiApiKey)
      ..writeBool(obj.aiEnabled)
      ..writeString(obj.aiModelId)
      ..writeBool(obj.aiSmartSearchEnabled)
      ..writeBool(obj.aiVoiceEnabled)
      ..writeBool(obj.aiScannerEnabled)
      ..writeBool(obj.aiSmsAiEnabled);
  }

  List<String> _readStringList(BinaryReader reader) {
    final length = reader.readInt();
    return List<String>.generate(length, (_) => reader.readString());
  }

  void _writeStringList(BinaryWriter writer, List<String> values) {
    writer.writeInt(values.length);
    for (final value in values) {
      writer.writeString(value);
    }
  }
}
