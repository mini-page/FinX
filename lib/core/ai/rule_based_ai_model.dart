import 'dart:io';

import 'ai_model.dart';
import 'ai_result.dart';

/// On-device rule-based fallback that never needs a network or API key.
///
///
///   - **identifyProduct** — Extracts filename as product name, `barcodeHint`
///     as name if present, category = `null` (falls back to "Other").
///   - **categorizeTransaction** — Keyword matching against merchant name.
///   - **parseVoiceInput** — Simple regex extraction of amount (`₹123`, `$50`).
///   - **smartSearch** — Case-insensitive substring match on note + category.
class RuleBasedAiModel extends AiModel {
  const RuleBasedAiModel();

  static const _categoryKeywords = <String, String>{
    'grocery': 'Groceries',
    'supermarket': 'Groceries',
    'mart': 'Groceries',
    'restaurant': 'Food & Dining',
    'cafe': 'Food & Dining',
    'food': 'Food & Dining',
    'pizza': 'Food & Dining',
    'swiggy': 'Food & Dining',
    'zomato': 'Food & Dining',
    'amazon': 'Shopping',
    'flipkart': 'Shopping',
    'myntra': 'Shopping',
    'mall': 'Shopping',
    'uber': 'Transport',
    'ola': 'Transport',
    'petrol': 'Transport',
    'fuel': 'Transport',
    'metro': 'Transport',
    'cab': 'Transport',
    'bus': 'Transport',
    'train': 'Transport',
    'electricity': 'Bills & Utilities',
    'bill': 'Bills & Utilities',
    'water': 'Bills & Utilities',
    'rent': 'Bills & Utilities',
    'phone': 'Bills & Utilities',
    'recharge': 'Bills & Utilities',
    'hospital': 'Health',
    'doctor': 'Health',
    'medical': 'Health',
    'pharmacy': 'Health',
    'medicine': 'Health',
    'netflix': 'Entertainment',
    'prime': 'Entertainment',
    'hotstar': 'Entertainment',
    'movie': 'Entertainment',
    'book': 'Education',
    'course': 'Education',
    'udemy': 'Education',
    'electronics': 'Electronics',
    'mobile': 'Electronics',
  };

  @override
  bool get isCloudBacked => false;

  @override
  Future<ProductScanResult> identifyProduct({
    required String imagePath,
    String? barcodeHint,
  }) async {
    // If we have a barcode, use it as the product name.
    if (barcodeHint != null && barcodeHint.isNotEmpty) {
      return ProductScanResult(name: barcodeHint);
    }

    // Fallback: derive name from filename.
    final name = File(imagePath).uri.pathSegments.lastOrNull ?? 'Product';
    final clean = name.replaceAll(RegExp(r'[._]\w+$'), '');
    return ProductScanResult(name: clean);
  }

  @override
  Future<CategoryResult> categorizeTransaction({
    required String merchant,
    required double amount,
  }) async {
    final lower = merchant.toLowerCase();
    for (final entry in _categoryKeywords.entries) {
      if (lower.contains(entry.key)) {
        return CategoryResult(category: entry.value, confidence: 0.7);
      }
    }
    return const CategoryResult(category: 'Other', confidence: 0.4);
  }

  @override
  Future<VoiceParseResult> parseVoiceInput({
    required String transcript,
  }) async {
    // Try to extract an amount: ₹1234, INR1234, $1234, 1234
    double? amount;
    final amountMatch = RegExp(r'(?:₹|INR|Rs\.?\s*|\$|€|£)?(\d+(?:,\d{3})*(?:\.\d{1,2})?)')
        .firstMatch(transcript);
    if (amountMatch != null) {
      amount = double.tryParse(amountMatch.group(1)!.replaceAll(',', ''));
    }

    // Try to match a category keyword.
    final lower = transcript.toLowerCase();
    String? category;
    for (final entry in _categoryKeywords.entries) {
      if (lower.contains(entry.key)) {
        category = entry.value;
        break;
      }
    }

    return VoiceParseResult(
      amount: amount,
      category: category,
      note: transcript.trim(),
    );
  }

  @override
  Future<List<SmartSearchResult>> smartSearch({
    required String query,
    required List<({String id, String note, double amount, String category})>
        expenses,
  }) async {
    final lowerQuery = query.toLowerCase();
    final terms = lowerQuery.split(RegExp(r'\s+')).where((t) => t.length > 1);

    final results = <SmartSearchResult>[];
    for (final expense in expenses) {
      double score = 0;
      final searchable =
          '${expense.note} ${expense.category} ${expense.amount}'.toLowerCase();

      for (final term in terms) {
        if (searchable.contains(term)) {
          score += 1.0 / terms.length;
        }
      }

      // Exact substring match bonus.
      if (searchable.contains(lowerQuery)) {
        score = (score + 1.0) / 2.0;
      }

      if (score > 0) {
        results.add(SmartSearchResult(
          expenseId: expense.id,
          relevance: score,
        ));
      }
    }

    results.sort((a, b) => b.relevance.compareTo(a.relevance));
    return results;
  }
}
