import 'package:flutter/material.dart';

import '../features/expense/data/models/expense_model.dart';
import '../features/expense/presentation/screens/add_expense_screen.dart';
import '../features/expense/presentation/screens/notifications_screen.dart';
import '../features/expense/presentation/screens/records_history_screen.dart';
import '../features/expense/presentation/screens/unified_scanner_screen.dart';
import 'package:xpens/features/settings/presentation/screens/settings_screen.dart';
import '../features/expense/presentation/screens/upi_scanner_screen.dart';
import '../features/expense/presentation/screens/calendar_view_screen.dart';

/// Centralised navigation helpers for XPens.
///
/// All `Navigator.push` / `pushReplacement` calls for named screens are
/// routed through this class so that screen locations and constructor
/// signatures are maintained in a single place.
abstract final class AppRoutes {
  // ── Add / Edit Expense ─────────────────────────────────────────────────────

  /// Push [AddExpenseScreen] to create a new transaction.
  static Future<void> pushAddExpense(
    BuildContext context, {
    String? initialCategory,
    double? initialAmount,
    DateTime? initialDate,
    String? initialNote,
    String? initialAccountId,
    String? initialToAccountId,
    TransactionType initialType = TransactionType.expense,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AddExpenseScreen(
          initialCategory: initialCategory,
          initialAmount: initialAmount,
          initialDate: initialDate,
          initialNote: initialNote,
          initialAccountId: initialAccountId,
          initialToAccountId: initialToAccountId,
          initialType: initialType,
        ),
      ),
    );
  }

  /// Push [AddExpenseScreen] to edit an existing transaction.
  static Future<void> pushEditExpense(
    BuildContext context, {
    required String expenseId,
    required double initialAmount,
    required String initialCategory,
    required DateTime initialDate,
    required String initialNote,
    String? initialAccountId,
    String? initialToAccountId,
    TransactionType initialType = TransactionType.expense,
    String? initialSubcategory,
    double? initialLatitude,
    double? initialLongitude,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AddExpenseScreen(
          expenseId: expenseId,
          initialAmount: initialAmount,
          initialCategory: initialCategory,
          initialDate: initialDate,
          initialNote: initialNote,
          initialAccountId: initialAccountId,
          initialToAccountId: initialToAccountId,
          initialType: initialType,
          initialSubcategory: initialSubcategory,
          initialLatitude: initialLatitude,
          initialLongitude: initialLongitude,
        ),
      ),
    );
  }

  // ── Calendar View ──────────────────────────────────────────────────────────

  /// Push the calendar and timeline view screen.
  static Future<void> pushCalendarView(BuildContext context, {DateTime? initialDate}) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => CalendarViewScreen(initialDate: initialDate)),
    );
  }

  // ── Records History ────────────────────────────────────────────────────────

  /// Push the transaction history screen.
  static Future<void> pushRecordsHistory(BuildContext context) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const RecordsHistoryScreen()),
    );
  }

  /// Push the records / search screen in search mode.
  ///
  /// The search bar is automatically focused and the keyboard opens.
  static Future<void> pushTransactionSearch(BuildContext context) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const RecordsHistoryScreen(autoFocusSearch: true),
      ),
    );
  }

  // ── Settings ───────────────────────────────────────────────────────────────

  /// Push the settings screen.
  static Future<void> pushSettings(BuildContext context) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );
  }

  // ── Notifications ──────────────────────────────────────────────────────────

  /// Push the notifications screen.
  static Future<void> pushNotifications(BuildContext context) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const NotificationsScreen(),
      ),
    );
  }

  // ── UPI Scanner (Pay via UPI) ──────────────────────────────────────────────

  /// Push the UPI QR scanner for the "Pay via UPI" flow.
  static Future<void> pushUpiScanner(BuildContext context) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const UpiScannerScreen()),
    );
  }

  /// Replace the current route with [AddExpenseScreen] in pay-mode.
  ///
  /// Used by [UpiScannerScreen] after a successful scan.  The screen shows an
  /// "Open UPI App" button that hands the user off to their preferred payment
  /// app with only the payee VPA — no pre-filled amount that could trigger
  /// fraud detection in GPay / PhonePe / Paytm.
  static void replaceWithPayExpense(
    BuildContext context, {
    required String payUpiUri,
    double? initialAmount,
    String? initialNote,
  }) {
    Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute<void>(
        builder: (_) => AddExpenseScreen(
          payUpiUri: payUpiUri,
          initialAmount: initialAmount,
          initialNote: initialNote,
        ),
      ),
    );
  }

  // ── Unified Scanner ────────────────────────────────────────────────────────

  /// Push the unified scanner screen (Bill Scan + AI Scan tabs).
  ///
  /// This is the primary entry point for the Scan & Log pill.
  static Future<Map<String, dynamic>?> pushUnifiedScanner(
    BuildContext context, {
    int initialTab = 0,
    bool returnResult = false,
  }) {
    return Navigator.of(context).push<Map<String, dynamic>?>(
      MaterialPageRoute<Map<String, dynamic>?>(
        builder: (_) => UnifiedScannerScreen(
          initialTab: initialTab,
          returnResult: returnResult,
        ),
      ),
    );
  }



  // ── Scanner (legacy alias) ─────────────────────────────────────────────────

  /// Push the QR / barcode scanner screen.
  ///
  /// Kept for backward compatibility (e.g. home-widget `scanner` action).
  /// New code should use [pushUnifiedScanner].
  static Future<void> pushScanner(BuildContext context) {
    return pushUnifiedScanner(context);
  }

  /// Replace the current route with [AddExpenseScreen].
  ///
  /// Used by scanner screens after a successful scan so that the user returns
  /// directly to the expense form rather than back to the scanner.
  static void replaceWithAddExpense(
    BuildContext context, {
    double? initialAmount,
    String? initialNote,
    String? initialCategory,
  }) {
    Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute<void>(
        builder: (_) => AddExpenseScreen(
          initialAmount: initialAmount,
          initialNote: initialNote,
          initialCategory: initialCategory,
        ),
      ),
    );
  }
}
