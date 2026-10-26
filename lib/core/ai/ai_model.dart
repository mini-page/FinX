import 'ai_result.dart';

/// Abstract interface for all AI models (Gemini, rule-based fallback, etc.).
///
/// Callers obtain the active model through [aiModelProvider] and never
/// need to know which implementation is backing it.
abstract class AiModel {
  const AiModel();
  /// Identifies a product from an image file on disk.
  Future<ProductScanResult> identifyProduct({
    required String imagePath,
    String? barcodeHint,
  });

  /// Predicts the best category for a transaction.
  Future<CategoryResult> categorizeTransaction({
    required String merchant,
    required double amount,
  });

  /// Parses a voice transcript into structured expense data.
  Future<VoiceParseResult> parseVoiceInput({
    required String transcript,
  });

  /// Ranks expenses by relevance to a natural-language query.
  Future<List<SmartSearchResult>> smartSearch({
    required String query,
    required List<({String id, String note, double amount, String category})>
        expenses,
  });

  /// Whether this model is backed by a cloud API (vs. local/on-device).
  bool get isCloudBacked;
}
