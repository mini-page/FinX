import 'package:local_auth/local_auth.dart';

/// Thin wrapper around [LocalAuthentication] so the rest of the app
/// never imports `local_auth` directly and tests can swap the service.
class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Returns `true` if the device supports *any* biometric and has at least
  /// one enrolled (fingerprint, face-id, iris, …).
  static Future<bool> isAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) return false;
      final enrolled = await _auth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Prompts the user for biometric authentication.
  ///
  /// Returns `true` if the user was successfully authenticated.
  /// Returns `false` on failure, cancellation, or if biometrics are
  /// unavailable.
  static Future<bool> authenticate({
    String reason = 'Verify your identity to unlock Expensio',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false, // allow PIN/pattern fallback
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
