# CLAUDE.md — Expensioa Global Instructions

Expensioa is a Flutter-based personal finance app targeting **Android** and **Web** (SPA).
It uses **Riverpod** for state management, **Hive** for local persistence, and follows
a **feature-driven Clean Architecture** layout under `lib/features/`.

---

## Architecture at a Glance

```
lib/
  core/           # Shared utilities, Hive bootstrap, theme, constants
  features/
    <feature>/
      data/         # Hive datasources, models, repository impls
      domain/       # Repository interfaces
      presentation/
        provider/   # Riverpod providers (AsyncNotifierProvider, etc.)
        screens/    # Top-level screens + sibling sub-directories for widget splits
        widgets/    # Feature-specific UI components
  shared/
    widgets/        # App-wide reusable widgets (e.g. PlaceholderScreen)
```

Feature barrels (`lib/features/<name>/<name>.dart`) re-export all public symbols —
always import from the barrel, not from internal paths.

---

## Build & Development Commands

| Task | Command |
|------|---------|
| Get dependencies | `flutter pub get` |
| Run app | `flutter run` |
| Lint | `flutter analyze` |
| Tests | `flutter test` |
| Build APK | `flutter build apk` |
| Build AAB | `flutter build appbundle` |
| Build Web | `flutter build web` |

---

## Coding Standards

- **State**: Riverpod only. Use `AsyncNotifierProvider` for async/storage-backed state.
- **Logging**: `dev.log` / `log` from `dart:developer`. Never `print()`.
- **Dates**: Always store/compare in UTC (`date.toUtc()`).
- **Models**: Pure Dart data-layer models — no Flutter imports in `data/models/`.
- **Linting**: `flutter analyze` must pass with zero issues before any merge.
- **Formatting**: `dart format .` is enforced in CI.

---

## State Management

- **Riverpod** (`flutter_riverpod`).
- `AsyncNotifier` for async data; `Notifier` for sync state.
- Providers are scoped to their feature's `provider/` directory and re-exported via the feature barrel.

---

## Local Storage

- **Hive** boxes: `Expenses`, `accounts`, `budgets`, `preferences`, `recurringSubscriptions`.
- Adapters and box initialization live in `lib/core/utils/hive_bootstrap.dart`.
- Models implement `HiveObject` and use generated TypeAdapters (`.g.dart`).

---

## Testing

- Unit tests: `test/features/<feature>/data/` and `test/features/<feature>/domain/`.
- Widget tests: `test/features/<feature>/presentation/`.
- Run all tests: `flutter test`.

---

## Platform Targets

| Platform | Notes |
|----------|-------|
| Android | Minimum SDK 21; builds APK / AAB via `flutter build apk|appbundle` |
| Web SPA | `flutter build web`; static assets served from `public_assets/` and `website/` |

---

## Agents & Rules

See `.claude/agents/` for specialist AI roles and `.claude/rules/` for engineering standards.
