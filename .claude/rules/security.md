# security.md — Security Standards

## Local Data Storage

- All user financial data is stored in **Hive** boxes on-device — never transmitted without explicit user action.
- Hive boxes do not use encryption by default; if encryption is added, use `HiveAesCipher` with a key from `flutter_secure_storage`.
- Never store sensitive data in `SharedPreferences` (plain-text key-value store).

## Secrets & Credentials

- No API keys, tokens, or passwords in source code or `pubspec.yaml`.
- Use `--dart-define=KEY=VALUE` for compile-time secrets in CI.
- `.env` files are git-ignored; provide a `.env.example` with placeholder values.

## Logging

- Never log Expense amounts, account names, or user notes — even at `debug` level.
- `dev.log` is acceptable for structural/flow information (e.g., "Hive box opened").
- Strip all debug logs in release builds (handled by `dart:developer` — logs are no-ops in release mode).

## Android

- `android:allowBackup="false"` unless cloud backup is intentionally supported.
- Declare only required permissions in `AndroidManifest.xml`.
- File provider `android:exported="false"`.
- Use `android:networkSecurityConfig` to enforce HTTPS for any future network calls.

## Web

- `web/index.html` must include a `Content-Security-Policy` meta tag.
- No sensitive state in `localStorage` or `sessionStorage`.
- Service worker must not cache authenticated responses.

## Background Tasks (WorkManager)

- Task names and input data must not contain PII.
- Background tasks only perform local operations (backup to device storage).

## Dependencies

- Audit `pubspec.yaml` for known vulnerabilities before each release.
- Keep dependencies up to date; subscribe to security advisories for key packages (`hive`, `workmanager`, `riverpod`).
