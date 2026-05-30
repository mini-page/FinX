# XPens – Project Memory

> **Purpose:** Living reference for AI agents and developers. Update this file at every structural change. Last updated: 2026-05-28.
>
> **Agent Rule:** Every AI agent (Claude, Copilot, Jules, Gemini, etc.) **must** read this file at the start of each session and **must** append a row to §8 Change Log for every file they modify. This is the single source of truth for the project state.
>
> **Brand note (2026-04-19):** Project was rebranded from **XPensa** to **XPens**. Package ID changed from `app.xpensa.finance` to `app.xpens.finance`. All occurrences of "XPensa" in source, strings, and config are now "XPens".

---

## 1. Repository Layout (as of 2026-04-20)

```
XPens/                                    ← rebranded from XPensa (2026-04-19)
├── android/                          # Android platform project
│   └── app/src/main/
│       ├── kotlin/app/xpens/finance/ # package ID: app.xpens.finance
│       └── res/                      # Launcher icons, splash assets (generated)
├── assets/
│   ├── icon/                         # Launcher/splash build-time icons (app_icon.png, app_icon_fg.png, splash_mark.png)
│   ├── images/                       # In-app runtime images (xpens_logo.png)
│   └── data/                         # Static data files (voice_keywords.json)
├── benchmark/                        # Standalone Dart performance benchmarks
├── docs/
│   ├── ai/                           # Agent guides: AGENTS.md, CLAUDE.md
│   └── plans/                        # Feature design docs (markdown)
├── TASKS.md                          # Future goals & backlog (created 2026-04-20)
├── lib/
│   ├── core/
│   │   ├── constants/
│   │   │   ├── app_assets.dart             # AppAssets – all asset path constants
│   │   │   ├── app_constants.dart          # AppConstants – app-wide string constants
│   │   │   └── index.dart
│   │   ├── services/                       # NEW (2026-04-19)
│   │   │   ├── ai_product_service.dart     # AI-assisted product price lookup
│   │   │   ├── biometric_service.dart      # Local biometric auth helper
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
│   │       ├── tag_parser.dart             # NEW – hashtag / mention parser
│   │       └── index.dart
│   ├── features/
│   │   ├── accounts/accounts.dart          # Re-export barrel
│   │   ├── analytics/analytics.dart        # Re-export barrel
│   │   ├── categories/categories.dart      # Re-export barrel
│   │   ├── recurring/recurring.dart        # Re-export barrel
│   │   ├── settings/settings.dart          # Re-export barrel
│   │   ├── transactions/transactions.dart  # Re-export barrel
│   │   ├── sms_parser/                     # NEW full SMS-parsing feature (2026-04-19)
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
│   │   └── expense/                        # Core feature (data layer lives here)
│   │       ├── data/
│   │       │   ├── datasource/             # Raw Hive box read/write
│   │       │   ├── models/
│   │       │   │   ├── expense_model.dart
│   │       │   │   ├── account_model.dart
│   │       │   │   ├── budget_model.dart
│   │       │   │   ├── custom_category_model.dart  # NEW
│   │       │   │   ├── recurring_subscription_model.dart
│   │       │   │   ├── app_preferences_model.dart
│   │       │   │   └── index.dart
│   │       │   └── repositories/
│   │       ├── domain/repositories/
│   │       └── presentation/
│   │           ├── provider/
│   │           │   ├── expense_providers.dart
│   │           │   ├── account_providers.dart
│   │           │   ├── budget_providers.dart
│   │           │   ├── preferences_providers.dart
│   │           │   ├── recurring_subscription_providers.dart
│   │           │   ├── backup_providers.dart
│   │           │   ├── notifications_provider.dart  # NEW
│   │           │   └── index.dart
│   │           ├── screens/
│   │           │   ├── app_shell.dart
│   │           │   ├── home_screen.dart + home/
│   │           │   ├── stats_screen.dart + stats/
│   │           │   ├── categories_screen.dart + categories/
│   │           │   ├── accounts_screen.dart + accounts/
│   │           │   │   └── tools_tab_widgets.dart   # NEW
│   │           │   ├── add_expense_screen.dart + add_expense/
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
│   │               ├── expense_category.dart
│   │               ├── account_editor_sheet.dart
│   │   └── expense/                        # Core feature
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
├── pubspec.yaml                        # name: xpens, version: 2.1.0+21
├── analysis_options.yaml
└── test/
    └── features/expense/               # Unit tests mirroring lib structure
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
| `presentation/widgets/expense_category.dart` | core category list and icon mapping |

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

#### Expense Core (`lib/features/expense/`)
| File | Role |
|------|------|
| `data/models/expense_model.dart` | `ExpenseModel`, `TransactionType`, `ExpenseStats` |
| `data/datasource/expense_local_datasource.dart` | `expenses` Hive box datasource |
| `data/repositories/hive_expense_repository.dart` | implementation of expense repository |
| `domain/repositories/expense_repository.dart` | repository interface |
| `presentation/provider/expense_providers.dart` | `expenseListProvider`, `expenseControllerProvider`, `statsProvider`, `filteredExpensesProvider` |
| `presentation/provider/notifications_provider.dart` | `notificationsProvider` (in-app derived alert state) |
| `presentation/screens/app_shell.dart` | root scaffold with IndexedStack + custom bottom nav |
| `presentation/screens/home_screen.dart` | dashboard: quick balance cards, date strip, recent list |
| `presentation/screens/records_history_screen.dart` | full history screen with filters, search, and export |
| `presentation/screens/unified_scanner_screen.dart` | camera scanner for barcode/QR code and AI photos |
| `presentation/screens/upi_scanner_screen.dart` | QR scanner that parses UPI deep links for quick pay |
| `presentation/screens/receipt_scanner_screen.dart` | OCR barcode/receipt scanning view |
| `presentation/screens/product_scanner_screen.dart` | AI product identifier camera view |
| `presentation/screens/voice_entry_screen.dart` | speech-to-expense voice capture screen |
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
| 1 | All domain features (accounts, settings, stats, categories) live under one `expense` feature folder | ~~Medium~~ Partially resolved: feature-namespace re-export barrels created in `lib/features/accounts/`, `analytics/`, `settings/`, `categories/`. Physical data-layer migration is future work. | `/lib/features/` |
| 2 | Large screen files with mixed UI + presentation logic | ~~Medium~~ Resolved: all screens ≤373 lines; private widget classes extracted into per-screen `screens/<name>/` subdirs. | — |
| 3 | Navigation scattered inline across screens (pre-routes refactor) | Resolved | `app_routes.dart` created |
| 4 | No barrel (`index.dart`) exports → long relative import chains | Resolved | All directories now have barrels |
| 5 | `app_shell.dart` contains `_CustomFloatingNavBar` private class — could be extracted | Resolved | `FloatingNavBar` → `shared/widgets/floating_nav_bar.dart` |
| 6 | `placeholder_screen.dart` unused in main navigation | ~~Low~~ Resolved: moved to `lib/shared/widgets/placeholder_screen.dart` + exported from `shared/widgets/index.dart` | `presentation/screens/` |
| 7 | No `/assets/images` or `/assets/fonts` subdirectory organisation | Resolved | `/assets/images/xpensa_logo.png` created |

---

## 6. Refactor Plan Summary

### Done ✅
- Feature-first architecture under `/lib/features/expense/`
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
    /expense
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
    /expense
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
| 2026-04-04 | Organized assets: moved `xpensa_logo.png` from `assets/icon/` → `assets/images/`; updated `AppAssets.logo` + `pubspec.yaml` flutter assets block | `assets/images/xpensa_logo.png`, `app_assets.dart`, `pubspec.yaml` |
| 2026-04-04 | Fixed `home_screen.dart` merge artifacts: duplicate `accountsMap`/`accountMap` variable, duplicate `accountLabel:` param, unreachable `return` | `home_screen.dart` |
| 2026-04-04 | Split `home_screen.dart` 810→337 L: extracted `HomeHeader`, `HomeMetricColumn`, `formatSignedCurrencyForHome`, `HomeDateStrip`, `HomeDateNavButton`, `HomeDayPill`, `HomeEmptyCard`, `HomeAmountChip` | `screens/home/home_header.dart`, `screens/home/home_date_strip.dart`, `screens/home/home_misc_widgets.dart` |
| 2026-04-04 | Split `records_history_screen.dart` 786→276 L + fixed severe merge artifacts (two parallel build/filter implementations): extracted `RecordsSummaryCard`, `RecordsStateCard`, `RecordsFilterChips`, `RecordsAccountDropdown`, `RecordsExpenseList`, `RecordsFilter` enum | `screens/records_history/records_cards.dart`, `records_filter_bar.dart`, `records_expense_list.dart`, `records_filter.dart` |
| 2026-04-04 | Split `add_expense_screen.dart` 797→598 L: extracted `AddExpenseTopButton`, `AddExpenseModeTab`, `AddExpenseInfoCapsule`, `AddExpenseSelectionCapsule`, `AddExpenseKeypadButton`, `TransactionTypeX` extension | `screens/add_expense/add_expense_widgets.dart` |
| 2026-04-04 | Split `stats_screen.dart` 427→267 L: extracted `StatsMetricTile`, `StatsBreakdownCard` | `screens/stats/stats_widgets.dart` |
| 2026-04-04 | Split `settings_screen.dart` 446→373 L: extracted `SettingsSectionHeader`, `SettingsCard`, `SettingsTileIcon` | `screens/settings/settings_widgets.dart` |
| 2026-04-04 | Split `accounts_screen.dart` 563→286 L: extracted `AccountsToolsTabView`, `AccountsPillSwitch`, `AccountsSummaryChip`, `AccountCard`, `EmptyAccountsCard` | `screens/accounts/accounts_widgets.dart` |
| 2026-04-04 | Split `categories_screen.dart` 490→257 L: extracted `CategoriesPillSwitch`, `CategoryGridCard`, `AddCategoryCard`, `CategoryGridData` | `screens/categories/categories_widgets.dart` |
| 2026-04-04 | Extracted `SliverAccountsTabView` as ConsumerWidget → `screens/accounts/accounts_widgets.dart`; stripped 14 redundant imports from `accounts_screen.dart`; `accounts_screen.dart` reduced to 57 lines | `accounts_screen.dart`, `accounts/accounts_widgets.dart` |
| 2026-04-04 | Updated `screens/index.dart` barrel to also export all per-screen sub-widget files | `screens/index.dart` |
| 2026-04-04 | Created feature-namespace re-export barrels: `lib/features/accounts/accounts.dart`, `analytics/analytics.dart`, `settings/settings.dart`, `categories/categories.dart` | 4 new files |
| 2026-04-04 | Created `lib/features/recurring/recurring.dart` re-export barrel (widgets, providers, model) | 1 new file |
| 2026-04-04 | Created `lib/features/transactions/transactions.dart` re-export barrel (add-expense + records-history + search screens + providers + model) | 1 new file |
| 2026-04-06 | Created `lib/shared/widgets/app_pill_switch.dart` – unified `AppPillSwitch` widget replacing duplicate `AccountsPillSwitch` and `CategoriesPillSwitch`; both now resolved as `typedef` aliases | `app_pill_switch.dart`, `accounts_widgets.dart`, `categories_widgets.dart`, `shared/widgets/index.dart` |
| 2026-04-06 | Created `lib/core/theme/app_theme.dart` – centralised `AppTheme.light()` / `AppTheme.dark()` factory replacing inline `ThemeData` in `main.dart`; `core/theme/index.dart` updated | `app_theme.dart`, `main.dart`, `core/theme/index.dart` |
| 2026-04-16 | Increased `home_screen.dart` scroll-list bottom padding from default to `160` (EdgeInsets.only(bottom: 160)) so the last record is never hidden behind the floating FAB or the floating nav bar | `home_screen.dart` line ~96 |
| 2026-04-19 | **Full rebrand XPensa → XPens**: renamed app name, package ID (`app.xpensa.finance` → `app.xpens.finance`), asset file (`xpensa_logo.png` → `xpens_logo.png`), Kotlin package tree, all user-facing strings, channel names, backup file prefixes, and root app class | `pubspec.yaml`, `AndroidManifest.xml`, `build.gradle.kts`, all `.kt` files, `app_constants.dart`, `app_assets.dart`, `main.dart`, `backup_local_datasource.dart`, `settings_screen.dart`, all strings throughout `lib/` |
| 2026-04-19 | Added `lib/features/sms_parser/` full feature: parser engine, broadcast service, monitoring service, queue model, Riverpod providers, settings sheet | 8 new files |
| 2026-04-19 | Added `lib/core/services/`: `ai_product_service.dart`, `biometric_service.dart`, `update_service.dart`, `widget_sync_service.dart` | 4 new files |
| 2026-04-19 | Added new screens: `upi_scanner_screen.dart`, `unified_scanner_screen.dart`, `receipt_scanner_screen.dart`, `product_scanner_screen.dart`, `scan_mode_sheet.dart`, `voice_entry_screen.dart`, `pin_entry_screen.dart`, `notifications_screen.dart`, `about_screen.dart`, `support_screen.dart` | 10 new files |
| 2026-04-19 | Added new shared widgets: `app_button.dart`, `app_filter_sheet.dart`, `app_page_header.dart`, `app_tab_switcher.dart`, `app_toggle_switch.dart` | 5 new files |
| 2026-04-19 | Added `lib/core/utils/tag_parser.dart`, `lib/core/constants/app_constants.dart`, `custom_category_model.dart`, `category_editor_sheet.dart`, `notifications_provider.dart`, `tools_tab_widgets.dart`, `amount_expression.dart`, `records_search_logic.dart` | 8 new files |
| 2026-04-20 | Created `TASKS.md` – full future-goals backlog organised into 7 sections (Brand, Architecture, Features, UI/UX, Testing, Performance, DevOps) | `TASKS.md` |
| 2026-04-20 | Updated `memory.md` – reflected rebrand, all new files (sms_parser, services, screens, widgets), updated §1 layout, §2 classification, §8 change log | `memory.md` |
| 2026-05-27 | Decoupled modular features (`accounts`, `settings`, `categories`, `recurring`, `analytics`) out of `expense/`, reorganized test suite to match, fixed Cyrillic 'T' in SMS parser engine, updated AGENTS/GEMINI docs, and verified codebase (69/69 tests passing) | Over 40 files modified/moved, `memory.md` |
| 2026-05-27 | Redesigned HomeTopBar and HomeHeader to replicate the floating white card hero layout from the user's design reference image (2).png, integrated quick amount chips inside the card, added navigation tap gestures, and resolved all 14 static analysis/formatting warnings across the codebase | lib/features/expense/presentation/screens/home/home_header.dart, lib/features/expense/presentation/screens/home_screen.dart, lib/features/categories/presentation/provider/budget_state.dart, lib/features/categories/presentation/screens/categories_screen.dart, lib/features/expense/presentation/widgets/power_pill_menu.dart, lib/features/sms_parser/domain/sms_parser_engine.dart, memory.md |
| 2026-05-28 | Redesigned manual transaction input screen UI layout and interaction rules to support mockup, adding unified card, left-aligned amount field with smaller size, Date/Time + Location row, and trigger symbol prefixes on choice chips | lib/features/expense/presentation/screens/add_expense_screen.dart, memory.md |
| 2026-05-28 | Refactored manual entry screen visual layout: removed brackets from chips, added premium accent tinted/solid colored styling, changed chips to fully rounded capsule shape (`BorderRadius.circular(20)`), relocated calculator preview to top-left of the input block, scaled down calculator toggle, grouped attachments/mic under a compact chip-like background pill placed on the same row as the Date/Time picker, enabled text keyboard with unified inline command parsing inside a cursor-friendly empty amount field (with blinking caret colored by transaction type), and set up a periodic tips hint rotator on the notes box. | lib/features/expense/presentation/screens/add_expense_screen.dart, memory.md |
| 2026-05-28 | Refined manual entry screen visual layout: configured explicit blinking caret sizing and properties, kept amount field focused during calculator toggling to preserve active cursor state, styled Date/Time picker and type tabs to match the fully rounded capsule shape (`BorderRadius.circular(20)`), and made the attachment/mic pill more compact with smaller 14px icons and padded capsule background. | lib/features/expense/presentation/screens/add_expense_screen.dart, lib/features/expense/presentation/screens/add_expense/add_expense_widgets.dart, memory.md |
| 2026-05-28 | Integrated voice entry sheet directly into entry screen mic button (passing returnResult flags and populating amount, type, category, note, date), enabled unified scanner OCR import via scanner callback, configured native FilePicker file attachments, and implemented inline SMS notification copy-pasting to auto-fill transaction fields directly inside the amount field onChanged listener. | lib/features/expense/presentation/screens/add_expense_screen.dart, lib/features/expense/presentation/screens/unified_scanner_screen.dart, lib/features/expense/presentation/screens/voice_entry_screen.dart, lib/routes/app_routes.dart, memory.md |
| 2026-05-28 | Redesigned Savings Goals layout in tools tab with a premium single card layout, custom progress bars featuring trophy badges, and a stateful picker dialog for selecting emojis, colors, and target dates. | lib/features/accounts/presentation/screens/accounts/tools_tab_widgets.dart, memory.md |
| 2026-05-28 | Restructured Tools navigation tabs from 5 to 3 (removing Budget, merging Recurring & Future), implemented combined RecurringAndFutureToolView, and refactored SplitBillToolView with contacts permission flow, custom list search, and Equal/Exact calculators. | lib/features/accounts/presentation/screens/accounts_screen.dart, lib/features/accounts/presentation/screens/accounts/tools_tab_widgets.dart, lib/features/accounts/presentation/widgets/split_bill_tool_view.dart, memory.md |
| 2026-05-28 | Fixed savings goals list item overflow with a column layout. Added Category subcategories Hive model serialization, separated subcategories from note hashtags by introducing a distinct subcategory field on ExpenseModel with custom Hive serialization, implemented subcategory choice chips in AddExpenseScreen, and transitioned CategoryListCard in Category screen to a spacious Wrap layout. | `tools_tab_widgets.dart`, `app_preferences_model.dart`, `preferences_providers.dart`, `categories_widgets.dart`, `categories_screen.dart`, `add_expense_screen.dart`, `expense_model.dart`, `expense_providers.dart`, `app_routes.dart`, `home_screen.dart`, `records_history_screen.dart`, `memory.md` |
| 2026-05-28 | Refined category subcategory chips to render in a single horizontal scrollable row using StadiumBorder, placed "+ Add" button at the first position, added shrinkWrap constraint and 40px layout height to prevent vertical clipping, configured Add Expense subcategory chips to use StadiumBorder, and excluded subcategories and "+ Add" button from the Accounts board tab. | `categories_screen.dart`, `categories_widgets.dart`, `add_expense_screen.dart`, `memory.md` |
| 2026-05-28 | Made the bottom navigation bar horizontally scrollable (via SingleChildScrollView and BouncingScrollPhysics) and added a fifth "Tags" tab placeholder mapped to a PlaceholderScreen in AppShell. Cleaned up unused variables and imports in add_expense_screen.dart, tools_tab_widgets.dart, and split_bill_tool_view.dart to ensure a warning-free static analysis build. | `floating_nav_bar.dart`, `app_shell.dart`, `add_expense_screen.dart`, `tools_tab_widgets.dart`, `split_bill_tool_view.dart`, `memory.md` |
| 2026-05-28 | Fixed FAB layout bugs (raised Tags screen FAB above bottom nav; wrapped AppShell PowerFab in AnimatedOpacity + IgnorePointer visibility guard) and implemented premium Tags & Shorthand UI/UX improvements (real-time autocomplete row in AddExpense, dynamic colored list cards, live mockup simulator in Editor sheet, haptic expansion feedback). | `tags_screen.dart`, `add_expense_screen.dart`, `app_shell.dart`, `memory.md` |
| 2026-05-29 | Fixed add_expense_screen.dart brace mismatch syntax error, restored normal preview chips list selection on manual transaction entry screen, and integrated inline "Search & Select" action chips to open bottom sheet selectors for Accounts, Categories, Tags, and Splits. | `add_expense_screen.dart`, `memory.md` |
| 2026-05-29 | Created CalendarViewScreen with interactive monthly calendar grid and chronological timeline views, mapped named route pushCalendarView in AppRoutes, and integrated month tap navigation inside HomeDateStrip. | `calendar_view_screen.dart`, `home_date_strip.dart`, `home_screen.dart`, `app_routes.dart`, `index.dart`, `memory.md` |
| 2026-05-29 | Fixed timeline view layout crash inside IntrinsicHeight, implemented Week, 2-Week, and Month views in Calendar screen with view popup pill toggles, styled day cells, spending capsules and category icon badges to match mockups, and redesigned Home screen date strip to be styled as a calendar week view (linking to Calendar screen on tap). | `calendar_view_screen.dart`, `app_routes.dart`, `home_date_strip.dart`, `home_screen.dart`, `memory.md` |
| 2026-05-29 | Hidden controls in Timeline tab, repositioned Today button to right side of calendar navigation, scaled calendar and timeline font sizes, changed Transactions metric card to fit space, and replicated summary metrics row in Timeline tab. | `calendar_view_screen.dart`, `home_date_strip.dart`, `memory.md` |
| 2026-05-29 | Removed Transactions metric card from Calendar and Timeline views. Redesigned Subscriptions view inside Tools tab to match mockup with horizontal slate upcoming cards, brand-colored brand icons vertical list, and renewal summary bar. Refactored Future Transactions view to use matching premium list tiles. | `calendar_view_screen.dart`, `recurring_tool_view.dart`, `tools_tab_widgets.dart`, `memory.md` |
| 2026-05-29 | Integrated AppColors theme colors into Subscriptions accent cards and headers. Added stateful ConsumerStatefulWidget expansion logic to collapse/expand long subscription lists inside the Tools tab. | `recurring_tool_view.dart`, `memory.md` |
| 2026-05-29 | Implemented Subscription Auto-Logging ("Log Payment" action, next bill date calculation, dynamic periodic rates label) and billingPeriod ChoiceChips selector in editor. Added swipe gestures to CalendarViewScreen grid container. Linked Savings Goals to dynamic bank account balances, displaying a linked tag and disabling manual adding on linked goals. Replaced Subscription icons list with emoji presets and custom emoji options. Fixed compiler type check and missing variable declarations. Added Compiler Error Prevention (Anti-Error Guidelines) sections in guidelines files. | `recurring_subscription_model.dart`, `recurring_subscription_providers.dart`, `subscription_editor_sheet.dart`, `recurring_tool_view.dart`, `subscription_icons.dart`, `calendar_view_screen.dart`, `tools_tab_widgets.dart`, `GEMINI.md`, `AGENTS.md`, `memory.md` |
| 2026-05-30 | Implemented Geolocation transaction logging and visual Sonar Radar Mapping Board tool screen. Added `geolocator` package, requested Android GPS hardware permissions, expanded custom Hive serialization for `ExpenseModel` coordinate variables with backward compatibility checks, updated controller methods, added `_toggleLocation()` and chip UI feedback to manual entry, and linked dashboard route card to Accounts tools menu. | `pubspec.yaml`, `AndroidManifest.xml`, `expense_model.dart`, `expense_providers.dart`, `app_routes.dart`, `tools_tab_widgets.dart`, `calendar_view_screen.dart`, `home_screen.dart`, `records_history_screen.dart`, `add_expense_screen.dart`, `location_map_screen.dart`, `accounts_screen.dart`, `memory.md` |
| 2026-05-30 | Implemented unified System Permissions settings screen with real-time state check observer, native Kotlin MethodChannel mock notification simulator trigger, and expanded display currency details (AUD, CAD, CHF, CNY, HKD, NZD, SEK, KRW, BTC). | `MainActivity.kt`, `currency_selector_sheet.dart`, `permissions_settings_screen.dart`, `settings_screen.dart`, `notification_settings_screen.dart`, `memory.md` |
| 2026-05-30 | Redesigned the Finance Tools dashboard (`accounts_screen.dart`) to replicate the 4-column rounded squircle card mockup with a lavender-purple top gradient background, real-time search filtering, and 16 dashboard utilities (expanding access to hidden/sub-pages like Alerts, AI Setup, Security, and Support). Resolved RenderFlex cell overflows by normalizing tool labels to concise single-word identifiers (Add, Map, Split, Scan, Pay, Voice), reducing vertical spacing to 6, and lowering `childAspectRatio` to 0.68. | `accounts_screen.dart`, `memory.md` |
| 2026-05-30 | Propagated global lavender-gradient header style (`GradientAppBar`) with a shadow elevated circular Android back button across all sub-screens (AboutScreen, SupportScreen, AccountsBoardScreen, UpiScannerScreen), made `Week` the default view type in `CalendarViewScreen`, and updated all search inputs in the application to inherit the tools page's premium search bar style. Cleared all static analysis warnings by removing unused imports. | `app_page_header.dart`, `calendar_view_screen.dart`, `about_screen.dart`, `support_screen.dart`, `accounts_board_screen.dart`, `upi_scanner_screen.dart`, `location_map_screen.dart`, `split_bill_tool_view.dart`, `categories_screen.dart`, `records_history_screen.dart`, `currency_selector_sheet.dart`, `app_shell.dart`, `data_settings_screen.dart`, `settings_screen.dart`, `memory.md` |
| 2026-05-30 | Created reusable, unified, and stateful `AppSearchBar` widget in `lib/shared/widgets/app_search_bar.dart` and integrated it across all screens (Tools dashboard, location map, split bill, categories, records history, currency selector sheet, and all selection bottom sheets in `add_expense_screen.dart`), updated the back button icon in `app_page_header.dart` to use `Icons.chevron_left_rounded` to show chevron left style (`<`), and redesigned the charts/insights screen (`stats_screen.dart`) to use the new premium `GradientAppBar` header style with integrated tab switcher. | `app_search_bar.dart`, `app_page_header.dart`, `stats_screen.dart`, `accounts_screen.dart`, `location_map_screen.dart`, `split_bill_tool_view.dart`, `categories_screen.dart`, `records_history_screen.dart`, `currency_selector_sheet.dart`, `add_expense_screen.dart`, `memory.md` |
| 2026-05-30 | Refactored stats screen range filters into a 5-tab app bar selector (Week, 2 Weeks, Month, Year, All Time) and chart selectors into a swipable body switcher (Flow, Spend, Habit). Upgraded flow trend line chart to a side-by-side double bar chart matching mockup design. | `stats_screen.dart`, `stats_widgets.dart`, `memory.md` |
| 2026-05-30 | Redesigned Stats screen into a single-page interactive dashboard: replaced top tab bar with outlined range capsule dropdown button, added IOS-style segment controls for charts in-place toggling (Flow, Spend, Habit), and integrated persistent summary metrics grid, smart insights grid, and detailed audit records scroll list. | `stats_screen.dart`, `stats_widgets.dart`, `memory.md` |
| 2026-05-30 | Overhauled Stats screen dashboard to align with mockup features and visual aesthetics in Stats.png (adding stacked card components for Overview metrics, Salary progress bar, daily Line Chart spending trends, Breakdown donut analysis, Category budget limits utilization, and Top transaction lists). | `stats_screen.dart`, `stats_widgets.dart`, `memory.md` |

---

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
| **Rebrand** | App name: XPensa → **XPens**. Package ID: `app.xpensa.finance` → `app.xpens.finance` |
| Home screen scroll | Increased bottom padding of the recent-transactions scroll list to `160 dp` so the last record is never occluded by the floating FAB or the floating nav bar |
| **SMS Auto-import** | New `sms_parser` feature: engine, monitoring service, queue model, provider, settings sheet |
| **Scanner modes** | Unified scanner with UPI / receipt / product sub-modes; dedicated screens scaffolded |
| **Voice entry** | `voice_entry_screen.dart` scaffolded for speech-to-expense |
| **Security** | PIN entry screen + biometric service added |
| **Notifications** | In-app notification screen + provider scaffolded |
| **Home widget** | `widget_sync_service.dart` for Android home-screen widget data sync |
| **Custom categories** | `CustomCategoryModel` + `category_editor_sheet.dart` added |
| **Shared widgets** | `AppButton`, `AppFilterSheet`, `AppPageHeader`, `AppTabSwitcher`, `AppToggleSwitch` added to `lib/shared/widgets/` |
| **Core services** | `AiProductService`, `BiometricService`, `UpdateService`, `WidgetSyncService` added to `lib/core/services/` |
| **New info screens** | `about_screen.dart`, `support_screen.dart` added |

### Migration Notes
- No database schema changes; no data migration required.
- New Kotlin package path: `android/app/src/main/kotlin/app/xpens/finance/`. Update any manual references.
- New backup file extension: `.xpens` (was `.xpensa`).

---
