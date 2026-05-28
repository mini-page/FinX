# Gemini CLI Project Configuration: XPens

You are acting as an expert Senior Flutter Developer and Architect working on the `XPens` application, a premium, modern expense tracker built specifically for Android.

## Project Tech Stack
- **Framework:** Flutter (Dart >= 3.0.0)
- **State Management:** Riverpod (`flutter_riverpod`)
- **Local Storage / Database:** Hive (`hive`, `hive_flutter`)
- **Charting & Data Viz:** `fl_chart`
- **Other Key Dependencies:** `mobile_scanner`, `workmanager`, `file_picker`, `permission_handler`.

## Core Architectural Guidelines

### 1. Feature-First Modular Architecture
The codebase is structured into self-contained feature directories inside `lib/features/`.
- `lib/core/`: Application-wide utilities, constants, theme systems, and database bootstraps.
- `lib/shared/`: Reusable cross-feature UI components (e.g. `lib/shared/widgets/app_button.dart`).
- `lib/features/`: Contains fully decoupled features:
  - `accounts/`: Bank and balance account management.
  - `categories/`: Category definitions, editor sheets, and budget logic.
  - `recurring/`: Subscriptions, due date calculations, and recurring tools.
  - `settings/`: App preferences, pin security, biometrics, and database backup controls.
  - `analytics/`: Monthly spending statistics and flow visualization.
  - `expense/`: Core transaction logging models and transaction list presentation.
  - `sms_parser/`: Automated transaction extraction from SMS notifications.
  - `transactions/`: General transactions barrel (add-expense, search, history screens).

Every feature directory must maintain its clean boundary. Consumers must import via the barrel files (e.g. `import 'package:xpens/features/accounts/accounts.dart'`).

### 2. State Management (Riverpod)
- Keep all business logic and screen state in Riverpod Notifiers/Providers.
- Limit `setState` exclusively to ephemeral UI state (e.g. local tab indices, animation controllers).

### 3. Data Persistence (Hive)
- Wrap all Hive boxes in datasource classes inside `lib/features/<feature>/data/datasource/`.
- Ensure models generated with `@HiveType` register adapters in `lib/core/utils/hive_bootstrap.dart`.

### 4. Code Quality & Formatting
- Maintain formatting with `flutter format .`.
- Run `flutter analyze` and resolve all lint issues.
- Keep tests updated under `test/features/` to mirror the features layout.

## Tooling & Command Directives

### 1. Modern Command-Line Alternatives
To search, find, and navigate the repository, prioritize using modern CLI utilities over classical counterparts:
- **File Finding:** Use `fd` instead of `find`.
- **Content Searching:** Use `ripgrep` (`rg`) instead of `grep`.
- **Directory Listing:** Use `eza` or `exa` instead of `ls` / `dir` for visual structure.
- **File Viewing:** Use `bat` instead of `cat` or `type` for syntax highlighting.
- **Directory Navigation:** Use `zoxide` (`z`) for fast jumping.

### 2. Execution Directives
- **Verification First:** Before finalizing any architectural or code changes, verify using `flutter analyze` and `flutter test`. Ensure all tests pass.
- **Impact Analysis:** Run `gitnexus_impact` or similar impact mapping when modifying critical symbols.
- **Living Memory:** You **must** update `memory.md` at the end of each session. Append changes to the Change Log and update the Layout structure to reflect reality.
