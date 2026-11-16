import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/ai/ai_model_providers.dart';
import '../../../../core/services/widget_sync_service.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:expensio/core/utils/date_time_parser.dart';
import '../../../../routes/app_routes.dart';
import '../../data/models/expense_model.dart';
import '../provider/expense_providers.dart';
import 'package:expensio/features/settings/presentation/provider/preferences_providers.dart';
import 'package:expensio/features/recurring/presentation/provider/recurring_subscription_providers.dart';
import 'package:expensio/features/accounts/data/models/account_model.dart';
import 'package:expensio/features/accounts/presentation/provider/account_providers.dart';
import 'package:expensio/features/categories/presentation/widgets/expense_category.dart';

// ── Public Entry Point ──────────────────────────────────────────────────────

/// Shows the unified [VoiceEntryScreen] as a modal bottom sheet.
Future<ParsedCommand?> showVoiceEntrySheet(
  BuildContext context, {
  bool returnResult = false,
}) {
  return showModalBottomSheet<ParsedCommand?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => VoiceEntryScreen(returnResult: returnResult),
  );
}

// ── Models ──────────────────────────────────────────────────────────────────

enum ActionType {
  none,
  addExpense,
  addSubscription,
  contributeGoal,
  createGoal,
  appCommand,
  clarification,
}

class VoiceChatMessage {
  VoiceChatMessage({
    required this.isUser,
    required this.text,
    this.actionType = ActionType.none,
    this.actionData,
    this.actionExecuted = false,
    this.quickOptions,
  });

  final bool isUser;
  final String text;
  final ActionType actionType;
  final Map<String, dynamic>? actionData;
  bool actionExecuted;
  final List<String>? quickOptions;
}

class ParsedCommand {
  const ParsedCommand({
    required this.amount,
    required this.type,
    required this.category,
    this.note = '',
    this.date,
    this.subcategory,
    this.accountId,
    this.accountName,
  });

  final double amount;
  final TransactionType type;
  final String category;
  final String note;
  final DateTime? date;
  final String? subcategory;
  final String? accountId;
  final String? accountName;
}

// ── Unified Expensio AI Assistant Screen ───────────────────────────────────

class VoiceEntryScreen extends ConsumerStatefulWidget {
  const VoiceEntryScreen({super.key, this.returnResult = false});

  final bool returnResult;

  @override
  ConsumerState<VoiceEntryScreen> createState() => _VoiceEntryScreenState();
}

class _VoiceEntryScreenState extends ConsumerState<VoiceEntryScreen> {
  final List<VoiceChatMessage> _chatMessages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isListening = false;
  bool _isProcessing = false;

  // Pending context for interactive clarification questions
  Map<String, dynamic>? _pendingDraft;

