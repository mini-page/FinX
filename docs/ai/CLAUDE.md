# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 🧠 Project Memory (Read First)

Before writing any code, open **`memory.md`** (repo root) and read it fully. It contains the authoritative layout, screen index, change log, and open issues. After every change you make, append a row to the §8 Change Log in `memory.md` so future agents stay in sync. Failing to update `memory.md` breaks the shared context for all AI agents.

## 🛠 Build & Development Commands

- **Get dependencies**: `flutter pub get`
- **Run the app**: `flutter run`
- **Lint code**: `flutter analyze`
- **Run all tests**: `flutter test`
- **Run a single test**: `flutter test <path_to_test_file>` (e.g., `flutter test test/features/Expense/data/models/Expense_model_test.dart`)
- **Build APK**: `flutter build apk`
- **Build App Bundle**: `flutter build appbundle`
- **Update Launcher Icons**: `flutter pub run flutter_launcher_icons:main`
- **Update Splash Screen**: `flutter pub run flutter_native_splash:create`

## 🏗 High-Level Architecture

The project follows a feature-driven, Clean Architecture-inspired structure located in `lib/features/`.

### Directory Structure
- `lib/core`: Shared utilities and cross-cutting concerns (e.g., Hive initialization).
- `lib/features/<feature_name>`:
  - `data/`: Local data sources (Hive), models (implementations), and repository implementations.
  - `domain/`: Repository interfaces.
  - `presentation/`:
    - `provider/`: Riverpod providers for state management (using `AsyncNotifierProvider`, `Provider`, etc.).
    - `screens/`: High-level UI screens.
    - `widgets/`: Feature-specific UI components.

### State Management
- Powered by **Riverpod**.
- **Notifiers**: `AsyncNotifier` is used for handling asynchronous data (e.g., `ExpenseListNotifier`).
- **Controllers**: Logic for modifying state is often encapsulated in controller classes (e.g., `ExpenseController`) provided via Riverpod.

### Local Storage
- **Hive** is used for persistent local storage.
- Adapters and boxes are initialized in `lib/core/utils/hive_bootstrap.dart`.
- Data is stored in feature-specific boxes (e.g., `Expenses`, `accounts`, `budgets`).

## 🖋 Coding Standards
- Follow standard Flutter/Dart lint rules (see `analysis_options.yaml`).
- Prefer `AsyncNotifierProvider` for state that depends on local storage.
- Maintain the separation of concerns between `data`, `domain`, and `presentation` layers.
- Use `dev.log` or `log` for debugging information instead of `print`.
