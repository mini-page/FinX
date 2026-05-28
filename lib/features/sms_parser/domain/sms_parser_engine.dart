import 'dart:convert';
import 'package:crypto/crypto.dart';

import '../../expense/data/models/expense_model.dart';
import '../data/sms_transaction.dart';

/// Pure-Dart regex parser that converts raw SMS / notification text into a
/// [SmsTransaction].
///
/// Parsing priority:
///  1. Extract monetary amount (₹ / Rs / INR / bare numeric near currency hint).
///  2. Detect transaction direction (credit/income vs debit/expense).
///  3. Extract date/time.
///  4. Build a notes string from ref IDs, UPI IDs, merchant names, etc.
///  5. Infer an expense category from merchant/sender keywords.
///  6. Compute a confidence score.
///
/// A result with [confidence] < [kMinConfidence] should be treated as
/// low-confidence and shown to the user for manual review rather than being
/// auto-confirmed.
abstract final class SmsParserEngine {
  /// Minimum confidence score accepted without forcing manual edit.
  static const double kMinConfidence = 0.5;

  /// Primary filter: sender IDs that end with "T" are typically bank/payment
  /// transactional senders (e.g. HDFCBANKТ, PAYTMT, SBIINT).
  static bool isTransactionalSender(String senderAddress) {
    final upper = senderAddress.trim().toUpperCase();
    // Alphanumeric sender IDs ending in T (Latin T or Cyrillic Т)
    if (RegExp(r'^[A-Z0-9\-]{3,}[TТ]$').hasMatch(upper)) return true;
    // Common patterns: -ALERTS, NOTIFY
    if (upper.contains('ALERT') ||
        upper.contains('NOTIFY') ||
        upper.contains('BANK') ||
        upper.contains('FINANCE') ||
        upper.contains('PAY') ||
        upper.contains('UPI')) {
      return true;
    }
    return false;
  }

  /// Secondary filter: body contains at least one currency/transaction keyword.
  static bool isTransactionalMessage(String body) {
    final lower = body.toLowerCase();
    return _kCurrencyPattern.hasMatch(body) ||
        _kCreditKeywords.any(lower.contains) ||
        _kDebitKeywords.any(lower.contains);
  }

