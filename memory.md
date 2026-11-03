# Expensio – Project Memory

> **Purpose:** Living reference for AI agents and developers. Update this file at every structural change. Last updated: 2026-06-02.
>
> **Agent Rule:** Every AI agent (Claude, Copilot, Jules, Gemini, etc.) **must** read this file at the start of each session and **must** append a row to §8 Change Log for every file they modify. This is the single source of truth for the project state.
>
> **Brand note (2026-04-19):** Project was rebranded from **Expensioa** to **Expensio**. Package ID changed from `app.Expensioa.finance` to `app.expensio`. All occurrences of "Expensioa" in source, strings, and config are now "Expensio".

---

## 1. Repository Layout (as of 2026-06-02)

```
Expensio/                                    ← rebranded from Expensioa (2026-04-19)
├── android/                          # Android platform project
│   └── app/src/main/
│       ├── kotlin/app/expensio/      # package ID: app.expensio
│       └── res/                      # Launcher icons, splash assets (generated)
├── assets/
│   ├── icon/                         # Launcher/splash build-time icons (app_icon.png, app_icon_fg.png, splash_mark.png)
│   ├── images/                       # In-app runtime images (expensio_logo.png, expensio_logo_dark.png, expensio_logo_light.png)
│   └── data/                         # Static data files (voice_keywords.json)
├── benchmark/                        # Standalone Dart performance benchmarks
├── docs/
│   └── ai/                           # Agent guides: AGENTS.md, CLAUDE.md, JULES.md, frontend_analysis.md
├── public_assets/                    # README screenshots (Google-Pixel5-localhost.png)
├── TASKS.md                          # Future goals & backlog (created 2026-04-20)
├── PLAN_2.md                         # Student & Everyday Money Management Engine plan (created 2026-11-01)
├── lib/
│   ├── core/
│   │   ├── ai/                             # AI model layer (2026-06-02)
│   │   │   ├── ai_model.dart               # Abstract AiModel interface
│   │   │   ├── gemini_ai_model.dart        # Gemini cloud implementation
│   │   │   ├── rule_based_ai_model.dart    # On-device fallback
│   │   │   ├── ai_model_providers.dart     # Factory provider
│   │   │   └── ai_result.dart              # Result types + AiModelException
│   │   ├── constants/
│   │   │   ├── app_assets.dart             # AppAssets – all asset path constants
│   │   │   ├── app_constants.dart          # AppConstants – app-wide string constants
│   │   │   └── index.dart
│   │   ├── services/
│   │   │   ├── ai_product_service.dart     # AI-assisted product price lookup
│   │   │   ├── biometric_service.dart      # Local biometric auth helper
│   │   │   ├── notification_service.dart   # FlutterLocalNotificationsPlugin wrapper
│   │   │   ├── update_service.dart         # In-app update check
│   │   │   └── widget_sync_service.dart    # Android home-widget data sync
│   │   ├── theme/
│   │   │   ├── app_colors.dart             # Brand + semantic colours
│   │   │   ├── app_tokens.dart             # Spacing, radii, text-styles
│   │   │   ├── app_theme.dart              # AppTheme.light() / AppTheme.dark()
│   │   │   └── index.dart
│   │   └── utils/
│   │       ├── background_backup.dart      # Workmanager callback dispatcher
│   │       ├── context_extensions.dart     # BuildContext helpers
│   │       ├── hive_bootstrap.dart         # Hive init + adapter registration
│   │       ├── tag_parser.dart             # Hashtag / mention parser
│   │       └── index.dart
│   ├── features/
│   │   ├── accounts/accounts.dart          # Re-export barrel
│   │   ├── analytics/analytics.dart        # Re-export barrel
│   │   ├── categories/categories.dart      # Re-export barrel
│   │   ├── gamification/                   # Gamification (2026-06-02)
│   │   │   ├── data/models/achievement_model.dart
│   │   │   └── presentation/provider/gamification_providers.dart
│   │   ├── recurring/recurring.dart        # Re-export barrel
│   │   ├── settings/settings.dart          # Re-export barrel
│   │   ├── transactions/transactions.dart  # Re-export barrel
│   │   ├── sms_parser/                     # SMS-parsing feature (2026-04-19)
│   │   │   ├── data/
│   │   │   │   ├── sms_queue_item.dart     # Parsed SMS awaiting user confirmation
│   │   │   │   └── sms_transaction.dart    # Extracted transaction data from SMS
│   │   │   ├── domain/
│   │   │   │   ├── sms_broadcast_service.dart    # BroadcastReceiver bridge
│   │   │   │   ├── sms_monitoring_service.dart   # Foreground monitoring service
│   │   │   │   └── sms_parser_engine.dart        # Regex-based SMS → transaction parser
│   │   │   ├── presentation/
│   │   │   │   ├── provider/sms_providers.dart   # Riverpod providers for SMS queue
│   │   │   │   └── screens/sms_settings_sheet.dart
│   │   │   └── sms_parser.dart                   # Feature barrel
│   │   └── Expense/                        # Core feature (data layer lives here)
│   │       ├── data/
│   │       │   ├── datasource/             # Raw Hive box read/write
│   │       │   ├── models/
│   │       │   │   ├── Expense_model.dart
│   │       │   │   ├── account_model.dart
│   │       │   │   ├── budget_model.dart
│   │       │   │   ├── custom_category_model.dart
│   │       │   │   ├── recurring_subscription_model.dart
│   │       │   │   ├── settlement_model.dart          # Split settlements
│   │       │   │   ├── app_preferences_model.dart
│   │       │   │   └── index.dart
│   │       │   └── repositories/
│   │       ├── domain/repositories/
│   │       └── presentation/
│   │           ├── provider/
│   │           │   ├── Expense_providers.dart
│   │           │   ├── account_providers.dart
│   │           │   ├── budget_providers.dart
│   │           │   ├── month_budget_providers.dart
│   │           │   ├── week_budget_providers.dart
│   │           │   ├── preferences_providers.dart
│   │           │   ├── recurring_subscription_providers.dart
│   │           │   ├── backup_providers.dart
│   │           │   ├── notifications_provider.dart
│   │           │   ├── settlement_providers.dart
│   │           │   └── index.dart
│   │           ├── screens/
│   │           │   ├── app_shell.dart
│   │           │   ├── home_screen.dart + home/
│   │           │   ├── stats_screen.dart + stats/
│   │           │   ├── categories_screen.dart + categories/
│   │           │   ├── accounts_screen.dart + accounts/
│   │           │   │   └── tools_tab_widgets.dart   # NEW
│   │           │   ├── add_Expense_screen.dart + add_Expense/
│   │           │   │   └── amount_expression.dart   # NEW – calculator expression parser
│   │           │   ├── records_history_screen.dart + records_history/
│   │           │   │   └── records_search_logic.dart  # NEW
│   │           │   ├── settings_screen.dart + settings/
│   │           │   ├── transaction_search_screen.dart
│   │           │   ├── onboarding_screen.dart
│   │           │   ├── scanner_screen.dart
│   │           │   ├── upi_scanner_screen.dart      # NEW
│   │           │   ├── unified_scanner_screen.dart  # NEW – routes to UPI / receipt / product scan
│   │           │   ├── receipt_scanner_screen.dart  # NEW
│   │           │   ├── product_scanner_screen.dart  # NEW
│   │           │   ├── scan_mode_sheet.dart         # NEW – bottom sheet to pick scan mode
│   │           │   ├── voice_entry_screen.dart      # NEW
│   │           │   ├── pin_entry_screen.dart        # NEW
│   │           │   ├── notifications_screen.dart    # NEW
│   │           │   ├── about_screen.dart            # NEW
│   │           │   ├── support_screen.dart          # NEW
│   │           │   ├── profile_screen.dart
│   │           │   └── index.dart
│   │           └── widgets/
│   │               ├── transaction_card.dart
│   │               ├── Expense_category.dart
│   │               ├── account_editor_sheet.dart
│   │   └── Expense/                        # Core feature
│   ├── routes/
│   │   ├── app_routes.dart             # Centralised navigation helpers
│   │   └── index.dart
│   ├── shared/widgets/
│   │   ├── floating_nav_bar.dart       # FloatingNavBar + NavBarItem
│   │   ├── placeholder_screen.dart     # Generic "coming soon" stub
│   │   ├── app_pill_switch.dart        # AppPillSwitch
│   │   ├── app_button.dart             # AppButton – full-width elevated button
│   │   ├── app_filter_sheet.dart       # NEW – reusable filter bottom sheet
│   │   ├── app_page_header.dart        # NEW – standard screen header
│   │   ├── app_tab_switcher.dart       # NEW – shared tab switch widget
│   │   ├── app_toggle_switch.dart      # NEW – shared toggle
│   │   └── index.dart
│   └── main.dart
├── pubspec.yaml                        # name: Expensio, version: 2.1.0+21
├── analysis_options.yaml
└── test/
    └── features/Expense/               # Unit tests mirroring lib structure
```

