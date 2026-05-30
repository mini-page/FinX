import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:xpens/core/theme/app_colors.dart';
import 'package:xpens/core/theme/app_tokens.dart';
import 'package:xpens/routes/app_routes.dart';
import 'package:xpens/features/expense/data/models/expense_model.dart';
import 'package:xpens/features/accounts/presentation/provider/account_providers.dart';
import 'package:xpens/features/accounts/data/models/account_model.dart';
import 'package:xpens/features/expense/presentation/provider/expense_providers.dart';
import 'package:xpens/features/settings/presentation/provider/preferences_providers.dart';
import 'package:xpens/features/recurring/presentation/widgets/recurring_tool_view.dart';
import 'package:xpens/features/accounts/presentation/widgets/split_bill_tool_view.dart';

const _maxDisplayedFutureTransactions = 6;

// ---------------------------------------------------------------------------
// Tab Bar & Tab View
// ---------------------------------------------------------------------------

/// Renders the tab views driven by [controller].
class ToolsTabView extends StatelessWidget {
  const ToolsTabView({super.key, required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return TabBarView(
      controller: controller,
      children: const <Widget>[
        _ToolsTabPane(child: GoalsToolView()),
        _ToolsTabPane(child: SplitBillToolView()),
        _ToolsTabPane(child: RecurringAndFutureToolView()),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Recurring & Future Tab Pane
// ---------------------------------------------------------------------------

class RecurringAndFutureToolView extends StatelessWidget {
  const RecurringAndFutureToolView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        RecurringToolView(),
        SizedBox(height: 32),
        FutureTransactionsToolView(),
      ],
    );
  }
}

/// Scroll wrapper used by each tool tab to prevent overflow.
class _ToolsTabPane extends StatelessWidget {
  const _ToolsTabPane({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(child: child);
  }
}

// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
// Goals / Savings Tab
// ---------------------------------------------------------------------------

/// Simple data class for a savings goal.
class _SavingsGoal {
  _SavingsGoal({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    this.emoji = '🎯',
    this.targetDate,
    this.colorHex = '#3B82F6',
    this.linkedAccountId,
  });

  factory _SavingsGoal.fromJson(Map<String, dynamic> map) => _SavingsGoal(
        id: map['id'] as String? ?? '',
        name: map['name'] as String? ?? 'Goal',
        targetAmount: (map['targetAmount'] as num?)?.toDouble() ?? 0,
        currentAmount: (map['currentAmount'] as num?)?.toDouble() ?? 0,
        emoji: map['emoji'] as String? ?? '🎯',
        targetDate: map['targetDate'] != null
            ? DateTime.tryParse(map['targetDate'] as String)
            : null,
        colorHex: map['colorHex'] as String? ?? '#3B82F6',
        linkedAccountId: map['linkedAccountId'] as String?,
      );

  final String id;
  String name;
  double targetAmount;
  double currentAmount;
  String emoji;
  DateTime? targetDate;
  String colorHex;
  String? linkedAccountId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'targetAmount': targetAmount,
        'currentAmount': currentAmount,
        'emoji': emoji,
        'targetDate': targetDate?.toIso8601String(),
        'colorHex': colorHex,
        'linkedAccountId': linkedAccountId,
      };
}

List<_SavingsGoal> _parseGoals(String json) {
  if (json.isEmpty) return [];
  try {
    final list = jsonDecode(json) as List<dynamic>;
    return list
        .cast<Map<String, dynamic>>()
        .map(_SavingsGoal.fromJson)
        .toList();
  } catch (_) {
    return [];
  }
}

String _encodeGoals(List<_SavingsGoal> goals) =>
    jsonEncode(goals.map((g) => g.toJson()).toList());

class _GoalProgressBar extends StatelessWidget {
  const _GoalProgressBar({
    required this.progress,
    required this.color,
  });

  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final progressWidth = width * progress.clamp(0.0, 1.0);

        return SizedBox(
          height: 18,
          child: Stack(
            alignment: Alignment.centerLeft,
            clipBehavior: Clip.none,
            children: [
              // Track
              Container(
                width: width,
                height: 6,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              // Progress Fill
              Container(
                width: progressWidth,
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              // Trophy Badge at the end of progress
              if (progressWidth > 0)
                Positioned(
                  left: (progressWidth - 9).clamp(0.0, width - 18),
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 3,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.emoji_events_rounded,
                        size: 9,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class GoalsToolView extends ConsumerWidget {
  const GoalsToolView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsJson = ref.watch(savingsGoalsJsonProvider);
    final goals = _parseGoals(goalsJson);
    final currency = ref.watch(currencyFormatProvider);
    final accounts = ref.watch(accountListProvider).value ?? [];
    final totalBalance = accounts.fold<double>(0, (s, a) => s + a.balance);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Savings Goals', style: AppTextStyles.sectionHeading),
                  Text(
                    'Track your financial milestones',
                    style: AppTextStyles.sectionSubtitle,
                  ),
                ],
              ),
            ),
            IconButton.filled(
              onPressed: () => _addGoal(context, ref, goals, currency),
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Add savings goal',
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        // Net worth hint
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: AppColors.lightBlueBg,
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.account_balance_wallet_outlined,
                color: AppColors.primaryBlue,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Available balance: ${currency.format(totalBalance)}',
                style: const TextStyle(
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        if (goals.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadii.xl),
            ),
            child: const Column(
              children: [
                Icon(Icons.flag_outlined, size: 48, color: AppColors.textMuted),
                SizedBox(height: AppSpacing.sm),
                Text(
                  'No goals yet',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Tap + to create your first savings goal.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ],
            ),
          )
        else
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(
                color: const Color(0xFFEDF2F7),
                width: 1,
              ),
            ),
            child: Column(
              children: List.generate(goals.length, (idx) {
                final goal = goals[idx];
                final linkedAccount = goal.linkedAccountId != null
                    ? accounts.where((a) => a.id == goal.linkedAccountId).firstOrNull
                    : null;
                final currentAmount = linkedAccount != null ? linkedAccount.balance : goal.currentAmount;
                final progress = goal.targetAmount > 0
                    ? (currentAmount / goal.targetAmount).clamp(0.0, 1.0)
                    : 0.0;
                final isLast = idx == goals.length - 1;

                return Column(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _addToGoal(context, ref, goals, idx, currency),
                      onDoubleTap: () => _editGoal(context, ref, goals, idx, currency),
                      onLongPress: () => _showGoalOptions(context, ref, goals, idx, currency),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                // Left Emoji Container
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF1F5F9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      goal.emoji,
                                      style: const TextStyle(fontSize: 22),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Name & Target Date
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        goal.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                          color: AppColors.textDark,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.calendar_today_outlined,
                                            size: 12,
                                            color: AppColors.textMuted,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            goal.targetDate != null
                                                ? DateFormat('MMM yyyy').format(goal.targetDate!)
                                                : 'No target date',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textMuted,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (linkedAccount != null) ...[
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.link_rounded,
                                              size: 12,
                                              color: AppColors.primaryBlue,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Linked: ${linkedAccount.name}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.primaryBlue,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                // Popup Menu Button for direct actions
                                PopupMenuButton<String>(
                                  color: Colors.white,
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(
                                    Icons.more_vert_rounded,
                                    color: AppColors.textMuted,
                                    size: 20,
                                  ),
                                  onSelected: (v) {
                                    if (v == 'edit') {
                                      _editGoal(context, ref, goals, idx, currency);
                                    } else if (v == 'delete') {
                                      _deleteGoal(ref, goals, idx);
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Edit', style: TextStyle(fontWeight: FontWeight.w600)),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Delete', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.redAccent)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Progress & Amounts Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: currency.format(currentAmount),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 13,
                                          color: _colorFromHex(goal.colorHex),
                                        ),
                                      ),
                                      const TextSpan(
                                        text: ' / ',
                                        style: TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 11,
                                        ),
                                      ),
                                      TextSpan(
                                        text: currency.format(goal.targetAmount),
                                        style: const TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${(progress * 100).toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    color: _colorFromHex(goal.colorHex),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _GoalProgressBar(
                              progress: progress,
                              color: _colorFromHex(goal.colorHex),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (!isLast)
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: Color(0xFFEDF2F7),
                        indent: 16,
                        endIndent: 16,
                      ),
                  ],
                );
              }),
            ),
          )
      ],
    );
  }

  Color _colorFromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  void _showGoalOptions(
    BuildContext context,
    WidgetRef ref,
    List<_SavingsGoal> goals,
    int idx,
    NumberFormat currency,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final goal = goals[idx];
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  goal.name,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.edit_rounded, color: AppColors.primaryBlue),
                title: const Text('Edit Goal', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _editGoal(context, ref, goals, idx, currency);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                title: const Text('Delete Goal', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteGoal(ref, goals, idx);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _addGoal(
    BuildContext context,
    WidgetRef ref,
    List<_SavingsGoal> goals,
    NumberFormat currency,
  ) async {
    await _showGoalDialog(context, ref, goals, null, currency);
  }

  Future<void> _editGoal(
    BuildContext context,
    WidgetRef ref,
    List<_SavingsGoal> goals,
    int idx,
    NumberFormat currency,
  ) async {
    await _showGoalDialog(context, ref, goals, idx, currency);
  }

  void _deleteGoal(WidgetRef ref, List<_SavingsGoal> goals, int idx) {
    final updated = List<_SavingsGoal>.from(goals)..removeAt(idx);
    ref.read(appPreferencesControllerProvider).setSavingsGoalsJson(
          _encodeGoals(updated),
        );
  }

  Future<void> _addToGoal(
    BuildContext context,
    WidgetRef ref,
    List<_SavingsGoal> goals,
    int idx,
    NumberFormat currency,
  ) async {
    final goal = goals[idx];
    if (goal.linkedAccountId != null) {
      final accounts = ref.read(accountListProvider).value ?? [];
      final linkedAccount = accounts.cast<AccountModel?>().firstWhere((a) => a?.id == goal.linkedAccountId, orElse: () => null);
      final accountName = linkedAccount?.name ?? 'Account';
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('This goal is linked to "$accountName". Add funds to this account directly to track progress.'),
          backgroundColor: AppColors.textDark,
        ),
      );
      return;
    }

    final amountController = TextEditingController();
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add to "${goals[idx].name}"'),
        content: TextField(
          controller: amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(hintText: 'Amount to add'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              ctx,
              double.tryParse(amountController.text),
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (result != null && result > 0) {
      final updated = List<_SavingsGoal>.from(goals);
      updated[idx] = _SavingsGoal(
        id: goals[idx].id,
        name: goals[idx].name,
        targetAmount: goals[idx].targetAmount,
        currentAmount: goals[idx].currentAmount + result,
        emoji: goals[idx].emoji,
        targetDate: goals[idx].targetDate,
        colorHex: goals[idx].colorHex,
      );
      await ref
          .read(appPreferencesControllerProvider)
          .setSavingsGoalsJson(_encodeGoals(updated));
    }
  }

  Future<void> _showGoalDialog(
    BuildContext context,
    WidgetRef ref,
    List<_SavingsGoal> goals,
    int? editIndex,
    NumberFormat currency,
  ) async {
    final existing = editIndex != null ? goals[editIndex] : null;
    final nameController = TextEditingController(text: existing?.name ?? '');
    final targetController = TextEditingController(
      text: existing != null ? existing.targetAmount.toStringAsFixed(0) : '',
    );
    final savedController = TextEditingController(
      text: existing != null ? existing.currentAmount.toStringAsFixed(0) : '',
    );

    // Initial state values for the new properties
    String selectedEmoji = existing?.emoji ?? '🎯';
    DateTime? selectedDate = existing?.targetDate;
    String selectedColorHex = existing?.colorHex ?? '#3B82F6';
    String? selectedAccountId = existing?.linkedAccountId;
    final accounts = ref.read(accountListProvider).value ?? [];

    final presetEmojis = [
      '🎯', '🏝️', '🏠', '🚗', '🎓', '💻',
      '✈️', '💍', '💰', '🎁', '🍔', '💪'
    ];

    final presetColors = [
      {'name': 'Blue', 'hex': '#3B82F6'},
      {'name': 'Purple', 'hex': '#A855F7'},
      {'name': 'Green', 'hex': '#10B981'},
      {'name': 'Orange', 'hex': '#F97316'},
      {'name': 'Rose', 'hex': '#F43F5E'},
      {'name': 'Teal', 'hex': '#0D9488'},
    ];

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            final activeColor = _colorFromHex(selectedColorHex);
            final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
            
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding + 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          existing == null ? 'New Savings Goal' : 'Edit Savings Goal',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            color: AppColors.textDark,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                          onPressed: () => Navigator.pop(ctx, false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Goal Name Field
                    const Text(
                      'Goal Name',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.textDark),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        hintText: 'e.g. Dream Vacation',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: activeColor, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Side-by-Side Target Amount and Already Saved
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Target Amount',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.textDark),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: targetController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  hintText: '0',
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(color: activeColor, width: 2),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Already Saved',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.textDark),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: savedController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  hintText: '0',
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(color: activeColor, width: 2),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Emoji Picker Row with custom add icon
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Select Icon / Emoji',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.textDark),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.textSecondary, size: 20),
                          onPressed: () async {
                            final emojiController = TextEditingController();
                            final customEmoji = await showDialog<String>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                title: const Text('Enter Custom Emoji', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                content: TextField(
                                  controller: emojiController,
                                  maxLength: 2,
                                  decoration: const InputDecoration(hintText: 'e.g. 🏡'),
                                  autofocus: true,
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, emojiController.text.trim()),
                                    child: const Text('Add'),
                                  ),
                                ],
                              ),
                            );
                            if (customEmoji != null && customEmoji.isNotEmpty) {
                              setState(() {
                                selectedEmoji = customEmoji;
                                if (!presetEmojis.contains(customEmoji)) {
                                  presetEmojis.insert(0, customEmoji);
                                }
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 52,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: presetEmojis.length,
                        itemBuilder: (context, index) {
                          final emoji = presetEmojis[index];
                          final isSelected = emoji == selectedEmoji;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedEmoji = emoji;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 50,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? activeColor.withOpacity(0.15)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? activeColor
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                emoji,
                                style: const TextStyle(fontSize: 22),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Date Picker Deadline Container Row
                    const Text(
                      'Target Date (Deadline)',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.textDark),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate ?? DateTime.now(),
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 3650)),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: activeColor,
                                  onPrimary: Colors.white,
                                  onSurface: AppColors.textDark,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_month_rounded,
                                  color: activeColor,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  selectedDate != null
                                      ? DateFormat('MMMM yyyy').format(selectedDate!)
                                      : 'No Deadline',
                                  style: TextStyle(
                                    color: selectedDate != null
                                        ? AppColors.textDark
                                        : AppColors.textMuted,
                                    fontWeight: selectedDate != null
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.textMuted,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Link to Account (Optional)
                    const Text(
                      'Link to Account (Optional)',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.textDark),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String?>(
                      value: selectedAccountId,
                      dropdownColor: Colors.white,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: activeColor, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      hint: const Text('No linked account (Manual)', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('No linked account (Manual)', style: TextStyle(fontSize: 14)),
                        ),
                        ...accounts.map((acc) => DropdownMenuItem<String?>(
                              value: acc.id,
                              child: Text(acc.name, style: const TextStyle(fontSize: 14)),
                            )),
                      ],
                      onChanged: (val) {
                        setState(() {
                          selectedAccountId = val;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Goal Theme Color
                    const Text(
                      'Goal Theme Color',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.textDark),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: presetColors.map((colorMap) {
                        final hex = colorMap['hex']!;
                        final color = _colorFromHex(hex);
                        final isSelected = hex == selectedColorHex;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedColorHex = hex;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? Colors.white : Colors.transparent,
                                width: 2,
                              ),
                              boxShadow: [
                                if (isSelected)
                                  BoxShadow(
                                    color: color.withOpacity(0.4),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                              ],
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  )
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    
                    // Full Width Save/Create Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: activeColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          existing == null ? 'Create Goal' : 'Save Goal',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == true) {
      final name = nameController.text.trim();
      final target = double.tryParse(targetController.text) ?? 0;
      final saved = double.tryParse(savedController.text) ?? 0;

      if (name.isEmpty) return;

      final updated = List<_SavingsGoal>.from(goals);
      if (editIndex != null) {
        updated[editIndex] = _SavingsGoal(
          id: goals[editIndex].id,
          name: name,
          targetAmount: target,
          currentAmount: saved,
          emoji: selectedEmoji,
          targetDate: selectedDate,
          colorHex: selectedColorHex,
          linkedAccountId: selectedAccountId,
        );
      } else {
        updated.add(_SavingsGoal(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: name,
          targetAmount: target,
          currentAmount: saved,
          emoji: selectedEmoji,
          targetDate: selectedDate,
          colorHex: selectedColorHex,
          linkedAccountId: selectedAccountId,
        ));
      }

      await ref
          .read(appPreferencesControllerProvider)
          .setSavingsGoalsJson(_encodeGoals(updated));
    }
  }
}

// ---------------------------------------------------------------------------
// Future Transactions Tab
// ---------------------------------------------------------------------------

/// Upcoming transactions that are dated after today.
class FutureTransactionsToolView extends ConsumerWidget {
  const FutureTransactionsToolView({super.key});

  IconData _getCategoryIcon(String category) {
    final catLower = category.toLowerCase();
    if (catLower.contains('food') || catLower.contains('restaurant') || catLower.contains('cafe')) {
      return Icons.restaurant_rounded;
    }
    if (catLower.contains('travel') || catLower.contains('car') || catLower.contains('uber')) {
      return Icons.directions_car_rounded;
    }
    if (catLower.contains('shopping') || catLower.contains('shop')) {
      return Icons.shopping_bag_rounded;
    }
    if (catLower.contains('bill') || catLower.contains('rent')) {
      return Icons.receipt_long_rounded;
    }
    if (catLower.contains('salary') || catLower.contains('income')) {
      return Icons.account_balance_rounded;
    }
    return Icons.payments_rounded;
  }

  Color _getCategoryColor(String category) {
    final catLower = category.toLowerCase();
    if (catLower.contains('food') || catLower.contains('restaurant') || catLower.contains('cafe')) {
      return const Color(0xFFF97316); // Orange
    }
    if (catLower.contains('travel') || catLower.contains('car') || catLower.contains('uber')) {
      return const Color(0xFF06B6D4); // Cyan
    }
    if (catLower.contains('shopping') || catLower.contains('shop')) {
      return const Color(0xFFEC4899); // Pink
    }
    if (catLower.contains('bill') || catLower.contains('rent')) {
      return const Color(0xFF3B82F6); // Blue
    }
    if (catLower.contains('salary') || catLower.contains('income')) {
      return const Color(0xFF10B981); // Green
    }
    return const Color(0xFF64748B); // Slate
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses =
        ref.watch(expenseListProvider).value ?? const <ExpenseModel>[];
    final currency = ref.watch(currencyFormatProvider);
    final today = DateUtils.dateOnly(DateTime.now());

    final futureTransactions = expenses
        .where(
          (expense) =>
              DateUtils.dateOnly(expense.date.toLocal()).isAfter(today),
        )
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final hasMore = futureTransactions.length > _maxDisplayedFutureTransactions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Header row — title + add button (mirrors RecurringToolView pattern)
        Row(
          children: <Widget>[
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Future Transactions',
                    style: AppTextStyles.sectionHeading,
                  ),
                  Text(
                    'Review and plan upcoming entries',
                    style: AppTextStyles.sectionSubtitle,
                  ),
                ],
              ),
            ),
            IconButton.filled(
              onPressed: () => AppRoutes.pushAddExpense(
                context,
                initialDate: today.add(const Duration(days: 1)),
              ),
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Add future transaction',
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // Empty state — icon + message (no separate floating CTA)
        if (futureTransactions.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xl,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadii.xl),
            ),
            child: Column(
              children: <Widget>[
                const Icon(
                  Icons.event_note_rounded,
                  size: 48,
                  color: AppColors.textMuted,
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'No upcoming transactions',
                  style: TextStyle(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                const Text(
                  'Add a transaction with a future date to plan ahead.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          )
        else ...<Widget>[
          ...futureTransactions
              .take(_maxDisplayedFutureTransactions)
              .map((expense) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadii.lg),
                child: InkWell(
                  onTap: () => AppRoutes.pushEditExpense(
                    context,
                    expenseId: expense.id,
                    initialAmount: expense.amount,
                    initialCategory: expense.category,
                    initialDate: expense.date.toLocal(),
                    initialNote: expense.note,
                    initialAccountId: expense.accountId,
                    initialToAccountId: expense.toAccountId,
                    initialType: expense.type,
                    initialSubcategory: expense.subcategory,
                    initialLatitude: expense.latitude,
                    initialLongitude: expense.longitude,
                  ),
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: <Widget>[
                        // Circle brand-colored icon
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: _getCategoryColor(expense.category),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            _getCategoryIcon(expense.category),
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                expense.note.isEmpty
                                    ? expense.category
                                    : expense.note,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textDark,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                DateFormat('EEE, d MMM').format(expense.date.toLocal()),
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          expense.isIncome
                              ? '+${currency.format(expense.amount)}'
                              : '-${currency.format(expense.amount)}',
                          style: TextStyle(
                            color: expense.isIncome
                                ? const Color(0xFF059669)
                                : const Color(0xFFDC2626),
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),

          // "View all (N)" escape when the list is capped
          if (hasMore)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => AppRoutes.pushRecordsHistory(context),
                child: Text(
                  'View all (${futureTransactions.length})',
                  style: const TextStyle(
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}
