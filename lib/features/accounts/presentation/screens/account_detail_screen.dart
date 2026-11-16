import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:expensio/core/theme/app_colors.dart';
import 'package:expensio/routes/app_routes.dart';
import 'package:expensio/features/accounts/data/models/account_model.dart';
import 'package:expensio/features/accounts/presentation/provider/account_providers.dart';
import 'package:expensio/features/accounts/presentation/widgets/account_editor_sheet.dart';
import 'package:expensio/features/accounts/presentation/widgets/account_icons.dart';
import 'package:expensio/features/expense/data/models/expense_model.dart';
import 'package:expensio/features/expense/presentation/provider/expense_providers.dart';
import 'package:expensio/features/settings/presentation/provider/preferences_providers.dart';

class AccountDetailScreen extends ConsumerStatefulWidget {
  const AccountDetailScreen({
    super.key,
    required this.accountId,
  });

  final String accountId;

  @override
  ConsumerState<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends ConsumerState<AccountDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(currencyFormatProvider);
    final accountState = ref.watch(accountListProvider);
    final accounts = accountState.value ?? const <AccountModel>[];
    final account = accounts.where((a) => a.id == widget.accountId).firstOrNull;

    if (account == null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundLight,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: const Center(
          child: Text('Account not found or has been deleted.', style: TextStyle(color: AppColors.textMuted)),
        ),
      );
    }

    final expenses = ref.watch(expenseListProvider).value ?? const <ExpenseModel>[];

    // Filter transactions involving this account
    final accountTransactions = expenses.where((e) {
      return e.accountId == account.id || e.toAccountId == account.id;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    // Calculate total inflows and outflows
    double totalInflow = 0.0;
    double totalOutflow = 0.0;
    for (final e in accountTransactions) {
      if (e.type == TransactionType.income && e.accountId == account.id) {
        totalInflow += e.amount;
      } else if (e.type == TransactionType.expense && e.accountId == account.id) {
        totalOutflow += e.amount;
      } else if (e.type == TransactionType.transfer) {
        if (e.toAccountId == account.id) {
          totalInflow += e.amount;
        } else if (e.accountId == account.id) {
          totalOutflow += e.amount;
        }
      }
    }

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
          account.name,
          style: const TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.textDark, size: 20),
            tooltip: 'Edit Account',
            onPressed: () => _editAccount(account),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 20),
            tooltip: 'Delete Account',
            onPressed: () => _confirmDelete(account),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          // ── Balance Hero Card ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  AppColors.primaryBlue,
                  AppColors.primaryBlueLight,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryBlue.withValues(alpha: 0.28),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          child: Icon(resolveAccountIcon(account.iconKey), color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          account.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Active Account',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Current Balance',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  currency.format(account.balance),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total Inflows',
                              style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '+${currency.format(totalInflow)}',
                              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total Outflows',
                              style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '-${currency.format(totalOutflow)}',
                              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Transactions Section ──────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Transactions (${accountTransactions.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (accountTransactions.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 36),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.account_balance_wallet_outlined, size: 42, color: AppColors.textMuted.withValues(alpha: 0.5)),
                  const SizedBox(height: 10),
                  const Text(
                    'No transactions recorded under this account.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: accountTransactions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final txn = accountTransactions[index];
                final isIncoming = txn.type == TransactionType.income ||
                    (txn.type == TransactionType.transfer && txn.toAccountId == account.id);
                return InkWell(
                  onTap: () {
                    AppRoutes.pushEditExpense(
                      context,
                      expenseId: txn.id,
                      initialAmount: txn.amount,
                      initialCategory: txn.category,
                      initialDate: txn.date.toLocal(),
                      initialNote: txn.note,
                      initialAccountId: txn.accountId,
                      initialToAccountId: txn.toAccountId,
                      initialType: txn.type,
                      initialSubcategory: txn.subcategory,
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: isIncoming
                              ? AppColors.success.withValues(alpha: 0.12)
                              : AppColors.danger.withValues(alpha: 0.12),
                          child: Icon(
                            isIncoming ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                            color: isIncoming ? AppColors.success : AppColors.danger,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                txn.note.isNotEmpty ? txn.note : txn.category,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: AppColors.textDark,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${DateFormat('d MMM yyyy').format(txn.date)} • ${txn.category}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${isIncoming ? '+' : '-'}${currency.format(txn.amount)}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: isIncoming ? AppColors.success : AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _editAccount(AccountModel account) async {
    final result = await showAccountEditorSheet(context, account: account);
    if (result == null || !mounted) return;

    if (result.isDelete) {
      await ref.read(accountControllerProvider).deleteAccount(account.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${account.name} deleted.')),
      );
      return;
    }

    await ref.read(accountControllerProvider).saveAccount(
          id: account.id,
          name: result.name,
          iconKey: result.iconKey,
          balance: result.balance,
        );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${result.name} updated.')),
    );
  }

  Future<void> _confirmDelete(AccountModel account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to delete "${account.name}"? Transactions assigned to this account will remain in your history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(accountControllerProvider).deleteAccount(account.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${account.name} deleted.')),
      );
    }
  }
}
