import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/ai/ai_model_providers.dart';
import '../../../../core/ai/ai_result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../routes/app_routes.dart';
import '../../../../shared/widgets/app_back_button.dart';

/// A unified scan-and-log screen combining three modes in a single, continuous camera view:
///
/// **Tab 0 – Bill Scan (default)**
/// Live barcode / QR scanner for receipts and bills. Detects codes and pre-fills the expense form.
///
/// **Tab 1 – UPI Pay**
/// Scans UPI QR codes (`upi://pay`) and launches the direct UPI payment flow.
///
/// **Tab 2 – AI Scan**
/// Camera capture sent to Gemini Vision to identify products and automatically pre-fill expenses.
class UnifiedScannerScreen extends ConsumerStatefulWidget {
  const UnifiedScannerScreen({
    super.key,
    this.initialTab = 0,
    this.returnResult = false,
  });

  /// 0 = Bill, 1 = UPI, 2 = AI Scan.
  final int initialTab;
  final bool returnResult;

  @override
  ConsumerState<UnifiedScannerScreen> createState() =>
      _UnifiedScannerScreenState();
}

class _UnifiedScannerScreenState extends ConsumerState<UnifiedScannerScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // ── Controller (Single continuous hardware session) ───────────────────────

  late final MobileScannerController _controller;

  /// Drives the shutter button enter/exit animation when the AI tab is active.
  late final AnimationController _shutterAnim;
  late final Animation<double> _shutterScale;
  late final Animation<double> _shutterOpacity;

  // ── State ─────────────────────────────────────────────────────────────────

  late int _tabIndex;
  bool _billProcessed = false;
  bool _upiProcessed = false;
  bool _isPickingBill = false;
  bool _isPickingUpi = false;

  // AI tab state
  String? _capturedImagePath;
  bool _isCapturing = false;
  bool _isPickingAi = false;
  bool _isProcessing = false;
  final GlobalKey _previewKey = GlobalKey();
  bool _showShutterFlash = false;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabIndex = widget.initialTab.clamp(0, 2);

    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      returnImage: false,
    );

    _shutterAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _shutterScale = CurvedAnimation(
      parent: _shutterAnim,
      curve: Curves.elasticOut,
    );
    _shutterOpacity = CurvedAnimation(
      parent: _shutterAnim,
      curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
    );

    if (_tabIndex == 2) {
      _shutterAnim.forward();
    }
    _checkCameraPermission();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      try {
        _controller.start();
      } catch (_) {}
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      try {
        _controller.stop();
      } catch (_) {}
    }
  }

  Future<void> _checkCameraPermission() async {
    final status = await Permission.camera.status;
    if (!status.isGranted) {
      final res = await Permission.camera.request();
      if (res.isGranted && mounted) {
        try {
          await _controller.start();
        } catch (_) {}
        if (mounted) setState(() {});
      }
    } else {
      try {
        await _controller.start();
      } catch (_) {}
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shutterAnim.dispose();
    _controller.dispose();
    super.dispose();
  }

  // ── Tab switching ─────────────────────────────────────────────────────────

  void _switchTab(int index) {
    if (index == _tabIndex) return;
    HapticFeedback.selectionClick();
    setState(() {
      _tabIndex = index;
      _capturedImagePath = null;
      _isProcessing = false;
    });

    if (index == 2) {
      _shutterAnim.forward();
    } else {
      _shutterAnim.reverse();
    }
  }

  // ── UPI scan logic ────────────────────────────────────────────────────────

  void _onUpiDetect(BarcodeCapture capture) {
    if (_upiProcessed || _tabIndex != 1) return;
    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue != null) {
        _parseUpiAndNavigate(rawValue);
        break;
      }
    }
  }

  void _parseUpiAndNavigate(String rawValue) {
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

    setState(() => _upiProcessed = true);

    final am = uri.queryParameters['am'];
    final pn = uri.queryParameters['pn'];
    final tn = uri.queryParameters['tn'];
    final amount = am != null ? double.tryParse(am) : null;
    final note = pn?.isNotEmpty == true ? pn : tn;

    if (!mounted) return;

    AppRoutes.replaceWithPayExpense(
      context,
      payUpiUri: rawValue,
      initialAmount: amount,
      initialNote: note,
    );
  }

  Future<void> _upiPickGallery() async {
    if (_isPickingUpi || _upiProcessed) return;
    setState(() => _isPickingUpi = true);

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (!mounted) return;
      final path = result?.files.singleOrNull?.path;
      if (path == null) {
        setState(() => _isPickingUpi = false);
        return;
      }

      final capture = await _controller.analyzeImage(path);
      if (!mounted) return;
      setState(() => _isPickingUpi = false);

      final rawValue = capture?.barcodes.firstOrNull?.rawValue;
      if (rawValue != null) {
        _parseUpiAndNavigate(rawValue);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No QR code found in selected image.')),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _isPickingUpi = false);
    }
  }

  // ── Bill scan logic ───────────────────────────────────────────────────────

  void _onBillDetect(BarcodeCapture capture) {
    if (_billProcessed || _tabIndex != 0) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null) {
        _parseBillAndNavigate(raw);
        break;
      }
    }
  }

  void _parseBillAndNavigate(String rawValue) {
    setState(() => _billProcessed = true);

    double? amount;
    String? note;

    if (rawValue.startsWith('upi://pay')) {
      final uri = Uri.parse(rawValue);
      final am = uri.queryParameters['am'];
      final pn = uri.queryParameters['pn'];
      final tn = uri.queryParameters['tn'];
      if (am != null) amount = double.tryParse(am);
      note = tn ?? pn;
    }

    if (!mounted) return;
    if (widget.returnResult) {
      Navigator.of(context).pop({
        'amount': amount,
        'note': note,
      });
      return;
    }
    AppRoutes.replaceWithAddExpense(
      context,
      initialAmount: amount,
      initialNote: note,
    );
  }

  Future<void> _billPickGallery() async {
    if (_isPickingBill || _billProcessed) return;
    setState(() => _isPickingBill = true);

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (!mounted) return;

      final path = result?.files.singleOrNull?.path;
      if (path == null) {
        setState(() => _isPickingBill = false);
        return;
      }

      final capture = await _controller.analyzeImage(path);
      if (!mounted) return;

      if (capture == null || capture.barcodes.isEmpty) {
        setState(() => _isPickingBill = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No QR code found in the image.')),
        );
        return;
      }
      _onBillDetect(capture);
    } catch (_) {
      if (mounted) {
        setState(() => _isPickingBill = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read QR from image.')),
        );
      }
    }
  }

  // ── AI scan logic ─────────────────────────────────────────────────────────

  Future<void> _captureAiPhoto() async {
    if (_isCapturing || _isProcessing) return;
    setState(() {
      _isCapturing = true;
      _showShutterFlash = true;
    });

    HapticFeedback.mediumImpact();

    // Tactile camera shutter flash
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _showShutterFlash = false);
    });

    try {
      final boundary = _previewKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Camera preview not ready');
      }

      final pixelRatio = MediaQuery.of(context).devicePixelRatio;
      final image =
          await boundary.toImage(pixelRatio: pixelRatio.clamp(1.5, 3.0));
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Failed to encode camera frame');
      }

      final dir = await getTemporaryDirectory();
      final filePath =
          '${dir.path}/expensio_ai_capture_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(filePath);
      await file.writeAsBytes(byteData.buffer.asUint8List());

      if (!mounted) return;
      setState(() {
        _capturedImagePath = filePath;
        _isCapturing = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isCapturing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to capture frame: $e')),
        );
      }
    }
  }

  Future<void> _aiPickGallery() async {
    if (_isPickingAi || _isProcessing) return;
    setState(() => _isPickingAi = true);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (!mounted) return;
      final path = result?.files.singleOrNull?.path;
      setState(() {
        _isPickingAi = false;
        if (path != null) _capturedImagePath = path;
      });
    } catch (_) {
      if (mounted) setState(() => _isPickingAi = false);
    }
  }

  void _aiRetake() {
    setState(() {
      _capturedImagePath = null;
      _isProcessing = false;
    });
  }

  Future<void> _aiIdentify() async {
    final imagePath = _capturedImagePath;
    if (imagePath == null || _isProcessing) return;

    final model = ref.read(aiModelProvider);
    final isCloud = ref.read(isAiCloudBackedProvider);

    if (!isCloud) {
      _showAiNotConfiguredSheet();
      return;
    }

    setState(() => _isProcessing = true);

    // Optional barcode hint extraction via controller.
    String? barcodeHint;
    try {
      final dir = await getTemporaryDirectory();
      final ext = imagePath.split('.').last.toLowerCase();
      final tmpPath =
          '${dir.path}/xpens_bc_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await File(imagePath).copy(tmpPath);
      final capture = await _controller.analyzeImage(tmpPath);
      final raw = capture?.barcodes.firstOrNull?.rawValue;
      if (raw != null && raw.isNotEmpty) barcodeHint = raw;
    } catch (_) {
      // Non-fatal.
    }

    if (!mounted) return;

    try {
      final result = await model.identifyProduct(
        imagePath: imagePath,
        barcodeHint: barcodeHint,
      );
      if (!mounted) return;
      if (widget.returnResult) {
        Navigator.of(context).pop({
          'amount': result.price,
          'category': result.category,
          'note': result.name,
        });
        return;
      }
      AppRoutes.replaceWithAddExpense(
        context,
        initialNote: result.name,
        initialCategory: result.category,
        initialAmount: result.price,
      );
    } on AiModelException catch (e) {
      if (mounted) _showAiFailureSheet(e.message);
    } catch (_) {
      if (mounted) {
        _showAiFailureSheet(
          "Couldn't identify this product. Try a clearer, closer photo.",
        );
      }
    }
  }

  // ── Sheet helpers ─────────────────────────────────────────────────────────

  void _showAiNotConfiguredSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3CD),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Color(0xFFE09D00),
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'AI Scanner Not Configured',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'To use AI product scanning, add your Gemini API key and enable AI Features in Settings.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'Got it',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAiFailureSheet(String reason) {
    setState(() => _isProcessing = false);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.image_search_rounded,
                color: AppColors.danger,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Couldn't identify product",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              reason,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textDark,
                      side: const BorderSide(color: AppColors.surfaceAccent),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Try Again',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      if (widget.returnResult) {
                        Navigator.of(context).pop();
                      } else {
                        AppRoutes.replaceWithAddExpense(context);
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Fill Manually',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final capturedPath = _capturedImagePath;
    final isAiTab = _tabIndex == 2;
    final hasCapture = isAiTab && capturedPath != null;

    final String title = _tabIndex == 0
        ? 'Bill Scan'
        : (_tabIndex == 1 ? 'UPI Pay' : 'AI Scan');

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        leading: const Center(
          child: AppBackButton(
            backgroundColor: Colors.white24,
            iconColor: Colors.white,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            color: Colors.white,
            shadows: [Shadow(color: Colors.black87, blurRadius: 10)],
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Single continuous camera view (Never goes black) ──────────────
          if (!hasCapture)
            RepaintBoundary(
              key: _previewKey,
              child: MobileScanner(
                controller: _controller,
                fit: BoxFit.cover,
                errorBuilder: (context, error) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.videocam_off_rounded, color: Colors.white70, size: 40),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Camera Access Needed',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Please grant camera permission to scan receipts, UPI QR codes, and products.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.4),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final status = await Permission.camera.request();
                              if (status.isGranted) {
                                _controller.start();
                                setState(() {});
                              } else if (status.isPermanentlyDenied) {
                                await openAppSettings();
                              }
                            },
                            icon: const Icon(Icons.lock_open_rounded, size: 16),
                            label: const Text('Allow Camera'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryBlue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                onDetect: (capture) {
                  if (_tabIndex == 0) {
                    _onBillDetect(capture);
                  } else if (_tabIndex == 1) {
                    _onUpiDetect(capture);
                  }
                  // Tab 2 (AI Scan) intentionally does not auto-detect barcodes
                },
              ),
            ),

          if (_showShutterFlash)
            Positioned.fill(
              child: Container(color: Colors.white),
            ),

          // ── AI captured image preview ─────────────────────────────────
          if (hasCapture)
            Positioned.fill(
              child: Image.file(
                File(capturedPath),
                fit: BoxFit.cover,
              ),
            ),

          // Top gradient scrim for transparent header readability
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 120,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black87, Colors.transparent],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // ── Bill scan overlay: rectangular receipt target box ─────────
          if (_tabIndex == 0 && !hasCapture)
            Center(
              child: Container(
                width: 260,
                height: 320,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 2),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.receipt_long_rounded, color: Colors.white70, size: 14),
                          SizedBox(width: 5),
                          Text(
                            'Receipt & Barcode',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // ── UPI scan overlay: QR target box (cyan border, NO blue tint) ──
          if (_tabIndex == 1 && !hasCapture)
            Center(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF00B0FF), width: 2.5),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black38,
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.qr_code_2_rounded, color: Color(0xFF00B0FF), size: 14),
                          SizedBox(width: 5),
                          Text(
                            'UPI QR',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // ── AI scan overlay: lens focus frame with purple accent ───────
          if (_tabIndex == 2 && !hasCapture)
            Center(
              child: Container(
                width: 270,
                height: 270,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.9),
                    width: 2.5,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black38,
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome_rounded, color: Color(0xFFC084FC), size: 14),
                          SizedBox(width: 5),
                          Text(
                            'AI Product Lens',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // ── Processing overlay ────────────────────────────────────────
          if (_isProcessing)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.55),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text(
                        'Identifying product…',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'This may take a few seconds',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Bottom controls + tab switcher ────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16, left: 20, right: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!hasCapture) ...[
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: _tabIndex == 0
                            ? const _HintPill(
                                key: ValueKey('bill_hint'),
                                text: 'Point camera at barcode or QR on bill',
                              )
                            : (_tabIndex == 1
                                ? const _HintPill(
                                    key: ValueKey('upi_hint'),
                                    text: 'Point camera at any UPI QR code to pay',
                                  )
                                : const _HintPill(
                                    key: ValueKey('ai_hint'),
                                    text: 'Point at a product & capture for AI detection',
                                  )),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Controls row ──────────────────────────────────────
                    if (_tabIndex == 0) _buildBillControls(),
                    if (_tabIndex == 1) _buildUpiControls(),
                    if (_tabIndex == 2 && !hasCapture) _buildAiControls(),
                    if (_tabIndex == 2 && hasCapture) ...[
                      _buildAiPreviewCtas(capturedPath),
                    ],

                    const SizedBox(height: 20),

                    // ── Smart Floating Navigation Tab switcher ────────────
                    _TabSwitcher(
                      currentIndex: _tabIndex,
                      onSwitch: _switchTab,
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

  // ── Bill controls: Flash + Gallery ───────────────────────────────────────

  Widget _buildBillControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ValueListenableBuilder<MobileScannerState>(
          valueListenable: _controller,
          builder: (_, state, __) {
            final on = state.torchState == TorchState.on;
            return _ControlButton(
              icon: on ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              label: on ? 'Flash On' : 'Flash Off',
              highlighted: on,
              onTap: _controller.toggleTorch,
            );
          },
        ),
        const SizedBox(width: 40),
        _ControlButton(
          icon: Icons.photo_library_outlined,
          label: 'Gallery',
          loading: _isPickingBill,
          onTap: _billPickGallery,
        ),
      ],
    );
  }

  // ── UPI controls: Flash + Gallery ────────────────────────────────────────

  Widget _buildUpiControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ValueListenableBuilder<MobileScannerState>(
          valueListenable: _controller,
          builder: (_, state, __) {
            final on = state.torchState == TorchState.on;
            return _ControlButton(
              icon: on ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              label: on ? 'Flash On' : 'Flash Off',
              highlighted: on,
              onTap: _controller.toggleTorch,
            );
          },
        ),
        const SizedBox(width: 40),
        _ControlButton(
          icon: Icons.photo_library_outlined,
          label: 'Gallery',
          loading: _isPickingUpi,
          onTap: _upiPickGallery,
        ),
      ],
    );
  }

  // ── AI controls: Flash + Shutter + Gallery ────────────────────────────────

  Widget _buildAiControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Flash
        ValueListenableBuilder<MobileScannerState>(
          valueListenable: _controller,
          builder: (_, state, __) {
            final on = state.torchState == TorchState.on;
            return _ControlButton(
              icon: on ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              label: on ? 'Flash On' : 'Flash Off',
              highlighted: on,
              onTap: _controller.toggleTorch,
            );
          },
        ),

        // Animated shutter button
        ScaleTransition(
          scale: _shutterScale,
          child: FadeTransition(
            opacity: _shutterOpacity,
            child: GestureDetector(
              onTap: _isCapturing ? null : _captureAiPhoto,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _isCapturing
                    ? Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      )
                    : Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white70, width: 3),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.black87,
                          size: 32,
                        ),
                      ),
              ),
            ),
          ),
        ),

        // Gallery
        _ControlButton(
          icon: Icons.photo_library_outlined,
          label: 'Gallery',
          loading: _isPickingAi,
          onTap: _aiPickGallery,
        ),
      ],
    );
  }

  // ── AI preview CTAs: Retake + Identify ───────────────────────────────────

  Widget _buildAiPreviewCtas(String imagePath) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // AI badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF7B2FF7),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome_rounded, size: 14, color: Colors.white),
              SizedBox(width: 6),
              Text(
                'Gemini Vision will identify this',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        Row(
          children: [
            // Retake
            Expanded(
              child: GestureDetector(
                onTap: _isProcessing ? null : _aiRetake,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(color: Colors.white30),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'Retake',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Identify
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: _isProcessing ? null : _aiIdentify,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: _isProcessing
                        ? const Color(0xFF7B2FF7).withValues(alpha: 0.6)
                        : const Color(0xFF7B2FF7),
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _isProcessing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(
                              Icons.auto_awesome_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                      const SizedBox(width: 6),
                      Text(
                        _isProcessing ? 'Identifying…' : 'Identify',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Hint pill ─────────────────────────────────────────────────────────────────

class _HintPill extends StatelessWidget {
  const _HintPill({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }
}

// ── Smart Floating Navigation Tab Switcher ────────────────────────────────────

class _TabSwitcher extends StatelessWidget {
  const _TabSwitcher({
    required this.currentIndex,
    required this.onSwitch,
  });

  final int currentIndex;
  final ValueChanged<int> onSwitch;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TabItem(
            icon: Icons.receipt_long_rounded,
            label: 'Bill',
            selected: currentIndex == 0,
            onTap: () => onSwitch(0),
            accentColor: AppColors.primaryBlue,
          ),
          const SizedBox(width: 4),
          _TabItem(
            icon: Icons.qr_code_scanner_rounded,
            label: 'UPI',
            selected: currentIndex == 1,
            onTap: () => onSwitch(1),
            accentColor: const Color(0xFF00B0FF),
          ),
          const SizedBox(width: 4),
          _TabItem(
            icon: Icons.auto_awesome_rounded,
            label: 'AI',
            selected: currentIndex == 2,
            onTap: () => onSwitch(2),
            accentColor: const Color(0xFF8B5CF6),
          ),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.accentColor,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? (accentColor ?? AppColors.primaryBlue)
        : Colors.transparent;
    final fg = selected ? Colors.white : Colors.white70;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: selected ? 14 : 10,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(32),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: fg, size: 19),
            AnimatedCrossFade(
              firstChild: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              secondChild: const SizedBox.shrink(),
              crossFadeState: selected
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Control button ────────────────────────────────────────────────────────────

class _ControlButton extends StatelessWidget {
  const _ControlButton({
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
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: highlighted
                  ? Colors.amber.withValues(alpha: 0.85)
                  : Colors.black54,
              shape: BoxShape.circle,
            ),
            child: loading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(
                    icon,
                    color: highlighted ? Colors.black87 : Colors.white,
                    size: 24,
                  ),
          ),
          const SizedBox(height: 5),
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
