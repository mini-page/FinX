# JULES.md - Expensioa Agent Guide (Jules / Gemini / General-Purpose AI)

## 0. Memory File (Read Before Anything Else)

**Always open `memory.md` (repo root) first.** It is the authoritative project state: current file layout, navigation map, identified issues, and change log. After every change, append a row to the §8 Change Log in `memory.md` (format: `| YYYY-MM-DD | Description | Files Affected |`). Never skip this step — it is how all agents stay in sync.

---

## 1. Project Overview

Expensioa is an offline-first, Android-focused Expense tracker built with:

- **Flutter** (Dart ≥ 3.0) for UI
- **Riverpod** (`flutter_riverpod`) for state management
- **Hive** (`hive`, `hive_flutter`) for local persistence
- **fl_chart** for analytics charts

---

## 2. Key Entry Points

| File | Purpose |
|------|---------|
| `lib/main.dart` | App bootstrap, Hive init, Riverpod scope |
| `lib/features/Expense/presentation/screens/app_shell.dart` | Root scaffold with `IndexedStack` + `FloatingNavBar` |
| `lib/core/utils/hive_bootstrap.dart` | Adapter registration – must run before any Hive box opens |
| `lib/routes/app_routes.dart` | **All** navigation helpers – never push routes inline |
| `memory.md` | Living project memory – read at session start, update at session end |

---

## 3. Architecture Rules

1. **Unidirectional flow**: UI → Provider → Repository → DataSource → Hive.
2. **No Hive access from UI** – only through datasource classes.
3. **No business logic in widgets** – keep it in Notifiers/Controllers.
4. **Use `AppRoutes`** for navigation – never call `Navigator.push` inline.
5. **Use `AppTheme.light()` / `AppTheme.dark()`** – never inline `ThemeData`.
6. **Use shared widgets first** – check `lib/shared/widgets/` before creating new ones.

---

## 4. File Conventions

- Large screens extract private widgets into `screens/<name>/` subdirectories.
- Each directory has an `index.dart` barrel export.
- Screens are named `<feature>_screen.dart`; extracted widgets are `<feature>_widgets.dart`.
- Use `dev.log` / `log` for debugging; never `print()`.

---

## 5. Build Commands

```bash
flutter pub get          # Fetch dependencies
flutter analyze          # Lint
dart format .            # Format
flutter test             # Run all tests
flutter build apk --release                              # Release APK
flutter build appbundle --release                        # Release AAB
flutter build apk --release --split-per-abi             # Per-ABI APKs
```

---

## 6. Coding Standards

- Prefer `const` constructors wherever possible.
- Models must be immutable.
- Always handle edge cases (empty lists, null-safe types).
- Avoid widgets longer than 200 lines; extract private widgets into sub-files.

---

## 7. Before You Finish

1. Run `flutter analyze` – zero warnings expected.
2. Run `dart format .` – no diff expected.
3. Update **`memory.md`** §8 Change Log with every file you touched.
