import 'package:flutter/services.dart';

import 'sms_broadcast_service.dart';

/// Reads incoming/historical SMS messages from the device's SMS Inbox
/// via the native Android MethodChannel.
abstract final class SmsInboxService {
  static const MethodChannel _channel = MethodChannel('app.expensio/widget');

  /// Fetches recent SMS messages from device inbox (Android only).
  ///
  /// Returns a list of [SmsMessage] ordered from newest to oldest.
  static Future<List<SmsMessage>> getRecentSms({int limit = 100}) async {
    try {
      final res = await _channel.invokeListMethod<dynamic>(
        'getInboxSms',
        <String, dynamic>{'limit': limit},
      );
      if (res == null) return const <SmsMessage>[];

      final list = <SmsMessage>[];
      for (final raw in res) {
        if (raw is Map) {
          final sender = (raw['sender'] as String?) ?? '';
          final body = (raw['body'] as String?) ?? '';
          final tsMillis = (raw['timestamp'] as int?) ?? 0;
          final ts = tsMillis > 0
              ? DateTime.fromMillisecondsSinceEpoch(tsMillis)
              : DateTime.now();
          list.add(SmsMessage(
            sender: sender,
            body: body,
            timestamp: ts,
          ));
        }
      }
      return list;
    } catch (_) {
      return const <SmsMessage>[];
    }
  }
}
