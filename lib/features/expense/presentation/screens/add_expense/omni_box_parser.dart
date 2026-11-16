import 'package:flutter/foundation.dart';
import '../../../../accounts/data/models/account_model.dart';
import '../../../data/models/expense_model.dart';
import '../../../../categories/presentation/widgets/expense_category.dart';
import 'package:expensio/core/utils/date_time_parser.dart';

enum OmniTriggerType {
  none,
  account,     // triggered by @
  toAccount,   // triggered by :
  category,    // triggered by /
  tag,         // triggered by #
}

@immutable
class OmniActiveTrigger {
  const OmniActiveTrigger({
    required this.type,
    required this.query,
    required this.startIndex,
    required this.endIndex,
  });

  final OmniTriggerType type;
  final String query;
  final int startIndex;
  final int endIndex;

  static const none = OmniActiveTrigger(
    type: OmniTriggerType.none,
    query: '',
    startIndex: -1,
    endIndex: -1,
  );
}

@immutable
class OmniParsedResult {
  const OmniParsedResult({
    required this.amountExpression,
    this.matchedAccountId,
    this.matchedToAccountId,
    this.matchedCategoryName,
    this.matchedSubcategoryName,
    this.matchedDate,
    required this.tags,
    required this.description,
  });

  final String amountExpression;
  final String? matchedAccountId;
  final String? matchedToAccountId;
  final String? matchedCategoryName;
  final String? matchedSubcategoryName;
  final DateTime? matchedDate;
  final List<String> tags;
  final String description;
}

class OmniBoxParser {
  const OmniBoxParser._();

  /// Inspects the cursor position inside [text] and returns the active trigger token
  /// (e.g. `@ca` or `/foo` or `#par` or `:h`), if any.
  static OmniActiveTrigger detectActiveTrigger(String text, int cursorPosition) {
    if (cursorPosition <= 0 || cursorPosition > text.length) {
      return OmniActiveTrigger.none;
    }

    final textBeforeCursor = text.substring(0, cursorPosition);
    // Find the start of the current token by looking for preceding whitespace
    final lastWhitespaceIndex = textBeforeCursor.lastIndexOf(RegExp(r'\s'));
    final tokenStart = lastWhitespaceIndex == -1 ? 0 : lastWhitespaceIndex + 1;
    final currentToken = textBeforeCursor.substring(tokenStart);

    if (currentToken.startsWith('@')) {
      return OmniActiveTrigger(
        type: OmniTriggerType.account,
        query: currentToken.substring(1),
        startIndex: tokenStart,
        endIndex: cursorPosition,
      );
    }
    if (currentToken.startsWith(':')) {
      return OmniActiveTrigger(
        type: OmniTriggerType.toAccount,
        query: currentToken.substring(1),
        startIndex: tokenStart,
        endIndex: cursorPosition,
      );
    }
    if (currentToken.startsWith('/')) {
      return OmniActiveTrigger(
        type: OmniTriggerType.category,
        query: currentToken.substring(1),
        startIndex: tokenStart,
        endIndex: cursorPosition,
      );
    }
    if (currentToken.startsWith('#')) {
      return OmniActiveTrigger(
        type: OmniTriggerType.tag,
        query: currentToken.substring(1),
        startIndex: tokenStart,
        endIndex: cursorPosition,
      );
    }

    return OmniActiveTrigger.none;
  }

  /// Parses the entire omni line into structured fields.
  static OmniParsedResult parse({
    required String text,
    required List<AccountModel> accounts,
    required List<ExpenseCategory> categories,
    required Map<String, List<String>> subcategoriesMap,
    required TransactionType transactionType,
  }) {
    if (text.trim().isEmpty) {
      return const OmniParsedResult(
        amountExpression: '',
        tags: [],
        description: '',
      );
    }

    final tokens = text.split(RegExp(r'\s+'));
    String amountExpression = '';
    String? matchedAccountId;
    String? matchedToAccountId;
    String? matchedCategory;
    String? matchedSubcategory;
    final tags = <String>[];
    final noteWords = <String>[];

    bool amountFound = false;

    for (int i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      if (token.isEmpty) continue;

      // 1. Amount: first numeric / math token
      if (!amountFound && RegExp(r'^[\d\.\+\-\*\/x]+$').hasMatch(token)) {
        amountExpression = token;
        amountFound = true;
        continue;
      }

      // 2. Account token: starts with @
      if (token.startsWith('@') && token.length > 1) {
        final raw = token.substring(1).toLowerCase().replaceAll('_', ' ');
        for (final acc in accounts) {
          final accName = acc.name.toLowerCase();
          if (accName == raw || accName.replaceAll(' ', '') == raw || accName.contains(raw)) {
            matchedAccountId = acc.id;
            break;
          }
        }
        continue;
      }

      // 3. To-Account token (for transfer): starts with :
      if (token.startsWith(':') && token.length > 1) {
        final raw = token.substring(1).toLowerCase().replaceAll('_', ' ');
        for (final acc in accounts) {
          final accName = acc.name.toLowerCase();
          if (accName == raw || accName.replaceAll(' ', '') == raw || accName.contains(raw)) {
            matchedToAccountId = acc.id;
            break;
          }
        }
        continue;
      }

      // 4. Category token: starts with /
      if (token.startsWith('/') && token.length > 1) {
        final raw = token.substring(1).toLowerCase().replaceAll('_', ' ');
        // Check if token contains colon for subcategory e.g. /food:dinner
        String catPart = raw;
        String? subPart;
        if (raw.contains(':')) {
          final split = raw.split(':');
          catPart = split[0];
          subPart = split.length > 1 ? split[1] : null;
        }

        for (final cat in categories) {
          final cName = cat.name.toLowerCase();
          if (cName == catPart || cName.replaceAll(' ', '') == catPart || cName.contains(catPart)) {
            matchedCategory = cat.name;
            // Match subcategory
            if (subPart != null) {
              final subs = subcategoriesMap[cat.name] ?? const <String>[];
              for (final sub in subs) {
                if (sub.toLowerCase().contains(subPart)) {
                  matchedSubcategory = sub;
                  break;
                }
              }
            }
            break;
          }
        }

        // If no main category matched directly, check if raw matches any subcategory
        if (matchedCategory == null) {
          for (final entry in subcategoriesMap.entries) {
            for (final sub in entry.value) {
              if (sub.toLowerCase() == raw || sub.toLowerCase().contains(raw)) {
                matchedCategory = entry.key;
                matchedSubcategory = sub;
                break;
              }
            }
            if (matchedCategory != null) break;
          }
        }
        continue;
      }

      // 5. Tag token: starts with #
      if (token.startsWith('#') && token.length > 1) {
        tags.add(token.substring(1));
        continue;
      }

      // 6. Otherwise: Description / Note word
      noteWords.add(token);
    }

    // Natural Language Date & Time Parsing
    final rawDescription = noteWords.join(' ');
    final parsedDateResult = DateTimeParser.parse(rawDescription);
    final finalDescription = parsedDateResult.cleanedText;
    final matchedDate = parsedDateResult.dateTime;

    // Default category to 'Uncategorised' if null and amount is present
    final resolvedCategory = matchedCategory ?? 'Uncategorised';

    return OmniParsedResult(
      amountExpression: amountExpression,
      matchedAccountId: matchedAccountId,
      matchedToAccountId: matchedToAccountId,
      matchedCategoryName: resolvedCategory,
      matchedSubcategoryName: matchedSubcategory,
      matchedDate: matchedDate,
      tags: tags,
      description: finalDescription,
    );
  }
}
