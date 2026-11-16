import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import 'package:expensio/core/theme/app_colors.dart';
import 'package:expensio/core/theme/app_tokens.dart';
import 'package:expensio/core/utils/tag_parser.dart';
import 'package:expensio/features/accounts/data/models/account_model.dart';
import 'package:expensio/features/accounts/presentation/widgets/account_icons.dart';
import 'package:expensio/features/categories/presentation/widgets/expense_category.dart';
import 'package:expensio/features/settings/presentation/provider/preferences_providers.dart';
import 'package:expensio/features/expense/data/models/expense_model.dart';
import 'package:expensio/features/expense/presentation/provider/expense_providers.dart';
import '../screens/add_expense_screen.dart';

/// Modal bottom sheet displaying complete details of a transaction.
/// Features top action icons: [Edit], [Delete], [Share], [Close],
/// along with receipt image preview, notes, hashtags, account, and location.
Future<void> showTransactionDetailsSheet(
  BuildContext context, {
  required ExpenseModel expense,
  required List<AccountModel> accounts,
  required void Function(ExpenseModel) onEdit,
  required void Function(ExpenseModel) onDelete,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _TransactionDetailsSheet(
      expense: expense,
      accounts: accounts,
      onEdit: onEdit,
      onDelete: onDelete,
    ),
  );
}

class _TransactionDetailsSheet extends ConsumerWidget {
  const _TransactionDetailsSheet({
    required this.expense,
    required this.accounts,
    required this.onEdit,
    required this.onDelete,
  });

  final ExpenseModel expense;
  final List<AccountModel> accounts;
  final void Function(ExpenseModel) onEdit;
  final void Function(ExpenseModel) onDelete;

  void _shareTransaction(BuildContext context, NumberFormat currency) {
    HapticFeedback.lightImpact();
    final typeStr = expense.type == TransactionType.income
        ? 'Income'
        : expense.type == TransactionType.transfer
            ? 'Transfer'
            : 'Expense';
    final sign = expense.isIncome ? '+' : '-';
    final text = '📋 Expensio Transaction Details\n'
        'Type: $typeStr\n'
        'Amount: $sign${currency.format(expense.amount)}\n'
        'Category: ${expense.category}${expense.subcategory != null ? " / ${expense.subcategory}" : ""}\n'
        'Date: ${DateFormat('d MMM yyyy, h:mm a').format(expense.date)}\n'
        '${expense.note.isNotEmpty ? "Note: ${expense.note}\n" : ""}'
        'Recorded via Expensio';
    SharePlus.instance.share(ShareParams(text: text));
  }

  void _confirmDelete(BuildContext context) {
    HapticFeedback.mediumImpact();
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transaction?'),
        content: const Text('Are you sure you want to delete this transaction? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true && context.mounted) {
        Navigator.of(context).pop();
        onDelete(expense);
      }
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(currencyFormatProvider);
    final allExpenseCategories = ref.watch(allExpenseCategoriesProvider);
    final allIncomeCategories = ref.watch(allIncomeCategoriesProvider);
    final isIncome = expense.type == TransactionType.income;
    final isTransfer = expense.type == TransactionType.transfer;

    final account = accounts.where((a) => a.id == expense.accountId).firstOrNull;
    final toAccount = isTransfer
        ? accounts.where((a) => a.id == expense.toAccountId).firstOrNull
        : null;

    final category = resolveCategory(
      expense.category,
      income: expense.isIncome,
      extra: expense.isIncome ? allIncomeCategories : allExpenseCategories,
    );

    final cleanNote = TagParser.stripTags(expense.note).trim();
    final tags = TagParser.extractTags(expense.note);
    final hasLocation = expense.latitude != null && expense.longitude != null;
    final locationStr = hasLocation
        ? '${expense.latitude!.toStringAsFixed(4)}, ${expense.longitude!.toStringAsFixed(4)}'
        : null;

    final typeColor = isIncome
        ? AppColors.success
        : isTransfer
            ? const Color(0xFF8B5CF6)
            : AppColors.danger;

    final typeLabel = isIncome
        ? 'Income'
        : isTransfer
            ? 'Transfer'
            : 'Expense';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Top Action Bar: Edit, Delete, Share, Close
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.textDark),
                    tooltip: 'Edit',
                    onPressed: () {
                      Navigator.of(context).pop();
                      onEdit(expense);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.share_outlined, size: 20, color: AppColors.textDark),
                    tooltip: 'Share',
                    onPressed: () => _shareTransaction(context, currency),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.danger),
                    tooltip: 'Delete',
                    onPressed: () => _confirmDelete(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22, color: AppColors.textMuted),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Amount & Date
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${isIncome ? '+' : '-'}${currency.format(expense.amount)}',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: typeColor,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            DateFormat('EEEE, d MMMM yyyy • h:mm a').format(expense.date),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 20),

          const Divider(height: 1, color: Color(0xFFEDF2F7)),
          const SizedBox(height: 16),

          // Detail rows
          // Category & Subcategory
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: category.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(category.icon, color: category.color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.category,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    if (expense.subcategory != null && expense.subcategory!.isNotEmpty)
                      Text(
                        expense.subcategory!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Account
          if (account != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(resolveAccountIcon(account.iconKey), color: AppColors.primaryBlue, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isTransfer && toAccount != null
                              ? '\ -> '
                              : account.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          'Balance: ' + currency.format(account.balance),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          // Note
          if (cleanNote.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFEDF2F7)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'NOTE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMuted,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    cleanNote,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Hashtags badges
          if (tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: tags.map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      '#$tag',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4F46E5),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

          // Location
          if (hasLocation)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on_rounded, size: 16, color: AppColors.primaryBlue),
                  const SizedBox(width: 6),
                  Text(
                    locationStr!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