---

## 2. File Classification

### Modular Features (`lib/features/`)

Features are self-contained modules. Files are categorized under the respective feature directories:

#### Accounts (`lib/features/accounts/`)
| File | Role |
|------|------|
| `data/models/account_model.dart` | `AccountModel` |
| `data/datasource/account_local_datasource.dart` | `accounts` Hive box datasource |
| `data/repositories/hive_account_repository.dart` | implementation of account repository |
| `domain/repositories/account_repository.dart` | repository interface |
| `presentation/provider/account_providers.dart` | `accountListProvider`, `accountControllerProvider` |
| `presentation/screens/accounts_screen.dart` | accounts listing screen |
| `presentation/screens/accounts/accounts_widgets.dart` | sub-widgets (tools tab view, card layout) |
| `presentation/screens/accounts/tools_tab_widgets.dart` | tools view (split bill tool, etc.) |
| `presentation/widgets/account_editor_sheet.dart` | bottom-sheet for create/edit account |
| `presentation/widgets/account_icons.dart` | icon lookup mapping for accounts |
| `presentation/widgets/split_bill_tool_view.dart` | bill-split calculator sub-view |

#### Categories & Budgets (`lib/features/categories/`)
| File | Role |
|------|------|
| `data/models/custom_category_model.dart` | `CustomCategoryModel` - user-defined categories |
| `data/models/budget_model.dart` | `BudgetModel` |
| `data/datasource/budget_local_datasource.dart` | `budgets` Hive box datasource |
| `data/datasource/month_budget_local_datasource.dart` | month-budget Hive box datasource |
| `data/repositories/hive_budget_repository.dart` | implementation of budget repository |
| `domain/repositories/budget_repository.dart` | repository interface |
| `presentation/provider/budget_providers.dart` | `budgetTargetsProvider`, `budgetControllerProvider` |
| `presentation/provider/budget_state.dart` | selected month and budget calculation notifier |
| `presentation/screens/categories_screen.dart` | categories budget tracking screen |
| `presentation/screens/categories/categories_widgets.dart` | sub-widgets (category cards, grid layout) |
| `presentation/screens/categories/budget_popup.dart` | set monthly budget bottom-sheet |
| `presentation/widgets/category_editor_sheet.dart` | bottom-sheet for create/edit custom categories |
| `presentation/widgets/budget_editor_sheet.dart` | bottom-sheet for set/edit category budget |
| `presentation/widgets/Expense_category.dart` | core category list and icon mapping |

#### Settings & Preferences (`lib/features/settings/`)
| File | Role |
|------|------|
| `data/models/app_preferences_model.dart` | `AppPreferencesModel` |
| `data/datasource/preferences_local_datasource.dart` | `preferences` Hive box datasource |
| `data/datasource/backup_local_datasource.dart` | JSON export/import backup helper |
| `data/repositories/hive_preferences_repository.dart` | implementation of preferences repository |
| `domain/repositories/preferences_repository.dart` | repository interface |
| `presentation/provider/preferences_providers.dart` | preferences and settings state providers |
| `presentation/provider/backup_providers.dart` | backup controller and sync state |
| `presentation/screens/settings_screen.dart` | app settings panel |
| `presentation/screens/settings/settings_widgets.dart` | section headers, tiles, settings UI cards |
| `presentation/screens/about_screen.dart` | app version, credits, and links screen |
| `presentation/screens/support_screen.dart` | FAQ, feedback, and support links screen |
| `presentation/screens/profile_screen.dart` | user profile overview screen |
| `presentation/screens/onboarding_screen.dart` | first-run setup flow |
| `presentation/screens/pin_entry_screen.dart` | security PIN entry screen |

#### Recurring Subscriptions (`lib/features/recurring/`)
| File | Role |
|------|------|
| `data/models/recurring_subscription_model.dart` | `RecurringSubscriptionModel` |
| `data/datasource/recurring_subscription_local_datasource.dart` | `recurring_subscriptions` Hive box datasource |
| `data/repositories/hive_recurring_subscription_repository.dart` | implementation of subscriptions repository |
| `domain/repositories/recurring_subscription_repository.dart` | repository interface |
| `presentation/provider/recurring_subscription_providers.dart` | list and controller providers for subscriptions |
| `presentation/widgets/subscription_editor_sheet.dart` | bottom-sheet for create/edit subscriptions |
| `presentation/widgets/subscription_icons.dart` | icon lookup mapping for subscriptions |
| `presentation/widgets/recurring_tool_view.dart` | recurring subscriptions manager view |

#### Analytics (`lib/features/analytics/`)
| File | Role |
|------|------|
| `presentation/screens/stats_screen.dart` | monthly analytics and spending trends screen |
| `presentation/screens/stats/stats_widgets.dart` | charts, metric tiles, and category breakdown widgets |

#### Expense Core (`lib/features/Expense/`)
| File | Role |
|------|------|
| `data/models/Expense_model.dart` | `ExpenseModel`, `TransactionType`, `ExpenseStats` |
| `data/datasource/Expense_local_datasource.dart` | `Expenses` Hive box datasource |
| `data/repositories/hive_Expense_repository.dart` | implementation of Expense repository |
| `domain/repositories/Expense_repository.dart` | repository interface |
| `presentation/provider/Expense_providers.dart` | `ExpenseListProvider`, `ExpenseControllerProvider`, `statsProvider`, `filteredExpensesProvider` |
| `presentation/provider/notifications_provider.dart` | `notificationsProvider` (in-app derived alert state) |
| `presentation/screens/app_shell.dart` | root scaffold with IndexedStack + custom bottom nav |
| `presentation/screens/home_screen.dart` | dashboard: quick balance cards, date strip, recent list |
| `presentation/screens/records_history_screen.dart` | full history screen with filters, search, and export |
| `presentation/screens/unified_scanner_screen.dart` | camera scanner for barcode/QR code and AI photos |
| `presentation/screens/upi_scanner_screen.dart` | QR scanner that parses UPI deep links for quick pay |
| `presentation/screens/receipt_scanner_screen.dart` | OCR barcode/receipt scanning view |
| `presentation/screens/product_scanner_screen.dart` | AI product identifier camera view |
| `presentation/screens/voice_entry_screen.dart` | speech-to-Expense voice capture screen |
| `presentation/screens/notifications_screen.dart` | list of alerts, budget warnings, and due notices |
| `presentation/widgets/transaction_card.dart` | single transaction row with swipe-to-delete |
| `presentation/widgets/amount_visibility.dart` | privacy-mode aware amount visibility |
| `presentation/widgets/ui_feedback.dart` | dialogs and confirmation sheets |
| `presentation/widgets/app_drawer.dart` | app drawer menu |
| `presentation/widgets/quick_action_bar.dart` | horizontal quick actions row on home |
| `presentation/widgets/power_pill_menu.dart` | expandable pill FAB actions |