  /// Full parse. Returns `null` if the message cannot be parsed meaningfully.
  static SmsTransaction? parse({
    required String senderAddress,
    required String body,
    required DateTime receivedAt,
  }) {
    final lower = body.toLowerCase();

    // ── 1. Amount ────────────────────────────────────────────────────────
    final amount = _extractAmount(body);
    if (amount == null || amount <= 0) return null;

    // ── 2. Transaction type ──────────────────────────────────────────────
    final type = _detectType(lower);

    // ── 3. Timestamp ─────────────────────────────────────────────────────
    final timestamp = _extractDateTime(body) ?? receivedAt;

    // ── 4. Notes ──────────────────────────────────────────────────────────
    final notes = _buildNotes(body, senderAddress);

    // ── 5. Category inference ─────────────────────────────────────────────
    final suggestedCategory = inferCategory(body, senderAddress);

    // ── 6. Confidence ─────────────────────────────────────────────────────
    final confidence = _computeConfidence(
      body: lower,
      amount: amount,
      type: type,
      timestamp: timestamp,
      receivedAt: receivedAt,
    );

    // ── 7. Stable ID ──────────────────────────────────────────────────────
    final id = _stableId(senderAddress, body, receivedAt);

    return SmsTransaction(
      id: id,
      amount: amount,
      type: type,
      timestamp: timestamp,
      notes: notes,
      rawMessage: body,
      senderAddress: senderAddress,
      confidence: confidence,
      suggestedCategory: suggestedCategory,
    );
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  static const List<String> _kCreditKeywords = <String>[
    'credited',
    'credit',
    'received',
    'added',
    'deposited',
    'refund',
    'cashback',
    'reversed',
    'transfer received',
    'money received',
  ];

  static const List<String> _kDebitKeywords = <String>[
    'debited',
    'debit',
    'paid',
    'payment',
    'spent',
    'sent',
    'withdrawn',
    'purchase',
    'txn',
    'transaction',
    'transferred',
    'transfer',
    'charged',
    'neft',
    'imps',
    'rtgs',
    'emi',
    'mandate',
    'bill payment',
  ];

  // Matches: ₹1,234.56  |  Rs.1234  |  Rs 1234  |  INR 1234  |  1234 INR
  static final RegExp _kCurrencyPattern = RegExp(
    r'(?:₹|Rs\.?\s*|INR\s*)([\d,]+(?:\.\d{1,2})?)'
    r'|'
    r'([\d,]+(?:\.\d{1,2})?)\s*(?:INR|Rs)',
    caseSensitive: false,
  );

  /// Returns the first monetary amount found in [body], or null.
  static double? _extractAmount(String body) {
    final match = _kCurrencyPattern.firstMatch(body);
    if (match == null) return null;
    final raw = (match.group(1) ?? match.group(2) ?? '').replaceAll(',', '');
    return double.tryParse(raw);
  }

  static TransactionType _detectType(String lower) {
    for (final kw in _kCreditKeywords) {
      if (lower.contains(kw)) return TransactionType.income;
    }
    return TransactionType.expense;
  }

  // ── Date/time extraction ─────────────────────────────────────────────────

  // Matches: 18-04-2026  |  18/04/2026  |  18.04.2026  |  2026-04-18
  static final RegExp _kDatePattern = RegExp(
    r'\b(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{2,4})\b'
    r'|'
    r'\b(\d{4})[\/\-\.](\d{1,2})[\/\-\.](\d{1,2})\b',
  );

  // Matches: 14:32  |  14:32:45  |  2:32 PM
  static final RegExp _kTimePattern = RegExp(
    r'\b(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(AM|PM)?\b',
    caseSensitive: false,
  );

  static DateTime? _extractDateTime(String body) {
    final dateMatch = _kDatePattern.firstMatch(body);
    int? day, month, year;
    if (dateMatch != null) {
      if (dateMatch.group(1) != null) {
        // dd/mm/yyyy
        day = int.tryParse(dateMatch.group(1)!);
        month = int.tryParse(dateMatch.group(2)!);
        year = int.tryParse(dateMatch.group(3)!);
      } else {
        // yyyy/mm/dd
        year = int.tryParse(dateMatch.group(4)!);
        month = int.tryParse(dateMatch.group(5)!);
        day = int.tryParse(dateMatch.group(6)!);
      }
      if (year != null && year < 100) year += 2000;
    }

    int hour = 0, minute = 0, second = 0;
    final timeMatch = _kTimePattern.firstMatch(body);
    if (timeMatch != null) {
      hour = int.tryParse(timeMatch.group(1)!) ?? 0;
      minute = int.tryParse(timeMatch.group(2)!) ?? 0;
      second = int.tryParse(timeMatch.group(3) ?? '0') ?? 0;
      final meridiem = (timeMatch.group(4) ?? '').toUpperCase();
      if (meridiem == 'PM' && hour < 12) hour += 12;
      if (meridiem == 'AM' && hour == 12) hour = 0;
    }

    if (day != null && month != null && year != null) {
      try {
        return DateTime(year, month, day, hour, minute, second);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  // ── Notes extraction ──────────────────────────────────────────────────────

  static final RegExp _kRefPattern = RegExp(
    r'(?:Ref(?:erence)?(?:\s*(?:No\.?|#|ID|Id))?\s*:?\s*)([A-Z0-9]{6,20})',
    caseSensitive: false,
  );

  // UTR is always a 12-digit numeric reference used by UPI/NEFT/IMPS
  static final RegExp _kUtrPattern = RegExp(
    r'(?:UTR|UPI\s*Ref(?:\s*No)?|Transaction\s*ID|Txn\s*ID)\s*:?\s*([A-Z0-9]{10,22})',
    caseSensitive: false,
  );

  static final RegExp _kUpiPattern = RegExp(
    r'(?:UPI(?:\s*ID)?:?\s*)([a-zA-Z0-9._\-]+@[a-zA-Z0-9._\-]+)',
    caseSensitive: false,
  );

  static final RegExp _kVpaPattern = RegExp(
    r'\b([a-zA-Z0-9._\-]+@(?:oksbi|okaxis|okhdfcbank|okicici|upi|paytm|'
    r'ybl|apl|ibl|axl|airtel|jio|boi|cnrb|psb|ezeepay|naviaxis|fbl))\b',
  );

  static final RegExp _kMerchantPattern = RegExp(
    r'(?:to|at|from|merchant|shop|store|vendor|using|towards|for)\s+([A-Z][A-Za-z0-9 &\.\-]{2,30})',
    caseSensitive: false,
  );

  static String _buildNotes(String body, String sender) {
    final parts = <String>[];

    // Prefer UTR over generic ref — UTR is the canonical UPI transaction ID
    final utrMatch = _kUtrPattern.firstMatch(body);
    if (utrMatch != null) {
      parts.add('UTR: ${utrMatch.group(1)}');
    } else {
      final refMatch = _kRefPattern.firstMatch(body);
      if (refMatch != null) parts.add('Ref: ${refMatch.group(1)}');
    }

    final upiMatch =
        _kUpiPattern.firstMatch(body) ?? _kVpaPattern.firstMatch(body);
    if (upiMatch != null) parts.add('UPI: ${upiMatch.group(1)}');

    final merchantMatch = _kMerchantPattern.firstMatch(body);
    if (merchantMatch != null) {
      final merchant = merchantMatch.group(1)!.trim();
      // Exclude very short or pure-number matches
      if (merchant.length > 2 && !RegExp(r'^\d+$').hasMatch(merchant)) {
        parts.add(merchant);
      }
    }

    if (parts.isEmpty) {
      // Fall back to sender ID as context
      parts.add('Via $sender');
    }

    return parts.join(' · ');
  }

  // ── Category inference ────────────────────────────────────────────────────

  /// Infer a likely expense category from message body and sender ID.
  ///
  /// Returns a category name string (matching the built-in expense category
  /// names) or `null` if no strong match is found.
  static String? inferCategory(String body, String sender) {
    final lower = body.toLowerCase();
    final senderLower = sender.toLowerCase();

    if (_containsAny(lower, const <String>[
      'swiggy', 'zomato', 'dunzo', 'blinkit', 'restaurant', 'cafe',
      'food', 'dine', 'hotel', 'domino', 'pizza', 'biryani',
    ])) {
      return 'Food & Dining';
    }

    if (_containsAny(lower, const <String>[
      'ola', 'uber', 'rapido', 'redbus', 'irctc', 'petrol', 'fuel',
      'diesel', 'metro', 'auto', 'cab', 'bus ticket', 'train',
    ])) {
      return 'Transport';
    }

    if (_containsAny(lower, const <String>[
      'amazon', 'flipkart', 'myntra', 'ajio', 'meesho', 'nykaa',
      'shopping', 'mall', 'retail',
    ])) {
      return 'Shopping';
    }

    // Combine message body + sender once to check both with a single pass.
    final combined = lower + senderLower;
    if (_containsAny(combined, const <String>[
      'electricity', 'water bill', 'gas bill', 'broadband', 'wifi',
      'jio', 'airtel', 'vodafone',
      'vi ', // trailing space avoids false-positive on words containing 'vi'
      'bsnl', 'recharge', 'dth',
      'tata sky', 'dish tv', 'bill pay', 'bill payment',
    ])) {
      return 'Bills & Utilities';
    }

    if (_containsAny(lower, const <String>[
      'pharmacy', 'medical', 'hospital', 'clinic', 'doctor', 'apollo',
      'medplus', 'netmeds', 'pharmeasy', 'health', 'medicine',
    ])) {
      return 'Healthcare';
    }

    if (_containsAny(lower, const <String>[
      'netflix', 'hotstar', 'prime video', 'amazon prime', 'spotify',
      'youtube', 'game', 'movie', 'theatre', 'multiplex', 'pvr', 'inox',
    ])) {
      return 'Entertainment';
    }

    if (_containsAny(lower, const <String>[
      'school', 'college', 'university', 'tuition', 'coaching',
      'education', 'course', 'udemy', 'coursera',
    ])) {
      return 'Education';
    }

    if (_containsAny(lower, const <String>[
      'salary', 'payroll', 'stipend', 'wages',
    ])) {
      return 'Salary';
    }

    return null;
  }

  static bool _containsAny(String text, List<String> keywords) =>
      keywords.any(text.contains);

  // ── Confidence scoring ────────────────────────────────────────────────────

  static double _computeConfidence({
    required String body,
    required double amount,
    required TransactionType type,
    required DateTime timestamp,
    required DateTime receivedAt,
  }) {
    double score = 0.0;

    // Amount found with explicit currency symbol
    if (_kCurrencyPattern.hasMatch(body)) score += 0.4;

    // Explicit debit/credit keyword
    final hasExplicitCredit = _kCreditKeywords.any(body.contains);
    final hasExplicitDebit = _kDebitKeywords.any(body.contains);
    if (hasExplicitCredit || hasExplicitDebit) score += 0.3;

    // Date/time found in message
    if (_kDatePattern.hasMatch(body)) score += 0.15;
    if (_kTimePattern.hasMatch(body)) score += 0.05;

    // UTR, Ref ID, or UPI ID found — strong signal of a real bank transaction
    if (_kUtrPattern.hasMatch(body) ||
        _kRefPattern.hasMatch(body) ||
        _kUpiPattern.hasMatch(body)) {
      score += 0.1;
    }

    return score.clamp(0.0, 1.0);
  }

  // ── Stable ID ─────────────────────────────────────────────────────────────

  static String _stableId(
    String sender,
    String body,
    DateTime receivedAt,
  ) {
    final raw = '$sender|$body|${receivedAt.millisecondsSinceEpoch}';
    final digest = sha256.convert(utf8.encode(raw));
    return digest.toString().substring(0, 16);
  }
}
