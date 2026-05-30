# AGENTS.md - XPensa Expense Tracker

## 0. Memory File (Read Before Anything Else)

Open **`memory.md`** (repo root) at the start of every session. It contains the current file layout, navigation map, identified issues, and a full change log. After completing any change, append a row to the §8 Change Log in `memory.md` (format: `| YYYY-MM-DD | Description | Files Affected |`). This keeps the shared agent context accurate and up-to-date for every subsequent session.

## 1. System Overview

XPensa is a cross-platform, offline-first expense tracker built with:

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
- All persisted data originates from the `Expense` model.
- Always import model files directly (e.g. `import 'package:xpens/features/accounts/data/models/account_model.dart';`) when referencing custom model types inside subviews, to prevent missing type errors.
- Always declare accessed lists or provider outputs (e.g. `final accounts = ref.read(accountListProvider).value ?? [];`) locally inside nested builders (like `StatefulBuilder` or list cell builders), to avoid out-of-scope compiler warnings.

## 3. Current Scope (MVP Only)

### Implement Only

- Add expense
- View expense list
- Delete expense
- Basic monthly total

### Do Not Implement Yet

- Accounts system
- Split bills
- Recurring subscriptions
- Authentication
- Cloud sync
- Advanced animations

## 4. Folder Responsibilities

Primary feature root:

```text
lib/features/expense/
```

### data/

- `models/` for Hive-compatible models
- `datasource/` for direct Hive operations
- `repositories/` for repository implementations

### domain/

- `entities/` for pure models if needed beyond MVP
- `usecases/` for minimal business logic

### presentation/

- `screens/` for pages
- `widgets/` for reusable UI components
- `provider/` for Riverpod state logic

## 5. Data Model Contract

```dart
class Expense {
  final String id;
  final double amount;
  final String category;
  final DateTime date;
  final String note;
}
```

### Constraints

- `id` must be a UUID.
- `amount` must be greater than `0`.
- `date` must be stored in UTC.
- Critical fields must not be nullable.

## 6. Hive Rules

- Box name must be `expenses`.
- Register adapters before app start.
- Do not call Hive directly outside datasource classes.

### Required Operations

- `addExpense()`
- `deleteExpense(id)`
- `getAllExpenses()`

## 7. Provider Rules (Riverpod)

### Required Providers

- `expenseListProvider` for `List<Expense>`
- `expenseControllerProvider` for add and delete logic
- `statsProvider` for computed totals

### Constraints

- No async logic inside UI.
- All mutations must go through the controller provider.
- Derived data belongs in separate providers.

## 8. UI Rules

### Screens

- `HomeScreen` for list and FAB
- `AddExpenseScreen` for the input form
- `StatsScreen` for summary

### Constraints

- UI handles display and input only.
- No database access from UI.
- No business logic in widgets.

## 9. Navigation Rules

- Use a simple `BottomNavigationBar` with 5 tabs.
- Only 3 screens are active in MVP:
  - Home
  - Stats
  - Categories placeholder

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

## 12. Performance Rules

- Cache the expense list in provider state.
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
1. Create feature branch
2. Implement vertical slice
3. Run flutter pub get (first run or after dependency changes)
4. Validate via flutter analyze && flutter test
5. Test via flutter run
6. Commit small changes
7. Push to GitHub
```

## 15. Immediate Task (Strict)

Build only:

```text
Add Expense -> Store -> Fetch -> Display -> Delete
```

Do not expand scope.

## 16. Future Extensions (Locked for Later)

- Firebase sync
- Authentication
- Multi-account system
- Split bills module
- Recurring transactions
- Budget goals

## 17. Final Constraint

The system must remain:

- Predictable
- Modular
- Replaceable, so Hive can be swapped for Firebase later
- Maintainable under scaling

```text
Keep it minimal. Ship fast. Iterate later.
```

## 18. Commands (Critical for Agent)

### Get Dependencies

```text
flutter pub get
```

### Run App

```text
flutter run
```

### Analyze Code

```text
flutter analyze
```

### Format Code

```text
dart format .
```

### Build APK

```text
flutter build apk
```

### Build App Bundle

```text
flutter build appbundle
```

### Hive Setup

```text
flutter packages pub run build_runner build
```

TODO: verify if code generation is still needed; adapters are currently hand-written and `build_runner` is not in `pubspec.yaml`.

### Run All Tests

```text
flutter test
```

### Run Single Test

```text
flutter test test/path/to/test_file.dart
```

### Update Launcher Icons

```text
flutter pub run flutter_launcher_icons:main
```

### Update Splash Screen

```text
flutter pub run flutter_native_splash:create
```

### Debug Single File

```text
flutter analyze lib/path/to/file.dart
```

## 19. Coding Rules

### DO

- Use Riverpod only for state.
- Keep widgets small and reusable.
- Use the repository pattern strictly.
- Use `ListView.builder` for lists.

### DO NOT

- Do not access Hive directly in UI.
- Do not mix business logic in widgets.
- Do not create large widgets over 200 lines.
- Do not introduce new dependencies without reason.

## 20. Key Entry Points

- App start -> `lib/main.dart`
- Expense feature -> `lib/features/expense/`
- Providers -> `lib/features/expense/provider/`
- UI screens -> `lib/features/expense/presentation/screens/`
- Hive setup -> `lib/core/utils/`

## 21. Task Templates

### Add New Feature

```text
1. Create model (data/models)
2. Create datasource
3. Create repository
4. Create provider
5. Create UI screen
```

### Add UI Component

- Create widget in `presentation/widgets`.
- No logic inside widget.
- Use provider for state.

## 22. Personal Rules

- Prefer clean architecture.
- Avoid hacks.
- Optimize for readability over cleverness.
- Always handle edge cases.
