# dart-style.md — Dart Coding Standards

## Formatting

- Code is formatted with `dart format .` (line length: 80 characters).
- CI enforces `dart format --set-exit-if-changed .` — no manual style overrides.

## Naming

| Construct | Convention | Example |
|-----------|-----------|---------|
| Classes / Enums | `UpperCamelCase` | `ExpenseModel` |
| Functions / Variables | `lowerCamelCase` | `totalExpenses` |
| Constants | `lowerCamelCase` | `kDefaultCurrency` |
| Private members | `_lowerCamelCase` | `_cache` |
| Files | `snake_case` | `Expense_model.dart` |

- Local variables must **not** have a leading underscore (lint: `no_leading_underscores_for_local_identifiers`).

## Type Safety

- Null-safety is enabled (`sdk: ">=3.0.0"`). Never use `dynamic` without explicit justification.
- Avoid unsafe `!` null-assertion operators — prefer conditional access or early returns.
- Avoid `as` downcasts without a prior `is` check.

## Logging

- Use `dev.log(message, name: 'FeatureName', error: e, stackTrace: st)` from `dart:developer`.
- Never use `print()` — it violates the `avoid_print` lint rule.

## Linting

- Lint config: `analysis_options.yaml` (inherits `package:flutter_lints/flutter.yaml`).
- All issues must be resolved before merge — `flutter analyze` must exit with code 0.
- Use `// ignore: rule_name` only with a comment explaining why.

## Imports

- Dart SDK imports first, then package imports, then relative imports.
- Always import from feature barrels (`package:Expensioa/features/<name>/<name>.dart`) rather than deep internal paths.