  @override
  void initState() {
    super.initState();
    _chatMessages.add(
      VoiceChatMessage(
        isUser: false,
        text:
            "Hi! I'm your Expensio AI Assistant. Speak or type to log transactions, manage savings goals, add subscriptions, or control the app.\n\nTry asking:\n• \"Spent 250 on lunch yesterday at 8pm\"\n• \"Add 500 to Vacation goal\"\n• \"Create goal Laptop target 50000\"\n• \"Netflix 499 monthly\"",
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final screenHeight = MediaQuery.of(context).size.height;
    final isCloud = ref.watch(isAiCloudBackedProvider);

    return Container(
      height: screenHeight * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header: AI Assistant Branding + Close
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x268B5CF6),
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Expensio AI Assistant',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textDark,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isCloud ? const Color(0xFF10B981) : const Color(0xFF8B5CF6),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isCloud ? 'Gemini AI Active' : 'Smart NLP Engine • Offline',
                            style: TextStyle(
                              fontSize: 11,
                              color: isCloud ? const Color(0xFF059669) : const Color(0xFF7C3AED),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Suggestion Chips Bar
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _QuickChip(
                  label: 'Spent 250 on lunch yesterday',
                  onTap: () => _handleUnifiedInput('Spent 250 on lunch yesterday'),
                ),
                _QuickChip(
                  label: 'Add 500 to Vacation goal',
                  onTap: () => _handleUnifiedInput('Add 500 to Vacation goal'),
                ),
                _QuickChip(
                  label: 'Create goal Laptop 50000',
                  onTap: () => _handleUnifiedInput('Create goal Laptop 50000'),
                ),
                _QuickChip(
                  label: 'Netflix 499 monthly',
                  onTap: () => _handleUnifiedInput('Netflix 499 monthly'),
                ),
                _QuickChip(
                  label: 'Salary 50000 credited',
                  onTap: () => _handleUnifiedInput('Salary 50000 credited'),
                ),
                _QuickChip(
                  label: 'Dark mode',
                  onTap: () => _handleUnifiedInput('turn on dark mode'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(color: Color(0xFFF1F5F9), height: 1),

          // Chat Messages Area
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              itemCount: _chatMessages.length,
              itemBuilder: (context, index) {
                final msg = _chatMessages[index];
                return _buildChatMessageItem(msg);
              },
            ),
          ),

          if (_isProcessing)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Thinking & extracting details…',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF8B5CF6),
                    ),
                  ),
                ],
              ),
            ),

          // Bottom Voice & Text Input Bar
          Container(
            padding: EdgeInsets.fromLTRB(16, 10, 16, (bottomInset > 0 ? bottomInset + 14 : safeBottom + 20)),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Voice Mic Button
                GestureDetector(
                  onTap: _isListening ? null : _startVoiceInput,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _isListening
                            ? [AppColors.danger, Colors.redAccent]
                            : [const Color(0xFF8B5CF6), const Color(0xFF6366F1)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (_isListening
                                  ? AppColors.danger
                                  : const Color(0xFF8B5CF6))
                              .withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      _isListening ? Icons.mic : Icons.mic_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Text Input Field
                Expanded(
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: TextField(
                      controller: _textController,
                      decoration: const InputDecoration(
                        hintText: 'Speak or type command…',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onSubmitted: (val) {
                        if (val.trim().isNotEmpty) {
                          _handleUnifiedInput(val.trim());
                          _textController.clear();
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Send Button
                IconButton(
                  onPressed: () {
                    final text = _textController.text.trim();
                    if (text.isNotEmpty) {
                      _handleUnifiedInput(text);
                      _textController.clear();
                    }
                  },
                  icon: const Icon(
                    Icons.send_rounded,
                    color: Color(0xFF8B5CF6),
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Chat Items & Action Cards ─────────────────────────────────────────────

  Widget _buildChatMessageItem(VoiceChatMessage msg) {
    if (msg.isUser) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                ),
                borderRadius: BorderRadius.circular(18).copyWith(
                  bottomRight: const Radius.circular(2),
                ),
              ),
              child: Text(
                msg.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // AI Message
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFF8B5CF6),
              size: 15,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(18).copyWith(
                      topLeft: const Radius.circular(2),
                    ),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    msg.text,
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                // Quick Clarification Chips
                if (msg.quickOptions != null && msg.quickOptions!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: msg.quickOptions!.map((opt) {
                      return ActionChip(
                        label: Text(
                          opt,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF7C3AED),
                          ),
                        ),
                        backgroundColor: const Color(0xFFF5F3FF),
                        side: const BorderSide(color: Color(0xFFDDD6FE)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        onPressed: () => _handleUnifiedInput(opt),
                      );
                    }).toList(),
                  ),
                ],

                // Attached Action Card
                if (msg.actionType != ActionType.none &&
                    msg.actionData != null) ...[
                  const SizedBox(height: 8),
                  _buildActionCard(msg),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(VoiceChatMessage msg) {
    final data = msg.actionData!;

    // ── 1. Add Transaction Card ──
    if (msg.actionType == ActionType.addExpense) {
      final amount = (data['amount'] as num?)?.toDouble() ?? 0;
      final category = data['category'] as String? ?? 'Uncategorised';
      final note = data['note'] as String? ?? '';
      final isIncome = data['type'] == 'income';
      final date = data['date'] is DateTime ? data['date'] as DateTime : DateTime.now();
      final accountId = data['accountId'] as String?;
      final accountName = data['accountName'] as String?;
      final subcategory = data['subcategory'] as String?;

      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: msg.actionExecuted
                ? AppColors.success
                : const Color(0xFF8B5CF6).withValues(alpha: 0.35),
            width: 1.3,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0C000000),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isIncome ? AppColors.success : AppColors.danger)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isIncome ? 'Income' : 'Expense',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isIncome ? AppColors.success : AppColors.danger,
                    ),
                  ),
                ),
                Text(
                  (isIncome ? '+' : '-') + '₹' + amount.toStringAsFixed(0),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: isIncome ? AppColors.success : AppColors.danger,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              category + (subcategory != null ? ' • $subcategory' : '') + (note.isNotEmpty ? ' • $note' : ''),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.account_balance_wallet_outlined, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  accountName ?? 'None (Unspecified)',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.calendar_today_rounded, size: 13, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  DateFormat('MMM d • h:mm a').format(date),
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Edit in composer button
                Expanded(
                  child: OutlinedButton(
                    onPressed: msg.actionExecuted
                        ? null
                        : () {
                            Navigator.of(context).pop();
                            AppRoutes.pushAddExpense(
                              context,
                              initialAmount: amount,
                              initialCategory: category,
                              initialNote: note,
                              initialDate: date,
                              initialAccountId: accountId,
                              initialType: isIncome
                                  ? TransactionType.income
                                  : TransactionType.expense,
                            );
                          },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Edit in Composer',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Confirm & Save
                Expanded(
                  child: FilledButton.icon(
                    onPressed: msg.actionExecuted
                        ? null
                        : () async {
                            HapticFeedback.mediumImpact();
                            if (widget.returnResult) {
                              Navigator.of(context).pop(
                                ParsedCommand(
                                  amount: amount,
                                  type: isIncome
                                      ? TransactionType.income
                                      : TransactionType.expense,
                                  category: category,
                                  note: note,
                                  date: date,
                                  subcategory: subcategory,
                                  accountId: accountId,
                                  accountName: accountName,
                                ),
                              );
                              return;
                            }
                            await ref.read(expenseControllerProvider).addExpense(
                                  amount: amount,
                                  category: category,
                                  date: date,
                                  note: note,
                                  type: isIncome
                                      ? TransactionType.income
                                      : TransactionType.expense,
                                  accountId: accountId,
                                  subcategory: subcategory,
                                );
                            setState(() {
                              msg.actionExecuted = true;
                              _chatMessages.add(
                                VoiceChatMessage(
                                  isUser: false,
                                  text:
                                      "✓ Saved ₹${amount.toStringAsFixed(0)} for $category successfully!",
                                ),
                              );
                            });
                            _scrollToBottom();
                          },
                    icon: Icon(
                      msg.actionExecuted ? Icons.check_circle : Icons.check_rounded,
                      size: 16,
                    ),
                    label: Text(
                      msg.actionExecuted ? 'Saved' : 'Confirm & Save',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: msg.actionExecuted
                          ? AppColors.success
                          : const Color(0xFF8B5CF6),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // ── 2. Add Subscription Card ──
    if (msg.actionType == ActionType.addSubscription) {
      final name = data['name'] as String? ?? 'Subscription';
      final amount = (data['amount'] as num?)?.toDouble() ?? 0;
      final category = data['category'] as String? ?? 'Entertainment';

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: msg.actionExecuted
                ? AppColors.success
                : const Color(0xFF8B5CF6).withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  '₹${amount.toStringAsFixed(0)}/mo',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              category,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 34,
              child: ElevatedButton.icon(
                onPressed: msg.actionExecuted
                    ? null
                    : () async {
                        HapticFeedback.mediumImpact();
                        await ref
                            .read(recurringSubscriptionControllerProvider)
                            .saveSubscription(
                              name: name,
                              amount: amount,
                              nextBillDate:
                                  DateTime.now().add(const Duration(days: 30)),
                              iconKey: '📺',
                              billingPeriod: '1:month',
                            );
                        setState(() {
                          msg.actionExecuted = true;
                          _chatMessages.add(
                            VoiceChatMessage(
                              isUser: false,
                              text:
                                  "✓ Created recurring subscription for $name (₹${amount.toStringAsFixed(0)}/mo)!",
                            ),
                          );
                        });
                        _scrollToBottom();
                      },
                icon: Icon(
                  msg.actionExecuted ? Icons.check_circle : Icons.autorenew_rounded,
                  size: 16,
                ),
                label: Text(
                  msg.actionExecuted ? 'Saved' : 'Save Subscription',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: msg.actionExecuted
                      ? AppColors.success
                      : const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ── 3. Contribute to Savings Goal Card ──
    if (msg.actionType == ActionType.contributeGoal) {
      final goalName = data['goalName'] as String? ?? 'Goal';
      final amount = (data['amount'] as num?)?.toDouble() ?? 0;
      final current = (data['current'] as num?)?.toDouble() ?? 0;
      final target = (data['target'] as num?)?.toDouble() ?? 0;
      final goalId = data['goalId'] as String? ?? '';

      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: msg.actionExecuted
                ? AppColors.success
                : const Color(0xFF8B5CF6).withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text('🎯 ', style: TextStyle(fontSize: 16)),
                    Text(
                      goalName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
                Text(
                  '+₹${amount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF10B981),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Current: ₹${current.toStringAsFixed(0)} / Target: ₹${target.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 36,
              child: FilledButton.icon(
                onPressed: msg.actionExecuted
                    ? null
                    : () async {
                        HapticFeedback.mediumImpact();
                        await _addMoneyToGoal(goalId, amount);
                        setState(() {
                          msg.actionExecuted = true;
                          _chatMessages.add(
                            VoiceChatMessage(
                              isUser: false,
                              text:
                                  "✓ Added ₹${amount.toStringAsFixed(0)} to goal \"$goalName\"! New progress: ₹${(current + amount).toStringAsFixed(0)} / ₹${target.toStringAsFixed(0)}.",
                            ),
                          );
                        });
                        _scrollToBottom();
                      },
                icon: Icon(
                  msg.actionExecuted ? Icons.check_circle : Icons.savings_rounded,
                  size: 16,
                ),
                label: Text(
                  msg.actionExecuted ? 'Added to Goal' : 'Confirm & Add to Goal',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: msg.actionExecuted
                      ? AppColors.success
                      : const Color(0xFF8B5CF6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ── 4. Create New Goal Card ──
    if (msg.actionType == ActionType.createGoal) {
      final goalName = data['goalName'] as String? ?? 'New Goal';
      final targetAmount = (data['targetAmount'] as num?)?.toDouble() ?? 0;

      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: msg.actionExecuted
                ? AppColors.success
                : const Color(0xFF8B5CF6).withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text('🎯 ', style: TextStyle(fontSize: 16)),
                    Text(
                      goalName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Target: ₹${targetAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF8B5CF6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 36,
              child: FilledButton.icon(
                onPressed: msg.actionExecuted
                    ? null
                    : () async {
                        HapticFeedback.mediumImpact();
                        await _createNewGoal(goalName, targetAmount);
                        setState(() {
                          msg.actionExecuted = true;
                          _chatMessages.add(
                            VoiceChatMessage(
                              isUser: false,
                              text:
                                  "✓ Created new savings goal \"$goalName\" with target ₹${targetAmount.toStringAsFixed(0)}!",
                            ),
                          );
                        });
                        _scrollToBottom();
                      },
                icon: Icon(
                  msg.actionExecuted ? Icons.check_circle : Icons.flag_rounded,
                  size: 16,
                ),
                label: Text(
                  msg.actionExecuted ? 'Goal Created' : 'Confirm & Create Goal',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: msg.actionExecuted
                      ? AppColors.success
                      : const Color(0xFF8B5CF6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ── 5. App Command Card ──
    if (msg.actionType == ActionType.appCommand) {
      final cmd = data['command'] as String? ?? '';
      final label = data['label'] as String? ?? 'Execute';

      return SizedBox(
        width: double.infinity,
        height: 34,
        child: ElevatedButton.icon(
          onPressed: () {
            HapticFeedback.lightImpact();
            _executeAppCommand(cmd);
          },
          icon: const Icon(Icons.touch_app_rounded, size: 16),
          label: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8B5CF6),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // ── Goal Management Logic ──────────────────────────────────────────────────

  Future<void> _addMoneyToGoal(String goalId, double amount) async {
    final rawJson = ref.read(savingsGoalsJsonProvider);
    List<dynamic> list = [];
    try {
      if (rawJson.isNotEmpty) list = jsonDecode(rawJson) as List<dynamic>;
    } catch (_) {}

    final updated = list.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      if (map['id'] == goalId) {
        final cur = (map['currentAmount'] as num?)?.toDouble() ?? 0;
        map['currentAmount'] = cur + amount;
      }
      return map;
    }).toList();

    await ref.read(appPreferencesControllerProvider).setSavingsGoalsJson(jsonEncode(updated));
  }

  Future<void> _createNewGoal(String name, double target) async {
    final rawJson = ref.read(savingsGoalsJsonProvider);
    List<dynamic> list = [];
    try {
      if (rawJson.isNotEmpty) list = jsonDecode(rawJson) as List<dynamic>;
    } catch (_) {}

    final newGoal = {
      'id': 'goal_${DateTime.now().millisecondsSinceEpoch}',
      'name': name,
      'targetAmount': target,
      'currentAmount': 0.0,
      'emoji': '🎯',
      'colorHex': '#8B5CF6',
    };

    list.add(newGoal);
    await ref.read(appPreferencesControllerProvider).setSavingsGoalsJson(jsonEncode(list));
  }

  // ── Core Input Processing Pipeline ────────────────────────────────────────

  Future<void> _startVoiceInput() async {
    setState(() => _isListening = true);
    final text = await WidgetSyncService.startVoiceInput();
    setState(() => _isListening = false);

    if (text != null && text.trim().isNotEmpty) {
      _handleUnifiedInput(text.trim());
    }
  }

  Future<void> _handleUnifiedInput(String query) async {
    HapticFeedback.lightImpact();
    setState(() {
      _chatMessages.add(VoiceChatMessage(isUser: true, text: query));
      _isProcessing = true;
    });
    _scrollToBottom();

    final lower = query.toLowerCase();

    // Check if answering a pending clarification question
    if (_pendingDraft != null) {
      final amountMatch = RegExp(r'(\d+(?:[.,]\d{1,2})?)').firstMatch(query);
      if (amountMatch != null) {
        final amount = double.tryParse(amountMatch.group(1)!.replaceAll(',', '.')) ?? 0;
        if (amount > 0) {
          final draft = _pendingDraft!;
          _pendingDraft = null;
          draft['amount'] = amount;
          _finishResponse(
            "Got it! I prepared the ${draft['category']} transaction of ₹${amount.toStringAsFixed(0)}.",
            actionType: ActionType.addExpense,
            actionData: draft,
          );
          return;
        }
      }
    }

    // ── 1. Check quick app command intents ──
    if (lower.contains('dark mode') || lower.contains('dark theme')) {
      await ref.read(appPreferencesControllerProvider).setThemeMode('dark');
      _finishResponse(
        "I've switched the app to Dark mode.",
        actionType: ActionType.appCommand,
        actionData: {'command': 'dark_mode', 'label': 'Dark Mode Enabled'},
      );
      return;
    }

    if (lower.contains('light mode') || lower.contains('light theme')) {
      await ref.read(appPreferencesControllerProvider).setThemeMode('light');
      _finishResponse(
        "I've switched the app to Light mode.",
        actionType: ActionType.appCommand,
        actionData: {'command': 'light_mode', 'label': 'Light Mode Enabled'},
      );
      return;
    }

    if (lower.contains('privacy mode') || lower.contains('hide amount')) {
      final currentPrivacy = ref.read(privacyModeEnabledProvider);
      await ref.read(appPreferencesControllerProvider).setPrivacyMode(!currentPrivacy);
      _finishResponse(
        !currentPrivacy ? 'Privacy mode enabled.' : 'Privacy mode disabled.',
        actionType: ActionType.appCommand,
        actionData: {'command': 'privacy', 'label': 'Privacy Mode Toggled'},
      );
      return;
    }

    if (lower.contains('open settings') || lower == 'settings') {
      Navigator.of(context).pop();
      AppRoutes.pushSettings(context);
      return;
    }

    // ── 2. Check Savings Goal intents ──
    // e.g. "Add 500 to Vacation goal", "Put 1000 in phone", "Contribute 2000 to laptop"
    final contributeMatch = RegExp(
      r'(?:add|put|deposit|contribute|saved)\s+(?:₹|rs\.?\s*)?(\d+(?:[.,]\d{1,2})?)\s+(?:to|in|towards|for)\s+(.+?)(?:\s+goal)?$',
      caseSensitive: false,
    ).firstMatch(query);

    if (contributeMatch != null) {
      final amount = double.tryParse(contributeMatch.group(1)!.replaceAll(',', '.')) ?? 0;
      final targetName = contributeMatch.group(2)!.trim().toLowerCase();

      final rawGoals = ref.read(savingsGoalsJsonProvider);
      List<dynamic> goalsList = [];
      try {
        if (rawGoals.isNotEmpty) goalsList = jsonDecode(rawGoals) as List<dynamic>;
      } catch (_) {}

      Map<String, dynamic>? matchedGoal;
      for (final g in goalsList) {
        final gMap = Map<String, dynamic>.from(g as Map);
        final name = (gMap['name'] as String? ?? '').toLowerCase();
        if (name == targetName || name.contains(targetName) || targetName.contains(name)) {
          matchedGoal = gMap;
          break;
        }
      }

      if (matchedGoal != null && amount > 0) {
        _finishResponse(
          "I found your \"${matchedGoal['name']}\" goal. Ready to add ₹${amount.toStringAsFixed(0)}?",
          actionType: ActionType.contributeGoal,
          actionData: {
            'goalId': matchedGoal['id'],
            'goalName': matchedGoal['name'],
            'amount': amount,
            'current': (matchedGoal['currentAmount'] as num?)?.toDouble() ?? 0,
            'target': (matchedGoal['targetAmount'] as num?)?.toDouble() ?? 0,
          },
        );
        return;
      }
    }

    // e.g. "Create goal Laptop 50000" or "New goal Bike target 80000"
    final createGoalMatch = RegExp(
      r'(?:create|new|start|set)\s+goal\s+(.+?)\s+(?:target\s+|amount\s+|of\s+)?(?:₹|rs\.?\s*)?(\d+(?:[.,]\d{1,2})?)$',
      caseSensitive: false,
    ).firstMatch(query);

    if (createGoalMatch != null) {
      final goalName = createGoalMatch.group(1)!.trim();
      final targetAmount = double.tryParse(createGoalMatch.group(2)!.replaceAll(',', '.')) ?? 0;
      if (goalName.isNotEmpty && targetAmount > 0) {
        _finishResponse(
          "Ready to set up a new savings milestone for \"$goalName\" with a target of ₹${targetAmount.toStringAsFixed(0)}.",
          actionType: ActionType.createGoal,
          actionData: {
            'goalName': goalName,
            'targetAmount': targetAmount,
          },
        );
        return;
      }
    }

    // ── 3. Check Subscription intent ──
    if (lower.contains('subscript') ||
        lower.contains('netflix') ||
        lower.contains('spotify') ||
        lower.contains('youtube') ||
        lower.contains('recharge') ||
        lower.contains('hotstar') ||
        lower.contains('prime video')) {
      final amountMatch = RegExp(r'(\d+)').firstMatch(lower);
      final amount = amountMatch != null ? double.tryParse(amountMatch.group(1)!) ?? 199 : 199.0;
      String name = 'Subscription';
      if (lower.contains('netflix')) name = 'Netflix';
      else if (lower.contains('spotify')) name = 'Spotify';
      else if (lower.contains('youtube')) name = 'YouTube Premium';
      else if (lower.contains('recharge')) name = 'Mobile Recharge';
      else if (lower.contains('hotstar')) name = 'Disney+ Hotstar';
      else if (lower.contains('prime')) name = 'Amazon Prime';

      _finishResponse(
        "I've prepared a recurring subscription for $name.",
        actionType: ActionType.addSubscription,
        actionData: {
          'name': name,
          'amount': amount,
          'category': 'Entertainment',
        },
      );
      return;
    }

    // ── 4. Parse Expense / Income intent with DateTime recognition & Fallbacks ──
    final accounts = ref.read(accountListProvider).value ?? [];
    final expenseCats = ref.read(allExpenseCategoriesProvider);
    final incomeCats = ref.read(allIncomeCategoriesProvider);
    final subcats = ref.read(categorySubcategoriesProvider);

    final parsed = await _VoiceCommandParser.parse(
      query,
      accounts: accounts,
      expenseCategories: expenseCats,
      incomeCategories: incomeCats,
      categorySubcategories: subcats,
    );

    if (parsed != null && parsed.amount > 0) {
      final isIncome = parsed.type == TransactionType.income;
      final subInfo = parsed.subcategory != null ? " (${parsed.subcategory})" : "";
      final accInfo = parsed.accountName != null ? " via ${parsed.accountName}" : " (no account specified)";
      final dateInfo = parsed.date != null ? " on " + DateFormat('MMM d, h:mm a').format(parsed.date!) : "";

      _finishResponse(
        "Recognized " + (isIncome ? 'income' : 'expense') + " of ₹${parsed.amount.toStringAsFixed(0)} for ${parsed.category}$subInfo$accInfo$dateInfo.",
        actionType: ActionType.addExpense,
        actionData: {
          'amount': parsed.amount,
          'category': parsed.category,
          'note': parsed.note,
          'type': isIncome ? 'income' : 'expense',
          'date': parsed.date ?? DateTime.now(),
          if (parsed.subcategory != null) 'subcategory': parsed.subcategory,
          if (parsed.accountId != null) 'accountId': parsed.accountId,
          if (parsed.accountName != null) 'accountName': parsed.accountName,
        },
      );
      return;
    }

    // ── 5. Missing Amount Clarification Flow ──
    // If user mentioned an item or merchant without an amount, ask them!
    if (parsed != null && parsed.amount <= 0 && parsed.note.isNotEmpty) {
      _pendingDraft = {
        'amount': 0.0,
        'category': parsed.category,
        'note': parsed.note,
        'type': parsed.type == TransactionType.income ? 'income' : 'expense',
        'date': parsed.date ?? DateTime.now(),
        'accountId': parsed.accountId,
        'accountName': parsed.accountName,
        'subcategory': parsed.subcategory,
      };

      _finishResponse(
        "How much did you spend on \"${parsed.note}\"?",
        actionType: ActionType.clarification,
        quickOptions: ['₹50', '₹100', '₹250', '₹500', '₹1000'],
      );
      return;
    }

    // ── 6. Fallback reply ──
    _finishResponse(
      "I heard: \"$query\". You can say things like:\n• \"Spent 350 on Groceries today\"\n• \"Add 500 to Vacation goal\"\n• \"Salary 60000 yesterday\"\n• \"Create goal Phone 30000\"",
      quickOptions: ['Spent 250 lunch', 'Salary 50000', 'Add 500 to Vacation'],
    );
  }

  void _finishResponse(
    String text, {
    ActionType actionType = ActionType.none,
    Map<String, dynamic>? actionData,
    List<String>? quickOptions,
  }) {
    setState(() {
      _isProcessing = false;
      _chatMessages.add(
        VoiceChatMessage(
          isUser: false,
          text: text,
          actionType: actionType,
          actionData: actionData,
          quickOptions: quickOptions,
        ),
      );
    });
    _scrollToBottom();
  }

  void _executeAppCommand(String cmd) {
    if (cmd == 'settings') {
      Navigator.of(context).pop();
      AppRoutes.pushSettings(context);
    }
  }
}

// ── Smart Parser Engine ─────────────────────────────────────────────────────

abstract final class _VoiceCommandParser {
  static Map<String, dynamic>? _dict;

  static Future<Map<String, dynamic>> _loadDict() async {
    if (_dict != null) return _dict!;
    try {
      final raw = await rootBundle.loadString('assets/data/voice_keywords.json');
      _dict = (jsonDecode(raw) as Map<String, dynamic>);
      return _dict!;
    } catch (_) {
      return {};
    }
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

  static Future<ParsedCommand?> parse(
    String rawText, {
    List<AccountModel>? accounts,
    List<ExpenseCategory>? expenseCategories,
    List<ExpenseCategory>? incomeCategories,
    Map<String, List<String>>? categorySubcategories,
  }) async {
    final cleanInput = rawText.trim();
    if (cleanInput.isEmpty) return null;

    final dict = await _loadDict();

    // 1. Natural Date & Time Extraction using unified DateTimeParser
    final dateResult = DateTimeParser.parse(cleanInput);
    final resolvedDate = dateResult.dateTime;
    final workingText = dateResult.cleanedText;

    // 2. Extract numeric amount
    final amountRegex = RegExp(r'(?:₹|rs\.?\s*)?(\d+(?:[.,]\d{1,2})?)', caseSensitive: false);
    final amountMatch = amountRegex.firstMatch(workingText);

    double amount = 0;
    String amountStr = '';
    if (amountMatch != null) {
      amountStr = amountMatch.group(1)!.replaceAll(',', '.');
      amount = double.tryParse(amountStr) ?? 0;
    }

    final lowerText = workingText.toLowerCase();

    // 3. Detect TransactionType
    final type = _detectType(lowerText, dict);

    // 4. Match Accounts dynamically
    String? matchedAccountId;
    String? matchedAccountName;
    final consumedTokens = <String>{};

    if (accounts != null && accounts.isNotEmpty) {
      for (final acc in accounts) {
        final accNameLower = acc.name.toLowerCase();
        if (lowerText.contains(accNameLower)) {
          matchedAccountId = acc.id;
          matchedAccountName = acc.name;
          for (final token in accNameLower.split(RegExp(r'\s+'))) {
            if (token.isNotEmpty) consumedTokens.add(token);
          }
          break;
        }
      }

      // Check common aliases
      if (matchedAccountId == null) {
        if (lowerText.contains('paytm')) {
          final acc = accounts.firstWhere(
            (a) => a.name.toLowerCase().contains('paytm'),
            orElse: () => accounts.first,
          );
          matchedAccountId = acc.id;
          matchedAccountName = acc.name;
          consumedTokens.add('paytm');
        } else if (lowerText.contains('cash')) {
          final acc = accounts.firstWhere(
            (a) => a.name.toLowerCase().contains('cash'),
            orElse: () => accounts.first,
          );
          matchedAccountId = acc.id;
          matchedAccountName = acc.name;
          consumedTokens.add('cash');
        } else if (lowerText.contains('gpay') || lowerText.contains('google pay')) {
          final acc = accounts.firstWhere(
            (a) => a.name.toLowerCase().contains('gpay') || a.name.toLowerCase().contains('google'),
            orElse: () => accounts.first,
          );
          matchedAccountId = acc.id;
          matchedAccountName = acc.name;
          consumedTokens.addAll(['gpay', 'google', 'pay']);
        }
      }
    }

    // 5. Match Subcategory & Category dynamically
    String? matchedCategory;
    String? matchedSubcategory;

    if (categorySubcategories != null && categorySubcategories.isNotEmpty) {
      for (final entry in categorySubcategories.entries) {
        final parentCat = entry.key;
        for (final sub in entry.value) {
          final subLower = sub.toLowerCase();
          final subRegex = RegExp(r'\b' + RegExp.escape(subLower) + r'\b');
          if (subRegex.hasMatch(lowerText)) {
            matchedCategory = parentCat;
            matchedSubcategory = sub;
            for (final token in subLower.split(RegExp(r'\s+'))) {
              if (token.isNotEmpty) consumedTokens.add(token);
            }
            break;
          }
        }
        if (matchedCategory != null) break;
      }
    }

    if (matchedCategory == null) {
      final catList = (type == TransactionType.income ? incomeCategories : expenseCategories) ?? [];
      for (final cat in catList) {
        final catLower = cat.name.toLowerCase();
        final catTokens = catLower.split(RegExp(r'[\s&/]+')).where((t) => t.length > 2);
        for (final token in catTokens) {
          if (RegExp(r'\b' + RegExp.escape(token) + r'\b').hasMatch(lowerText)) {
            matchedCategory = cat.name;
            consumedTokens.add(token);
            break;
          }
        }
        if (matchedCategory != null) break;
      }
    }

    if (matchedCategory == null) {
      matchedCategory = _detectCategoryFromDict(lowerText, type, dict);
    }

    // Default category fallback to 'Uncategorised'
    matchedCategory ??= 'Uncategorised';

    // 6. Extract Note / Title
    final note = _extractSmartNote(
      workingText,
      amountStr,
      consumedTokens,
      matchedCategory,
      matchedSubcategory,
    );

    return ParsedCommand(
      amount: amount,
      type: type,
      category: matchedCategory,
      subcategory: matchedSubcategory,
      accountId: matchedAccountId, // default is null (None)
      accountName: matchedAccountName,
      note: note,
      date: resolvedDate ?? DateTime.now(),
    );
  }

  static TransactionType _detectType(String text, Map<String, dynamic> dict) {
    if (_any(text, _group(dict, 'transaction_types/transfer')) ||
        text.contains('transfer') || text.contains('bheja')) {
      return TransactionType.transfer;
    }
    if (_any(text, _group(dict, 'transaction_types/income')) ||
        text.contains('income') || text.contains('salary') || text.contains('credited') || text.contains('mila') || text.contains('aaya')) {
      return TransactionType.income;
    }
    return TransactionType.expense;
  }

  static String? _detectCategoryFromDict(
    String text,
    TransactionType type,
    Map<String, dynamic> dict,
  ) {
    if (type == TransactionType.transfer) return 'Transfer';

    if (type == TransactionType.income) {
      final incomeCats = dict['income_categories'] as Map<String, dynamic>? ?? {};
      for (final entry in incomeCats.entries) {
        final keywords = (entry.value as List).cast<String>();
        if (_any(text, keywords)) return entry.key;
      }
      return 'Salary';
    }

    final expenseCats = dict['expense_categories'] as Map<String, dynamic>? ?? {};
    for (final entry in expenseCats.entries) {
      final keywords = (entry.value as List).cast<String>();
      if (_any(text, keywords)) return entry.key;
    }

    if (text.contains('food') || text.contains('dinner') || text.contains('lunch') || text.contains('snack') || text.contains('cafe')) {
      return 'Food & Dining';
    }
    if (text.contains('uber') || text.contains('ola') || text.contains('auto') || text.contains('petrol') || text.contains('fuel')) {
      return 'Transportation';
    }
    if (text.contains('rent') || text.contains('kiraya') || text.contains('bijli') || text.contains('bill')) {
      return 'Bills & Utilities';
    }
    if (text.contains('gift') || text.contains('shopping') || text.contains('clothes')) {
      return 'Shopping';
    }

    return null;
  }

  static String _extractSmartNote(
    String rawText,
    String amountStr,
    Set<String> consumedTokens,
    String? matchedCategory,
    String? matchedSubcategory,
  ) {
    final stopWords = <String>{
      'a', 'an', 'the', 'on', 'for', 'at', 'in', 'of', 'to', 'from',
      'and', 'or', 'is', 'it', 'my', 'me', 'i', 'rs', 'inr', 'rupees',
      'rupee', 'add', 'new', 'entry', 'pe', 'par', 'ka', 'ki', 'ke',
      'se', 'ko', 'ne', 'kiya', 'hai', 'tha', 'thi', 'kharch',
      'diye', 'kharche', 'pay', 'paid', 'expense', 'income', 'transfer',
      'spent', 'amount', 'cost', 'debited', 'credited', 'bheja', 'mila'
    };

    if (matchedCategory != null) {
      for (final t in matchedCategory.toLowerCase().split(RegExp(r'[\s&/]+'))) {
        if (t.isNotEmpty) stopWords.add(t);
      }
    }

    final cleaned = (amountStr.isNotEmpty ? rawText.replaceAll(amountStr, ' ') : rawText)
        .replaceAll(RegExp(r'[,.\-_:;!?()]'), ' ');

    final words = cleaned
        .split(RegExp(r'\s+'))
        .map((w) => w.trim())
        .where((w) {
          final low = w.toLowerCase();
          return low.isNotEmpty &&
              !stopWords.contains(low) &&
              !consumedTokens.contains(low);
        })
        .toList();

    if (words.isNotEmpty) {
      words[0] = words[0][0].toUpperCase() + words[0].substring(1);
      return words.join(' ');
    }

    if (matchedSubcategory != null && matchedSubcategory.isNotEmpty) {
      return matchedSubcategory[0].toUpperCase() + matchedSubcategory.substring(1);
    }
    if (matchedCategory != null && matchedCategory.isNotEmpty && matchedCategory != 'Uncategorised') {
      return matchedCategory;
    }
    return '';
  }

  static bool _any(String text, List<String> keywords) =>
      keywords.any((k) => text.contains(k));
}

// ── Quick Suggestion Chip Widget ───────────────────────────────────────────

class _QuickChip extends StatelessWidget {
  const _QuickChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF6D28D9),
          ),
        ),
        backgroundColor: const Color(0xFFFAF5FF),
        side: const BorderSide(color: Color(0xFFE9D5FF), width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: () {
          HapticFeedback.selectionClick();
          onTap();
        },
      ),
    );
  }
}
