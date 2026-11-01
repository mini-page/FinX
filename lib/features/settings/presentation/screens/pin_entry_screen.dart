import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/biometric_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../provider/preferences_providers.dart';
import 'package:expensio/features/expense/presentation/screens/app_shell.dart';

/// SHA-256 hash of the raw PIN string.
String hashPin(String pin) {
  final bytes = utf8.encode(pin);
  return sha256.convert(bytes).toString();
}

/// Full-screen 4-digit PIN pad.
///
/// [isSetup] = `true`  → asks user to set a new PIN (confirm step included).
/// [isSetup] = `false` → asks user to enter existing PIN to unlock the app.
/// [isChange] = `true` → first asks for current PIN, then new PIN + confirm.
/// [tryBiometricFirst] = `true` → attempt biometric auth automatically on open.
class PinEntryScreen extends ConsumerStatefulWidget {
  const PinEntryScreen({
    super.key,
    required this.isSetup,
    this.isChange = false,
    this.tryBiometricFirst = false,
  });

  final bool isSetup;
  final bool isChange;
  final bool tryBiometricFirst;

  @override
  ConsumerState<PinEntryScreen> createState() => _PinEntryScreenState();
}

class _PinEntryScreenState extends ConsumerState<PinEntryScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // ── Phase state ────────────────────────────────────────────────────────────
  // 'verify'   – change-PIN flow: verify current PIN first
  // 'enter'    – normal unlock or first entry in setup
  // 'confirm'  – setup flow: re-enter the new PIN to confirm
  String _phase = 'enter';
  String _entered = '';
  String _firstEntry = ''; // stored during setup confirm phase
  String _errorMessage = '';
  bool _isAuthenticating = false;
  bool _biometricFailedOnce = false;
  AppLifecycleState _lastLifecycleState = AppLifecycleState.resumed;

  // ── Animation controllers ──────────────────────────────────────────────────
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Shake animation: quick horizontal oscillation on error
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    _phase = widget.isChange ? 'verify' : 'enter';

    if (widget.tryBiometricFirst && !widget.isSetup && !widget.isChange) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shakeController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-prompt biometric when app returns from background.
    if (_lastLifecycleState == AppLifecycleState.paused &&
        state == AppLifecycleState.resumed &&
        widget.tryBiometricFirst &&
        !widget.isSetup &&
        !widget.isChange &&
        !_isAuthenticating) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
    }
    _lastLifecycleState = state;
  }

  // ── Biometric ──────────────────────────────────────────────────────────────
  Future<void> _tryBiometric() async {
    if (_isAuthenticating) return;
    setState(() => _isAuthenticating = true);

    final ok = await BiometricService.authenticate();
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const AppShell()),
      );
    } else {
      setState(() {
        _isAuthenticating = false;
        _biometricFailedOnce = true;
        _errorMessage = 'Biometric failed. Enter your PIN to unlock.';
      });
    }
  }

  // ── Labels ─────────────────────────────────────────────────────────────────
  String get _title {
    if (_phase == 'verify') return 'Enter Current PIN';
    if (_phase == 'confirm') return 'Confirm New PIN';
    if (widget.isSetup) return 'Create PIN';
    return 'Enter PIN';
  }

  String get _subtitle {
    if (_isAuthenticating) return 'Checking biometric…';
    if (_phase == 'verify') return 'Verify your existing 4-digit PIN';
    if (_phase == 'confirm') return 'Re-enter your new PIN to confirm';
    if (widget.isSetup) return 'Choose a 4-digit PIN to secure the app';
    return 'Enter your 4-digit PIN to unlock Expensio';
  }

  // ── Input handlers ─────────────────────────────────────────────────────────
  void _onDigit(String digit) {
    if (_entered.length >= 4) return;
    setState(() {
      _entered += digit;
      _errorMessage = '';
    });
    if (_entered.length == 4) {
      _handleComplete();
    }
  }

  void _onBackspace() {
    if (_entered.isEmpty) return;
    setState(() {
      _entered = _entered.substring(0, _entered.length - 1);
      _errorMessage = '';
    });
  }

  // ── Core business logic (unchanged) ───────────────────────────────────────
  Future<void> _handleComplete() async {
    final controller = ref.read(appPreferencesControllerProvider);
    final prefs = ref.read(appPreferencesProvider).value;

    if (_phase == 'verify') {
      // Verify current PIN
      if (hashPin(_entered) == (prefs?.pinHash ?? '')) {
        setState(() {
          _phase = 'enter';
          _entered = '';
          _errorMessage = '';
        });
      } else {
        await _triggerError('Incorrect PIN. Try again.');
      }
      return;
    }

    if (widget.isSetup || widget.isChange) {
      if (_phase == 'enter') {
        // Move to confirm step
        setState(() {
          _firstEntry = _entered;
          _phase = 'confirm';
          _entered = '';
        });
        return;
      }
      // Confirm step
      if (_entered == _firstEntry) {
        await controller.setPin(hashPin(_entered));
        if (!mounted) return;
        Navigator.of(context).pop(true);
      } else {
        await _triggerError('PINs did not match. Try again.', () {
          _firstEntry = '';
          _phase = 'enter';
        });
      }
    } else {
      // Unlock flow
      if (hashPin(_entered) == (prefs?.pinHash ?? '')) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const AppShell()),
        );
      } else {
        await _triggerError('Incorrect PIN. Try again.');
      }
    }
  }

  /// Triggers haptic + shake animation and sets the error message.
  /// Optionally runs [extraReset] inside the setState after shake.
  Future<void> _triggerError(String message, [VoidCallback? extraReset]) async {
    HapticFeedback.heavyImpact();
    setState(() {
      _errorMessage = message;
    });
    await _shakeController.forward(from: 0);
    if (!mounted) return;
    setState(() {
      _entered = '';
      if (extraReset != null) extraReset();
    });
    _shakeController.reset();
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      // Remove default bg so our gradient fills everything
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        // Pixel lock-screen soft blue-grey gradient
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFDDE4EF),
              Color(0xFFF0F4FA),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: 32,
              vertical: size.height * 0.04,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Logo / branding area ─────────────────────────────────
                _GlassLogoCircle(),
                SizedBox(height: size.height * 0.035),

                // ── Title ────────────────────────────────────────────────
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    _title,
                    key: ValueKey(_title),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    _subtitle,
                    key: ValueKey(_subtitle),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ),
                SizedBox(height: size.height * 0.045),

                // ── PIN dot indicators ───────────────────────────────────
                _ShakingPinDots(
                  enteredLength: _entered.length,
                  shakeAnimation: _shakeAnimation,
                  hasError: _errorMessage.isNotEmpty,
                ),

                // ── Error message ────────────────────────────────────────
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  child: _errorMessage.isNotEmpty
                      ? Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: AppColors.danger,
                                size: 14,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _errorMessage,
                                style: const TextStyle(
                                  color: AppColors.danger,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox(height: 0),
                ),

                SizedBox(height: size.height * 0.05),

                // ── Number pad ───────────────────────────────────────────
                _PixelNumPad(
                  onDigit: _onDigit,
                  onBackspace: _onBackspace,
                ),

                // ── Biometric button ─────────────────────────────────────
                if (!widget.isSetup && widget.tryBiometricFirst) ...[
                  const SizedBox(height: 28),
                  _GlassBiometricButton(
                    onTap: _isAuthenticating ? null : _tryBiometric,
                    isLoading: _isAuthenticating,
                    hasError: _biometricFailedOnce,
                  ),
                ],

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Sub-widgets
// ════════════════════════════════════════════════════════════════════════════

