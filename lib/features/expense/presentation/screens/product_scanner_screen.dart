import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/services/ai_product_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../routes/app_routes.dart';
import 'package:xpens/features/settings/presentation/provider/preferences_providers.dart';

/// AI-powered product scanner.
///
/// Flow:
/// 1. Landing view: user picks a photo from their gallery (or camera via the
///    native file picker on Android) using [FilePicker].
/// 2. Preview view: selected image is shown; user taps **Identify Product**.
/// 3. Processing: optional barcode hint extraction + Gemini Vision call.
/// 4. On success  → navigates to [AddExpenseScreen] with pre-filled fields.
/// 5. On failure  → shows a recovery sheet ("Try Again" / "Fill Manually").
class ProductScannerScreen extends ConsumerStatefulWidget {
  const ProductScannerScreen({super.key});

  @override
  ConsumerState<ProductScannerScreen> createState() =>
      _ProductScannerScreenState();
}

class _ProductScannerScreenState extends ConsumerState<ProductScannerScreen> {
  // MobileScanner controller is used only for barcode hint extraction via
  // analyzeImage() — not for live camera preview.
  final MobileScannerController _scannerController = MobileScannerController(
    autoStart: false,
  );

  String? _selectedImagePath;
  bool _processing = false;
  bool _isPicking = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  // ── Image selection ────────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    if (_isPicking || _processing) return;
    setState(() => _isPicking = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (!mounted) return;

      final path = result?.files.singleOrNull?.path;
      setState(() {
        _isPicking = false;
        if (path != null) _selectedImagePath = path;
      });
    } catch (_) {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  // ── Identify pipeline ──────────────────────────────────────────────────────

  Future<void> _identify() async {
    final imagePath = _selectedImagePath;
    if (imagePath == null || _processing) return;

    // Guard: AI must be configured.
    final apiKey = ref.read(aiApiKeyProvider);
    final aiEnabled = ref.read(aiEnabledProvider);
    final modelId = ref.read(aiModelIdProvider);

    if (!aiEnabled || apiKey.isEmpty) {
      _showAiNotConfiguredSheet();
      return;
    }

    setState(() => _processing = true);

    // Step A — barcode extraction (best-effort; never blocks AI call).
    String? barcodeHint;
    try {
      // Copy image to temp dir so analyzeImage() has a reliable path.
      final dir = await getTemporaryDirectory();
      final ext = imagePath.split('.').last.toLowerCase();
      final tempPath =
          '${dir.path}/xpens_ai_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await File(imagePath).copy(tempPath);

      final capture = await _scannerController.analyzeImage(tempPath);
      final raw = capture?.barcodes.firstOrNull?.rawValue;
      if (raw != null && raw.isNotEmpty) barcodeHint = raw;
    } catch (_) {
      // Non-fatal; proceed without barcode hint.
    }

    if (!mounted) return;

    // Step B — Gemini Vision call.
    try {
      final result = await AiProductService.identifyProduct(
        imagePath: imagePath,
        apiKey: apiKey,
        modelId: modelId,
        barcodeHint: barcodeHint,
      );

      if (!mounted) return;

      AppRoutes.replaceWithAddExpense(
        context,
        initialNote: result.name,
        initialCategory: result.category,
        initialAmount: result.price,
      );
    } on AiProductException catch (e) {
      if (mounted) _showFailureSheet(e.message);
    } catch (_) {
      if (mounted) {
        _showFailureSheet(
          "Couldn't identify this product. Try a clearer, closer photo.",
        );
      }
    }
  }

  // ── Sheet helpers ──────────────────────────────────────────────────────────

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

  void _showFailureSheet(String reason) {
    setState(() => _processing = false);
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
                      AppRoutes.replaceWithAddExpense(context);
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

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Snap a Product'),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          if (_selectedImagePath != null)
            TextButton(
              onPressed: _isPicking ? null : _pickImage,
              child: const Text(
                'Change',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
      body: _selectedImagePath == null
          ? _buildLandingView()
          : _buildPreviewView(_selectedImagePath!),
    );
  }

  // ── Landing view ───────────────────────────────────────────────────────────

  Widget _buildLandingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Illustration placeholder
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFFF3E8FF),
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(
                Icons.camera_alt_outlined,
                color: Color(0xFF7B2FF7),
                size: 56,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Identify a product with AI',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Take a photo of any product or its label.\nAI will identify it and pre-fill your expense for you.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isPicking ? null : _pickImage,
                icon: _isPicking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.photo_library_outlined, size: 20),
                label: const Text(
                  'Choose a Photo',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF7B2FF7),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(40),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Tip: Include the product label or barcode for better results',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textMuted.withValues(alpha: 0.7),
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Preview view ───────────────────────────────────────────────────────────

  Widget _buildPreviewView(String imagePath) {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image preview
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.file(
                    File(imagePath),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),

            // AI badge + CTA
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  children: [
                    // AI badge row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3E8FF),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.auto_awesome_rounded,
                                  size: 14, color: Color(0xFF7B2FF7)),
                              SizedBox(width: 4),
                              Text(
                                'Gemini Vision will identify this product',
                                style: TextStyle(
                                  color: Color(0xFF7B2FF7),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Identify button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _processing ? null : _identify,
                        icon: _processing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Icon(Icons.auto_awesome_rounded, size: 20),
                        label: Text(
                          _processing ? 'Identifying…' : 'Identify Product',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: _processing
                              ? AppColors.primaryBlue.withValues(alpha: 0.7)
                              : AppColors.primaryBlue,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(40),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        // Full-screen loading overlay
        if (_processing)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.45),
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
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
