import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ai_model.dart';
import 'ai_result.dart';
import 'gemini_ai_model.dart';
import 'rule_based_ai_model.dart';
import '../../features/settings/presentation/provider/preferences_providers.dart';

// ---------------------------------------------------------------------------
// Active model — chooses Gemini when available, rule-based fallback otherwise
// ---------------------------------------------------------------------------

/// The currently active [AiModel] based on user preferences.
///
/// - If `aiEnabled == true` and `apiKey` is non-empty → [GeminiAiModel]
/// - Otherwise → [RuleBasedAiModel]
final aiModelProvider = Provider<AiModel>((ref) {
  final apiKey = ref.watch(aiApiKeyProvider);
  final enabled = ref.watch(aiEnabledProvider);
  final modelId = ref.watch(aiModelIdProvider);

  if (enabled && apiKey.isNotEmpty) {
    return GeminiAiModel(apiKey: apiKey, modelId: modelId);
  }
  return const RuleBasedAiModel();
});

// ---------------------------------------------------------------------------
// Convenience providers for each operation (wraps aiModelProvider call)
// ---------------------------------------------------------------------------

final aiIdentifyProductProvider = Provider.family<
    Future<ProductScanResult>,
    ({String imagePath, String? barcodeHint})>((ref, params) {
  return ref.watch(aiModelProvider).identifyProduct(
        imagePath: params.imagePath,
        barcodeHint: params.barcodeHint,
      );
});

final aiCategorizeTransactionProvider = Provider.family<
    Future<CategoryResult>,
    ({String merchant, double amount})>((ref, params) {
  return ref.watch(aiModelProvider).categorizeTransaction(
        merchant: params.merchant,
        amount: params.amount,
      );
});

final aiParseVoiceProvider = Provider.family<
    Future<VoiceParseResult>,
    String>((ref, transcript) {
  return ref.watch(aiModelProvider).parseVoiceInput(transcript: transcript);
});

/// Whether the user has an active cloud-backed AI model (e.g. Gemini).
final isAiCloudBackedProvider = Provider<bool>((ref) {
  return ref.watch(aiModelProvider).isCloudBacked;
});
