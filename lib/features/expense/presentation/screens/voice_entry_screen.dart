import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../../../core/services/widget_sync_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../routes/app_routes.dart';
import '../../data/models/expense_model.dart';

// ── Public entry point ─────────────────────────────────────────────────────

/// Shows the [VoiceEntryScreen] as a modal bottom-sheet.
///
/// Callers should `await` this; when the sheet closes after a successful
/// voice command the user is already navigating to [AddExpenseScreen].
Future<ParsedCommand?> showVoiceEntrySheet(BuildContext context, {bool returnResult = false}) {
  return showModalBottomSheet<ParsedCommand?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => VoiceEntryScreen(returnResult: returnResult),
  );
}

// ── Screen ─────────────────────────────────────────────────────────────────

/// A bottom-sheet that:
/// 1. Lets the user tap 🎤 to start Android speech recognition.
/// 2. Displays the recognised text.
/// 3. Parses it into a [ParsedCommand] (amount / type / category).
/// 4. Navigates to [AddExpenseScreen] with pre-filled data on confirm.
class VoiceEntryScreen extends StatefulWidget {
  const VoiceEntryScreen({super.key, this.returnResult = false});

  final bool returnResult;

  @override
  State<VoiceEntryScreen> createState() => _VoiceEntryScreenState();
}

class _VoiceEntryScreenState extends State<VoiceEntryScreen> {
  _VoiceState _state = _VoiceState.idle;
  String? _recognisedText;
  ParsedCommand? _parsed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(
            24,
            16,
            24,
            24 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDE4F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title row
              Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.mic_rounded,
                      color: AppColors.primaryBlue,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Voice Entry',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          'Speak to log a transaction',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ── State-driven body ──────────────────────────────────────
              if (_state == _VoiceState.idle) _buildIdleBody(),
              if (_state == _VoiceState.listening) _buildListeningBody(),
              if (_state == _VoiceState.result) _buildResultBody(),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ── Idle (tap mic) ─────────────────────────────────────────────────

  Widget _buildIdleBody() {
    return Column(
      children: <Widget>[
        const Text(
          'Tap the microphone and say something like:\n'
          '  • "Add 250 food expense"\n'
          '  • "Add salary 25000 income"\n'
          '  • "Transfer 5000 from cash"',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.7,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 28),
        _MicButton(onTap: _startListening),
        const SizedBox(height: 16),
      ],
    );
  }

  // ── Listening (spinner) ────────────────────────────────────────────

  Widget _buildListeningBody() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: <Widget>[
          CircularProgressIndicator(color: AppColors.primaryBlue),
          SizedBox(height: 16),
          Text(
            'Listening…',
            style: TextStyle(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ── Result (preview + confirm) ─────────────────────────────────────

  Widget _buildResultBody() {
    final cmd = _parsed;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Recognised text chip
        if (_recognisedText != null) ...<Widget>[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceAccent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.record_voice_over_rounded,
                  color: AppColors.primaryBlue,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '"$_recognisedText"',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Parsed preview
        if (cmd != null) ...<Widget>[
          _ParsedPreview(command: cmd),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _confirmCommand,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text(
              'Continue to Add Transaction',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
        ] else ...<Widget>[
          const Text(
            "Couldn't understand that. Please try again.",
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppColors.textMuted, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
        ],

        const SizedBox(height: 8),
        TextButton(
          onPressed: () => setState(() {
            _state = _VoiceState.idle;
            _recognisedText = null;
            _parsed = null;
          }),
          child: const Text('Try again'),
        ),
      ],
    );
  }

  // ── Logic ──────────────────────────────────────────────────────────

  Future<void> _startListening() async {
    setState(() => _state = _VoiceState.listening);

    final text = await WidgetSyncService.startVoiceInput();

    if (!mounted) return;

    if (text == null || text.trim().isEmpty) {
      setState(() => _state = _VoiceState.idle);
      return;
    }

    final parsed = await _VoiceCommandParser.parse(text);
    setState(() {
      _state = _VoiceState.result;
      _recognisedText = text;
      _parsed = parsed;
    });
  }

  void _confirmCommand() {
    final cmd = _parsed;
    if (cmd == null || !mounted) return;

    if (widget.returnResult) {
      Navigator.of(context).pop(cmd);
      return;
    }

    Navigator.of(context).pop();

    AppRoutes.pushAddExpense(
      context,
      initialAmount: cmd.amount,
      initialType: cmd.type,
      initialCategory: cmd.category,
      initialNote: cmd.note,
      initialDate: cmd.date,
    );
  }
}

// ── Supporting widgets ─────────────────────────────────────────────────────

class _MicButton extends StatelessWidget {
  const _MicButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.primaryBlue,
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.primaryBlue.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.mic_rounded,
            color: Colors.white,
            size: 32,
          ),
        ),
      ),
    );
  }
}

