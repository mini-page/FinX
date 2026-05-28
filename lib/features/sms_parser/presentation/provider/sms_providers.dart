import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../expense/presentation/provider/expense_providers.dart';
import 'package:xpens/features/settings/presentation/provider/preferences_providers.dart';
import '../../../expense/data/models/expense_model.dart';
import '../../data/sms_queue_item.dart';
import '../../data/sms_transaction.dart';
import '../../domain/sms_parser_engine.dart';

// ── Preferences-level SMS providers ─────────────────────────────────────────

final smsParsingEnabledProvider = Provider<bool>((ref) {
  return ref.watch(appPreferencesProvider).value?.smsParsingEnabled ?? false;
});

final smsDefaultAccountIdProvider = Provider<String>((ref) {
  return ref.watch(appPreferencesProvider).value?.smsDefaultAccountId ?? '';
});

final smsDefaultCategoryProvider = Provider<String>((ref) {
  return ref.watch(appPreferencesProvider).value?.smsDefaultCategory ?? '';
});

// ── SMS Queue ─────────────────────────────────────────────────────────────────

/// In-session queue of parsed SMS transactions awaiting confirmation.
final smsQueueProvider = NotifierProvider<SmsQueueNotifier, List<SmsQueueItem>>(
  SmsQueueNotifier.new,
);

/// Controller for acting on the queue.
final smsQueueControllerProvider = Provider<SmsQueueController>((ref) {
  return SmsQueueController(ref);
});

/// Count of pending (unconfirmed) SMS transactions.
final pendingSmsCountProvider = Provider<int>((ref) {
  return ref
      .watch(smsQueueProvider)
      .where((item) => item.status == SmsQueueStatus.pending)
      .length;
});

class SmsQueueNotifier extends Notifier<List<SmsQueueItem>> {
  @override
  List<SmsQueueItem> build() => const <SmsQueueItem>[];

  /// Parse [body] and add to the queue if valid + not a duplicate.
  /// Returns the new [SmsQueueItem] on success, or `null` if the message
  /// was rejected (unparseable, duplicate, or below confidence threshold for
  /// silent ingestion).
  SmsQueueItem? ingest({
    required String sender,
    required String body,
    required DateTime receivedAt,
  }) {
    // Primary filter: only transactional senders
    if (!SmsParserEngine.isTransactionalSender(sender)) return null;
    if (!SmsParserEngine.isTransactionalMessage(body)) return null;

    final parsed = SmsParserEngine.parse(
      senderAddress: sender,
      body: body,
      receivedAt: receivedAt,
    );
    if (parsed == null) return null;

    // Duplicate check
    if (state.any((item) => item.transaction.id == parsed.id)) return null;

    final item = SmsQueueItem(
      transaction: parsed,
      receivedAt: receivedAt,
    );
    state = [...state, item];
    return item;
  }

  void markConfirmed(String transactionId) {
    state = state
        .map((item) => item.transaction.id == transactionId
            ? item.copyWith(status: SmsQueueStatus.confirmed)
            : item)
        .toList(growable: false);
  }

  void markEditing(String transactionId) {
    state = state
        .map((item) => item.transaction.id == transactionId
            ? item.copyWith(status: SmsQueueStatus.editing)
            : item)
        .toList(growable: false);
  }

  void dismiss(String transactionId) {
    state = state
        .map((item) => item.transaction.id == transactionId
            ? item.copyWith(status: SmsQueueStatus.dismissed)
            : item)
        .toList(growable: false);
  }

  void dismissAll() {
    state = state
        .map((item) => item.copyWith(status: SmsQueueStatus.dismissed))
        .toList(growable: false);
  }

  /// Remove all non-pending items to keep the list lean.
  void prune() {
    state = state
        .where((item) => item.status == SmsQueueStatus.pending)
        .toList(growable: false);
  }
}

// ── Controller ────────────────────────────────────────────────────────────────

class SmsQueueController {
  const SmsQueueController(this._ref);

  final Ref _ref;

  /// Save a parsed transaction using the user's configured defaults.
  Future<void> confirmWithDefaults(SmsTransaction tx) async {
    final prefs = _ref.read(appPreferencesProvider).value;
    final defaultAccountId = prefs?.smsDefaultAccountId ?? '';
    final defaultCategory = prefs?.smsDefaultCategory ?? '';

    // Prefer user-configured default → parser-inferred category → fallback
    final category = defaultCategory.isNotEmpty
        ? defaultCategory
        : (tx.suggestedCategory ?? 'Other');
    final accountId = defaultAccountId.isNotEmpty ? defaultAccountId : null;

    await _ref.read(expenseControllerProvider).addExpense(
          amount: tx.amount,
          category: category,
          date: tx.timestamp,
          note: tx.notes,
          accountId: accountId,
          type: tx.type,
        );

    _ref.read(smsQueueProvider.notifier).markConfirmed(tx.id);
  }

  void markEditing(String transactionId) {
    _ref.read(smsQueueProvider.notifier).markEditing(transactionId);
  }

  void dismiss(String transactionId) {
    _ref.read(smsQueueProvider.notifier).dismiss(transactionId);
  }

  void dismissAll() {
    _ref.read(smsQueueProvider.notifier).dismissAll();
  }

  /// Manually ingest an SMS string (e.g. pasted by the user for testing).
  SmsQueueItem? ingestManual({
    required String sender,
    required String body,
  }) {
    return _ref.read(smsQueueProvider.notifier).ingest(
          sender: sender,
          body: body,
          receivedAt: DateTime.now(),
        );
  }

  /// Build prefill parameters for opening [AddExpenseScreen] for a pending item.
  ({
    double amount,
    String? category,
    DateTime date,
    String note,
    String? accountId,
    TransactionType type,
  }) prefillFor(SmsTransaction tx) {
    final prefs = _ref.read(appPreferencesProvider).value;
    final defaultAccountId = prefs?.smsDefaultAccountId ?? '';
    final defaultCategory = prefs?.smsDefaultCategory ?? '';
    // Prefer user-configured default → parser-inferred category → fallback
    final category = defaultCategory.isNotEmpty
        ? defaultCategory
        : (tx.suggestedCategory ?? 'Other');
    return (
      amount: tx.amount,
      category: category,
      date: tx.timestamp,
      note: tx.notes,
      accountId: defaultAccountId.isNotEmpty ? defaultAccountId : null,
      type: tx.type,
    );
  }
}

// ── Permission helper ──────────────────────────────────────────────────────────

class SmsPermissionHelper {
  /// Returns `true` if both READ_SMS and RECEIVE_SMS are granted.
  static Future<bool> isGranted() async {
    final read = await Permission.sms.isGranted;
    return read;
  }

  /// Requests SMS permissions. Returns `true` if granted.
  static Future<bool> request() async {
    final result = await Permission.sms.request();
    return result.isGranted;
  }

  /// Opens the app settings page if the permission is permanently denied.
  static Future<void> openSettings() async {
    await openAppSettings();
  }
}
