import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/tag_parser.dart';
import 'package:expensio/features/accounts/presentation/provider/account_providers.dart';
import 'package:expensio/features/settings/presentation/provider/preferences_providers.dart';
import '../../data/models/expense_model.dart';
import 'amount_visibility.dart';
import 'package:expensio/features/categories/presentation/widgets/expense_category.dart';
import 'transaction_details_sheet.dart';

/// The Universal Transaction Card for Expensio.
/// - Crisp, non-expanding card with full details opened via bottom sheet.
/// - Supports multi-selection mode with custom checkmark circle (1000040644.png).
/// - Long-press enters multi-selection mode.
class TransactionCard extends ConsumerWidget {
  const TransactionCard({
    super.key,
    required this.expense,
    required this.onDelete,
    this.onEdit,
    this.onShare,
    this.onLocationTap,
    this.accountLabel,
    this.toAccountLabel,
    this.maskAmounts = false,
    this.initiallyExpanded = false,
    this.showDateInCollapsed = false,
    this.isSelectable = false,
    this.isSelected = false,
    this.onSelect,
    this.onLongPress,
  });

  final ExpenseModel expense;
  final VoidCallback onDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onShare;
  final VoidCallback? onLocationTap;
  final String? accountLabel;
  final String? toAccountLabel;
  final bool maskAmounts;
  final bool initiallyExpanded;
  final bool showDateInCollapsed;
  final bool isSelectable;
  final bool isSelected;
  final VoidCallback? onSelect;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final symbol = ref.watch(currencySymbolProvider);
    final allExpenseCategories = ref.watch(allExpenseCategoriesProvider);
    final allIncomeCategories = ref.watch(allIncomeCategoriesProvider);

    final currencyFormat = NumberFormat.currency(
      locale: locale,
      symbol: symbol,
      decimalDigits:
          expense.amount.truncateToDouble() == expense.amount ? 0 : 2,
    );
    final timeFormat = DateFormat('h:mm a');
    final shortDateFormat = DateFormat('d MMM');

    final category = resolveCategory(
      expense.category,
      income: expense.isIncome,
      extra: expense.isIncome ? allIncomeCategories : allExpenseCategories,
    );

    final isTransfer = expense.type == TransactionType.transfer;
    final isIncome = expense.type == TransactionType.income;

    final String signedPrefix = isTransfer ? '' : (isIncome ? '+' : '-');
    final Color amountColor = isTransfer
        ? AppColors.primaryBlue
        : (isIncome ? AppColors.success : AppColors.danger);

    final sourceLabel = accountLabel?.trim().isNotEmpty ?? false
        ? accountLabel!
        : (expense.accountId == null ? 'No Account' : 'Archived Account');

    final localDate = expense.date.toLocal();
    final cleanNote = TagParser.stripTags(expense.note).trim();
    final hasTags = TagParser.hasTags(expense.note);
    final tags = hasTags ? TagParser.extractTags(expense.note) : <String>[];
    final hasLocation = expense.latitude != null && expense.longitude != null;
    final hasSplit = expense.splitMethod != null;
    final hasNote = expense.note.trim().isNotEmpty;

    final String displayTitle = isTransfer
        ? (cleanNote.isNotEmpty ? cleanNote : 'Transfer')
        : (cleanNote.isNotEmpty ? cleanNote : category.name);

    final List<String> metaParts = [];
    if (isTransfer) {
      metaParts.add('TRANSFER');
      if (toAccountLabel != null && toAccountLabel!.isNotEmpty) {
        metaParts.add('$sourceLabel ➔ $toAccountLabel');
      } else {
        metaParts.add(sourceLabel);
      }
    } else {
      metaParts.add(category.name.toUpperCase());
      if (expense.subcategory != null && expense.subcategory!.isNotEmpty) {
        metaParts.add(expense.subcategory!.toUpperCase());
      }
      metaParts.add(sourceLabel.toUpperCase());
    }
    final String metaSubtitle = metaParts.join('  ·  ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isSelected
              ? AppColors.primaryBlue
              : const Color(0xFFF1F5F9),
          width: isSelected ? 1.5 : 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C09386D),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: () {
            if (isSelectable) {
              onSelect?.call();
            } else {
              final accounts = ref.read(accountListProvider).value ?? const [];
              showTransactionDetailsSheet(
                context,
                expense: expense,
                accounts: accounts,
                onEdit: (e) => onEdit?.call(),
                onDelete: (e) => onDelete(),
              );
            }
          },
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Category Avatar or Multi-Select Checkmark Circle (1000040644.png)
                if (isSelectable)
                  isSelected
                      ? Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: AppColors.primaryBlue,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        )
                      : Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF94A3B8),
                              width: 2.0,
                            ),
                          ),
                        )
                else
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isTransfer
                          ? AppColors.primaryBlue.withValues(alpha: 0.12)
                          : category.color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      isTransfer ? Icons.swap_horiz_rounded : category.icon,
                      color: isTransfer ? AppColors.primaryBlue : category.color,
                      size: 22,
                    ),
                  ),
                const SizedBox(width: 12),

                // 2. Title & Metadata & Compact Badges
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        metaSubtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSubtle,
                          letterSpacing: 0.2,
                        ),
                      ),

                      // Indicator Badges
                      if (hasSplit || hasLocation || hasTags || hasNote) ...[
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 4,
                          runSpacing: 2,
                          children: [
                            if (hasSplit)
                              _MiniBadge(
                                icon: Icons.splitscreen_rounded,
                                label: expense.splitMethod!,
                                color: AppColors.accentPurple,
                              ),
                            if (hasLocation)
                              const _MiniBadge(
                                icon: Icons.location_on_rounded,
                                label: 'Location',
                                color: Color(0xFF0284C7),
                              ),
                            if (hasTags)
                              _MiniBadge(
                                icon: Icons.tag_rounded,
                                label: '${tags.length}',
                                color: const Color(0xFF6366F1),
                              ),
                            if (hasNote && displayTitle == category.name)
                              const _MiniBadge(
                                icon: Icons.short_text_rounded,
                                label: 'Note',
                                color: Color(0xFF64748B),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // 3. Amount & Time
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$signedPrefix${maskAmount(currencyFormat.format(expense.amount), masked: maskAmounts)}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: amountColor,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      showDateInCollapsed
                          ? '${shortDateFormat.format(localDate)} · ${timeFormat.format(localDate)}'
                          : timeFormat.format(localDate),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