/// Blurred glass circle with a shield/lock icon — app branding area.
class _GlassLogoCircle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Frosted glass look via layered whites + border
        color: Colors.white.withValues(alpha: 0.55),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.75),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.12),
            blurRadius: 24,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.7),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primaryBlue.withValues(alpha: 0.9),
              const Color(0xFF0854C7),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryBlue.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.shield_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}

/// 4 PIN dots with shake animation on error and gradient fill when entered.
class _ShakingPinDots extends StatelessWidget {
  const _ShakingPinDots({
    required this.enteredLength,
    required this.shakeAnimation,
    required this.hasError,
  });

  final int enteredLength;
  final Animation<double> shakeAnimation;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: shakeAnimation,
      builder: (context, child) {
        // Horizontal shake: oscillate ±10px using a sine wave
        final dx = math.sin(shakeAnimation.value * math.pi * 6) * 10.0;
        return Transform.translate(
          offset: Offset(dx, 0),
          child: child,
        );
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(4, (index) {
          final filled = index < enteredLength;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutBack,
            margin: const EdgeInsets.symmetric(horizontal: 11),
            width: filled ? 22 : 20,
            height: filled ? 22 : 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: filled
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primaryBlue,
                        Color(0xFF0854C7),
                      ],
                    )
                  : null,
              color: filled ? null : Colors.white.withValues(alpha: 0.5),
              border: Border.all(
                color: filled
                    ? AppColors.primaryBlue
                    : hasError
                        ? AppColors.danger.withValues(alpha: 0.7)
                        : AppColors.textMuted.withValues(alpha: 0.5),
                width: filled ? 0 : 2,
              ),
              boxShadow: filled
                  ? [
                      BoxShadow(
                        color: AppColors.primaryBlue.withValues(alpha: 0.4),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          );
        }),
      ),
    );
  }
}

