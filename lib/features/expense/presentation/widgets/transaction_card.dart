import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/tag_parser.dart';
import 'package:expensio/features/settings/presentation/provider/preferences_providers.dart';
import '../../data/models/expense_model.dart';
import 'amount_visibility.dart';
import 'package:expensio/features/categories/presentation/widgets/expense_category.dart';
import 'package:expensio/routes/app_routes.dart';

/// The Universal Transaction Card for Expensio.
/// Adheres strictly to universal UI design consistency:
/// - Collapsed: Category bubble, title/name, metadata subtitle, indicators (note, split, location, tags),
///   and color-coded amount (Red & '-' for expenses, Green & '+' for income, Blue & no sign for transfers).
/// - Expanded: Smooth AnimatedSize transition displaying full remarks, tags, split details,
///   GPS location with tap-to-map, full timestamps, and Edit/Delete/Share actions.
class TransactionCard extends ConsumerStatefulWidget {
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

  @override
  ConsumerState<TransactionCard> createState() => _TransactionCardState();
}

class _TransactionCardState extends ConsumerState<TransactionCard> {
  late bool _expanded;
  final GlobalKey _cardBoundaryKey = GlobalKey();
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  void _toggleExpanded() {
    HapticFeedback.selectionClick();
    setState(() => _expanded = !_expanded);
  }

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
    final shortDateFormat = DateFormat('d MMM');
    final fullDateFormat = DateFormat('EEEE, d MMMM yyyy');

    final category = resolveCategory(
      widget.expense.category,
      income: widget.expense.isIncome,
      extra:
          widget.expense.isIncome ? allIncomeCategories : allExpenseCategories,
    );

    // ── Strict Color & Sign Rules ──────────────────────────────────────────
    final isTransfer = widget.expense.type == TransactionType.transfer;
    final isIncome = widget.expense.type == TransactionType.income;

    // Rules:
    // - Expense: Red and minus sign ('-')
    // - Income: Green and plus sign ('+')
    // - Transfer/transaction: Blue and NO sign ('')
    final String signedPrefix = isTransfer ? '' : (isIncome ? '+' : '-');
    final Color amountColor = isTransfer
        ? AppColors.primaryBlue
        : (isIncome ? AppColors.success : AppColors.danger);

    // ── Metadata & Labels ──────────────────────────────────────────────────
    final sourceLabel = widget.accountLabel?.trim().isNotEmpty ?? false
        ? widget.accountLabel!
        : (widget.expense.accountId == null ? 'No Account' : 'Archived Account');

    final localDate = widget.expense.date.toLocal();
    final cleanNote = TagParser.stripTags(widget.expense.note).trim();
    final hasTags = TagParser.hasTags(widget.expense.note);
    final tags = hasTags ? TagParser.extractTags(widget.expense.note) : <String>[];
    final hasLocation = widget.expense.latitude != null && widget.expense.longitude != null;
    final hasSplit = widget.expense.splitMethod != null;
    final hasNote = widget.expense.note.trim().isNotEmpty;

    // Title: Display remark/name if present, otherwise Category
    final String displayTitle = isTransfer
        ? (cleanNote.isNotEmpty ? cleanNote : 'Transfer')
        : (cleanNote.isNotEmpty ? cleanNote : category.name);

    // Subtitle meta: Category · Subcategory · Account
    final List<String> metaParts = [];
    if (isTransfer) {
      metaParts.add('TRANSFER');
      if (widget.toAccountLabel != null && widget.toAccountLabel!.isNotEmpty) {
        metaParts.add('$sourceLabel ➔ ${widget.toAccountLabel}');
      } else {
        metaParts.add(sourceLabel);
      }
    } else {
      metaParts.add(category.name.toUpperCase());
      if (widget.expense.subcategory != null && widget.expense.subcategory!.isNotEmpty) {
        metaParts.add(widget.expense.subcategory!.toUpperCase());
      }
      metaParts.add(sourceLabel.toUpperCase());
    }
    final String metaSubtitle = metaParts.join('  ·  ');

