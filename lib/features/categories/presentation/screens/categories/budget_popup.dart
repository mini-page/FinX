import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_tokens.dart';
import '../../../../../core/utils/context_extensions.dart';

/// Shows the "Set Monthly Budget" bottom sheet.
///
/// The sheet offers two actions:
///   1. **Enter Manually** – reveals an amount input and a Save button.
///   2. **Copy Previous Month** – immediately copies the previous month's
///      total budget and category limits into [selectedMonth].
Future<void> showSetBudgetPopup(
  BuildContext context, {
  required DateTime selectedMonth,
  required String currencySymbol,
  required double? currentTotal,
  required Future<void> Function(double amount) onManual,
  required Future<void> Function() onCopyPrevious,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SetBudgetPopup(
      selectedMonth: selectedMonth,
      currencySymbol: currencySymbol,
      currentTotal: currentTotal,
      onManual: onManual,
      onCopyPrevious: onCopyPrevious,
    ),
  );
}

// ── private widget ────────────────────────────────────────────────────────────

class _SetBudgetPopup extends StatefulWidget {
  const _SetBudgetPopup({
    required this.selectedMonth,
    required this.currencySymbol,
    required this.currentTotal,
    required this.onManual,
    required this.onCopyPrevious,
  });

  final DateTime selectedMonth;
  final String currencySymbol;
  final double? currentTotal;
  final Future<void> Function(double) onManual;
  final Future<void> Function() onCopyPrevious;

  @override
  State<_SetBudgetPopup> createState() => _SetBudgetPopupState();
}

class _SetBudgetPopupState extends State<_SetBudgetPopup> {
  bool _showManualEntry = false;
  bool _saving = false;
  late final TextEditingController _amountController;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.currentTotal != null
          ? widget.currentTotal!.toStringAsFixed(0)
          : '',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  String get _monthLabel =>
      DateFormat('MMMM yyyy').format(widget.selectedMonth);

  String get _previousMonthLabel {
    final prev = DateTime(
        widget.selectedMonth.year, widget.selectedMonth.month - 1);
    return DateFormat('MMMM yyyy').format(prev);
  }

  Future<void> _handleManualSave() async {
    final raw = _amountController.text.trim();
    final amount = double.tryParse(raw);
    if (amount == null || amount < 0) {
      context.showSnackBar('Enter a valid budget amount.',
          type: AppFeedbackType.error);
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onManual(amount);
      if (!mounted) return;
      Navigator.of(context).pop();
      context.showSnackBar('Budget saved for $_monthLabel.',
          type: AppFeedbackType.success);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _handleCopyPrevious() async {
    setState(() => _saving = true);
    try {
      await widget.onCopyPrevious();
      if (!mounted) return;
      Navigator.of(context).pop();
      context.showSnackBar(
        'Copied budget from $_previousMonthLabel to $_monthLabel.',
        type: AppFeedbackType.success,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xxl),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadii.sheet)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Drag handle
            Center(
              child: Container(
                width: 46,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Title
            const Text(
              'Set Monthly Budget',
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _monthLabel,
              style: const TextStyle(
                color: AppColors.primaryBlue,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            if (!_showManualEntry) ...<Widget>[
              // Option 1: Enter Manually
              _OptionTile(
                icon: Icons.edit_rounded,
                label: 'Enter Manually',
                subtitle: 'Type a custom total budget for this month.',
                onTap: _saving
                    ? null
                    : () => setState(() => _showManualEntry = true),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Option 2: Copy Previous Month
              _OptionTile(
                icon: Icons.content_copy_rounded,
                label: 'Copy Previous Month',
                subtitle:
                    'Import budget & category limits from $_previousMonthLabel.',
                onTap: _saving ? null : _handleCopyPrevious,
                loading: _saving,
              ),
            ] else ...<Widget>[
              // Manual amount entry
              TextField(
                controller: _amountController,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Monthly budget',
                  prefixText: '${widget.currencySymbol} ',
                  filled: true,
                  fillColor: AppColors.surfaceLight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _saving ? null : () => setState(() => _showManualEntry = false),
                      style: OutlinedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.md),
                        ),
                      ),
                      child: const Text('Back'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _saving ? null : _handleManualSave,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        padding:
                            const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.md),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'Save Budget',
                              style:
                                  TextStyle(fontWeight: FontWeight.w800),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── option tile ───────────────────────────────────────────────────────────────

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    this.onTap,
    this.loading = false,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadii.lg);
    return Material(
      color: AppColors.surfaceLight,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.lightBlueBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.primaryBlue, size: 22),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.textDark,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              if (loading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
