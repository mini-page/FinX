import 'package:flutter_test/flutter_test.dart';
import 'package:expensio/features/expense/data/models/expense_model.dart';
import 'package:expensio/features/sms_parser/domain/sms_parser_engine.dart';

void main() {
  final now = DateTime(2026, 4, 18, 14, 30);

  // ── Sender filter ───────────────────────────────────────────────────────────

  group('isTransactionalSender', () {
    test('returns true for sender ending with T', () {
      expect(SmsParserEngine.isTransactionalSender('VK-HDFCBANKT'), isTrue);
      expect(SmsParserEngine.isTransactionalSender('AD-SBIMSGТ'), isTrue);
    });

    test('returns true for sender containing BANK / PAY / ALERT', () {
      expect(
          SmsParserEngine.isTransactionalSender('AM-ICICIBANKNOTIFY'), isTrue);
      expect(SmsParserEngine.isTransactionalSender('BZ-PAYALERT'), isTrue);
      expect(SmsParserEngine.isTransactionalSender('VD-UPIALERTS'), isTrue);
    });

    test('returns false for regular contact numbers', () {
      expect(SmsParserEngine.isTransactionalSender('+919876543210'), isFalse);
      expect(SmsParserEngine.isTransactionalSender('Mom'), isFalse);
    });
  });

  // ── Message filter ──────────────────────────────────────────────────────────

  group('isTransactionalMessage', () {
    test('returns true for messages with ₹ amount', () {
      expect(
        SmsParserEngine.isTransactionalMessage(
          'Your account debited by ₹500 on 18-04-2026.',
        ),
        isTrue,
      );
    });

    test('returns true for messages with Rs amount', () {
      expect(
        SmsParserEngine.isTransactionalMessage('Rs.1000 credited to your a/c.'),
        isTrue,
      );
    });

    test('returns false for OTP messages', () {
      expect(
        SmsParserEngine.isTransactionalMessage(
          'Your OTP is 123456. Do not share.',
        ),
        isFalse,
      );
    });
  });

  // ── Amount extraction ───────────────────────────────────────────────────────

  group('parse – amount extraction', () {
    test('extracts ₹ amount', () {
      final tx = SmsParserEngine.parse(
        senderAddress: 'VK-HDFCBANKT',
        body: 'INR 2,500.00 debited from a/c XX1234 on 18-04-2026.',
        receivedAt: now,
      );
      expect(tx, isNotNull);
      expect(tx!.amount, equals(2500.00));
    });

    test('extracts Rs. amount', () {
      final tx = SmsParserEngine.parse(
        senderAddress: 'VK-HDFCBANKT',
        body: 'Rs.1500 credited to your account.',
        receivedAt: now,
      );
      expect(tx, isNotNull);
      expect(tx!.amount, equals(1500.0));
    });

    test('returns null when no amount present', () {
      final tx = SmsParserEngine.parse(
        senderAddress: 'VK-HDFCBANKT',
        body: 'Your account has been updated.',
        receivedAt: now,
      );
      expect(tx, isNull);
    });
  });

  // ── Type detection ──────────────────────────────────────────────────────────

  group('parse – transaction type', () {
    test('detects income from "credited"', () {
      final tx = SmsParserEngine.parse(
        senderAddress: 'VK-HDFCBANKT',
        body: '₹5000 credited to your a/c XX1234.',
        receivedAt: now,
      );
      expect(tx!.type, equals(TransactionType.income));
    });

    test('detects expense from "debited"', () {
      final tx = SmsParserEngine.parse(
        senderAddress: 'VK-HDFCBANKT',
        body: '₹999 debited from a/c XX1234.',
        receivedAt: now,
      );
      expect(tx!.type, equals(TransactionType.expense));
    });

    test('detects expense from "paid"', () {
      final tx = SmsParserEngine.parse(
        senderAddress: 'VK-PAYALERT',
        body: 'You paid Rs.250 to Swiggy via UPI. Ref 9876543210.',
        receivedAt: now,
      );
      expect(tx!.type, equals(TransactionType.expense));
    });

    test('detects income from "received"', () {
      final tx = SmsParserEngine.parse(
        senderAddress: 'VK-SBIBANKТ',
        body: 'You have received Rs.10000 from JOHN DOE.',
        receivedAt: now,
      );
      expect(tx!.type, equals(TransactionType.income));
    });
  });

  // ── Date extraction ─────────────────────────────────────────────────────────

  group('parse – date extraction', () {
    test('extracts dd-mm-yyyy date', () {
      final tx = SmsParserEngine.parse(
        senderAddress: 'VK-HDFCBANKT',
        body: '₹500 debited on 15-04-2026 at 10:22 AM.',
        receivedAt: now,
      );
      expect(tx!.timestamp.day, equals(15));
      expect(tx.timestamp.month, equals(4));
      expect(tx.timestamp.year, equals(2026));
    });

    test('extracts time correctly', () {
      final tx = SmsParserEngine.parse(
        senderAddress: 'VK-HDFCBANKT',
        body: '₹750 debited on 18-04-2026 at 02:45 PM.',
        receivedAt: now,
      );
      expect(tx!.timestamp.hour, equals(14));
      expect(tx.timestamp.minute, equals(45));
    });

    test('falls back to receivedAt when no date in body', () {
      final tx = SmsParserEngine.parse(
        senderAddress: 'VK-HDFCBANKT',
        body: '₹200 debited from a/c XX1234.',
        receivedAt: now,
      );
      expect(tx!.timestamp, equals(now));
    });
  });

  // ── Notes extraction ────────────────────────────────────────────────────────

  group('parse – notes', () {
    test('extracts Ref ID', () {
      final tx = SmsParserEngine.parse(
        senderAddress: 'VK-HDFCBANKT',
        body: '₹500 paid. Ref No: TXN20264567891.',
        receivedAt: now,
      );
      expect(tx!.notes, contains('Ref:'));
    });

    test('extracts UPI ID', () {
      final tx = SmsParserEngine.parse(
        senderAddress: 'VK-PAYALERT',
        body: '₹100 paid via UPI ID: customer@okaxis.',
        receivedAt: now,
      );
      expect(tx!.notes, contains('UPI:'));
    });
  });

  // ── Confidence ──────────────────────────────────────────────────────────────

  group('parse – confidence', () {
    test('full message yields confidence >= kMinConfidence', () {
      final tx = SmsParserEngine.parse(
        senderAddress: 'VK-HDFCBANKT',
        body:
            '₹1,200 debited from a/c XX9876 on 18-04-2026 at 3:00 PM. Ref 1234567890.',
        receivedAt: now,
      );
      expect(
          tx!.confidence, greaterThanOrEqualTo(SmsParserEngine.kMinConfidence));
    });

    test('bare amount only yields lower confidence', () {
      // No explicit currency symbol, just a debit keyword
      final tx = SmsParserEngine.parse(
        senderAddress: 'VK-HDFCBANKT',
        body: 'INR 50 debited.',
        receivedAt: now,
      );
      expect(tx, isNotNull);
      expect(tx!.confidence, lessThan(1.0));
    });
  });

  // ── Deduplication ───────────────────────────────────────────────────────────

  group('parse – stable ID', () {
    test('same inputs produce same ID', () {
      final tx1 = SmsParserEngine.parse(
        senderAddress: 'VK-HDFCBANKT',
        body: '₹500 debited.',
        receivedAt: now,
      );
      final tx2 = SmsParserEngine.parse(
        senderAddress: 'VK-HDFCBANKT',
        body: '₹500 debited.',
        receivedAt: now,
      );
      expect(tx1!.id, equals(tx2!.id));
    });

    test('different body produces different ID', () {
      final tx1 = SmsParserEngine.parse(
        senderAddress: 'VK-HDFCBANKT',
        body: '₹500 debited.',
        receivedAt: now,
      );
      final tx2 = SmsParserEngine.parse(
        senderAddress: 'VK-HDFCBANKT',
        body: '₹600 debited.',
        receivedAt: now,
      );
      expect(tx1!.id, isNot(equals(tx2!.id)));
    });
  });
}
