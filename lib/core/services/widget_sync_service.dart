import 'dart:convert';
import 'dart:developer' as dev;

import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

/// Holds the pre-computed payload that is written to the home_widget
/// SharedPreferences store whenever accounts, transactions, or currency
/// settings change.
///
/// Used with [ref.listen] in [AppShell] to trigger [WidgetSyncService.syncData].
class WidgetDataPayload {
  const WidgetDataPayload({
    required this.totalBalance,
    required this.currencySymbol,
    required this.transactions,
  });

  final double totalBalance;
  final String currencySymbol;
  final List<Map<String, dynamic>> transactions;
}

// ── home_widget bridge ─────────────────────────────────────────────────────

/// Service that communicates with the native Android widget layer via
/// [home_widget].  All calls are best-effort: failures are silently
/// swallowed so a widget-sync error never crashes the app.
class WidgetSyncService {
  static const _qaWidgetName = 'QuickActionWidget';
  static const _rtWidgetName = 'RecentTransactionsWidget';
  static const _packageName = 'app.xpens.finance';

  // ── Outbound (Flutter → Android) ──────────────────────────────────

  /// Write the latest balance, transactions, and currency symbol to the
  /// home_widget SharedPreferences store, then trigger a widget refresh.
  static Future<void> syncData(WidgetDataPayload payload) async {
    try {
      await Future.wait([
        HomeWidget.saveWidgetData<double>(
          'total_balance',
          payload.totalBalance,
        ),
        HomeWidget.saveWidgetData<String>(
          'currency_symbol',
          payload.currencySymbol,
        ),
        HomeWidget.saveWidgetData<String>(
          'transactions',
          jsonEncode(payload.transactions),
        ),
        HomeWidget.saveWidgetData<int>(
          'last_synced',
          DateTime.now().millisecondsSinceEpoch,
        ),
      ]);
      // Trigger a redraw of both widget types.
      await Future.wait([
        HomeWidget.updateWidget(
          qualifiedAndroidName: '$_packageName.$_qaWidgetName',
        ),
        HomeWidget.updateWidget(
          qualifiedAndroidName: '$_packageName.$_rtWidgetName',
        ),
      ]);
    } catch (e, st) {
      assert(() {
        dev.log('WidgetSyncService.syncData failed: $e', stackTrace: st);
        return true;
      }());
    }
  }

  // ── Voice input ────────────────────────────────────────────────────

  /// Launches the Android system speech recogniser and returns the first
  /// recognised string, or `null` if cancelled / unavailable.
  static Future<String?> startVoiceInput() async {
    try {
      const channel = MethodChannel('app.expensio/widget');
      return await channel.invokeMethod<String>('startVoiceInput');
    } catch (e, st) {
      assert(() {
        dev.log('WidgetSyncService.startVoiceInput failed: $e', stackTrace: st);
        return true;
      }());
      return null;
    }
  }
}
