import 'dart:collection';

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import 'package:xpens/features/accounts/data/models/account_model.dart';
import '../../../data/models/expense_model.dart';
import '../../widgets/transaction_card.dart';

/// Grouped, scrollable list of transactions for the records history screen.
class RecordsExpenseList extends StatelessWidget {
  const RecordsExpenseList({
    super.key,
    required this.groupedExpenses,
    required this.accounts,
    required this.privacyModeEnabled,
    required this.groupLabel,
    required this.accountLabelFor,
    required this.onEdit,
    required this.onDelete,
  });

  final SplayTreeMap<DateTime, List<ExpenseModel>> groupedExpenses;
  final List<AccountModel> accounts;
  final bool privacyModeEnabled;
  final String Function(DateTime) groupLabel;
  final String? Function(ExpenseModel, List<AccountModel>) accountLabelFor;
  final void Function(ExpenseModel) onEdit;
  final void Function(ExpenseModel) onDelete;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: groupedExpenses.entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  groupLabel(entry.key),
                  style: const TextStyle(
                    color: AppColors.primaryBlue,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              ...entry.value.map((expense) {
                return TransactionCard(
                  expense: expense,
                  accountLabel: accountLabelFor(expense, accounts),
                  maskAmounts: privacyModeEnabled,
                  onEdit: () => onEdit(expense),
                  onDelete: () => onDelete(expense),
                );
              }),
            ],
          ),
        );
      }).toList(growable: false),
    );
  }
}
