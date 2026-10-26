import 'package:flutter/services.dart';

/// Controls whether the Android [SmsReceiverPlugin] is actively monitoring
/// incoming SMS messages.
///
/// The Flutter side calls [start] / [stop] which notify the native layer via
/// the shared widget [MethodChannel] so that the receiver is registered /
/// unregistered in [MainActivity].
abstract final class SmsMonitoringService {
  static const MethodChannel _channel =
      MethodChannel('app.expensio/widget');

  /// Start monitoring incoming SMS (registers Android BroadcastReceiver).
  static Future<void> start() async {
    try {
      await _channel.invokeMethod<void>('startSmsMonitoring');
    } on PlatformException {
      // Non-fatal — feature may not be supported on this build.
    }
  }

  /// Stop monitoring incoming SMS (unregisters Android BroadcastReceiver).
  static Future<void> stop() async {
    try {
      await _channel.invokeMethod<void>('stopSmsMonitoring');
    } on PlatformException {
      // Non-fatal
    }
  }
}