### SMS Parser Feature (`lib/features/sms_parser/`)
| File | Purpose |
|------|---------|
| `data/sms_queue_item.dart` | Parsed SMS pending user confirmation |
| `data/sms_transaction.dart` | Structured transaction extracted from SMS |
| `domain/sms_broadcast_service.dart` | Android BroadcastReceiver bridge |
| `domain/sms_monitoring_service.dart` | Foreground SMS monitoring service |
| `domain/sms_parser_engine.dart` | Regex-based engine: bank SMS → `SmsTransaction` |
| `presentation/provider/sms_providers.dart` | Riverpod providers for SMS queue |
| `presentation/screens/sms_settings_sheet.dart` | Settings bottom sheet for SMS parsing |
| `sms_parser.dart` | Feature barrel |

### Core Services (`lib/core/services/`)
| File | Purpose |
|------|---------|
| `ai_product_service.dart` | AI-assisted product price lookup from barcode |
| `biometric_service.dart` | Local biometric (fingerprint / face) authentication |
| `update_service.dart` | Check for and prompt in-app updates |
| `widget_sync_service.dart` | Sync today's spend to Android home-screen widget |

### Core / Utils
| File | Purpose |
|------|---------|
| `lib/core/constants/app_assets.dart` | `AppAssets` – all asset paths |
| `lib/core/constants/app_constants.dart` | `AppConstants` – app-wide string constants |
| `lib/core/theme/app_colors.dart` | `AppColors` – all colour constants |
| `lib/core/theme/app_tokens.dart` | `AppSpacing`, `AppRadii`, `AppTextStyles` |
| `lib/core/utils/hive_bootstrap.dart` | `HiveBootstrap.initialize()` – registers all Hive adapters |
| `lib/core/utils/background_backup.dart` | `callbackDispatcher` for Workmanager |
| `lib/core/utils/context_extensions.dart` | `BuildContext` extension helpers |
| `lib/core/utils/tag_parser.dart` | Hashtag / mention parser for transaction notes |

### Routes
| File | Purpose |
|------|---------|
| `lib/routes/app_routes.dart` | `AppRoutes` – static navigation helpers for every pushed screen |

### Shared Widgets (`lib/shared/widgets/`)
| File | Role |
|------|------|
| `floating_nav_bar.dart` | `FloatingNavBar` – pill-shaped bottom nav; `NavBarItem` – single animated tab |
| `placeholder_screen.dart` | Generic "coming soon" stub |
| `app_pill_switch.dart` | `AppPillSwitch` – two-option pill toggle |
| `app_button.dart` | `AppButton` – full-width elevated button with loading state |
| `app_filter_sheet.dart` | Reusable filter bottom sheet |
| `app_page_header.dart` | Standard screen header component |
| `app_tab_switcher.dart` | Shared animated tab-switcher |
| `app_toggle_switch.dart` | Shared toggle switch |

---

## 3. Navigation Map

```
AppShell (IndexedStack)
├── [0] HomeScreen
│        ├── push → TransactionSearchScreen
│        ├── push → AddExpenseScreen (new)
│        ├── push → AddExpenseScreen (edit)
│        └── push → RecordsHistoryScreen
│
├── [1] StatsScreen
│
├── [2] CategoriesScreen
│        └── push → AddExpenseScreen (new with category)
│
└── [3] AccountsScreen
         └── sheet → AccountEditorSheet

AppShell (Drawer)
└── push → SettingsScreen

AddExpenseScreen
└── child push → ScannerScreen
                └── pushReplacement → AddExpenseScreen (with parsed amount/note)
```

All `push` / `pushReplacement` calls are centralised through **`AppRoutes`** in `lib/routes/app_routes.dart`.

---

## 4. Key Dependencies

| Package | Use |
|---------|-----|
| `flutter_riverpod` | State management (providers + notifiers) |
| `hive` / `hive_flutter` | Local persistence |
| `fl_chart` | Charts in StatsScreen |
| `intl` | Date + currency formatting |
| `uuid` | ID generation |
| `mobile_scanner` | QR/barcode scanning |
| `workmanager` | Background backup scheduler |
| `file_picker` | Import backup file |
| `permission_handler` | Storage permission for backup |
| `share_plus` | Share backup file |
| `archive` | JSON compression for backups |
| `path_provider` | App documents path |

---

## 5. Identified Issues (at scan date)

| # | Issue | Severity | Location |
|---|-------|----------|----------|
| 1 | All domain features (accounts, settings, stats, categories) live under one `Expense` feature folder | ~~Medium~~ Partially resolved: feature-namespace re-export barrels created in `lib/features/accounts/`, `analytics/`, `settings/`, `categories/`. Physical data-layer migration is future work. | `/lib/features/` |
| 2 | Large screen files with mixed UI + presentation logic | ~~Medium~~ Resolved: all screens ≤373 lines; private widget classes extracted into per-screen `screens/<name>/` subdirs. | — |
| 3 | Navigation scattered inline across screens (pre-routes refactor) | Resolved | `app_routes.dart` created |
| 4 | No barrel (`index.dart`) exports → long relative import chains | Resolved | All directories now have barrels |
| 5 | `app_shell.dart` contains `_CustomFloatingNavBar` private class — could be extracted | Resolved | `FloatingNavBar` → `shared/widgets/floating_nav_bar.dart` |
| 6 | `placeholder_screen.dart` unused in main navigation | ~~Low~~ Resolved: moved to `lib/shared/widgets/placeholder_screen.dart` + exported from `shared/widgets/index.dart` | `presentation/screens/` |
| 7 | No `/assets/images` or `/assets/fonts` subdirectory organisation | Resolved | `/assets/images/Expensioa_logo.png` created |

---

## 6. Refactor Plan Summary

### Done ✅
- Feature-first architecture under `/lib/features/Expense/`
- Clean data / domain / presentation separation
- Riverpod for all state management
- Hive for local persistence with adapter registration in `HiveBootstrap`
- Centralised colours, spacing, radii in `core/theme/`
- Centralised navigation via `lib/routes/app_routes.dart`
- Barrel `index.dart` exports added to **all** directories:
  - `screens/`, `widgets/`, `provider/`, `models/`
  - `datasource/`, `data/repositories/`, `domain/repositories/`
  - `theme/`, `utils/`, `constants/`
  - `routes/`, `shared/widgets/`
- `FloatingNavBar` + `NavBarItem` extracted from `app_shell.dart` → `lib/shared/widgets/floating_nav_bar.dart`
- `lib/shared/widgets/` directory created for cross-feature UI components
- All large screens split into sub-widget directories (see §8 change log)
- `SliverAccountsTabView` extracted: `accounts_screen.dart` 563→57 L
- Feature-namespace barrels created: `accounts/`, `analytics/`, `settings/`, `categories/`, `recurring/`, `transactions/`
- Assets organised: `assets/images/` for runtime images, `assets/icon/` for build icons

- `PlaceholderScreen` promoted to `lib/shared/widgets/placeholder_screen.dart` (cross-feature empty-state UI)
- `AppPillSwitch` created in `lib/shared/widgets/app_pill_switch.dart`; replaces duplicate `AccountsPillSwitch` / `CategoriesPillSwitch` (now `typedef` aliases)
- `AppTheme.light()` / `AppTheme.dark()` centralised in `lib/core/theme/app_theme.dart`; `main.dart` uses `AppTheme` instead of inline `ThemeData`

### Recommended Next Steps (future sessions)
1. **Physical feature migration** – move providers and data layer files into the new feature namespaces (`lib/features/accounts/`, etc.) once `flutter analyze` is available to validate import changes
2. **`AppButton` widget** – abstract the repeated full-width `ElevatedButton` pattern (onboarding, editor sheets) into a shared `lib/shared/widgets/app_button.dart`

---

## 7. Before / After Structure

### Before (pre-refactor)
```
/lib
  main.dart
  /core
    /constants
    /theme
    /utils
  /features
    /Expense
      /data
        /datasource
        /models
        /repositories
      /domain
        /repositories
      /presentation
        /provider
        /screens   ← all 13 screens + app_shell + _FloatingNavBar mixed (263 lines)
        /widgets   ← all 14 widgets mixed
```

