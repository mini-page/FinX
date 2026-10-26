# api.md — API Integration Standards

> **Current status:** Expensioa is fully offline (Hive-only). These rules apply when external network calls are introduced (e.g., cloud sync, currency rates, auth).

## HTTP Client Setup

- Use a single shared `http.Client` or `Dio` instance, scoped to a Riverpod provider.
- Set `connectTimeout`, `receiveTimeout` (recommended: 10 s / 30 s).
- Base URL and environment config must come from compile-time constants or `--dart-define`, **never** hardcoded strings in logic.

## Request / Response Models

- All API payloads have typed Dart models with `fromJson` / `toJson`.
- Use `json_serializable` or `freezed` for code generation.
- Validate required fields and handle missing/null JSON keys gracefully.

## Error Handling

Every network call must handle:
1. `SocketException` — no connectivity.
2. `TimeoutException` — server unresponsive.
3. HTTP 4xx — client error (parse error body into a typed `ApiError`).
4. HTTP 5xx — server error (retry with back-off).
5. Unknown exceptions — log with `dev.log` and surface a generic user message.

## Retry Policy

- Retry transient errors (5xx, timeout) with **exponential back-off**: base 1 s, multiplier 2×, max 3 retries.
- Do **not** retry 4xx errors (they are client-side and won't resolve on retry).
- Add jitter (±10 %) to back-off intervals to avoid thundering herd.

## Security

- All endpoints must use HTTPS.
- Auth tokens stored in `flutter_secure_storage`, never in Hive or `SharedPreferences`.
- Never log response bodies containing PII.
- Refresh tokens on 401 before retrying the original request once.

## Testing

- Mock network layer with `http.MockClient` or `mocktail`.
- Test success, 4xx, 5xx, and timeout paths for every endpoint.
