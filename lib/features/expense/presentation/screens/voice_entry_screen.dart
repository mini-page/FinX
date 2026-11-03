import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/widget_sync_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../routes/app_routes.dart';
import '../../data/models/expense_model.dart';
import '../provider/expense_providers.dart';
import 'package:expensio/features/settings/presentation/provider/preferences_providers.dart';
import 'package:expensio/features/recurring/presentation/provider/recurring_subscription_providers.dart';
import 'package:expensio/features/accounts/data/models/account_model.dart';
import 'package:expensio/features/accounts/presentation/provider/account_providers.dart';
import 'package:expensio/features/categories/presentation/widgets/expense_category.dart';

// ── Public entry point ─────────────────────────────────────────────────────

/// Shows the [VoiceEntryScreen] as a modal bottom-sheet.
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

// ── Voice Message Model ────────────────────────────────────────────────────

enum ActionType { none, addExpense, addSubscription, appCommand }

class VoiceChatMessage {
  VoiceChatMessage({
    required this.isUser,
    required this.text,
    this.actionType = ActionType.none,
    this.actionData,
    this.actionExecuted = false,
  });

  final bool isUser;
  final String text;
  final ActionType actionType;
  final Map<String, dynamic>? actionData;
  bool actionExecuted;
}

// ── Screen ─────────────────────────────────────────────────────────────────

class VoiceEntryScreen extends ConsumerStatefulWidget {
  const VoiceEntryScreen({super.key, this.returnResult = false});

  final bool returnResult;

  @override
  ConsumerState<VoiceEntryScreen> createState() => _VoiceEntryScreenState();
}

class _VoiceEntryScreenState extends ConsumerState<VoiceEntryScreen> {
  int _activeTab = 0; // 0 = AI Copilot, 1 = Quick Log (Generic)

  // ── AI Copilot State ──
  final List<VoiceChatMessage> _chatMessages = [];
  final TextEditingController _aiTextController = TextEditingController();
  final ScrollController _aiScrollController = ScrollController();
  bool _isAiListening = false;
  bool _isAiProcessing = false;

  // ── Quick Log (Generic) State ──
  _VoiceState _genericState = _VoiceState.idle;
  String? _genericRecognisedText;
  ParsedCommand? _genericParsed;

  @override
  void initState() {
    super.initState();
    _chatMessages.add(
      VoiceChatMessage(
        isUser: false,
        text:
            "Hi! I'm your Expensio AI Copilot. Speak or type to log transactions, manage subscriptions, or change settings.\n\nExamples:\n• \"Spent ₹450 at Dominos on dinner\"\n• \"Add Netflix subscription 499 monthly\"\n• \"Turn on dark mode\"",
      ),
    );
  }

  @override
  void dispose() {
    _aiTextController.dispose();
    _aiScrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_aiScrollController.hasClients) {
        _aiScrollController.animateTo(
          _aiScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.82,
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

          // Header with Dual-Tab Switcher
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _activeTab == 0 ? 'AI Copilot' : 'Quick Voice Log',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        _activeTab == 0
                            ? 'Natural voice agent with actions & chat'
                            : 'Fast offline parser (English / Hinglish)',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Dual Tab Switcher Pill
                _VoiceTabSwitcher(
                  currentIndex: _activeTab,
                  onSwitch: (tab) {
                    HapticFeedback.selectionClick();
                    setState(() => _activeTab = tab);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFFF1F5F9), height: 1),

          // Tab Body
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _activeTab == 0
                  ? _buildAiCopilotTab(bottomInset)
                  : _buildQuickLogTab(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 0: AI Copilot (Conversational + Actions) ──────────────────────────

  Widget _buildAiCopilotTab(double bottomInset) {
    return Column(
      key: const ValueKey('ai_copilot_tab'),
      children: [
        // Chat Message List
        Expanded(
          child: ListView.builder(
            controller: _aiScrollController,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            itemCount: _chatMessages.length,
            itemBuilder: (context, index) {
              final msg = _chatMessages[index];
              return _buildChatMessageItem(msg);
            },
          ),
        ),

        if (_isAiProcessing)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7B2FF7)),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Copilot is processing intent…',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF7B2FF7).withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),

        // Bottom Voice & Text Input Bar
        Container(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomInset),
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
              // Mic Button
              GestureDetector(
                onTap: _isAiListening ? null : _startAiVoiceInput,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: _isAiListening
                        ? AppColors.danger
                        : const Color(0xFF7B2FF7),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (_isAiListening
                                ? AppColors.danger
                                : const Color(0xFF7B2FF7))
                            .withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    _isAiListening ? Icons.mic : Icons.mic_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Text Field
              Expanded(
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _aiTextController,
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
                        _handleAiInput(val.trim());
                        _aiTextController.clear();
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Send Button
              IconButton(
                onPressed: () {
                  final text = _aiTextController.text.trim();
                  if (text.isNotEmpty) {
                    _handleAiInput(text);
                    _aiTextController.clear();
                  }
                },
                icon: const Icon(Icons.send_rounded,
                    color: Color(0xFF7B2FF7), size: 22),
              ),
            ],
          ),
        ),
      ],
    );
  }

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
                color: const Color(0xFF7B2FF7),
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

