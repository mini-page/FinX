import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:xpens/core/theme/app_colors.dart';
import 'package:xpens/core/theme/app_tokens.dart';
import 'package:xpens/shared/widgets/app_pill_switch.dart';
import 'package:xpens/features/accounts/data/models/account_model.dart';
import 'package:xpens/features/accounts/presentation/provider/account_providers.dart';
import 'package:xpens/features/expense/presentation/provider/expense_providers.dart';
import 'package:xpens/features/settings/presentation/provider/preferences_providers.dart';
import 'package:xpens/features/accounts/presentation/widgets/account_editor_sheet.dart';
import 'package:xpens/features/accounts/presentation/widgets/account_icons.dart';
import 'package:xpens/features/expense/presentation/widgets/amount_visibility.dart';
import 'package:xpens/features/recurring/presentation/widgets/recurring_tool_view.dart';
import 'package:xpens/features/accounts/presentation/widgets/split_bill_tool_view.dart';
import 'package:xpens/features/expense/presentation/widgets/ui_feedback.dart';

/// Tools tab showing split-bill and recurring tools.
class AccountsToolsTabView extends StatelessWidget {
  const AccountsToolsTabView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const <Widget>[
        SplitBillToolView(),
        SizedBox(height: 32),
        RecurringToolView(),
      ],
    );
  }
}

/// Two-option pill toggle used for the Accounts / Tools tab.
///
/// Thin wrapper around the shared [AppPillSwitch] that preserves the
/// existing call-site API.
typedef AccountsPillSwitch = AppPillSwitch;

/// A labelled summary chip shown in the net-worth hero card.
class AccountsSummaryChip extends StatelessWidget {
  const AccountsSummaryChip({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.overlayWhiteSoft,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AppColors.overlayWhiteStrong,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Card showing a single account row with balance and edit/delete popup.
class AccountCard extends StatelessWidget {
  const AccountCard({
    super.key,
    required this.account,
    required this.balanceText,
    required this.isNegative,
    required this.onTap,
    required this.onDelete,
  });

  final AccountModel account;
  final String balanceText;
  final bool isNegative;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  resolveAccountIcon(account.iconKey),
                  color: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      account.name,
                      style: const TextStyle(
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Balance: ${isNegative ? '-' : ''}$balanceText',
                        style: TextStyle(
                          color: isNegative
                              ? AppColors.danger
                              : AppColors.primaryBlue,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_horiz_rounded,
                  color: AppColors.textMuted,
                ),
                onSelected: (value) {
                  if (value == 'delete') {
                    onDelete();
                  } else {
                    onTap();
                  }
                },
                itemBuilder: (context) => const <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(value: 'edit', child: Text('Edit')),
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Text('Delete'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Placeholder card shown when no accounts exist yet.
class EmptyAccountsCard extends StatelessWidget {
  const EmptyAccountsCard({super.key, required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.wallet_outlined,
              size: 42,
              color: AppColors.primaryBlue,
            ),
            const SizedBox(height: 12),
            const Text(
              'No accounts yet',
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create your first account to track balances.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onCreate,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
              ),
              child: const Text('Create Account'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sliver content for the Accounts tab: net-worth hero card + scrollable
/// account list. Handles loading, empty, and error states and owns the
/// edit / delete account actions.
class SliverAccountsTabView extends ConsumerWidget {
  const SliverAccountsTabView({super.key, required this.currency});

  final NumberFormat currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statsProvider);
    final accountState = ref.watch(accountListProvider);
    final summary = ref.watch(accountSummaryProvider);
    final privacyModeEnabled = ref.watch(privacyModeEnabledProvider);
    final accounts = accountState.value ?? const <AccountModel>[];

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
      sliver: SliverMainAxisGroup(
        slivers: [
          // Net-worth hero card
          SliverToBoxAdapter(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: <Color>[
                    AppColors.primaryBlue,
                    AppColors.primaryBlueLight,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppRadii.hero),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: AppColors.darkBlueShadow,
                    blurRadius: 26,
                    offset: Offset(0, 16),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Net Worth',
                    style: TextStyle(
                      color: AppColors.overlayWhiteBold,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      maskAmount(
                        currency.format(summary.totalBalance),
                        masked: privacyModeEnabled,
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: AccountsSummaryChip(
                          label: 'Expense',
                          value: maskAmount(
                            currency.format(stats.monthTotal),
                            masked: privacyModeEnabled,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AccountsSummaryChip(
                          label: 'Income',
                          value: maskAmount(
                            currency.format(stats.monthIncomeTotal),
                            masked: privacyModeEnabled,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Section header + add button
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 24, bottom: 12),
              child: Row(
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      'Your Accounts',
                      style: TextStyle(
                        color: AppColors.textSubtle,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton.filled(
                    onPressed: () => _openAccountEditor(context, ref),
                    icon: const Icon(Icons.add_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                    ),
                    constraints:
                        const BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
                ],
              ),
            ),
          ),

          // Loading indicator
          if (accountState.isLoading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            ),

          // Empty state or list
          if (accounts.isEmpty)
            SliverToBoxAdapter(
              child: EmptyAccountsCard(
                onCreate: () => _openAccountEditor(context, ref),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final account = accounts[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: AccountCard(
                      account: account,
                      balanceText: maskAmount(
                        currency.format(account.balance.abs()),
                        masked: privacyModeEnabled,
                      ),
                      isNegative: account.balance < 0,
                      onTap: () =>
                          _openAccountEditor(context, ref, account: account),
                      onDelete: () => _deleteAccount(context, ref, account),
                    ),
                  );
                },
                childCount: accounts.length,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openAccountEditor(
    BuildContext context,
    WidgetRef ref, {
    AccountModel? account,
  }) async {
    final result = await showAccountEditorSheet(context, account: account);
    if (result == null) return;

    await ref.read(accountControllerProvider).saveAccount(
          id: result.id,
          name: result.name,
          iconKey: result.iconKey,
          balance: result.balance,
        );

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          account == null
              ? '${result.name} created.'
              : '${result.name} updated.',
        ),
      ),
    );
  }

  Future<void> _deleteAccount(
    BuildContext context,
    WidgetRef ref,
    AccountModel account,
  ) async {
    final confirmed = await confirmDestructiveAction(
      context,
      title: 'Delete account?',
      message:
          'Remove ${account.name}? Transactions stay in history, but the account itself will be deleted.',
      confirmLabel: 'Delete account',
    );
    if (!confirmed || !context.mounted) return;

    await ref.read(accountControllerProvider).deleteAccount(account.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${account.name} removed.')));
  }
}
