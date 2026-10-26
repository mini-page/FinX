import 'dart:async';

import 'package:flutter/services.dart';

/// Bridges the native Android SMS BroadcastReceiver to the Dart layer.
///
/// The Android side sends messages over the method channel
/// `app.expensio/sms_receiver` using the method `onSmsReceived`
/// with a map payload `{sender: String, body: String, timestamp: int}`.
///
/// Call [initialize] once from [main] (after [HiveBootstrap]).  Callers
/// subscribe to the [messages] stream to receive incoming SMS events.
class SmsBroadcastService {
  SmsBroadcastService._();

  static const MethodChannel _channel =
      MethodChannel('app.expensio/sms_receiver');

  static final StreamController<SmsMessage> _controller =
      StreamController<SmsMessage>.broadcast();

  /// Stream of transactional SMS messages received from the native layer.
  static Stream<SmsMessage> get messages => _controller.stream;

  static bool _initialized = false;

  /// Wire up the MethodChannel handler.  Safe to call multiple times.
  static void initialize() {
    if (_initialized) return;
    _initialized = true;

    _channel.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'onSmsReceived') {
        final map = Map<String, dynamic>.from(call.arguments as Map);
        final sender = (map['sender'] as String?) ?? '';
        final body = (map['body'] as String?) ?? '';
        final tsMillis = (map['timestamp'] as int?) ?? 0;
        final ts = tsMillis > 0
            ? DateTime.fromMillisecondsSinceEpoch(tsMillis)
            : DateTime.now();
        _controller.add(SmsMessage(
          sender: sender,
          body: body,
          timestamp: ts,
        ));
      }
    });
  }
}

/// Lightweight value object representing a received SMS.
class SmsMessage {
  const SmsMessage({
    required this.sender,
    required this.body,
    required this.timestamp,
  });

  final String sender;
  final String body;
  final DateTime timestamp;
}
