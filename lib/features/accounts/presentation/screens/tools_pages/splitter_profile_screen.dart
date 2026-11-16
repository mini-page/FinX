import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:expensio/core/theme/app_colors.dart';
import 'package:expensio/core/theme/app_tokens.dart';
import 'package:expensio/features/accounts/accounts.dart';
import 'package:expensio/features/accounts/presentation/provider/participant_providers.dart';
import 'package:expensio/features/accounts/presentation/provider/settlement_providers.dart';
import 'package:expensio/features/accounts/data/models/settlement_model.dart';
import 'package:expensio/features/expense/data/models/expense_model.dart';
import 'package:expensio/features/expense/presentation/provider/expense_providers.dart';
import 'package:expensio/features/settings/presentation/provider/preferences_providers.dart';

class SplitterProfileScreen extends ConsumerWidget {
  const SplitterProfileScreen({
    super.key,
    required this.participantId,
    required this.participantName,
  });

  final String participantId;
  final String participantName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settlements = ref.watch(settlementListProvider).value ?? const <SettlementModel>[];
    final expenses = ref.watch(expenseListProvider).value ?? const <ExpenseModel>[];
    final currency = ref.watch(currencyFormatProvider);

    // Filter pending and settled records for this splitter
    final pending = settlements.where((s) =>
        !s.isSettled &&
        (s.fromParticipantId == participantId || s.toParticipantId == participantId)).toList();
    final settled = settlements.where((s) =>
        s.isSettled &&
        (s.fromParticipantId == participantId || s.toParticipantId == participantId)).toList();

    // Filter expenses / splits involving this splitter
    final relevantExpenses = expenses.where((e) {
      final note = e.note.toLowerCase();
      final pNameLower = participantName.toLowerCase();
      return note.contains(pNameLower) ||
          (e.splitMethod != null && e.splitMethod!.isNotEmpty && note.contains('split'));
    }).toList();

    // Calculate net balance:
    // If fromParticipantId == participantId: participant owes to (user or another), balance is negative for them / positive for user
    double netBalance = 0;
    for (final s in pending) {
      if (s.fromParticipantId == participantId) {
        netBalance -= s.amount;
      }
      if (s.toParticipantId == participantId) {
        netBalance += s.amount;
      }
    }