    return AnimatedSize(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeInOutCubic,
      child: RepaintBoundary(
        key: _cardBoundaryKey,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: _expanded
                ? amountColor.withValues(alpha: 0.25)
                : const Color(0xFFF1F5F9),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: _expanded
                  ? amountColor.withValues(alpha: 0.08)
                  : const Color(0x0C09386D),
              blurRadius: _expanded ? 20 : 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            onTap: _toggleExpanded,
            borderRadius: BorderRadius.circular(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Collapsed Row (Everything in One Glance) ─────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 1. Category Avatar Bubble
                      Container(
                        width: 46,
                        height: 46,
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

                            // Indicator Badges in Collapsed View
                            if (hasSplit || hasLocation || hasTags || hasNote) ...[
                              const SizedBox(height: 5),
                              Wrap(
                                spacing: 4,
                                runSpacing: 2,
                                children: [
                                  if (hasSplit)
                                    _MiniBadge(
                                      icon: Icons.splitscreen_rounded,
                                      label: widget.expense.splitMethod!,
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

                      // 3. Amount & Time & Chevron
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$signedPrefix${maskAmount(currencyFormat.format(widget.expense.amount), masked: widget.maskAmounts)}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: amountColor,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.showDateInCollapsed
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
                      const SizedBox(width: 6),

                      // 4. Chevron Animation
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeInOutCubic,
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppColors.textMuted,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Expanded Detail Panel (Zero Redundancy) ──────────────────
                if (_expanded) ...[
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFFF1F5F9),
                    indent: 14,
                    endIndent: 14,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Full Note / Remarks Box
                        if (widget.expense.note.trim().isNotEmpty) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.format_quote_rounded,
                                  size: 16,
                                  color: Color(0xFF64748B),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    widget.expense.note,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textDark,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],

                        // Tags Pills
                        if (hasTags) ...[
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: tags.map((t) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF2FF),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: const Color(0xFFC7D2FE),
                                  ),
                                ),
                                child: Text(
                                  '#$t',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF4F46E5),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 10),
                        ],

                        // Split Details Box
                        if (hasSplit) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accentPurpleBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.accentPurpleLight),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.people_outline_rounded,
                                  size: 16,
                                  color: AppColors.accentPurpleDark,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Split Method: ${widget.expense.splitMethod} · Logged in Group',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.accentPurpleDark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],

                        // Location Radar Chip
                        if (hasLocation) ...[
                          InkWell(
                            onTap: widget.onLocationTap ??
                                () {
                                  HapticFeedback.lightImpact();
                                  AppRoutes.pushLocationMap(context);
                                },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F9FF),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFBAE6FD)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.location_on_rounded,
                                    size: 16,
                                    color: Color(0xFF0284C7),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Pinned Location (${widget.expense.latitude!.toStringAsFixed(4)}, ${widget.expense.longitude!.toStringAsFixed(4)})',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0369A1),
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 12,
                                    color: Color(0xFF0284C7),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],

                        // Timestamp & Account Details Row
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_rounded,
                              size: 13,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${fullDateFormat.format(localDate)} at ${timeFormat.format(localDate)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.account_balance_wallet_rounded,
                              size: 13,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                isTransfer
                                    ? 'Transfer: $sourceLabel ➔ ${widget.toAccountLabel ?? "Account"}'
                                    : 'Account: $sourceLabel',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Action Buttons or Clean Receipt Footer when Sharing
                        if (_isSharing)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryBlue.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.account_balance_wallet_rounded, size: 14, color: AppColors.primaryBlue),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Expensio',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.primaryBlue,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                                const Text(
                                  'Personal Expense Receipt',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Row(
                            children: [
                              if (widget.onEdit != null)
                                Expanded(
                                  child: _CardActionButton(
                                    icon: Icons.edit_outlined,
                                    label: 'Edit',
                                    color: AppColors.primaryBlue,
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      widget.onEdit!();
                                    },
                                  ),
                                ),
                              if (widget.onEdit != null)
                                const SizedBox(width: 8),
                              Expanded(
                                child: _CardActionButton(
                                  icon: Icons.delete_outline_rounded,
                                  label: 'Delete',
                                  color: AppColors.danger,
                                  onTap: () {
                                    HapticFeedback.mediumImpact();
                                    widget.onDelete();
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              _CardIconActionButton(
                                icon: Icons.share_outlined,
                                tooltip: 'Share Receipt Image',
                                color: const Color(0xFF64748B),
                                onTap: widget.onShare ?? _shareCardAsImage,
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  Future<void> _shareCardAsImage() async {
    HapticFeedback.lightImpact();
    if (_isSharing) return;
    setState(() => _isSharing = true);

    try {
      await WidgetsBinding.instance.endOfFrame;

      final boundary = _cardBoundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Could not find render object to capture receipt image.');
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Failed to convert receipt to PNG format.');
      }

      final Uint8List pngBytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final safeId = widget.expense.id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final file = File('${tempDir.path}/expensio_receipt_$safeId.png');
      await file.writeAsBytes(pngBytes);

      final isTransfer = widget.expense.type == TransactionType.transfer;
      final isIncome = widget.expense.type == TransactionType.income;
      final isExpense = widget.expense.type == TransactionType.expense;
      final displayTitle = widget.expense.note.trim().isNotEmpty
          ? widget.expense.note.trim()
          : (isTransfer ? 'Transfer' : widget.expense.category);
      final signedPrefix = isIncome ? '+' : (isExpense ? '-' : '');
      final currencyFormat = ref.read(currencyFormatProvider);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: 'Expensio Receipt: $displayTitle · $signedPrefix${currencyFormat.format(widget.expense.amount)}',
        subject: 'Expensio Transaction Receipt - $displayTitle',
      );
    } catch (e) {
      if (mounted) {
        final isTransfer = widget.expense.type == TransactionType.transfer;
        final isIncome = widget.expense.type == TransactionType.income;
        final isExpense = widget.expense.type == TransactionType.expense;
        final displayTitle = widget.expense.note.trim().isNotEmpty
            ? widget.expense.note.trim()
            : (isTransfer ? 'Transfer' : widget.expense.category);
        final signedPrefix = isIncome ? '+' : (isExpense ? '-' : '');
        final currencyFormat = ref.read(currencyFormatProvider);
        final shortDateFormat = DateFormat('dd MMM, yyyy');
        final text =
            'Expensio Receipt: $displayTitle · $signedPrefix${currencyFormat.format(widget.expense.amount)} on ${shortDateFormat.format(widget.expense.date.toLocal())}';
        await Clipboard.setData(ClipboardData(text: text));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Transaction summary copied to clipboard!'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }
}

/// Mini status badge for collapsed transaction view.
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
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 9, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pill Action button inside expanded card.
class _CardActionButton extends StatelessWidget {
  const _CardActionButton({
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
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: color),
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

/// Square icon-only action button (e.g. Share).
class _CardIconActionButton extends StatelessWidget {
  const _CardIconActionButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Icon(icon, size: 16, color: color),
          ),
        ),
      ),
    );
  }
}