class _ParsedPreview extends StatelessWidget {
  const _ParsedPreview({required this.command});

  final ParsedCommand command;

  @override
  Widget build(BuildContext context) {
    final typeLabel = switch (command.type) {
      TransactionType.income => 'Income',
      TransactionType.transfer => 'Transfer',
      _ => 'Expense',
    };
    final typeColor = switch (command.type) {
      TransactionType.income => AppColors.success,
      TransactionType.transfer => AppColors.primaryBlue,
      _ => AppColors.danger,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDE4F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  typeLabel,
                  style: TextStyle(
                    color: typeColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  command.category,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                    fontSize: 15,
                  ),
                ),
              ),
              Text(
                command.amount.toStringAsFixed(0),
                style: TextStyle(
                  color: typeColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          if (command.note.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              command.note,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (command.date != null) ...<Widget>[
            const SizedBox(height: 4),
            Row(
              children: <Widget>[
                const Icon(Icons.calendar_today_rounded,
                    size: 11, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  'Yesterday',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── State enum ─────────────────────────────────────────────────────────────

enum _VoiceState { idle, listening, result }

// ── Voice command parser ───────────────────────────────────────────────────

class ParsedCommand {
  const ParsedCommand({
    required this.amount,
    required this.type,
    required this.category,
    this.note = '',
    this.date,
  });

  final double amount;
  final TransactionType type;
  final String category;
  final String note;
  final DateTime? date;
}

/// Heuristic NLP parser that extracts transaction data from free-form voice
/// input strings.  Keywords are loaded from [assets/data/voice_keywords.json]
/// on first use and cached for the lifetime of the app.
abstract final class _VoiceCommandParser {
  // ── Dictionary cache ───────────────────────────────────────────────
  static Map<String, dynamic>? _dict;

  static Future<Map<String, dynamic>> _loadDict() async {
    if (_dict != null) return _dict!;
    final raw = await rootBundle.loadString('assets/data/voice_keywords.json');
    _dict = (jsonDecode(raw) as Map<String, dynamic>);
    return _dict!;
  }

  static List<String> _group(Map<String, dynamic> dict, String path) {
    final parts = path.split('/');
    dynamic node = dict;
    for (final p in parts) {
      if (node is Map<String, dynamic> && node.containsKey(p)) {
        node = node[p];
      } else {
        return const <String>[];
      }
    }
    if (node is List) return node.cast<String>();
    return const <String>[];
  }

  // ── Public API ─────────────────────────────────────────────────────

  static Future<ParsedCommand?> parse(String rawText) async {
    final dict = await _loadDict();
    final text = rawText.toLowerCase().trim();

    // ── 1. Extract amount ────────────────────────────────────────────
    final amountRegex = RegExp(r'(\d+(?:[.,]\d{1,2})?)');
    final amountMatch = amountRegex.firstMatch(text);
    if (amountMatch == null) return null;

    final amountStr = amountMatch.group(1)!.replaceAll(',', '.');
    final amount = double.tryParse(amountStr) ?? 0;
    if (amount <= 0) return null;

    // ── 2. Determine transaction type ────────────────────────────────
    final type = _detectType(text, dict);

    // ── 3. Determine category ────────────────────────────────────────
    final category = _detectCategory(text, type, dict);

    // ── 4. Extract note (remaining meaningful words) ─────────────────
    final note = _extractNote(text, amountStr);

    // ── 5. Detect date hint ──────────────────────────────────────────
    final date = _detectDate(text, dict);

    return ParsedCommand(
      amount: amount,
      type: type,
      category: category,
      note: note,
      date: date,
    );
  }

  // ── Type detection ─────────────────────────────────────────────────

  static TransactionType _detectType(String text, Map<String, dynamic> dict) {
    if (_any(text, _group(dict, 'transaction_types/transfer'))) {
      return TransactionType.transfer;
    }
    if (_any(text, _group(dict, 'transaction_types/income'))) {
      return TransactionType.income;
    }
    // Default: expense (also catches explicit expense keywords)
    return TransactionType.expense;
  }

  // ── Category detection ─────────────────────────────────────────────

  static String _detectCategory(
      String text, TransactionType type, Map<String, dynamic> dict) {
    if (type == TransactionType.transfer) return 'Transfer';

    if (type == TransactionType.income) {
      final incomeCats =
          dict['income_categories'] as Map<String, dynamic>? ?? {};
      for (final entry in incomeCats.entries) {
        final keywords = (entry.value as List).cast<String>();
        if (_any(text, keywords)) return entry.key;
      }
      return 'Salary'; // default income category
    }

    // Expense categories
    final expenseCats =
        dict['expense_categories'] as Map<String, dynamic>? ?? {};
    for (final entry in expenseCats.entries) {
      final keywords = (entry.value as List).cast<String>();
      if (_any(text, keywords)) return entry.key;
    }

    return 'Other';
  }

  // ── Note extraction ────────────────────────────────────────────────

  /// Returns a short human-readable note derived from the recognised text,
  /// stripping the numeric amount and very common filler words.
  static String _extractNote(String text, String amountStr) {
    final stopWords = <String>{
      'a',
      'an',
      'the',
      'on',
      'for',
      'at',
      'in',
      'of',
      'to',
      'from',
      'and',
      'or',
      'is',
      'it',
      'my',
      'me',
      'i',
      'rs',
      'inr',
      'rupees',
      'rupee',
      'add',
      'new',
      'entry',
      'pe',
      'par',
      'ka',
      'ki',
      'ke',
      'se',
      'ko',
      'ne',
      'kiya',
      'hai',
      'tha',
      'thi',
    };
    final words = text
        .replaceAll(amountStr, '')
        .split(RegExp(r'\s+'))
        .map((w) => w.replaceAll(RegExp(r'[^\w\s]'), '').trim())
        .where((w) => w.isNotEmpty && !stopWords.contains(w))
        .toList();
    // Capitalise first word and join
    if (words.isEmpty) return '';
    words[0] = words[0][0].toUpperCase() + words[0].substring(1);
    return words.join(' ');
  }

  // ── Date detection ─────────────────────────────────────────────────

  /// Returns [DateTime.now()] for "today" hints, yesterday's date for
  /// "yesterday" hints, or `null` (caller should default to today).
  static DateTime? _detectDate(String text, Map<String, dynamic> dict) {
    final hints = dict['date_hints'] as Map<String, dynamic>? ?? {};
    final yesterdayKeys =
        (hints['yesterday'] as List?)?.cast<String>() ?? const <String>[];
    if (_any(text, yesterdayKeys)) {
      return DateTime.now().subtract(const Duration(days: 1));
    }
    // "today" is the default; return null so caller uses its own default.
    return null;
  }

  // ── Helper ─────────────────────────────────────────────────────────

  static bool _any(String text, List<String> keywords) =>
      keywords.any((k) => text.contains(k));
}