    final isZero = netBalance.abs() < 0.01;
    final owesYou = netBalance < -0.01; // They owe money

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            margin: const EdgeInsets.only(left: 12),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.chevron_left_rounded,
              color: AppColors.textDark,
              size: 22,
            ),
          ),
        ),
        title: Text(
          participantName,
          style: const TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.textDark, size: 20),
            tooltip: 'Rename Splitter',
            onPressed: () => _showEditSplitterDialog(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 20),
            tooltip: 'Delete Splitter',
            onPressed: () => _confirmDeleteSplitter(context, ref, pending.isNotEmpty),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          // ── Net Balance Card ───────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadii.lg),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.1),
                  child: Text(
                    participantName.isNotEmpty ? participantName[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Net Balance with $participantName',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isZero
                      ? currency.format(0)
                      : '${netBalance >= 0 ? '+' : '-'}${currency.format(netBalance.abs())}',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: isZero
                        ? AppColors.textDark
                        : (owesYou ? AppColors.success : AppColors.danger),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isZero
                      ? 'All settled up • No pending dues'
                      : (owesYou
                          ? '$participantName owes you ${currency.format(netBalance.abs())}'
                          : 'You owe $participantName ${currency.format(netBalance.abs())}'),
                  style: TextStyle(
                    color: isZero ? AppColors.textMuted : (owesYou ? AppColors.success : AppColors.danger),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                if (!isZero) ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        HapticFeedback.mediumImpact();
                        final controller = ref.read(settlementControllerProvider);
                        for (final s in pending) {
                          await controller.markSettled(s.id);
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('All pending dues with $participantName settled!')),
                          );
                        }
                      },
                      icon: const Icon(Icons.handshake_rounded, size: 18),
                      label: const Text('Settle Up All Dues', style: TextStyle(fontWeight: FontWeight.w800)),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.success,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Pending Settlements ────────────────────────────────────────────
          if (pending.isNotEmpty) ...[
            Text(
              'Pending Settlements (${pending.length})',
              style: const TextStyle(
                color: AppColors.textDark,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            ...pending.map((s) => _SplitterSettlementTile(
                  settlement: s,
                  currency: currency,
                  showSettleButton: true,
                  onSettle: () async {
                    HapticFeedback.selectionClick();
                    await ref.read(settlementControllerProvider).markSettled(s.id);
                  },
                )),
            const SizedBox(height: 24),
          ],

          // ── Shared Records / Splits ────────────────────────────────────────
          if (relevantExpenses.isNotEmpty) ...[
            Text(
              'Recent Splits & Records (${relevantExpenses.length})',
              style: const TextStyle(
                color: AppColors.textDark,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            ...relevantExpenses.take(8).map((e) => Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.08),
                        child: const Icon(Icons.call_split_rounded, size: 14, color: AppColors.primaryBlue),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.note.isNotEmpty ? e.note : e.category,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: AppColors.textDark,
                              ),
                            ),
                            Text(
                              DateFormat('d MMM yyyy, h:mm a').format(e.date),
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        currency.format(e.amount),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 24),
          ],

          // ── Settled History ────────────────────────────────────────────────
          if (settled.isNotEmpty) ...[
            Text(
              'Settlement History (${settled.length})',
              style: const TextStyle(
                color: AppColors.textDark,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            ...settled.map((s) => _SplitterSettlementTile(
                  settlement: s,
                  currency: currency,
                  showSettleButton: false,
                )),
          ],

          if (pending.isEmpty && settled.isEmpty && relevantExpenses.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(
                child: Text(
                  'No transactions or settlements recorded with this splitter yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showEditSplitterDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: participantName);
    final updated = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Edit Splitter Name', style: TextStyle(fontWeight: FontWeight.w800)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Full Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) Navigator.pop(ctx, text);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (updated != null && updated != participantName) {
      final participantNotifier = ref.read(participantListProvider.notifier);
      await participantNotifier.saveParticipant(
        ParticipantModel(id: participantId, name: updated),
      );
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Updated to $updated')),
        );
      }
    }
  }

  Future<void> _confirmDeleteSplitter(BuildContext context, WidgetRef ref, bool hasPending) async {
    if (hasPending) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Cannot Delete Splitter', style: TextStyle(fontWeight: FontWeight.w800)),
          content: Text('$participantName still has pending dues. Settle them first before deleting.'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Delete $participantName?', style: const TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('This will remove this person from your splitters list.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(participantListProvider.notifier).deleteParticipant(participantId);
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Removed $participantName')),
        );
      }
    }
  }
}

class _SplitterSettlementTile extends StatelessWidget {
  const _SplitterSettlementTile({
    required this.settlement,
    required this.currency,
    required this.showSettleButton,
    this.onSettle,
  });

  final SettlementModel settlement;
  final NumberFormat currency;
  final bool showSettleButton;
  final VoidCallback? onSettle;

  @override
  Widget build(BuildContext context) {
    final isSettled = settlement.isSettled;

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.md),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: isSettled
                ? AppColors.primaryBlue.withValues(alpha: 0.1)
                : AppColors.success.withValues(alpha: 0.1),
            child: Icon(
              isSettled ? Icons.check_circle_rounded : Icons.sync_alt_rounded,
              size: 16,
              color: isSettled ? AppColors.primaryBlue : AppColors.success,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${settlement.fromParticipantName} → ${settlement.toParticipantName}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.textDark,
                  ),
                ),
                if (settlement.expenseDescription != null)
                  Text(
                    settlement.expenseDescription!,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                Text(
                  DateFormat('d MMM yyyy').format(settlement.createdAt),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                currency.format(settlement.amount),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: AppColors.textDark,
                ),
              ),
              if (isSettled)
                Text(
                  'Settled ${DateFormat('d MMM').format(settlement.settledAt!)}',
                  style: const TextStyle(
                    color: AppColors.success,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (!isSettled && showSettleButton && onSettle != null)
                GestureDetector(
                  onTap: onSettle,
                  child: Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    child: const Text(
                      'Settle Up',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
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
}
