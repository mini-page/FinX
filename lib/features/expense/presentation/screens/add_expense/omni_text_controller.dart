import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';

/// A custom [TextEditingController] that provides syntax highlighting for the
/// Expensio Omni Box:
/// - `@account` tokens in cyan / blue
/// - `:toAccount` tokens in purple / violet
/// - `/category` tokens in emerald / teal
/// - `#tag` tokens in pink
/// - Numbers and math operators in prominent dark text
/// - Plain words (notes / description) in standard body style
class OmniTextEditingController extends TextEditingController {
  OmniTextEditingController({super.text});

  static const Color accountColor = Color(0xFF0091EA); // Vibrant Cyan / Blue
  static const Color toAccountColor = Color(0xFF7C3AED); // Vibrant Purple / Violet
  static const Color categoryColor = Color(0xFF059669); // Emerald / Teal
  static const Color tagColor = Color(0xFFDB2777); // Pink

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final text = this.text;
    if (text.isEmpty) {
      return TextSpan(style: style, text: '');
    }

    final spans = <TextSpan>[];
    // Tokenize text into words, whitespace, and special trigger tokens
    final regex = RegExp(r'(@\S+|:\S+|/\S+|#\S+|\S+|\s+)');
    final matches = regex.allMatches(text);

    bool isFirstToken = true;

    for (final match in matches) {
      final token = match.group(0)!;

      if (token.startsWith('@')) {
        spans.add(TextSpan(
          text: token,
          style: (style ?? const TextStyle()).copyWith(
            color: accountColor,
            fontWeight: FontWeight.w800,
          ),
        ));
      } else if (token.startsWith(':')) {
        spans.add(TextSpan(
          text: token,
          style: (style ?? const TextStyle()).copyWith(
            color: toAccountColor,
            fontWeight: FontWeight.w800,
          ),
        ));
      } else if (token.startsWith('/')) {
        spans.add(TextSpan(
          text: token,
          style: (style ?? const TextStyle()).copyWith(
            color: categoryColor,
            fontWeight: FontWeight.w800,
          ),
        ));
      } else if (token.startsWith('#')) {
        spans.add(TextSpan(
          text: token,
          style: (style ?? const TextStyle()).copyWith(
            color: tagColor,
            fontWeight: FontWeight.w800,
          ),
        ));
      } else if (isFirstToken && RegExp(r'^[\d\.\+\-\*\/x]+$').hasMatch(token)) {
        spans.add(TextSpan(
          text: token,
          style: (style ?? const TextStyle()).copyWith(
            color: AppColors.textDark,
            fontWeight: FontWeight.w900,
          ),
        ));
      } else {
        spans.add(TextSpan(
          text: token,
          style: style,
        ));
      }

      if (token.trim().isNotEmpty) {
        isFirstToken = false;
      }
    }

    return TextSpan(style: style, children: spans);
  }
}