    // AI message
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF7B2FF7).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFF7B2FF7),
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
    if (msg.actionType == ActionType.addExpense) {
      final amount = (data['amount'] as num?)?.toDouble() ?? 0;
      final category = data['category'] as String? ?? 'Other';
      final note = data['note'] as String? ?? '';
      final isIncome = data['type'] == 'income';

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: msg.actionExecuted
                ? AppColors.success
                : const Color(0xFF7B2FF7).withValues(alpha: 0.3),
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (isIncome ? AppColors.success : AppColors.danger)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isIncome ? 'Income' : 'Expense',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: isIncome ? AppColors.success : AppColors.danger,
                    ),
                  ),
                ),
                Text(
                  (isIncome ? '+' : '-') + '₹' + amount.toStringAsFixed(0),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: isIncome ? AppColors.success : AppColors.danger,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '$category' + (note.isNotEmpty ? ' • ' + note : ''),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
                color: AppColors.textDark,
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
                        await ref.read(expenseControllerProvider).addExpense(
                              amount: amount,
                              category: category,
                              date: DateTime.now(),
                              note: note,
                              type: isIncome
                                  ? TransactionType.income
                                  : TransactionType.expense,
                            );
                        setState(() {
                          msg.actionExecuted = true;
                          _chatMessages.add(
                            VoiceChatMessage(
                              isUser: false,
                              text:
                                  "✓ Logged ₹" + amount.toStringAsFixed(0) + " $category transaction successfully!",
                            ),
                          );
                        });
                        _scrollToBottom();
                      },
                icon: Icon(
                  msg.actionExecuted ? Icons.check_circle : Icons.add_circle,
                  size: 16,
                ),
                label: Text(
                  msg.actionExecuted ? 'Logged' : 'Confirm & Log Transaction',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: msg.actionExecuted
                      ? AppColors.success
                      : const Color(0xFF7B2FF7),
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
                : const Color(0xFF7B2FF7).withValues(alpha: 0.3),
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
                  '₹' + amount.toStringAsFixed(0) + '/mo',
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
                                  "✓ Created recurring subscription for $name (₹" + amount.toStringAsFixed(0) + "/mo)!",
                            ),
                          );
                        });
                        _scrollToBottom();
                      },
                icon: Icon(
                  msg.actionExecuted
                      ? Icons.check_circle
                      : Icons.autorenew_rounded,
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
                      : const Color(0xFF7B2FF7),
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
            backgroundColor: const Color(0xFF7B2FF7),
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

  Future<void> _startAiVoiceInput() async {
    setState(() => _isAiListening = true);
    final text = await WidgetSyncService.startVoiceInput();
    setState(() => _isAiListening = false);

    if (text != null && text.trim().isNotEmpty) {
      _handleAiInput(text.trim());
    }
  }

  Future<void> _handleAiInput(String query) async {
    HapticFeedback.lightImpact();
    setState(() {
      _chatMessages.add(VoiceChatMessage(isUser: true, text: query));
      _isAiProcessing = true;
    });
    _scrollToBottom();

    final lower = query.toLowerCase();

    // ── 1. Check quick app command intents ──
    if (lower.contains('dark mode') || lower.contains('dark theme')) {
      await ref.read(appPreferencesControllerProvider).setThemeMode('dark');
      _finishAiResponse(
        "I've switched the app to Dark mode.",
        actionType: ActionType.appCommand,
        actionData: {'command': 'dark_mode', 'label': 'Dark Mode Enabled'},
      );
      return;
    }

    if (lower.contains('light mode') || lower.contains('light theme')) {
      await ref.read(appPreferencesControllerProvider).setThemeMode('light');
      _finishAiResponse(
        "I've switched the app to Light mode.",
        actionType: ActionType.appCommand,
        actionData: {'command': 'light_mode', 'label': 'Light Mode Enabled'},
      );
      return;
    }

    if (lower.contains('privacy mode') || lower.contains('hide amount')) {
      final currentPrivacy = ref.read(privacyModeEnabledProvider);
      await ref
          .read(appPreferencesControllerProvider)
          .setPrivacyMode(!currentPrivacy);
      _finishAiResponse(
        !currentPrivacy ? 'Privacy mode enabled.' : 'Privacy mode disabled.',
        actionType: ActionType.appCommand,
        actionData: {'command': 'privacy', 'label': 'Privacy Mode Toggled'},
      );
      return;
    }

    if (lower.contains('setting')) {
      Navigator.of(context).pop();
      AppRoutes.pushSettings(context);
      return;
    }

    // ── 2. Check subscription intent ──
    if (lower.contains('subscript') || lower.contains('netflix') || lower.contains('spotify') || lower.contains('youtube') || lower.contains('recharge')) {
      final amountMatch = RegExp(r'(\d+)').firstMatch(lower);
      final amount = amountMatch != null ? double.tryParse(amountMatch.group(1)!) ?? 199 : 199.0;
      String name = 'Subscription';
      if (lower.contains('netflix')) name = 'Netflix';
      else if (lower.contains('spotify')) name = 'Spotify';
      else if (lower.contains('youtube')) name = 'YouTube Premium';
      else if (lower.contains('recharge')) name = 'Mobile Recharge';

      _finishAiResponse(
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

    // ── 3. Parse expense / income intent ──
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
      final accInfo = parsed.accountName != null ? " via ${parsed.accountName}" : "";
      _finishAiResponse(
        "I recognized a " + (isIncome ? 'income' : 'expense') + " of ₹" + parsed.amount.toStringAsFixed(0) + " for " + parsed.category + subInfo + accInfo + ".",
        actionType: ActionType.addExpense,
        actionData: {
          'amount': parsed.amount,
          'category': parsed.category,
          'note': parsed.note,
          'type': isIncome ? 'income' : 'expense',
          if (parsed.subcategory != null) 'subcategory': parsed.subcategory,
          if (parsed.accountId != null) 'accountId': parsed.accountId,
          if (parsed.accountName != null) 'accountName': parsed.accountName,
        },
      );
      return;
    }

    // ── 4. General fallback conversational reply ──
    _finishAiResponse(
      "I heard: \"$query\". Try saying something like 'Spent 250 on food' or 'Add Netflix 499'.",
    );
  }

  void _finishAiResponse(
    String text, {
    ActionType actionType = ActionType.none,
    Map<String, dynamic>? actionData,
  }) {
    setState(() {
      _isAiProcessing = false;
      _chatMessages.add(
        VoiceChatMessage(
          isUser: false,
          text: text,
          actionType: actionType,
          actionData: actionData,
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

  // ── Tab 1: Quick Log (Fast Offline Heuristic Parser) ──────────────────────

  Widget _buildQuickLogTab() {
    return SingleChildScrollView(
      key: const ValueKey('quick_log_tab'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          // Sample prompts chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _SampleChip(
                label: '250 food expense',
                onTap: () => _runGenericVoiceWithText('250 food expense'),
              ),
              _SampleChip(
                label: 'chai pe 20 kharch kiye',
                onTap: () => _runGenericVoiceWithText('chai pe 20 kharch kiye'),
              ),
              _SampleChip(
                label: '500 auto rikshaw',
                onTap: () => _runGenericVoiceWithText('500 auto rikshaw'),
              ),
              _SampleChip(
                label: 'salary 50000 income',
                onTap: () => _runGenericVoiceWithText('salary 50000 income'),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // State-driven body
          if (_genericState == _VoiceState.idle) _buildGenericIdleBody(),
          if (_genericState == _VoiceState.listening) _buildGenericListeningBody(),
          if (_genericState == _VoiceState.result) _buildGenericResultBody(),
        ],
      ),
    );
  }

  Widget _buildGenericIdleBody() {
    return Column(
      children: [
        const Text(
          'Tap the microphone and speak naturally in English or Hinglish.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 32),
        _MicButton(onTap: _startGenericListening),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildGenericListeningBody() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
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

  Widget _buildGenericResultBody() {
    final cmd = _genericParsed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_genericRecognisedText != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceAccent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.record_voice_over_rounded,
                  color: AppColors.primaryBlue,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '"' + (_genericRecognisedText ?? '') + '"',
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

        if (cmd != null) ...[
          _ParsedPreview(command: cmd),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _confirmGenericCommand,
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
        ] else ...[
          const Text(
            "Couldn't understand that. Please try again.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
        ],

        const SizedBox(height: 8),
        TextButton(
          onPressed: () => setState(() {
            _genericState = _VoiceState.idle;
            _genericRecognisedText = null;
            _genericParsed = null;
          }),
          child: const Text('Try again'),
        ),
      ],
    );
  }

  Future<void> _startGenericListening() async {
    setState(() => _genericState = _VoiceState.listening);
    final text = await WidgetSyncService.startVoiceInput();
    if (!mounted) return;

    if (text == null || text.trim().isEmpty) {
      setState(() => _genericState = _VoiceState.idle);
      return;
    }

    _runGenericVoiceWithText(text.trim());
  }

  Future<void> _runGenericVoiceWithText(String text) async {
    final accounts = ref.read(accountListProvider).value ?? [];
    final expenseCats = ref.read(allExpenseCategoriesProvider);
    final incomeCats = ref.read(allIncomeCategoriesProvider);
    final subcats = ref.read(categorySubcategoriesProvider);

    final parsed = await _VoiceCommandParser.parse(
      text,
      accounts: accounts,
      expenseCategories: expenseCats,
      incomeCategories: incomeCats,
      categorySubcategories: subcats,
    );
    setState(() {
      _genericState = _VoiceState.result;
      _genericRecognisedText = text;
      _genericParsed = parsed;
    });
  }

  void _confirmGenericCommand() {
    final cmd = _genericParsed;
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
      initialSubcategory: cmd.subcategory,
      initialAccountId: cmd.accountId,
    );
  }
}

// ── Tab Switcher Capsule ───────────────────────────────────────────────────

class _VoiceTabSwitcher extends StatelessWidget {
  const _VoiceTabSwitcher({
    required this.currentIndex,
    required this.onSwitch,
  });

  final int currentIndex;
  final ValueChanged<int> onSwitch;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _VoiceTabItem(
            icon: Icons.auto_awesome_rounded,
            label: 'AI Copilot',
            selected: currentIndex == 0,
            onTap: () => onSwitch(0),
            accentColor: const Color(0xFF7B2FF7),
          ),
          const SizedBox(width: 4),
          _VoiceTabItem(
            icon: Icons.bolt_rounded,
            label: 'Quick Log',
            selected: currentIndex == 1,
            onTap: () => onSwitch(1),
            accentColor: AppColors.primaryBlue,
          ),
        ],
      ),
    );
  }
}

class _VoiceTabItem extends StatelessWidget {
  const _VoiceTabItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.accentColor,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: selected ? 12 : 8,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: selected ? accentColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: selected ? Colors.white : AppColors.textMuted,
              size: 15,
            ),
            if (selected) ...[
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 11.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Sample Prompt Chip ─────────────────────────────────────────────────────

class _SampleChip extends StatelessWidget {
  const _SampleChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: onTap,
      label: Text(label),
      labelStyle: const TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        color: AppColors.textDark,
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      side: const BorderSide(color: Color(0xFFE2E8F0)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}

// ── Mic Button ─────────────────────────────────────────────────────────────

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
            boxShadow: [
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

// ── Parsed Preview Card ────────────────────────────────────────────────────

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

    final categoryDisplay = command.subcategory != null && command.subcategory!.isNotEmpty
        ? '${command.category}  ·  ${command.subcategory!}'
        : command.category;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDE4F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
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
                  categoryDisplay,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                    fontSize: 15,
                  ),
                ),
              ),
              Text(
                '₹' + command.amount.toStringAsFixed(0),
                style: TextStyle(
                  color: typeColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          if (command.accountName != null && command.accountName!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.account_balance_wallet_rounded, size: 13, color: AppColors.textMuted),
                const SizedBox(width: 5),
                Text(
                  'Account: ${command.accountName!}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
          if (command.note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              command.note,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── State enum ─────────────────────────────────────────────────────────────

enum _VoiceState { idle, listening, result }

// ── Voice Command Parser ───────────────────────────────────────────────────

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
    final dict = await _loadDict();
    final cleanInput = rawText.trim();
    if (cleanInput.isEmpty) return null;

    // 1. Extract numeric amount
    final amountRegex = RegExp(r'(\d+(?:[.,]\d{1,2})?)');
    final amountMatch = amountRegex.firstMatch(cleanInput);
    if (amountMatch == null) return null;

    final amountStr = amountMatch.group(1)!.replaceAll(',', '.');
    final amount = double.tryParse(amountStr) ?? 0;
    if (amount <= 0) return null;

    final lowerText = cleanInput.toLowerCase();

    // 2. Detect TransactionType
    final type = _detectType(lowerText, dict);

    // 3. Match Accounts dynamically
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

    // 4. Match Subcategory & Category dynamically
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
      matchedCategory = _detectCategory(lowerText, type, dict);
    }

    // 5. Extract Note / Title
    final note = _extractSmartNote(
      cleanInput,
      amountStr,
      consumedTokens,
      matchedCategory,
      matchedSubcategory,
    );

    // 6. Detect Date
    final date = _detectDate(lowerText, dict);

    return ParsedCommand(
      amount: amount,
      type: type,
      category: matchedCategory,
      subcategory: matchedSubcategory,
      accountId: matchedAccountId,
      accountName: matchedAccountName,
      note: note,
      date: date,
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

  static String _detectCategory(
    String text,
    TransactionType type,
    Map<String, dynamic> dict,
  ) {
    if (type == TransactionType.transfer) return 'Transfer';

    if (type == TransactionType.income) {
      final incomeCats =
          dict['income_categories'] as Map<String, dynamic>? ?? {};
      for (final entry in incomeCats.entries) {
        final keywords = (entry.value as List).cast<String>();
        if (_any(text, keywords)) return entry.key;
      }
      return 'Salary';
    }

    final expenseCats =
        dict['expense_categories'] as Map<String, dynamic>? ?? {};
    for (final entry in expenseCats.entries) {
      final keywords = (entry.value as List).cast<String>();
      if (_any(text, keywords)) return entry.key;
    }

    // Heuristics for common Hindi / Hinglish terms
    if (text.contains('chai') || text.contains('nashta') || text.contains('khana') || text.contains('food') || text.contains('dinner') || text.contains('lunch')) {
      return 'Food & Dining';
    }
    if (text.contains('auto') || text.contains('cab') || text.contains('petrol') || text.contains('rickshaw') || text.contains('uber') || text.contains('ola')) {
      return 'Transportation';
    }
    if (text.contains('rent') || text.contains('kiraya') || text.contains('bijli') || text.contains('bill')) {
      return 'Bills & Utilities';
    }
    if (text.contains('gift') || text.contains('shopping') || text.contains('clothes')) {
      return 'Shopping';
    }

    return 'Other';
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

    final cleaned = rawText
        .replaceAll(amountStr, ' ')
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
    if (matchedCategory != null && matchedCategory.isNotEmpty && matchedCategory != 'Other') {
      return matchedCategory;
    }
    return '';
  }

  static DateTime? _detectDate(String text, Map<String, dynamic> dict) {
    final hints = dict['date_hints'] as Map<String, dynamic>? ?? {};
    final yesterdayKeys =
        (hints['yesterday'] as List?)?.cast<String>() ?? const <String>[];
    if (_any(text, yesterdayKeys) || text.contains('kal')) {
      return DateTime.now().subtract(const Duration(days: 1));
    }
    return null;
  }

  static bool _any(String text, List<String> keywords) =>
      keywords.any((k) => text.contains(k));
}
