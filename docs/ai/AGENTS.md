# AGENTS.md - Expensio Expense Tracker

## 0. Memory File (Read Before Anything Else)

Open **`memory.md`** (repo root) at the start of every session. It contains the current file layout, navigation map, identified issues, and a full change log. After completing any change, append a row to the §8 Change Log in `memory.md` (format: `| YYYY-MM-DD | Description | Files Affected |`). This keeps the shared agent context accurate and up-to-date for every subsequent session.

## 1. System Overview

Expensio is a cross-platform, offline-first Expense tracker built with:

- Flutter for UI
- Riverpod for state management
- Hive for local database storage

Architecture follows feature-first clean layering:

```text
UI -> Provider -> Repository -> DataSource -> Hive
```

## 2. Core Principles

### Mandatory Rules

- Use unidirectional data flow only.
- Do not place business logic inside UI widgets.
- Repository is the single abstraction layer.
- Hive access is allowed only through datasource classes.
- Providers control all state mutations.
- All persisted data originates from the model layer.
- Always import model files directly (e.g. `import 'package:expensio/features/accounts/data/models/account_model.dart';`) when referencing custom model types inside subviews, to prevent missing type errors.
- Always declare accessed lists or provider outputs (e.g. `final accounts = ref.read(accountListProvider).value ?? [];`) locally inside nested builders (like `StatefulBuilder` or list cell builders), to avoid out-of-scope compiler warnings.

## 3. Current Scope

### Implemented Features

- Add / Edit / Delete Expenses
- Expense list with search, filters, month navigation
- Multi-account / wallet management
- Categories with monthly and weekly budgets
- Recurring subscriptions with notifications and price tracking
- Split bills with settlement system and debt simplification
- Visual analytics (monthly, category breakdown, trends)
- Settings: backup/restore, notifications, biometric/PIN lock, theme, import/export
- Gamification with achievements and streaks
- AI model layer (Gemini cloud + rule-based local fallback)
- Smart input: voice, SMS parsing, barcode scanning
- Push notifications (budget alerts, recurring due)

## 4. Folder Responsibilities

### lib/features/{feature}/

```
data/
  models/      Hive-compatible models
  datasource/  Direct Hive operations
  repositories/ Repository implementations
presentation/
  screens/     Pages
  widgets/     Reusable UI components
  provider/    Riverpod state logic
```

## 5. Data Model Guidelines

### Best Practices

- `id` must be a UUID.
- `amount` must be greater than `0`.
- `date` must be stored in UTC.
- Critical fields must not be nullable.
- Use immutable models (all fields final).
- Backwards-compatible Hive adapters when adding fields.

## 6. Hive Rules

- Box names are lowercase plural (e.g. `expenses`, `accounts`, `budgets`).
- Register adapters before app start in `main.dart`.
- Do not call Hive directly outside datasource classes.

## 7. Provider Rules (Riverpod)

### Required Patterns

- `ListProvider` for `List<Model>`
- `ControllerProvider` for add/update/delete logic
- Derived data belongs in separate providers

### Constraints

- No async logic inside UI.
- All mutations must go through the controller provider.
- Derived data belongs in separate providers (use `ref.watch`).

## 8. UI Rules

### Screens

- `HomeScreen` for dashboard (balance, month nav, expense list, FAB)
- `AddExpenseScreen` for input form
- `StatsScreen` for analytics
- Feature screens under their feature directory

### Constraints

- UI handles display and input only.
- No database access from UI.
- No business logic in widgets.
- Keep widgets small and reusable.
- Avoid widgets over 200 lines; extract sub-widgets.

## 9. Navigation

- `AppShell` with `Drawer` (hamburger menu) for top-level navigation
- Bottom nav tabs for: Home, Stats, Accounts, Categories, Settings
- Feature pages pushed via Navigator

## 10. Execution Flow (Critical)

```text
User taps FAB
 -> Open AddExpenseScreen
 -> Submit form
 -> Provider.addExpense()
 -> Repository.save()
 -> Hive write
 -> Provider refresh
 -> UI rebuild
```

## 11. Error Handling

- Validate amount input before submit.
- Prevent empty or invalid values.
- Handle Hive initialization failure.
- Return safe defaults such as an empty list.
- Wrap AI operations in try/catch with `AiModelException`.

## 12. Performance Rules

- Cache lists in provider state.
- Avoid repeated Hive reads.
- Use `ListView.builder`.
- Avoid full rebuilds where a selector is sufficient.

## 13. Code Constraints

### Must Use

- `const` constructors where possible
- Immutable models
- Clean separation of layers

### Must Avoid

- Logic inside widgets
- Direct Hive usage in UI
- Global mutable state
- Tight coupling between layers

## 14. Development Workflow

```text
1. Run gitnexus_impact before editing any symbol
2. Implement vertical slice
3. Run flutter pub get (first run or after dependency changes)
4. Validate via flutter analyze --no-fatal-infos --no-fatal-warnings
5. Test via flutter run
6. Commit small changes
7. Push to GitHub
```

## 15. Commands

### Get Dependencies

```
flutter pub get
```

### Run App

```
flutter run
```

### Analyze Code

```
flutter analyze --no-fatal-infos --no-fatal-warnings
```

### Format Code

```
dart format .
```

### Build APK

```
flutter build apk
```

### Build App Bundle

```
flutter build appbundle
```

### Run All Tests

```
flutter test
```

### Run Single Test

```
flutter test test/path/to/test_file.dart
```

### Update Launcher Icons

```
flutter pub run flutter_launcher_icons:main
```

### Update Splash Screen

```
flutter pub run flutter_native_splash:create
```

### Debug Single File

```
flutter analyze lib/path/to/file.dart
```

## 16. Coding Rules

### DO

- Use Riverpod only for state.
- Keep widgets small and reusable.
- Use the repository pattern strictly.
- Use `ListView.builder` for lists.
- Use `AppSpacing` and `AppColors` tokens instead of hardcoded values.
- Use `formatCurrency()` from `app_formatters.dart` for all money display.
- Run impact analysis before editing any existing symbol.

### DO NOT

- Do not access Hive directly in UI.
- Do not mix business logic in widgets.
- Do not create large widgets over 200 lines.
- Do not introduce new dependencies without reason.
- Do not ignore impact analysis warnings.

## 17. Key Entry Points

- App start -> `lib/main.dart`
- Expense feature -> `lib/features/expense/`
- Providers -> `lib/features/*/presentation/provider/`
- UI screens -> `lib/features/*/presentation/screens/`
- Hive setup -> `lib/core/utils/`
- AI model layer -> `lib/core/ai/`
- Theme & tokens -> `lib/core/theme/`

## 18. Task Templates

### Add New Feature

```
1. Run gitnexus_impact to understand affected code
2. Create model (data/models) with Hive adapter
3. Create datasource
4. Create repository
5. Create provider
6. Create UI screen
7. Open Hive box in bootstrap (main.dart)
```

### Add UI Component

- Create widget in `presentation/widgets`.
- No logic inside widget.
- Use provider for state.
- Use existing theme tokens (AppColors, AppSpacing, AppTextStyles).

## 19. Personal Rules

- Prefer clean architecture.
- Avoid hacks.
- Optimize for readability over cleverness.
- Always handle edge cases.
- Ship fast, iterate later.
