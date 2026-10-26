/// Error thrown by [AiModel] implementations.
class AiModelException implements Exception {
  const AiModelException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Fields extracted from an AI product-identification response.
class ProductScanResult {
  const ProductScanResult({
    required this.name,
    this.category,
    this.price,
  });

  final String name;
  final String? category;
  final double? price;
}

/// Category predicted for a transaction, with confidence.
class CategoryResult {
  const CategoryResult({
    required this.category,
    required this.confidence,
  });

  final String category;
  final double confidence;
}

/// Parsed result from a voice-input transcript.
class VoiceParseResult {
  const VoiceParseResult({
    this.amount,
    this.category,
    this.note,
  });

  final double? amount;
  final String? category;
  final String? note;
}

/// Smart search match.
class SmartSearchResult {
  const SmartSearchResult({
    required this.expenseId,
    required this.relevance,
  });

  final String expenseId;
  final double relevance;
}