### After (post-refactor)
```
/lib
  main.dart
  /core
    /constants
      index.dart
    /theme
      app_colors.dart
      app_tokens.dart
      index.dart
    /utils
      index.dart
  /features
    /Expense
      /data
        /datasource
          index.dart
        /models
          index.dart
        /repositories
          index.dart
      /domain
        /repositories
          index.dart
      /presentation
        /provider
          index.dart
        /screens
          index.dart    ← app_shell now 127 lines (clean shell only)
        /widgets
          index.dart
  /routes
    app_routes.dart
    index.dart
  /shared
    /widgets
      floating_nav_bar.dart   ← FloatingNavBar + NavBarItem (extracted)
      index.dart
```

---

## 8. Change Log

| Date | Change | Files Affected |
|------|--------|----------------|
| 2026-04-04 | Created `memory.md` | `memory.md` |
| 2026-04-04 | Created `lib/routes/app_routes.dart` – centralised navigation helpers | `app_routes.dart`, `app_shell.dart`, `home_screen.dart`, `records_history_screen.dart`, `transaction_search_screen.dart`, `categories_screen.dart`, `app_drawer.dart`, `scanner_screen.dart` |
| 2026-04-04 | Added barrel `index.dart` exports (screens, widgets, provider, models, theme, utils, constants) | 7 files |
| 2026-04-04 | Extracted `FloatingNavBar` + `NavBarItem` from `app_shell.dart` → `lib/shared/widgets/floating_nav_bar.dart`; `app_shell.dart` reduced from 263 to 127 lines | `app_shell.dart`, `floating_nav_bar.dart` |
| 2026-04-04 | Added barrel `index.dart` exports for remaining directories (datasource, data/repositories, domain/repositories, routes, shared/widgets) | 5 files |
| 2026-04-04 | Organized assets: moved `Expensioa_logo.png` from `assets/icon/` → `assets/images/`; updated `AppAssets.logo` + `pubspec.yaml` flutter assets block | `assets/images/Expensioa_logo.png`, `app_assets.dart`, `pubspec.yaml` |
| 2026-04-04 | Fixed `home_screen.dart` merge artifacts: duplicate `accountsMap`/`accountMap` variable, duplicate `accountLabel:` param, unreachable `return` | `home_screen.dart` |
| 2026-04-04 | Split `home_screen.dart` 810→337 L: extracted `HomeHeader`, `HomeMetricColumn`, `formatSignedCurrencyForHome`, `HomeDateStrip`, `HomeDateNavButton`, `HomeDayPill`, `HomeEmptyCard`, `HomeAmountChip` | `screens/home/home_header.dart`, `screens/home/home_date_strip.dart`, `screens/home/home_misc_widgets.dart` |
| 2026-04-04 | Split `records_history_screen.dart` 786→276 L + fixed severe merge artifacts (two parallel build/filter implementations): extracted `RecordsSummaryCard`, `RecordsStateCard`, `RecordsFilterChips`, `RecordsAccountDropdown`, `RecordsExpenseList`, `RecordsFilter` enum | `screens/records_history/records_cards.dart`, `records_filter_bar.dart`, `records_Expense_list.dart`, `records_filter.dart` |
| 2026-04-04 | Split `add_Expense_screen.dart` 797→598 L: extracted `AddExpenseTopButton`, `AddExpenseModeTab`, `AddExpenseInfoCapsule`, `AddExpenseSelectionCapsule`, `AddExpenseKeypadButton`, `TransactionTypeX` extension | `screens/add_Expense/add_Expense_widgets.dart` |
| 2026-04-04 | Split `stats_screen.dart` 427→267 L: extracted `StatsMetricTile`, `StatsBreakdownCard` | `screens/stats/stats_widgets.dart` |
| 2026-04-04 | Split `settings_screen.dart` 446→373 L: extracted `SettingsSectionHeader`, `SettingsCard`, `SettingsTileIcon` | `screens/settings/settings_widgets.dart` |
| 2026-04-04 | Split `accounts_screen.dart` 563→286 L: extracted `AccountsToolsTabView`, `AccountsPillSwitch`, `AccountsSummaryChip`, `AccountCard`, `EmptyAccountsCard` | `screens/accounts/accounts_widgets.dart` |
| 2026-04-04 | Split `categories_screen.dart` 490→257 L: extracted `CategoriesPillSwitch`, `CategoryGridCard`, `AddCategoryCard`, `CategoryGridData` | `screens/categories/categories_widgets.dart` |
| 2026-04-04 | Extracted `SliverAccountsTabView` as ConsumerWidget → `screens/accounts/accounts_widgets.dart`; stripped 14 redundant imports from `accounts_screen.dart`; `accounts_screen.dart` reduced to 57 lines | `accounts_screen.dart`, `accounts/accounts_widgets.dart` |
| 2026-04-04 | Updated `screens/index.dart` barrel to also export all per-screen sub-widget files | `screens/index.dart` |
| 2026-04-04 | Created feature-namespace re-export barrels: `lib/features/accounts/accounts.dart`, `analytics/analytics.dart`, `settings/settings.dart`, `categories/categories.dart` | 4 new files |
| 2026-04-04 | Created `lib/features/recurring/recurring.dart` re-export barrel (widgets, providers, model) | 1 new file |
| 2026-04-04 | Created `lib/features/transactions/transactions.dart` re-export barrel (add-Expense + records-history + search screens + providers + model) | 1 new file |
| 2026-04-06 | Created `lib/shared/widgets/app_pill_switch.dart` – unified `AppPillSwitch` widget replacing duplicate `AccountsPillSwitch` and `CategoriesPillSwitch`; both now resolved as `typedef` aliases | `app_pill_switch.dart`, `accounts_widgets.dart`, `categories_widgets.dart`, `shared/widgets/index.dart` |
| 2026-04-06 | Created `lib/core/theme/app_theme.dart` – centralised `AppTheme.light()` / `AppTheme.dark()` factory replacing inline `ThemeData` in `main.dart`; `core/theme/index.dart` updated | `app_theme.dart`, `main.dart`, `core/theme/index.dart` |
| 2026-04-16 | Increased `home_screen.dart` scroll-list bottom padding from default to `160` (EdgeInsets.only(bottom: 160)) so the last record is never hidden behind the floating FAB or the floating nav bar | `home_screen.dart` line ~96 |
| 2026-04-19 | **Full rebrand Expensioa → Expensio**: renamed app name, package ID (`app.Expensioa.finance` → `app.Expensio.finance`), asset file (`Expensioa_logo.png` → `Expensio_logo.png`), Kotlin package tree, all user-facing strings, channel names, backup file prefixes, and root app class | `pubspec.yaml`, `AndroidManifest.xml`, `build.gradle.kts`, all `.kt` files, `app_constants.dart`, `app_assets.dart`, `main.dart`, `backup_local_datasource.dart`, `settings_screen.dart`, all strings throughout `lib/` |
| 2026-04-19 | Added `lib/features/sms_parser/` full feature: parser engine, broadcast service, monitoring service, queue model, Riverpod providers, settings sheet | 8 new files |
| 2026-04-19 | Added `lib/core/services/`: `ai_product_service.dart`, `biometric_service.dart`, `update_service.dart`, `widget_sync_service.dart` | 4 new files |
| 2026-04-19 | Added new screens: `upi_scanner_screen.dart`, `unified_scanner_screen.dart`, `receipt_scanner_screen.dart`, `product_scanner_screen.dart`, `scan_mode_sheet.dart`, `voice_entry_screen.dart`, `pin_entry_screen.dart`, `notifications_screen.dart`, `about_screen.dart`, `support_screen.dart` | 10 new files |
| 2026-04-19 | Added new shared widgets: `app_button.dart`, `app_filter_sheet.dart`, `app_page_header.dart`, `app_tab_switcher.dart`, `app_toggle_switch.dart` | 5 new files |
| 2026-04-19 | Added `lib/core/utils/tag_parser.dart`, `lib/core/constants/app_constants.dart`, `custom_category_model.dart`, `category_editor_sheet.dart`, `notifications_provider.dart`, `tools_tab_widgets.dart`, `amount_expression.dart`, `records_search_logic.dart` | 8 new files |
| 2026-04-20 | Created `TASKS.md` – full future-goals backlog organised into 7 sections (Brand, Architecture, Features, UI/UX, Testing, Performance, DevOps) | `TASKS.md` |
| 2026-04-20 | Updated `memory.md` – reflected rebrand, all new files (sms_parser, services, screens, widgets), updated §1 layout, §2 classification, §8 change log | `memory.md` |
| 2026-05-27 | Decoupled modular features (`accounts`, `settings`, `categories`, `recurring`, `analytics`) out of `Expense/`, reorganized test suite to match, fixed Cyrillic 'T' in SMS parser engine, updated AGENTS/GEMINI docs, and verified codebase (69/69 tests passing) | Over 40 files modified/moved, `memory.md` |
| 2026-05-27 | Redesigned HomeTopBar and HomeHeader to replicate the floating white card hero layout from the user's design reference image (2).png, integrated quick amount chips inside the card, added navigation tap gestures, and resolved all 14 static analysis/formatting warnings across the codebase | lib/features/Expense/presentation/screens/home/home_header.dart, lib/features/Expense/presentation/screens/home_screen.dart, lib/features/categories/presentation/provider/budget_state.dart, lib/features/categories/presentation/screens/categories_screen.dart, lib/features/Expense/presentation/widgets/power_pill_menu.dart, lib/features/sms_parser/domain/sms_parser_engine.dart, memory.md |
| 2026-05-28 | Redesigned manual transaction input screen UI layout and interaction rules to support mockup, adding unified card, left-aligned amount field with smaller size, Date/Time + Location row, and trigger symbol prefixes on choice chips | lib/features/Expense/presentation/screens/add_Expense_screen.dart, memory.md |
| 2026-05-28 | Refactored manual entry screen visual layout: removed brackets from chips, added premium accent tinted/solid colored styling, changed chips to fully rounded capsule shape (`BorderRadius.circular(20)`), relocated calculator preview to top-left of the input block, scaled down calculator toggle, grouped attachments/mic under a compact chip-like background pill placed on the same row as the Date/Time picker, enabled text keyboard with unified inline command parsing inside a cursor-friendly empty amount field (with blinking caret colored by transaction type), and set up a periodic tips hint rotator on the notes box. | lib/features/Expense/presentation/screens/add_Expense_screen.dart, memory.md |
| 2026-05-28 | Refined manual entry screen visual layout: configured explicit blinking caret sizing and properties, kept amount field focused during calculator toggling to preserve active cursor state, styled Date/Time picker and type tabs to match the fully rounded capsule shape (`BorderRadius.circular(20)`), and made the attachment/mic pill more compact with smaller 14px icons and padded capsule background. | lib/features/Expense/presentation/screens/add_Expense_screen.dart, lib/features/Expense/presentation/screens/add_Expense/add_Expense_widgets.dart, memory.md |
| 2026-05-28 | Integrated voice entry sheet directly into entry screen mic button (passing returnResult flags and populating amount, type, category, note, date), enabled unified scanner OCR import via scanner callback, configured native FilePicker file attachments, and implemented inline SMS notification copy-pasting to auto-fill transaction fields directly inside the amount field onChanged listener. | lib/features/Expense/presentation/screens/add_Expense_screen.dart, lib/features/Expense/presentation/screens/unified_scanner_screen.dart, lib/features/Expense/presentation/screens/voice_entry_screen.dart, lib/routes/app_routes.dart, memory.md |
| 2026-05-28 | Redesigned Savings Goals layout in tools tab with a premium single card layout, custom progress bars featuring trophy badges, and a stateful picker dialog for selecting emojis, colors, and target dates. | lib/features/accounts/presentation/screens/accounts/tools_tab_widgets.dart, memory.md |
| 2026-05-28 | Restructured Tools navigation tabs from 5 to 3 (removing Budget, merging Recurring & Future), implemented combined RecurringAndFutureToolView, and refactored SplitBillToolView with contacts permission flow, custom list search, and Equal/Exact calculators. | lib/features/accounts/presentation/screens/accounts_screen.dart, lib/features/accounts/presentation/screens/accounts/tools_tab_widgets.dart, lib/features/accounts/presentation/widgets/split_bill_tool_view.dart, memory.md |
| 2026-05-28 | Fixed savings goals list item overflow with a column layout. Added Category subcategories Hive model serialization, separated subcategories from note hashtags by introducing a distinct subcategory field on ExpenseModel with custom Hive serialization, implemented subcategory choice chips in AddExpenseScreen, and transitioned CategoryListCard in Category screen to a spacious Wrap layout. | `tools_tab_widgets.dart`, `app_preferences_model.dart`, `preferences_providers.dart`, `categories_widgets.dart`, `categories_screen.dart`, `add_Expense_screen.dart`, `Expense_model.dart`, `Expense_providers.dart`, `app_routes.dart`, `home_screen.dart`, `records_history_screen.dart`, `memory.md` |
| 2026-05-28 | Refined category subcategory chips to render in a single horizontal scrollable row using StadiumBorder, placed "+ Add" button at the first position, added shrinkWrap constraint and 40px layout height to prevent vertical clipping, configured Add Expense subcategory chips to use StadiumBorder, and excluded subcategories and "+ Add" button from the Accounts board tab. | `categories_screen.dart`, `categories_widgets.dart`, `add_Expense_screen.dart`, `memory.md` |
| 2026-05-28 | Made the bottom navigation bar horizontally scrollable (via SingleChildScrollView and BouncingScrollPhysics) and added a fifth "Tags" tab placeholder mapped to a PlaceholderScreen in AppShell. Cleaned up unused variables and imports in add_Expense_screen.dart, tools_tab_widgets.dart, and split_bill_tool_view.dart to ensure a warning-free static analysis build. | `floating_nav_bar.dart`, `app_shell.dart`, `add_Expense_screen.dart`, `tools_tab_widgets.dart`, `split_bill_tool_view.dart`, `memory.md` |
| 2026-05-28 | Fixed FAB layout bugs (raised Tags screen FAB above bottom nav; wrapped AppShell PowerFab in AnimatedOpacity + IgnorePointer visibility guard) and implemented premium Tags & Shorthand UI/UX improvements (real-time autocomplete row in AddExpense, dynamic colored list cards, live mockup simulator in Editor sheet, haptic expansion feedback). | `tags_screen.dart`, `add_Expense_screen.dart`, `app_shell.dart`, `memory.md` |
| 2026-05-29 | Fixed add_Expense_screen.dart brace mismatch syntax error, restored normal preview chips list selection on manual transaction entry screen, and integrated inline "Search & Select" action chips to open bottom sheet selectors for Accounts, Categories, Tags, and Splits. | `add_Expense_screen.dart`, `memory.md` |
| 2026-05-29 | Created CalendarViewScreen with interactive monthly calendar grid and chronological timeline views, mapped named route pushCalendarView in AppRoutes, and integrated month tap navigation inside HomeDateStrip. | `calendar_view_screen.dart`, `home_date_strip.dart`, `home_screen.dart`, `app_routes.dart`, `index.dart`, `memory.md` |
| 2026-05-29 | Fixed timeline view layout crash inside IntrinsicHeight, implemented Week, 2-Week, and Month views in Calendar screen with view popup pill toggles, styled day cells, spending capsules and category icon badges to match mockups, and redesigned Home screen date strip to be styled as a calendar week view (linking to Calendar screen on tap). | `calendar_view_screen.dart`, `app_routes.dart`, `home_date_strip.dart`, `home_screen.dart`, `memory.md` |
| 2026-05-29 | Hidden controls in Timeline tab, repositioned Today button to right side of calendar navigation, scaled calendar and timeline font sizes, changed Transactions metric card to fit space, and replicated summary metrics row in Timeline tab. | `calendar_view_screen.dart`, `home_date_strip.dart`, `memory.md` |
| 2026-05-29 | Removed Transactions metric card from Calendar and Timeline views. Redesigned Subscriptions view inside Tools tab to match mockup with horizontal slate upcoming cards, brand-colored brand icons vertical list, and renewal summary bar. Refactored Future Transactions view to use matching premium list tiles. | `calendar_view_screen.dart`, `recurring_tool_view.dart`, `tools_tab_widgets.dart`, `memory.md` |
| 2026-05-29 | Integrated AppColors theme colors into Subscriptions accent cards and headers. Added stateful ConsumerStatefulWidget expansion logic to collapse/expand long subscription lists inside the Tools tab. | `recurring_tool_view.dart`, `memory.md` |
| 2026-05-29 | Implemented Subscription Auto-Logging ("Log Payment" action, next bill date calculation, dynamic periodic rates label) and billingPeriod ChoiceChips selector in editor. Added swipe gestures to CalendarViewScreen grid container. Linked Savings Goals to dynamic bank account balances, displaying a linked tag and disabling manual adding on linked goals. Replaced Subscription icons list with emoji presets and custom emoji options. Fixed compiler type check and missing variable declarations. Added Compiler Error Prevention (Anti-Error Guidelines) sections in guidelines files. | `recurring_subscription_model.dart`, `recurring_subscription_providers.dart`, `subscription_editor_sheet.dart`, `recurring_tool_view.dart`, `subscription_icons.dart`, `calendar_view_screen.dart`, `tools_tab_widgets.dart`, `GEMINI.md`, `AGENTS.md`, `memory.md` |
| 2026-05-30 | Implemented Geolocation transaction logging and visual Sonar Radar Mapping Board tool screen. Added `geolocator` package, requested Android GPS hardware permissions, expanded custom Hive serialization for `ExpenseModel` coordinate variables with backward compatibility checks, updated controller methods, added `_toggleLocation()` and chip UI feedback to manual entry, and linked dashboard route card to Accounts tools menu. | `pubspec.yaml`, `AndroidManifest.xml`, `Expense_model.dart`, `Expense_providers.dart`, `app_routes.dart`, `tools_tab_widgets.dart`, `calendar_view_screen.dart`, `home_screen.dart`, `records_history_screen.dart`, `add_Expense_screen.dart`, `location_map_screen.dart`, `accounts_screen.dart`, `memory.md` |
| 2026-05-30 | Implemented unified System Permissions settings screen with real-time state check observer, native Kotlin MethodChannel mock notification simulator trigger, and expanded display currency details (AUD, CAD, CHF, CNY, HKD, NZD, SEK, KRW, BTC). | `MainActivity.kt`, `currency_selector_sheet.dart`, `permissions_settings_screen.dart`, `settings_screen.dart`, `notification_settings_screen.dart`, `memory.md` |
| 2026-05-30 | Redesigned the Finance Tools dashboard (`accounts_screen.dart`) to replicate the 4-column rounded squircle card mockup with a lavender-purple top gradient background, real-time search filtering, and 16 dashboard utilities (expanding access to hidden/sub-pages like Alerts, AI Setup, Security, and Support). Resolved RenderFlex cell overflows by normalizing tool labels to concise single-word identifiers (Add, Map, Split, Scan, Pay, Voice), reducing vertical spacing to 6, and lowering `childAspectRatio` to 0.68. | `accounts_screen.dart`, `memory.md` |
| 2026-05-30 | Propagated global lavender-gradient header style (`GradientAppBar`) with a shadow elevated circular Android back button across all sub-screens (AboutScreen, SupportScreen, AccountsBoardScreen, UpiScannerScreen), made `Week` the default view type in `CalendarViewScreen`, and updated all search inputs in the application to inherit the tools page's premium search bar style. Cleared all static analysis warnings by removing unused imports. | `app_page_header.dart`, `calendar_view_screen.dart`, `about_screen.dart`, `support_screen.dart`, `accounts_board_screen.dart`, `upi_scanner_screen.dart`, `location_map_screen.dart`, `split_bill_tool_view.dart`, `categories_screen.dart`, `records_history_screen.dart`, `currency_selector_sheet.dart`, `app_shell.dart`, `data_settings_screen.dart`, `settings_screen.dart`, `memory.md` |
| 2026-05-30 | Created reusable, unified, and stateful `AppSearchBar` widget in `lib/shared/widgets/app_search_bar.dart` and integrated it across all screens (Tools dashboard, location map, split bill, categories, records history, currency selector sheet, and all selection bottom sheets in `add_Expense_screen.dart`), updated the back button icon in `app_page_header.dart` to use `Icons.chevron_left_rounded` to show chevron left style (`<`), and redesigned the charts/insights screen (`stats_screen.dart`) to use the new premium `GradientAppBar` header style with integrated tab switcher. | `app_search_bar.dart`, `app_page_header.dart`, `stats_screen.dart`, `accounts_screen.dart`, `location_map_screen.dart`, `split_bill_tool_view.dart`, `categories_screen.dart`, `records_history_screen.dart`, `currency_selector_sheet.dart`, `add_Expense_screen.dart`, `memory.md` |
| 2026-05-30 | Refactored stats screen range filters into a 5-tab app bar selector (Week, 2 Weeks, Month, Year, All Time) and chart selectors into a swipable body switcher (Flow, Spend, Habit). Upgraded flow trend line chart to a side-by-side double bar chart matching mockup design. | `stats_screen.dart`, `stats_widgets.dart`, `memory.md` |
| 2026-05-30 | Redesigned Stats screen into a single-page interactive dashboard: replaced top tab bar with outlined range capsule dropdown button, added IOS-style segment controls for charts in-place toggling (Flow, Spend, Habit), and integrated persistent summary metrics grid, smart insights grid, and detailed audit records scroll list. | `stats_screen.dart`, `stats_widgets.dart`, `memory.md` |
| 2026-05-30 | Overhauled Stats screen dashboard to align with mockup features and visual aesthetics in Stats.png (adding stacked card components for Overview metrics, Salary progress bar, daily Line Chart spending trends, Breakdown donut analysis, Category budget limits utilization, and Top transaction lists). | `stats_screen.dart`, `stats_widgets.dart`, `memory.md` |
| 2026-05-31 | Implemented manual Split Management screen (no contact permissions, swipe-to-delete, multi-select, and validation) and integrated a real-time split calculator in Expense Entry screen (supporting Equal, Exact, Shares, and Percentages modes). Resized "Finance Tools" header and left-aligned all sub-screen app headers. | `app_page_header.dart`, `accounts_screen.dart`, `split_bill_screen.dart`, `split_bill_tool_view.dart`, `add_Expense_screen.dart`, `hive_bootstrap.dart`, `participant_model.dart`, `participant_local_datasource.dart`, `participant_providers.dart`, `accounts.dart`, `memory.md` |
| 2026-05-31 | Resolved Gradle/Kotlin incompatibilities causing NoClassDefFoundError for AbstractKotlinAndroidPluginWrapper by downgrading Kotlin Gradle plugin to 1.9.24, and reverted Gradle wrapper to 8.13-all.zip to match the current AGP (8.11.1) and plugin configurations. | `android/gradle/wrapper/gradle-wrapper.properties`, `android/build.gradle.kts`, `android/settings.gradle.kts`, `memory.md` |
| 2026-05-31 | Cleaned current Flutter deprecations in tags/settings/tools screens, bumped the Gradle wrapper to 8.14, restored Kotlin plugin 2.2.20 in `settings.gradle.kts`, removed the root `buildscript` classpath and eager `evaluationDependsOn(":app")` from `android/build.gradle.kts`, and repaired multiple corrupted Gradle 8.14 transform-cache entries while validating the Android build. The remaining build blocker is network access to cached Flutter engine debug jars from Gradle. | `android/build.gradle.kts`, `android/gradle/wrapper/gradle-wrapper.properties`, `android/settings.gradle.kts`, `lib/features/accounts/presentation/screens/accounts/tools_tab_widgets.dart`, `lib/features/settings/presentation/screens/settings/ai_settings_screen.dart`, `lib/features/settings/presentation/screens/settings/settings_widgets.dart`, `lib/features/tags/presentation/screens/tags_screen.dart`, `memory.md` |
| 2026-06-02 | Cleaned stale files: removed `docs/plans/` (all 11 implemented plans), `docs/ai/NEW_SESSION_PLAN.md` (handoff done), `.planning/plans/2026-04-03-ui-integration.md` (git plan done), `scratch_inspect.py` / `scratch_delete_scanners.py` (trash scripts), `.antigravitycli/` (stale config), `.Jules/` (personal notes), `generate_assets.py` / `generate_assets.ps1` (redundant scripts), unused design refs in `public_assets/` (split 1.png, split 2.png, image (2).png, 4 font zips), unused `assets/images/brand_logo_expensio.png`. Kept `public_assets/Google-Pixel5-localhost.png` (used in README), `docs/ai/frontend_analysis.md` (website ref), `.planning/ui-reviews/PHASE-UI-REVIEW.md` (quality ref). Updated `docs/ai/AGENTS.md` with current scope, data models, navigation, commands. Fixed AndroidManifest URI scheme (`Expensio://` → `expensio://`). | `docs/ai/AGENTS.md`, `AndroidManifest.xml`, `memory.md`, and 17 deleted files |
| 2026-10-26 | Implemented universal UI design principles across app: UniversalTopBar, UniversalScreenScaffold, and FilterSortSplitCapsule. Standardized top bar title at top-left, white rounded square container with '<' back button, right-aligned toggleable search bar with fade transition carrying a split capsule for Filter and Sort options on surface. Dynamic search visibility based on item count (>10 items). Adopted purplish & pink theme identity (accentPurple #8B5CF6, accentPink #EC4899, backgroundGradient lavender-to-white) across Finance Tools, Categories, Settings, Records History, and Tags screens. Fixed widget launcher exception and Gradle transformation cache locking. Generated and verified release APK and deployed to connected device. | `lib/core/theme/app_colors.dart`, `lib/shared/widgets/universal_top_bar.dart`, `lib/shared/widgets/app_page_header.dart`, `lib/features/accounts/presentation/screens/accounts_screen.dart`, `lib/features/categories/presentation/screens/categories_screen.dart`, `lib/features/settings/presentation/screens/settings_screen.dart`, `lib/features/expense/presentation/screens/records_history_screen.dart`, `lib/features/tags/presentation/screens/tags_screen.dart`, `memory.md` |
| 2026-10-26 | UI/UX Refinement & Consistency Overhaul: (1) Fixed FAB position on Home screen adding a clear 24dp gap above the floating nav bar; (2) Created reusable circular white `AppBackButton` with '<' icon (`BoxShape.circle`) in `lib/shared/widgets/app_back_button.dart` and integrated across UniversalTopBar, GradientAppBar, UnifiedScannerScreen, and Settings; (3) Refactored `AppSearchBar` to embed filter & sort icon capsules directly on the right inside the search bar, with dynamic sort icons reflecting active order; (4) Reconciled period selector in `StatsScreen` (`stats_widgets.dart`) into a standardized floating bottom sheet with title, right '✕' close button, and colored icon badges; (5) Removed redundant Month/Year/Lifetime tabs and date pill from StatsScreen; (6) Redesigned `CurrencySelectorSheet` into a floating modal bottom sheet with top title, toggleable search icon, and right '✕' close button; (7) Cleaned Location Mapping screen replacing static search bar with top-bar search toggle button embedding Radar/List view toggle inside search bar; (8) Merged UPI QR scanning into `UnifiedScannerScreen` with 3-tab segmented switcher (Bill Scan, AI Scan, UPI Pay) and blurred/translucent header; (9) Fixed Settings screen back button when accessed via Finance Tools (`showBackButton` support). Successfully compiled release APK and installed on device `app.expensio` (PID active). | `app_shell.dart`, `app_back_button.dart`, `universal_top_bar.dart`, `app_search_bar.dart`, `app_page_header.dart`, `records_history_screen.dart`, `stats_screen.dart`, `stats_widgets.dart`, `currency_selector_sheet.dart`, `location_map_screen.dart`, `unified_scanner_screen.dart`, `app_routes.dart`, `settings_screen.dart`, `index.dart`, `memory.md` |
| 2026-10-26 | Scanner, Categories & SMS Overhaul: (1) Embedded Filter & Sort icon capsule inside AppSearchBar on Categories screen with dedicated modal sheets (A-Z/Amount and All/Budgeted/Over-budget); (2) UnifiedScannerScreen top bar made completely transparent (removed dark backdrop filter); (3) Reordered and renamed scanner bottom tabs to exact order: Bill (Tab 0), UPI (Tab 1), AI Scan (Tab 2) with concise labels fitting cleanly; (4) Removed blue shadow/filter from UPI scan target box leaving crisp cyan border; (5) Implemented 100% in-app camera capture for AI scan via RepaintBoundary on live camera with tactile flash effect, eliminating external camera launches; (6) Added Android SMS inbox querying (Telephony.Sms.Inbox content resolver in MainActivity.kt) and SmsInboxService; (7) Auto-scanned SMS inbox upon permission grant + added manual "Scan SMS Inbox Now" button in settings sheet; (8) Connected detected SMS transactions directly into in-app notificationsProvider and notifications_screen.dart with "Review & Log" action chip. Verified 0 analyze errors, compiled release APK (76.3MB), installed and launched on device. | `categories_screen.dart`, `unified_scanner_screen.dart`, `app_routes.dart`, `MainActivity.kt`, `sms_inbox_service.dart`, `sms_parser.dart`, `sms_providers.dart`, `sms_settings_sheet.dart`, `notifications_provider.dart`, `notifications_screen.dart`, `memory.md` |
| 2026-11-01 | Rebrand to Expensio (fin.expensio.com) & Dual Light/Dark Swoosh Logo Overhaul: (1) Processed high-resolution swoosh brand logos into transparent multi-density assets: `expensio_logo_dark.png` (black swoosh) and `expensio_logo_light.png` (white swoosh) alongside launcher icons and splash mark; (2) Added `AppAssets.logoDark` and `AppAssets.logoLight` constants with strict contrast enforcement: light surfaces use dark silhouette, dark surfaces/splash use white silhouette; (3) Updated AppConstants domain to `fin.expensio.com`, website URL to `https://fin.expensio.com`, and support email to `support@expensio.com`; (4) Cleared all legacy "XPens" text traces across 15+ core screens and services (home header, drawer, about screen with clickable domain chip, profile, backup providers, pin entry, onboarding); (5) Regenerated Android adaptive launcher icons and native splash screens; (6) Built release APK (77.7MB) and installed/verified execution on wireless ADB device `100.114.171.167:5555` (PID 14512 active); (7) Prepared deep strategic gap & constraints analysis for scaling Expensio into a tier-1 finance platform. | `app_assets.dart`, `app_constants.dart`, `home_header.dart`, `about_screen.dart`, `support_screen.dart`, `onboarding_screen.dart`, `biometric_service.dart`, `pin_entry_screen.dart`, `app_drawer.dart`, `profile_screen.dart`, `records_history_screen.dart`, `backup_providers.dart`, `background_backup.dart`, `update_service.dart`, `permissions_settings_screen.dart`, `notification_settings_screen.dart`, `sms_settings_sheet.dart`, `memory.md` |
| 2026-11-02 | Timeline, Scanner Modes & Subscriptions Overhaul: (1) CalendarViewScreen Timeline simplified: removed redundant outer container card with blue border, chevron, and duplicate amounts; transactions render directly on the timeline beside date markers using standard TransactionCard; (2) UnifiedScannerScreen rebuilt with single continuous MobileScannerController: eliminated camera black-screens/freezes, fixed tab ordering (Tab 0: Bill, Tab 1: UPI, Tab 2: AI Scan), dynamic titles matching active mode, smart floating navbar switcher where unselected tabs show only icons and selected tab expands smoothly, removed blue tint filter over UPI viewfinder, in-app frame capture for AI vision; (3) Recurring Subscriptions & Bills: purged hardcoded dummy seed records (Netflix 499, Spotify 119, YouTube 129) from Hive, empty defaultSubscriptions, added attractive actionable empty state with '+ Add Subscription / Bill' CTA, integrated with FutureTransactionsToolView. Verified with flutter analyze (0 errors). | calendar_view_screen.dart, unified_scanner_screen.dart, recurring_subscription_providers.dart, recurring_tool_view.dart, memory.md |\n| 2026-11-02 | Component-Based Architecture & Universal Transaction Card Overhaul: (1) Held Plan 2 implementation per user directive to establish design consistency first; (2) Overhauled TransactionCard into the single universal card across app with strict color & sign rules (Red & '-' for expenses, Green & '+' for income, Blue & no sign for transfers), 1-glance collapsed view (category bubble, title/name, meta, metadata badges for note, tags, split, location), and smooth AnimatedSize expanded detail panel (notes quote box, tags wrap, split method, location pin chip with tap-to-map, full timestamps, Edit/Delete/Share actions with haptic feedback); (3) Replaced ad-hoc transaction lists in CalendarViewScreen (Day list & Timeline list), ToolsTabWidgets (Future/recent transactions), and LocationMapScreen (selected radar card & list view) with TransactionCard; (4) Created reusable components in lib/shared/widgets/ including AppCloseButton (circular 'âœ•'), AppBottomSheetContainer & showAppBottomSheet modal wrapper, and universal_transaction_card.dart export. Verified with flutter analyze (0 errors). | 	ransaction_card.dart, universal_transaction_card.dart, pp_close_button.dart, pp_bottom_sheet.dart, calendar_view_screen.dart, 	ools_tab_widgets.dart, location_map_screen.dart, pp_routes.dart, index.dart, memory.md |
| 2026-11-01 | Authored Expensio Plan 2 (`PLAN_2.md`): Formulated architecture for Student & Everyday Money Management Engine. Details: (1) On-device habit learning engine tracking recurring tuples (≥4 logs) to automatically generate 1-tap contextual home screen quick-chips with instant undo; (2) Cloud AI Copilot (Gemini BYOK) with tool/function calling for voice/text action automation (create expenses, split bills, add reminders); (3) Social bill splitting with 1-tap WhatsApp summary and direct UPI deep-link settle (`upi://pay`); (4) "Safe to Spend" runway calculations and trial expiry sentinel; (5) Image compression and receipt viewer optimizations. Saved to `PLAN_2.md` and `docs/plans/PLAN_2_STUDENT_MONEY_MANAGEMENT.md`. | `PLAN_2.md`, `docs/plans/PLAN_2_STUDENT_MONEY_MANAGEMENT.md`, `memory.md` |
 
 ---

| 2026-11-02 | Navigation Bar Containment & Customization, Quick Add Multi-Gesture, Real-time Voice Intent Parser, and Receipt Image Sharing: (1) Overhauled FloatingNavBar with clipBehavior: Clip.antiAlias, borderRadius: 32, and responsive layout spacing (spaceEvenly for <=5 tabs, smooth bounded scrolling for >5 tabs) completely eliminating edge clipping; (2) Added interactive Navigation Customization bottom sheet (CustomizeNavBarSheet) in Settings allowing drag-and-drop reordering, tab removal (min 3), and adding any Finance Tool (Subscriptions, Split Bill, Budget, Goals, Radar, Accounts) dynamically; (3) Added showBackButton suppression to all tool screens when mounted in AppShell navbar tabs while keeping back button enabled when launched from routes; (4) Added multi-gesture support to Quick Add FAB (Tap -> Add transaction, Double Tap -> configurable default Voice, Long Press -> configurable default Scanner) with bottom-sheet selection menus in General Settings; (5) Upgraded generic offline voice command parser with real-time dynamic account, category, and subcategory detection (e.g. 'suresh expense 250, food dinner cash' -> Category: Food & Dining, Subcategory: dinner, Account: Cash, Note: Suresh; 'expense 2500 gift paytm' -> Category: Shopping, Subcategory: gift, Account: Paytm), with smart note fallback; (6) Transformed expanded Transaction Card Share button to render a high-res (3x) receipt image via RepaintBoundary with subtle watermark footer and trigger native Android share sheet (SharePlus.shareXFiles). Verified with flutter analyze (0 compile errors), built release APK (78.2MB), installed and verified live on wireless device 100.72.147.162:5555 (PID 23572 active). | floating_nav_bar.dart, app_shell.dart, power_pill_menu.dart, customize_navbar_sheet.dart, general_settings_screen.dart, app_preferences_model.dart, preferences_providers.dart, voice_entry_screen.dart, transaction_card.dart, location_map_screen.dart, gamification_screen.dart, subscriptions_screen.dart, split_bill_screen.dart, savings_goals_screen.dart, app_routes.dart, memory.md |
| 2026-11-02 | Camera Permissions, Scanner Tab Animation, 54 Common Service Presets & Recurring Segment Filters: (1) Added missing android.permission.CAMERA and camera hardware features to AndroidManifest.xml, resolving camera black-screen failure; (2) Added runtime _checkCameraPermission() and in-viewfinder interactive errorBuilder fallback in UnifiedScannerScreen; (3) Refactored floating scanner navbar with AnimatedCrossFade: collapsed icon-only for inactive tabs and smooth expansion for active tab with aligned hints; (4) Added 54 service presets divided into 2 horizontal scrollable rows in SubscriptionEditorSheet with 1-tap autofill and shorthand recurrence pills; (5) Overhauled RecurringToolView with 4-segment filter chips (All, Subscriptions, Recurring Bills, Future Due) and added direct 1-tap Log Payment in card options and upcoming cards; (6) Built release APK (77.8MB), installed, and launched on wireless device 100.123.72.159:5555. | AndroidManifest.xml, unified_scanner_screen.dart, subscription_editor_sheet.dart, recurring_tool_view.dart, voice_entry_screen.dart, common_services_catalog.dart, memory.md |

## 9. AI Agent Instructions

All AI agents working on this repository **must** follow these rules:

1. **Read first** – Open and read `memory.md` at the start of every session before touching any code.
2. **Write after** – Append a row to §8 Change Log for every file you create or modify (format: `| YYYY-MM-DD | Description | Files Affected |`).
3. **Check issues** – Consult §5 Identified Issues before opening new ones; mark an issue resolved in §5 and §6 when your change fixes it.
4. **Follow patterns** – Respect the conventions in §2 (screens, widgets, models, providers) and use the shared widgets in `lib/shared/widgets/` before building new ones.
5. **Keep memory.md current** – This file is the authoritative project state; stale entries mislead future agents. Always update it.

---

## 10. Release Notes – v2.1.0 (2026-04-19)

### What Changed
| Area | Change |
|------|--------|
| **Rebrand** | App name: Expensioa → **Expensio**. Package ID: `app.Expensioa.finance` → `app.Expensio.finance` |
| Home screen scroll | Increased bottom padding of the recent-transactions scroll list to `160 dp` so the last record is never occluded by the floating FAB or the floating nav bar |
| **SMS Auto-import** | New `sms_parser` feature: engine, monitoring service, queue model, provider, settings sheet |
| **Scanner modes** | Unified scanner with UPI / receipt / product sub-modes; dedicated screens scaffolded |
| **Voice entry** | `voice_entry_screen.dart` scaffolded for speech-to-Expense |
| **Security** | PIN entry screen + biometric service added |
| **Notifications** | In-app notification screen + provider scaffolded |
| **Home widget** | `widget_sync_service.dart` for Android home-screen widget data sync |
| **Custom categories** | `CustomCategoryModel` + `category_editor_sheet.dart` added |
| **Shared widgets** | `AppButton`, `AppFilterSheet`, `AppPageHeader`, `AppTabSwitcher`, `AppToggleSwitch` added to `lib/shared/widgets/` |
| **Core services** | `AiProductService`, `BiometricService`, `UpdateService`, `WidgetSyncService` added to `lib/core/services/` |
| **New info screens** | `about_screen.dart`, `support_screen.dart` added |

### Migration Notes
- No database schema changes; no data migration required.
- New Kotlin package path: `android/app/src/main/kotlin/app/Expensio/finance/`. Update any manual references.
- New backup file extension: `.Expensio` (was `.Expensioa`).

---
