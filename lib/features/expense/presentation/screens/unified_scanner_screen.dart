import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/services/ai_product_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../routes/app_routes.dart';
import 'package:xpens/features/settings/presentation/provider/preferences_providers.dart';

/// A unified scan-and-log screen combining two modes in a single camera view.
///
/// **Tab 0 – Bill Scan (default)**
/// Live barcode / QR scanner. Detects codes on receipts, bills, and UPI
/// QR codes, then opens [AddExpenseScreen] with pre-filled amount / merchant.
///
/// **Tab 1 – AI Scan**
/// Live camera with a shutter button (or gallery picker). The captured photo
/// is sent to Gemini Vision which identifies the product and pre-fills the
/// expense form.
///
/// A segmented tab switcher at the bottom lets the user toggle between modes
/// without leaving the screen — no extra taps or bottom sheets needed.
class UnifiedScannerScreen extends ConsumerStatefulWidget {
  const UnifiedScannerScreen({
    super.key,
    this.initialTab = 0,
    this.returnResult = false,
  });

  /// 0 = Bill Scan, 1 = AI Scan.
  final int initialTab;
  final bool returnResult;

  @override
  ConsumerState<UnifiedScannerScreen> createState() =>
      _UnifiedScannerScreenState();
}

class _UnifiedScannerScreenState extends ConsumerState<UnifiedScannerScreen>
    with TickerProviderStateMixin {
  // ── Controllers ───────────────────────────────────────────────────────────

  late final MobileScannerController _billController;
  late final MobileScannerController _aiController;

  /// Drives the shutter button enter/exit animation when the AI tab is active.
  late final AnimationController _shutterAnim;
  late final Animation<double> _shutterScale;
  late final Animation<double> _shutterOpacity;

  // ── State ─────────────────────────────────────────────────────────────────

  late int _tabIndex;
  bool _billProcessed = false;

  // AI tab state
  String? _capturedImagePath;
  bool _isCapturing = false;
  bool _isPicking = false;
  bool _isProcessing = false;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tabIndex = widget.initialTab;

    _billController = MobileScannerController();
    _aiController = MobileScannerController(autoStart: false);

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

    if (_tabIndex == 1) {
      // Start AI camera instead of bill camera when launched on AI tab.
      _billController.stop();
      _aiController.start();
      _shutterAnim.forward();
    }
  }

  @override
  void dispose() {
    _shutterAnim.dispose();
    _billController.dispose();
    _aiController.dispose();
    super.dispose();
  }

  // ── Tab switching ─────────────────────────────────────────────────────────

  void _switchTab(int index) {
    if (index == _tabIndex) return;
    setState(() {
      _tabIndex = index;
      _capturedImagePath = null;
      _isProcessing = false;
    });
    if (index == 0) {
      _aiController.stop();
      _billController.start();
      _shutterAnim.reverse();
    } else {
      _billController.stop();
      _aiController.start();
      _shutterAnim.forward();
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
    AppRoutes.replaceWithAddExpense(context,
        initialAmount: amount, initialNote: note);
  }

  Future<void> _billPickGallery() async {
    if (_isPicking || _billProcessed) return;
    setState(() => _isPicking = true);

    try {
      final result = await FilePicker.platform
          .pickFiles(type: FileType.image, allowMultiple: false);
      if (!mounted) return;

      final path = result?.files.singleOrNull?.path;
      if (path == null) {
        setState(() => _isPicking = false);
        return;
      }

      final capture = await _billController.analyzeImage(path);
      if (!mounted) return;

      if (capture == null || capture.barcodes.isEmpty) {
        setState(() => _isPicking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No QR code found in the image.')),
        );
        return;
      }
      _onBillDetect(capture);
    } catch (_) {
      if (mounted) {
        setState(() => _isPicking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read QR from image.')),
        );
      }
    }
  }

  // ── AI scan logic ─────────────────────────────────────────────────────────

  Future<void> _captureAiPhoto() async {
    if (_isCapturing || _isProcessing) return;
    setState(() => _isCapturing = true);
    try {
      // Release the scanner camera so image_picker can access the device camera.
      await _aiController.stop();
      final picked = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (!mounted) return;
      if (picked == null) {
        // User cancelled – restart the live preview.
        await _aiController.start();
        setState(() => _isCapturing = false);
        return;
      }
      setState(() {
        _capturedImagePath = picked.path;
        _isCapturing = false;
      });
    } catch (_) {
      if (mounted) {
        await _aiController.start();
        setState(() => _isCapturing = false);
      }
    }
  }

  Future<void> _aiPickGallery() async {
    if (_isPicking || _isProcessing) return;
    setState(() => _isPicking = true);
    try {
      final result = await FilePicker.platform
          .pickFiles(type: FileType.image, allowMultiple: false);
      if (!mounted) return;
      final path = result?.files.singleOrNull?.path;
      setState(() {
        _isPicking = false;
        if (path != null) _capturedImagePath = path;
      });
    } catch (_) {
      if (mounted) setState(() => _isPicking = false);
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

    final apiKey = ref.read(aiApiKeyProvider);
    final aiEnabled = ref.read(aiEnabledProvider);
    final modelId = ref.read(aiModelIdProvider);

    if (!aiEnabled || apiKey.isEmpty) {
      _showAiNotConfiguredSheet();
      return;
    }

    setState(() => _isProcessing = true);

    // Optional barcode hint extraction via bill controller.
    String? barcodeHint;
    try {
      final dir = await getTemporaryDirectory();
      final ext = imagePath.split('.').last.toLowerCase();
      final tmpPath =
          '${dir.path}/xpens_bc_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await File(imagePath).copy(tmpPath);
      final capture = await _billController.analyzeImage(tmpPath);
      final raw = capture?.barcodes.firstOrNull?.rawValue;
      if (raw != null && raw.isNotEmpty) barcodeHint = raw;
    } catch (_) {
      // Non-fatal.
    }

    if (!mounted) return;

    try {
      final result = await AiProductService.identifyProduct(
        imagePath: imagePath,
        apiKey: apiKey,
        modelId: modelId,
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
    } on AiProductException catch (e) {
      if (mounted) _showAiFailureSheet(e.message);
    } catch (_) {
      if (mounted) {
        _showAiFailureSheet(
            "Couldn't identify this product. Try a clearer, closer photo.");
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
              child: const Icon(Icons.auto_awesome_rounded,
                  color: Color(0xFFE09D00), size: 32),
            ),
            const SizedBox(height: 16),
            const Text('AI Scanner Not Configured',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark)),
            const SizedBox(height: 8),
            const Text(
              'To use AI product scanning, add your Gemini API key and enable AI Features in Settings.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textMuted, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Got it',
                    style: TextStyle(fontWeight: FontWeight.w800)),
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
              child: Icon(Icons.image_search_rounded,
                  color: AppColors.danger, size: 32),
            ),
            const SizedBox(height: 16),
            const Text("Couldn't identify product",
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark)),
            const SizedBox(height: 8),
            Text(reason,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 13, height: 1.5)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textDark,
                      side:
                          const BorderSide(color: AppColors.surfaceAccent),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Try Again',
                        style: TextStyle(fontWeight: FontWeight.w700)),
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
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Fill Manually',
                        style: TextStyle(fontWeight: FontWeight.w800)),
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
    final isAiTab = _tabIndex == 1;
    final hasCapture = isAiTab && capturedPath != null;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.black45,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_rounded, size: 20),
          ),
        ),
        title: Text(
          isAiTab ? 'AI Scan' : 'Bill Scan',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Camera views ─────────────────────────────────────────────────
          if (!hasCapture)
            IndexedStack(
              index: _tabIndex,
              children: [
                // Tab 0: Bill scanner
                MobileScanner(
                  controller: _billController,
                  onDetect: _onBillDetect,
                ),
                // Tab 1: AI camera (no barcode detection needed)
                MobileScanner(controller: _aiController),
              ],
            ),

          // ── AI captured image preview ─────────────────────────────────
          if (hasCapture)
            Positioned.fill(
              child: Image.file(
                File(capturedPath),
                fit: BoxFit.cover,
              ),
            ),

          // ── Bill scan overlay: target box ─────────────────────────────
          if (!isAiTab)
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
                padding:
                    const EdgeInsets.only(bottom: 16, left: 20, right: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Hint pill (both scan tabs, cross-fades on switch;
                    //    hidden when AI capture preview is shown) ───────────
                    if (!hasCapture) ...[
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: isAiTab
                            ? const _HintPill(
                                key: ValueKey('ai_hint'),
                                text:
                                    'Point at a product & capture for AI detection',
                              )
                            : const _HintPill(
                                key: ValueKey('bill_hint'),
                                text:
                                    'Point camera at barcode or QR on receipt',
                              ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Controls row (bill or AI) ─────────────────────────
                    if (!isAiTab) _buildBillControls(),
                    if (isAiTab && !hasCapture) _buildAiControls(),

                    if (isAiTab && hasCapture) ...[
                      _buildAiPreviewCtas(capturedPath),
                    ],

                    const SizedBox(height: 20),

                    // ── Tab switcher ─────────────────────────────────────
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
          valueListenable: _billController,
          builder: (_, state, __) {
            final on = state.torchState == TorchState.on;
            return _ControlButton(
              icon: on ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              label: on ? 'Flash On' : 'Flash Off',
              highlighted: on,
              onTap: _billController.toggleTorch,
            );
          },
        ),
        const SizedBox(width: 40),
        _ControlButton(
          icon: Icons.photo_library_outlined,
          label: 'Gallery',
          loading: _isPicking,
          onTap: _billPickGallery,
        ),
      ],
    );
  }

  // ── AI controls: Flash + Shutter (animated) + Gallery ────────────────────

  Widget _buildAiControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Flash
        ValueListenableBuilder<MobileScannerState>(
          valueListenable: _aiController,
          builder: (_, state, __) {
            final on = state.torchState == TorchState.on;
            return _ControlButton(
              icon: on ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              label: on ? 'Flash On' : 'Flash Off',
              highlighted: on,
              onTap: _aiController.toggleTorch,
            );
          },
        ),

        // Animated shutter button (scales+fades in when AI tab becomes active)
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
          loading: _isPicking,
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
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF7B2FF7),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome_rounded,
                  size: 14, color: Colors.white),
              SizedBox(width: 6),
              Text(
                'Gemini Vision will identify this',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
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
                      Icon(Icons.refresh_rounded,
                          color: Colors.white, size: 18),
                      SizedBox(width: 6),
                      Text('Retake',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
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
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white)))
                          : const Icon(Icons.auto_awesome_rounded,
                              color: Colors.white, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        _isProcessing ? 'Identifying…' : 'Identify',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14),
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

// ── Tab switcher ──────────────────────────────────────────────────────────────

class _TabSwitcher extends StatelessWidget {
  const _TabSwitcher(
      {required this.currentIndex, required this.onSwitch});

  final int currentIndex;
  final ValueChanged<int> onSwitch;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TabItem(
            icon: Icons.receipt_long_rounded,
            label: 'Bill Scan',
            selected: currentIndex == 0,
            onTap: () => onSwitch(0),
          ),
          const SizedBox(width: 4),
          _TabItem(
            icon: Icons.auto_awesome_rounded,
            label: 'AI Scan',
            selected: currentIndex == 1,
            onTap: () => onSwitch(1),
            accentColor: const Color(0xFF7B2FF7),
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(36),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: fg, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontWeight:
                    selected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 13,
              ),
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
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(icon,
                    color:
                        highlighted ? Colors.black87 : Colors.white,
                    size: 24),
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
