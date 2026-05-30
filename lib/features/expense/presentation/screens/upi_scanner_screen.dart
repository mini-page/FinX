import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../routes/app_routes.dart';
import 'package:xpens/shared/widgets/app_page_header.dart';

/// A QR scanner specialised for the "Pay via UPI" flow.
///
/// Detects a UPI payment QR, extracts the payee VPA and merchant name, and
/// opens [AddExpenseScreen] in pay-mode.  The amount the user enters in
/// XPensa is shown as a hint; the user manually enters it in their UPI app
/// to avoid the fraud flags that externally pre-filled payment intents trigger.
class UpiScannerScreen extends StatefulWidget {
  const UpiScannerScreen({super.key});

  @override
  State<UpiScannerScreen> createState() => _UpiScannerScreenState();
}

class _UpiScannerScreenState extends State<UpiScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessed = false;
  bool _isPickingImage = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessed) return;
    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue != null) {
        _parseAndNavigate(rawValue);
        break;
      }
    }
  }

  void _parseAndNavigate(String rawValue) {
    if (!rawValue.startsWith('upi://pay')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not a UPI payment QR. Try again.')),
      );
      return;
    }

    final Uri uri;
    try {
      uri = Uri.parse(rawValue);
    } on FormatException {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read QR data. Try again.')),
      );
      return;
    }

    final pa = uri.queryParameters['pa'];
    if (pa == null || pa.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid QR: payee UPI ID is missing. Try again.'),
        ),
      );
      return;
    }

    setState(() => _isProcessed = true);

    final am = uri.queryParameters['am'];
    final pn = uri.queryParameters['pn'];
    final tn = uri.queryParameters['tn'];
    final amount = am != null ? double.tryParse(am) : null;
    // Prefer merchant name (pn) as pre-filled note, fall back to transaction note (tn).
    final note = pn?.isNotEmpty == true ? pn : tn;

    if (!mounted) return;

    AppRoutes.replaceWithPayExpense(
      context,
      payUpiUri: rawValue,
      initialAmount: amount,
      initialNote: note,
    );
  }

  Future<void> _pickImageAndScan() async {
    if (_isPickingImage || _isProcessed) return;
    setState(() => _isPickingImage = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (!mounted) return;

      final path = result?.files.singleOrNull?.path;
      if (path == null) {
        setState(() => _isPickingImage = false);
        return;
      }

      final capture = await _controller.analyzeImage(path);

      if (!mounted) return;

      if (capture == null || capture.barcodes.isEmpty) {
        setState(() => _isPickingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No QR code found in the image.')),
        );
        return;
      }

      _onDetect(capture);
    } catch (_) {
      if (mounted) {
        setState(() => _isPickingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read QR from image.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GradientAppBar(
        title: 'Pay via UPI',
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          // Hint pill + controls — stacked at the very bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Hint pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Scan merchant UPI QR to pay',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Flash toggle + image picker
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ValueListenableBuilder<MobileScannerState>(
                          valueListenable: _controller,
                          builder: (_, state, __) {
                            final torchOn = state.torchState == TorchState.on;
                            return _ScannerControlButton(
                              icon: torchOn
                                  ? Icons.flash_on_rounded
                                  : Icons.flash_off_rounded,
                              label: torchOn ? 'Flash On' : 'Flash Off',
                              highlighted: torchOn,
                              onTap: _controller.toggleTorch,
                            );
                          },
                        ),
                        const SizedBox(width: 32),
                        _ScannerControlButton(
                          icon: Icons.photo_library_outlined,
                          label: 'Gallery',
                          loading: _isPickingImage,
                          onTap: _pickImageAndScan,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared control button ─────────────────────────────────────────────────────

class _ScannerControlButton extends StatelessWidget {
  const _ScannerControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlighted = false,
    this.loading = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlighted;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: highlighted
                  ? Colors.amber.withValues(alpha: 0.85)
                  : Colors.black54,
              shape: BoxShape.circle,
            ),
            child: loading
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(icon,
                    color: highlighted ? Colors.black87 : Colors.white,
                    size: 26),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              shadows: [Shadow(color: Colors.black, blurRadius: 4)],
            ),
          ),
        ],
      ),
    );
  }
}
