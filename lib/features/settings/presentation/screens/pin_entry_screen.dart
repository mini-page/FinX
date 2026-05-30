import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/biometric_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../provider/preferences_providers.dart';
import 'package:xpens/features/expense/presentation/screens/app_shell.dart';

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

class _PinEntryScreenState extends ConsumerState<PinEntryScreen> {
  // Phases:
  // 'verify'   – change-PIN flow: verify current PIN first
  // 'enter'    – normal unlock or first entry in setup
  // 'confirm'  – setup flow: re-enter the new PIN to confirm
  String _phase = 'enter';
  String _entered = '';
  String _firstEntry = ''; // stored during setup confirm phase
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _phase = widget.isChange ? 'verify' : 'enter';
    if (widget.tryBiometricFirst && !widget.isSetup && !widget.isChange) {
      // Attempt biometric authentication automatically after the first frame.
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
    }
  }

  Future<void> _tryBiometric() async {
    final ok = await BiometricService.authenticate();
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const AppShell()),
      );
    }
  }

  String get _title {
    if (_phase == 'verify') return 'Enter Current PIN';
    if (_phase == 'confirm') return 'Confirm New PIN';
    if (widget.isSetup) return 'Create PIN';
    return 'Enter PIN';
  }

  String get _subtitle {
    if (_phase == 'verify') return 'Verify your existing 4-digit PIN';
    if (_phase == 'confirm') return 'Re-enter your new PIN to confirm';
    if (widget.isSetup) return 'Choose a 4-digit PIN to secure the app';
    return 'Enter your 4-digit PIN to unlock XPens';
  }

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
        HapticFeedback.heavyImpact();
        setState(() {
          _entered = '';
          _errorMessage = 'Incorrect PIN. Try again.';
        });
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
        HapticFeedback.heavyImpact();
        setState(() {
          _entered = '';
          _firstEntry = '';
          _phase = 'enter';
          _errorMessage = 'PINs did not match. Try again.';
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
        HapticFeedback.heavyImpact();
        setState(() {
          _entered = '';
          _errorMessage = 'Incorrect PIN. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Lock icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    color: AppColors.primaryBlue,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 36),
                // PIN dot display
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    final filled = index < _entered.length;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: filled
                            ? AppColors.primaryBlue
                            : AppColors.surfaceAccent,
                        border: Border.all(
                          color: filled
                              ? AppColors.primaryBlue
                              : AppColors.textMuted,
                          width: 2,
                        ),
                      ),
                    );
                  }),
                ),
                if (_errorMessage.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage,
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 40),
                // Numpad
                _NumPad(onDigit: _onDigit, onBackspace: _onBackspace),
                if (!widget.isSetup) ...[
                  const SizedBox(height: 24),
                  if (widget.tryBiometricFirst)
                    TextButton.icon(
                      onPressed: _tryBiometric,
                      icon: const Icon(
                        Icons.fingerprint_rounded,
                        color: AppColors.primaryBlue,
                      ),
                      label: const Text(
                        'Use Biometric',
                        style: TextStyle(
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NumPad extends StatelessWidget {
  const _NumPad({required this.onDigit, required this.onBackspace});

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
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((label) {
              if (label.isEmpty) {
                return const SizedBox(width: 90);
              }
              if (label == '<') {
                return _PadButton(
                  onTap: onBackspace,
                  child: const Icon(
                    Icons.backspace_outlined,
                    color: AppColors.textDark,
                    size: 22,
                  ),
                );
              }
              return _PadButton(
                onTap: () => onDigit(label),
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark,
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

class _PadButton extends StatelessWidget {
  const _PadButton({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 80,
        margin: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}