/// Glassmorphic circular numpad matching Google Pixel lock screen aesthetic.
class _PixelNumPad extends StatelessWidget {
  const _PixelNumPad({
    required this.onDigit,
    required this.onBackspace,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  static const _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['', '0', '<'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _rows.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((label) {
              if (label.isEmpty) {
                // Empty slot in bottom-left
                return const SizedBox(width: 80, height: 80);
              }
              if (label == '<') {
                return _GlassPadButton(
                  onTap: onBackspace,
                  child: const Icon(
                    Icons.backspace_outlined,
                    color: AppColors.textDark,
                    size: 22,
                  ),
                );
              }
              return _GlassPadButton(
                onTap: () => onDigit(label),
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                    height: 1,
                  ),
                ),
              );
            }).toList(growable: false),
          ),
        );
      }).toList(growable: false),
    );
  }
}

/// A single frosted-glass circular numpad button with InkWell ripple.
class _GlassPadButton extends StatelessWidget {
  const _GlassPadButton({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Frosted/translucent glass fill
        color: Colors.white.withValues(alpha: 0.60),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.85),
          width: 1.5,
        ),
        boxShadow: [
          // Outer diffused glow
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 16,
            spreadRadius: 0,
            offset: const Offset(0, 5),
          ),
          // Inner highlight on top edge
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.60),
            blurRadius: 4,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      // Clip the ripple to the circle
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: AppColors.primaryBlue.withValues(alpha: 0.18),
          highlightColor: AppColors.primaryBlue.withValues(alpha: 0.08),
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// Glass pill button for biometric authentication.
class _GlassBiometricButton extends StatelessWidget {
  const _GlassBiometricButton({
    required this.onTap,
    this.isLoading = false,
    this.hasError = false,
  });

  final VoidCallback? onTap;
  final bool isLoading;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final borderColor = hasError
        ? AppColors.danger.withValues(alpha: 0.6)
        : Colors.white.withValues(alpha: 0.80);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        color: Colors.white.withValues(alpha: 0.55),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.6),
            blurRadius: 4,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(40),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: AppColors.primaryBlue.withValues(alpha: 0.15),
          highlightColor: AppColors.primaryBlue.withValues(alpha: 0.07),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                    Icon(
                      Icons.fingerprint_rounded,
                      color: hasError ? AppColors.danger : AppColors.primaryBlue,
                      size: 26,
                    ),
                const SizedBox(width: 10),
                Text(
                  isLoading
                      ? 'Authenticating…'
                      : hasError
                          ? 'Try Biometric Again'
                          : 'Use Biometric',
                  style: TextStyle(
                    color: hasError ? AppColors.danger : AppColors.primaryBlue,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
