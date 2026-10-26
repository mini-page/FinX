# API Consumption — Skill Module

## Domain
Patterns for consuming REST (and optionally GraphQL) APIs in Flutter: client setup, request/response modeling, error handling, retries, and caching.

> **Expensioa context:** The app is currently offline-first (Hive). This skill applies when cloud sync, currency rates, or auth endpoints are added.

## Core Concepts

### Client Setup (Dio example)
```dart
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: const String.fromEnvironment('API_BASE_URL'),
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
  ));
  dio.interceptors.add(LogInterceptor()); // debug only
  return dio;
});
```

### Response Models
```dart
@JsonSerializable()
class ApiExpense {
  final String id;
  final double amount;
  final String category;
  final DateTime date;

  const ApiExpense({required this.id, required this.amount,
      required this.category, required this.date});

  factory ApiExpense.fromJson(Map<String, dynamic> json) =>
      _$ApiExpenseFromJson(json);
  Map<String, dynamic> toJson() => _$ApiExpenseToJson(this);
}
```

### Error Handling
```dart
Future<T> safeApiCall<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on DioException catch (e) {
    if (e.type == DioExceptionType.connectionError) throw NoConnectivityException();
    if (e.type == DioExceptionType.connectionTimeout) throw RequestTimeoutException();
    throw ApiException(statusCode: e.response?.statusCode, message: e.message);
  } catch (e, st) {
    dev.log('Unexpected error', error: e, stackTrace: st);
    rethrow;
  }
}
```

### Retry with Exponential Back-off
```dart
Future<T> withRetry<T>(Future<T> Function() fn, {int maxRetries = 3}) async {
  for (var attempt = 0; attempt < maxRetries; attempt++) {
    try {
      return await fn();
    } on TransientException {
      if (attempt == maxRetries - 1) rethrow;
      final delay = Duration(seconds: (1 << attempt)) +
          Duration(milliseconds: Random().nextInt(200));
      await Future.delayed(delay);
    }
  }
  throw UnreachableException();
}
```

### Caching
- Cache GET responses in Hive with a TTL field.
- Invalidate cache on mutation (POST/PUT/DELETE).
- Show stale data while revalidating (stale-while-revalidate pattern).

## Checklist
- [ ] All endpoints have typed request and response models.
- [ ] Every call has error handling for connectivity, timeout, 4xx, and 5xx.
- [ ] Retry logic applied to transient errors only.
- [ ] Secrets injected via `--dart-define`, not hardcoded.
- [ ] Tests cover success, 4xx, 5xx, and timeout scenarios.
