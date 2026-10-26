import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'ai_model.dart';
import 'ai_result.dart';

class GeminiAiModel extends AiModel {
  GeminiAiModel({
    required this.apiKey,
    required this.modelId,
  }) : super();

  final String apiKey;
  final String modelId;

  static const _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';
  static const _timeout = Duration(seconds: 15);

  @override
  bool get isCloudBacked => true;

  @override
  Future<ProductScanResult> identifyProduct({
    required String imagePath,
    String? barcodeHint,
  }) async {
    final barcodeClue = barcodeHint != null && barcodeHint.isNotEmpty
        ? ' The barcode/QR value detected in the image is: "$barcodeHint".'
        : '';

    final prompt =
        'This is a product or receipt photo.$barcodeClue '
        'Extract: product name, the best matching expense category from this list '
        '(Groceries, Food & Dining, Shopping, Electronics, Health, Transport, '
        'Entertainment, Bills & Utilities, Education, Other), '
        'and the price in the local currency if clearly visible. '
        'Respond ONLY with a compact JSON object — no markdown, no extra text:\n'
        '{"name":"<product name>","category":"<category>","price":<number or null>}';

    final Uint8List imageBytes;
    try {
      imageBytes = await File(imagePath).readAsBytes();
    } catch (_) {
      throw const AiModelException('Could not read image file.');
    }

    final extension = imagePath.split('.').last.toLowerCase();
    final mimeType = extension == 'png' ? 'image/png' : 'image/jpeg';

    final body = jsonEncode(<String, dynamic>{
      'contents': <Map<String, dynamic>>[
        {
          'parts': <Map<String, dynamic>>[
            {
              'inlineData': {
                'mimeType': mimeType,
                'data': base64Encode(imageBytes),
              },
            },
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': <String, dynamic>{
        'temperature': 0.1,
        'maxOutputTokens': 256,
      },
    });

    final uri = Uri.parse('$_baseUrl/$modelId:generateContent?key=$apiKey');

    try {
      final response = await http
          .post(
            uri,
            headers: <String, String>{'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        return _parseProductResponse(response.body);
      }

      if (response.statusCode == 400 || response.statusCode == 403) {
        throw const AiModelException(
            'API key error. Check your key in Settings → AI Features.');
      }

      throw const AiModelException(
          "Couldn't identify this product. Try a clearer, closer photo.");
    } on SocketException {
      throw const AiModelException(
          'No internet connection. Please check your network and try again.');
    } on TimeoutException {
      throw const AiModelException(
          'Request timed out. Please check your connection and try again.');
    }
  }

  ProductScanResult _parseProductResponse(String responseBody) {
    try {
      final data = jsonDecode(responseBody) as Map<String, dynamic>;
      final candidates = data['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) {
        throw const AiModelException('No response from AI model.');
      }

      final content =
          (candidates.first as Map<String, dynamic>)['content']
              as Map<String, dynamic>?;
      final parts = content?['parts'] as List<dynamic>?;
      final text = (parts?.first as Map<String, dynamic>?)?['text'] as String?;

      if (text == null || text.trim().isEmpty) {
        throw const AiModelException(
            "Couldn't identify this product. Try a clearer, closer photo.");
      }

      final jsonMatch = RegExp(r'\{[^{}]+\}').firstMatch(text);
      if (jsonMatch == null) {
        throw const AiModelException(
            "Couldn't identify this product. Try a clearer, closer photo.");
      }

      final parsed =
          jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;

      final name = (parsed['name'] as String? ?? '').trim();
      if (name.isEmpty) {
        throw const AiModelException(
            "Couldn't identify this product. Try a clearer, closer photo.");
      }

      final category = parsed['category'] as String?;

      double? price;
      final priceRaw = parsed['price'];
      if (priceRaw is num) {
        price = priceRaw.toDouble();
      } else if (priceRaw is String) {
        price = double.tryParse(priceRaw);
      }

      return ProductScanResult(name: name, category: category, price: price);
    } on AiModelException {
      rethrow;
    } catch (_) {
      throw const AiModelException(
          "Couldn't identify this product. Try a clearer, closer photo.");
    }
  }

  @override
  Future<CategoryResult> categorizeTransaction({
    required String merchant,
    required double amount,
  }) async {
    final prompt =
        'Categorize this expense into exactly one of these categories: '
        '(Groceries, Food & Dining, Shopping, Electronics, Health, Transport, '
        'Entertainment, Bills & Utilities, Education, Other).\n'
        'Merchant: "$merchant"\n'
        'Amount: $amount\n'
        'Respond ONLY with a JSON object:\n'
        '{"category":"<category>","confidence":<0.0-1.0>}';

    final result = await _generateText(prompt);
    return _parseCategoryResponse(result);
  }

  @override
  Future<VoiceParseResult> parseVoiceInput({
    required String transcript,
  }) async {
    final prompt =
        'Parse this voice transcript into expense details. '
        'Extract amount (in local currency), category from the list '
        '(Groceries, Food & Dining, Shopping, Electronics, Health, Transport, '
        'Entertainment, Bills & Utilities, Education, Other), '
        'and a short note/description.\n'
        'Transcript: "$transcript"\n'
        'Respond ONLY with a JSON object:\n'
        '{"amount":<number or null>,"category":"<category or null>","note":"<string or null>"}';

    final result = await _generateText(prompt);
    return _parseVoiceResponse(result);
  }

  @override
  Future<List<SmartSearchResult>> smartSearch({
    required String query,
    required List<({String id, String note, double amount, String category})>
        expenses,
  }) async {
    final expensesJson = expenses
        .map((e) =>
            '{"id":"${e.id}","note":"${e.note}","amount":${e.amount},"category":"${e.category}"}')
        .join(',');

    final prompt =
        'You have a list of expenses. For the search query "$query", '
        'rank the relevant expenses by relevance (0.0 to 1.0). '
        'Return ONLY a JSON array of objects with id and relevance.\n'
        'Expenses: [$expensesJson]\n'
        'Respond ONLY with a JSON array:\n'
        '[{"id":"<expense id>","relevance":<0.0-1.0>}]';

    final result = await _generateText(prompt);
    return _parseSmartSearchResponse(result);
  }

  Future<String> _generateText(String prompt) async {
    final body = jsonEncode(<String, dynamic>{
      'contents': <Map<String, dynamic>>[
        {
          'parts': <Map<String, dynamic>>[
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': <String, dynamic>{
        'temperature': 0.2,
        'maxOutputTokens': 512,
      },
    });

    final uri = Uri.parse('$_baseUrl/$modelId:generateContent?key=$apiKey');

    try {
      final response = await http
          .post(
            uri,
            headers: <String, String>{'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        throw AiModelException('Gemini API returned ${response.statusCode}');
      }

      return _extractText(response.body);
    } on SocketException {
      throw const AiModelException(
          'No internet connection. Please check your network and try again.');
    } on TimeoutException {
      throw const AiModelException(
          'Request timed out. Please check your connection and try again.');
    }
  }

  String _extractText(String responseBody) {
    final data = jsonDecode(responseBody) as Map<String, dynamic>;
    final candidates = data['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw const AiModelException('No response from AI model.');
    }
    final content =
        (candidates.first as Map<String, dynamic>)['content']
            as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>?;
    final text = (parts?.first as Map<String, dynamic>?)?['text'] as String?;
    if (text == null || text.trim().isEmpty) {
      throw const AiModelException('Empty response from AI model.');
    }
    return text;
  }

  CategoryResult _parseCategoryResponse(String text) {
    final match = RegExp(r'\{[^{}]+\}').firstMatch(text);
    if (match == null) {
      return const CategoryResult(category: 'Other', confidence: 0.5);
    }
    try {
      final parsed = jsonDecode(match.group(0)!) as Map<String, dynamic>;
      return CategoryResult(
        category: parsed['category'] as String? ?? 'Other',
        confidence: (parsed['confidence'] as num?)?.toDouble() ?? 0.5,
      );
    } catch (_) {
      return const CategoryResult(category: 'Other', confidence: 0.5);
    }
  }

  VoiceParseResult _parseVoiceResponse(String text) {
    final match = RegExp(r'\{[^{}]+\}').firstMatch(text);
    if (match == null) return const VoiceParseResult();
    try {
      final parsed = jsonDecode(match.group(0)!) as Map<String, dynamic>;
      double? amount;
      final amt = parsed['amount'];
      if (amt is num) amount = amt.toDouble();
      else if (amt is String) amount = double.tryParse(amt);
      return VoiceParseResult(
        amount: amount,
        category: parsed['category'] as String?,
        note: parsed['note'] as String?,
      );
    } catch (_) {
      return const VoiceParseResult();
    }
  }

  List<SmartSearchResult> _parseSmartSearchResponse(String text) {
    final match = RegExp(r'\[.*\]', dotAll: true).firstMatch(text);
    if (match == null) return [];
    try {
      final list = jsonDecode(match.group(0)!) as List<dynamic>;
      return list.map((e) {
        final m = e as Map<String, dynamic>;
        return SmartSearchResult(
          expenseId: m['id'] as String? ?? '',
          relevance: (m['relevance'] as num?)?.toDouble() ?? 0,
        );
      }).where((r) => r.expenseId.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }
}
