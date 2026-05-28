import 'package:flutter/foundation.dart';

import 'package:xpens/features/accounts/data/models/account_model.dart';
import '../../../data/models/expense_model.dart';

/// Evaluates a user-typed search query against an [ExpenseModel].
///
/// Supported syntax (operators are case-insensitive, whitespace-separated):
///
/// | Input example          | Meaning                                     |
/// |------------------------|---------------------------------------------|
/// | `coffee`               | contains "coffee"                           |
/// | `coffee food`          | contains "coffee" AND "food"                |
/// | `coffee AND food`      | same as above                               |
/// | `coffee OR food`       | contains "coffee" or "food"                 |
/// | `NOT coffee`           | does NOT contain "coffee"                   |
/// | `coffee NOT food`      | contains "coffee" but not "food"            |
/// | `"coffee shop"`        | exact phrase "coffee shop"                  |
/// | `income OR transfer`   | matches income or transfer transactions     |
///
/// Default conjunction between adjacent terms is AND.
/// OR has lower precedence than AND.
///
/// The search corpus for each transaction includes:
///   category · note · amount · from-account · to-account · type name.
@immutable
class SearchQuery {
  const SearchQuery._(this._groups, this._raw);

  /// The raw query string as typed by the user.
  final String _raw;

  /// Outer list = OR groups; each inner list = AND terms (with optional NOT).
  final List<List<({String term, bool negated})>> _groups;

  /// `true` when the query is empty and should match all transactions.
  bool get isEmpty => _raw.trim().isEmpty;

  /// Parse [raw] into a [SearchQuery].
  factory SearchQuery.parse(String raw) {
    if (raw.trim().isEmpty) return const SearchQuery._([], '');

    final orGroups = <List<({String term, bool negated})>>[];
    final currentGroup = <({String term, bool negated})>[];
    bool pendingNot = false;

    for (final tok in _tokenize(raw)) {
      switch (tok.toUpperCase()) {
        case 'OR':
          if (currentGroup.isNotEmpty) {
            orGroups.add(List.unmodifiable(currentGroup));
            currentGroup.clear();
          }
          pendingNot = false;
        case 'AND':
          // AND is the default; nothing to do but clear any pending NOT.
          pendingNot = false;
        case 'NOT':
          pendingNot = true;
        default:
          currentGroup.add((term: tok.toLowerCase(), negated: pendingNot));
          pendingNot = false;
      }
    }
    if (currentGroup.isNotEmpty) {
      orGroups.add(List.unmodifiable(currentGroup));
    }

    return SearchQuery._(List.unmodifiable(orGroups), raw);
  }

  /// Returns `true` if [expense] satisfies this query.
  ///
  /// [accountMap] is used to resolve account names for the corpus.
  bool matchesExpense(
    ExpenseModel expense,
    Map<String, AccountModel> accountMap,
  ) {
    if (_groups.isEmpty) return true;

    final fromAccount = expense.accountId == null
        ? ''
        : accountMap[expense.accountId]?.name ?? '';
    final toAccount = expense.toAccountId == null
        ? ''
        : accountMap[expense.toAccountId]?.name ?? '';

    // Use a NUL separator so a term cannot bridge two fields accidentally.
    final corpus = [
      expense.category,
      expense.note,
      expense.amount.toStringAsFixed(2),
      expense.amount.toStringAsFixed(0),
      fromAccount,
      toAccount,
      expense.type.name, // "expense", "income", "transfer"
    ].join('\x00');

    final lower = corpus.toLowerCase();
    for (final group in _groups) {
      if (_groupMatches(lower, group)) return true;
    }
    return false;
  }

  static bool _groupMatches(
    String corpus,
    List<({String term, bool negated})> group,
  ) {
    for (final t in group) {
      final found = corpus.contains(t.term);
      if (t.negated && found) return false;
      if (!t.negated && !found) return false;
    }
    return true;
  }

  /// Tokenises [raw] into a list of tokens, respecting double-quoted phrases.
  static List<String> _tokenize(String raw) {
    final tokens = <String>[];
    final buf = StringBuffer();
    bool inQuote = false;

    for (int i = 0; i < raw.length; i++) {
      final ch = raw[i];
      if (ch == '"') {
        if (inQuote) {
          if (buf.isNotEmpty) {
            tokens.add(buf.toString());
            buf.clear();
          }
          inQuote = false;
        } else {
          inQuote = true;
        }
      } else if (!inQuote && ch == ' ') {
        if (buf.isNotEmpty) {
          tokens.add(buf.toString());
          buf.clear();
        }
      } else {
        buf.write(ch);
      }
    }
    if (buf.isNotEmpty) tokens.add(buf.toString());
    return tokens;
  }
}
