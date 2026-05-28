import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/tag_parser.dart';
import 'package:xpens/features/settings/presentation/provider/preferences_providers.dart';
import '../../data/models/expense_model.dart';
import 'amount_visibility.dart';
import 'package:xpens/features/categories/presentation/widgets/expense_category.dart';

class TransactionCard extends ConsumerStatefulWidget {
  const TransactionCard({
    super.key,
    required this.expense,
    required this.onDelete,
    this.onEdit,
    this.accountLabel,
    this.maskAmounts = false,
  });

  final ExpenseModel expense;
  final VoidCallback onDelete;
  final VoidCallback? onEdit;
  final String? accountLabel;
  final bool maskAmounts;

  @override
  ConsumerState<TransactionCard> createState() => _TransactionCardState();
}

class _TransactionCardState extends ConsumerState<TransactionCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final symbol = ref.watch(currencySymbolProvider);
    final allExpenseCategories = ref.watch(allExpenseCategoriesProvider);
    final allIncomeCategories = ref.watch(allIncomeCategoriesProvider);

    final currencyFormat = NumberFormat.currency(
      locale: locale,
      symbol: symbol,
      decimalDigits:
          widget.expense.amount.truncateToDouble() == widget.expense.amount
              ? 0
              : 2,
    );
    final timeFormat = DateFormat('h:mm a');
    final dateFormat = DateFormat('EEE, d MMM yyyy');

    final category = resolveCategory(
      widget.expense.category,
      income: widget.expense.isIncome,
      extra:
          widget.expense.isIncome ? allIncomeCategories : allExpenseCategories,
    );
    final isTransfer = widget.expense.type == TransactionType.transfer;
    final signedPrefix =
        isTransfer ? '↔' : (widget.expense.isIncome ? '+' : '-');
    final amountColor = isTransfer
        ? AppColors.primaryBlue
        : (widget.expense.isIncome ? AppColors.success : AppColors.danger);
    final sourceLabel = widget.accountLabel?.trim().isNotEmpty ?? false
        ? widget.accountLabel!
        : widget.expense.accountId == null
            ? 'No Account'
            : 'Archived Account';

    final localDate = widget.expense.date.toLocal();
    final cleanNote = TagParser.stripTags(widget.expense.note).trim();
    final hasTags = TagParser.hasTags(widget.expense.note);
    final tags =
        hasTags ? TagParser.extractTags(widget.expense.note) : <String>[];

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // ── Collapsed row ─────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      // Category icon
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: category.color.withValues(alpha: 0.10),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          category.icon,
                          color: category.color,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Title + meta
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              widget.expense.note.isEmpty
                                  ? category.name
                                  : cleanNote.isNotEmpty
                                      ? cleanNote
                                      : category.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${widget.expense.category.toUpperCase()}  ·  ${sourceLabel.toUpperCase()}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSubtle,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Amount + time + chevron
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            '$signedPrefix${maskAmount(currencyFormat.format(widget.expense.amount), masked: widget.maskAmounts)}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: amountColor,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            timeFormat.format(localDate),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 6),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 220),
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppColors.textMuted,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Expanded panel ────────────────────────────────────────
                if (_expanded) ...[
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.cardShadow.withValues(alpha: 0.5),
                    indent: 14,
                    endIndent: 14,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        // Full date
                        _InfoRow(
                          icon: Icons.calendar_today_outlined,
                          text: dateFormat.format(localDate),
                        ),
                        const SizedBox(height: 6),
                        // Account
                        _InfoRow(
                          icon: Icons.account_balance_wallet_outlined,
                          text: sourceLabel,
                        ),
                        // Full note (when it's long / has been truncated)
                        if (widget.expense.note.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          _InfoRow(
                            icon: Icons.notes_rounded,
                            text: widget.expense.note,
                            softWrap: true,
                          ),
                        ],
                        // Tag chips
                        if (hasTags) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: tags
                                .map(
                                  (tag) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryBlue
                                          .withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '#$tag',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primaryBlue,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                          ),
                        ],
                        const SizedBox(height: 12),
                        // Action buttons
                        Row(
                          children: <Widget>[
                            if (widget.onEdit != null)
                              Expanded(
                                child: _ActionButton(
                                  icon: Icons.edit_outlined,
                                  label: 'Edit',
                                  color: AppColors.primaryBlue,
                                  onTap: widget.onEdit!,
                                ),
                              ),
                            if (widget.onEdit != null)
                              const SizedBox(width: 10),
                            Expanded(
                              child: _ActionButton(
                                icon: Icons.delete_outline_rounded,
                                label: 'Delete',
                                color: AppColors.danger,
                                onTap: widget.onDelete,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small icon + text row for the expanded detail panel.
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.text,
    this.softWrap = false,
  });

  final IconData icon;
  final String text;
  final bool softWrap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment:
          softWrap ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: <Widget>[
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: softWrap ? 4 : 1,
            overflow: softWrap ? TextOverflow.visible : TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Compact action button for Edit / Delete inside the expanded panel.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
