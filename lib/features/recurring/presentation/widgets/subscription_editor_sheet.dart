import '../../domain/common_services_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/context_extensions.dart';
import '../../data/models/recurring_subscription_model.dart';
import '../../domain/recurrence_parser.dart';
import 'subscription_icons.dart';

/// The result returned from the bottom sheet when the user confirms.
class SubscriptionFormResult {
  const SubscriptionFormResult({
    this.id,
    required this.name,
    required this.amount,
    required this.nextBillDate,
    required this.iconKey,
    required this.note,
    required this.isActive,
    required this.billingPeriod,
    required this.category,
    this.notifyDaysBefore = 7,
    this.lastPaymentDate,
    this.priceHistory,
    this.cancellationNote,
    this.cancelledAt,
  });

  final String? id;
  final String name;
  final double amount;
  final DateTime nextBillDate;
  final String iconKey;
  final String note;
  final bool isActive;
  final String billingPeriod;
  final String category;
  final int notifyDaysBefore;
  final DateTime? lastPaymentDate;
  final List<double>? priceHistory;
  final String? cancellationNote;
  final DateTime? cancelledAt;
}

/// Opens the subscription editor as a bottom sheet and returns the result.
Future<SubscriptionFormResult?> showSubscriptionEditorSheet(
  BuildContext context, {
  RecurringSubscriptionModel? subscription,
  /// Pre-fill with a parsed recurrence from a !-shortcode.
  RecurrenceParsed? initialRecurrence,
  String? initialName,
  double? initialAmount,
  String? initialIconKey,
  String? initialCategory,
}) {
  return showModalBottomSheet<SubscriptionFormResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _SubscriptionEditorSheet(
      subscription: subscription,
      initialRecurrence: initialRecurrence,
      initialName: initialName,
      initialAmount: initialAmount,
      initialIconKey: initialIconKey,
      initialCategory: initialCategory,
    ),
  );
}

class _SubscriptionEditorSheet extends StatefulWidget {
  const _SubscriptionEditorSheet({
    this.subscription,
    this.initialRecurrence,
    this.initialName,
    this.initialAmount,
    this.initialIconKey,
    this.initialCategory,
  });

  final RecurringSubscriptionModel? subscription;
  final RecurrenceParsed? initialRecurrence;
  final String? initialName;
  final double? initialAmount;
  final String? initialIconKey;
  final String? initialCategory;

  @override
  State<_SubscriptionEditorSheet> createState() =>
      _SubscriptionEditorSheetState();
}

class _SubscriptionEditorSheetState extends State<_SubscriptionEditorSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late DateTime _nextBillDate;
  late String _iconKey;
  late bool _isActive;
  late int _intervalCount;
  late RecurrenceUnit _intervalUnit;
  late int _notifyDaysBefore;
  final _cancelNoteController = TextEditingController();
  late String _category;

  // ── Smart recurrence helpers ─────────────────────────────────────────────

  /// Valid count options per unit — curated to cover all meaningful intervals.
  static List<int> _countOptionsForUnit(RecurrenceUnit unit) {
    return switch (unit) {
      // Day: 1–6. (7 days = 1 week, handled by auto-normalize)
      RecurrenceUnit.day => [1, 2, 3, 4, 5, 6],
      // Week: 1–4. (5+ weeks is unusual; 4 weeks ≠ 1 month exactly)
      RecurrenceUnit.week => [1, 2, 3, 4],
      // Month: curated milestones up to 1 year
      RecurrenceUnit.month => [1, 2, 3, 6, 12],
    };
  }

  /// Alias labels shown as badges on chips (e.g. "Quarterly", "Biweekly").
  static String? _aliasFor(int count, RecurrenceUnit unit) {
    return switch ((count, unit)) {
      (2, RecurrenceUnit.week) => 'Biweekly',
      (3, RecurrenceUnit.month) => 'Quarterly',
      (6, RecurrenceUnit.month) => 'Semi-annual',
      (12, RecurrenceUnit.month) => 'Yearly',
      _ => null,
    };
  }

  /// Normalizes an arbitrary (count, unit) pair to its simplest canonical form.
  /// e.g. 7 days → 1 week, 14 days → 2 weeks, 30 days → 1 month, 90 days → 3 months.
  static (int, RecurrenceUnit) _normalize(int count, RecurrenceUnit unit) {
    if (unit == RecurrenceUnit.day) {
      if (count % 30 == 0) {
        final months = count ~/ 30;
        if (months <= 12) return (months, RecurrenceUnit.month);
      }
      if (count % 7 == 0) {
        final weeks = count ~/ 7;
        if (weeks <= 4) return (weeks, RecurrenceUnit.week);
      }
    }
    if (unit == RecurrenceUnit.week) {
      // 4+ weeks that map to clean month boundaries kept as-is
    }
    return (count, unit);
  }

  /// Called when unit toggle changes. Snaps current count to nearest valid option.
  void _onUnitChanged(RecurrenceUnit newUnit) {
    HapticFeedback.selectionClick();
    final options = _countOptionsForUnit(newUnit);
    // Find nearest valid count
    final nearest = options.reduce((a, b) =>
        (a - _intervalCount).abs() <= (b - _intervalCount).abs() ? a : b);
    setState(() {
      _intervalUnit = newUnit;
      _intervalCount = nearest;
    });
  }

  /// Called when a count chip is tapped.
  void _onCountTapped(int count) {
    HapticFeedback.selectionClick();
    // Auto-normalize: e.g. 7 days → 1 week
    final (normCount, normUnit) = _normalize(count, _intervalUnit);
    setState(() {
      _intervalCount = normCount;
      _intervalUnit = normUnit;
    });
  }

  @override
  void initState() {
    super.initState();

    // Name / amount / note
    _nameController = TextEditingController(
      text: widget.initialName ?? widget.subscription?.name ?? '',
    );
    _amountController = TextEditingController(
      text: widget.initialAmount != null
          ? widget.initialAmount!.toStringAsFixed(0)
          : (widget.subscription?.amount.toStringAsFixed(0) ?? ''),
    );
    _noteController = TextEditingController(
      text: widget.subscription?.note ?? '',
    );

    _nextBillDate = widget.subscription?.nextBillDate ?? DateTime.now();
    _iconKey = widget.initialIconKey ??
        widget.subscription?.iconKey ??
        subscriptionIconOptions.first.key;
    _isActive = widget.subscription?.isActive ?? true;
    _notifyDaysBefore = widget.subscription?.notifyDaysBefore ?? 7;
    _category = widget.initialCategory ??
        widget.subscription?.category ??
        'Entertainment';

    // Recurrence — prefer initialRecurrence (from ! shortcode), then subscription
    final raw = widget.initialRecurrence ??
        widget.subscription?.recurrence ??
        const RecurrenceParsed(count: 1, unit: RecurrenceUnit.month);

    // Auto-normalize on load (e.g. !14days → 2 weeks)
    final (normCount, normUnit) = _normalize(raw.count, raw.unit);
    // Snap to nearest valid chip if needed
    final options = _countOptionsForUnit(normUnit);
    final snapped = options.contains(normCount)
        ? normCount
        : options.reduce((a, b) =>
            (a - normCount).abs() <= (b - normCount).abs() ? a : b);
    _intervalCount = snapped;
    _intervalUnit = normUnit;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    _cancelNoteController.dispose();
    super.dispose();
  }


  String get _encodedPeriod {
    return RecurrenceParsed(count: _intervalCount, unit: _intervalUnit).encoded;
  }


  void _selectPreset(CommonServicePreset preset) {
    HapticFeedback.lightImpact();
    setState(() {
      _nameController.text = preset.name;
      _amountController.text = preset.defaultAmount.toStringAsFixed(0);
      _iconKey = preset.iconKey;
      _category = preset.category;
      _intervalCount = preset.defaultCount;
      _intervalUnit = preset.defaultUnit;
    });
  }

  Widget _buildPresetChip(CommonServicePreset preset) {
    final isSelected = _nameController.text == preset.name;
    return GestureDetector(
      onTap: () => _selectPreset(preset),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryBlue : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primaryBlue : const Color(0xFFE2EAF4),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(preset.iconKey, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 5),
            Text(
              preset.name,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textDark,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white24 : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '₹${preset.defaultAmount.toInt()}',
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Preview text shown in the info card.
  String get _previewText {
    final rec = RecurrenceParsed(count: _intervalCount, unit: _intervalUnit);
    final next = rec.nextDate(_nextBillDate);
    final fmt = DateFormat('d MMM yyyy');
    return '${rec.label}, next on ${fmt.format(next)}.';
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.only(bottom: insets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Handle bar
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.backgroundLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Title
              Text(
                widget.subscription == null
                    ? 'Add Recurring Entry'
                    : 'Edit Recurring Entry',
                style: const TextStyle(
                  color: AppColors.textDark,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Set up a repeating expense with custom recurrence.',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),

              // ── Quick Presets (50+ Services in 2 Rows) ────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const _SectionLabel(label: 'Quick Pick Popular Service (50+)'),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Tap to autofill',
                      style: TextStyle(
                        color: AppColors.primaryBlue,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Row 1: Entertainment, AI, Books, Dev, Social
              SizedBox(
                height: 38,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: CommonServicesCatalog.digitalAndStreaming.length,
                  itemBuilder: (context, i) => _buildPresetChip(
                    CommonServicesCatalog.digitalAndStreaming[i],
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Row 2: Bills, Rent, Utilities, Food, Fitness, Recharges
              SizedBox(
                height: 38,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: CommonServicesCatalog.billsAndUtilities.length,
                  itemBuilder: (context, i) => _buildPresetChip(
                    CommonServicesCatalog.billsAndUtilities[i],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Name
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: _inputDecoration('Name (e.g. Netflix, Rent)'),
              ),
              const SizedBox(height: 8),
              // Shorthand helper chips
              Row(
                children: [
                  const Text(
                    'Shorthand:',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          '!month',
                          '!quarter',
                          '!year',
                          '!week',
                          '!2weeks',
                          '!30days',
                        ].map((sh) {
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              final parsed = parseRecurrenceToken(sh.startsWith('!') ? sh.substring(1) : sh);
                              if (parsed != null) {
                                final (cnt, unt) = _normalize(parsed.count, parsed.unit);
                                setState(() {
                                  _intervalCount = cnt;
                                  _intervalUnit = unt;
                                });
                              }
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Text(
                                sh,
                                style: const TextStyle(
                                  color: AppColors.primaryBlue,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Amount
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: _inputDecoration('Amount').copyWith(
                  prefixText: '₹ ',
                ),
              ),
              const SizedBox(height: 12),

              // Note
              TextField(
                controller: _noteController,
                decoration: _inputDecoration('Note (optional)'),
              ),
              const SizedBox(height: 18),

              // ── RECURRENCE PICKER ──────────────────────────────────────
              _SectionLabel(label: 'Repeat Every'),
              const SizedBox(height: 10),
              _SmartRecurrencePicker(
                count: _intervalCount,
                unit: _intervalUnit,
                onCountTapped: _onCountTapped,
                onUnitChanged: _onUnitChanged,
              ),

              const SizedBox(height: 14),

              // Recurrence preview card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.primaryBlue.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.sync_rounded,
                      color: AppColors.primaryBlue,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _previewText,
                        style: const TextStyle(
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // ── NEXT BILL DATE ─────────────────────────────────────────
              _SectionLabel(label: 'Next Due Date'),
              const SizedBox(height: 10),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.calendar_today_rounded,
                          color: AppColors.primaryBlue, size: 18),
                      const SizedBox(width: 10),
                      Text(
                        DateFormat('EEE, d MMM yyyy').format(_nextBillDate),
                        style: const TextStyle(
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // ── ICON / EMOJI ───────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const _SectionLabel(label: 'Icon / Emoji'),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline_rounded,
                        color: AppColors.textSecondary, size: 20),
                    onPressed: _pickCustomEmoji,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  // Show currently selected icon if it's not in the preset list
                  if (![
                    '📺',
                    '🎵',
                    '🍿',
                    '💾',
                    '🏋️',
                    '📰',
                    '🌐',
                    '🎮',
                    '💼',
                    '🏠',
                    '🚗',
                    '💊',
                  ].contains(_iconKey))
                    ChoiceChip(
                      label: resolveSubscriptionIcon(_iconKey,
                          color: AppColors.primaryBlue, size: 18),
                      selected: true,
                      selectedColor:
                          AppColors.primaryBlue.withValues(alpha: 0.2),
                      backgroundColor: AppColors.lightBlueBg,
                      onSelected: (_) {},
                    ),
                  ...[
                    '📺',
                    '🎵',
                    '🍿',
                    '💾',
                    '🏋️',
                    '📰',
                    '🌐',
                    '🎮',
                    '💼',
                    '🏠',
                    '🚗',
                    '💊',
                  ].map((emoji) {
                    final isSelected = emoji == _iconKey;
                    return ChoiceChip(
                      label: Text(emoji,
                          style: const TextStyle(fontSize: 18)),
                      selected: isSelected,
                      selectedColor:
                          AppColors.primaryBlue.withValues(alpha: 0.2),
                      backgroundColor: AppColors.lightBlueBg,
                      onSelected: (_) =>
                          setState(() => _iconKey = emoji),
                    );
                  }),
                ],
              ),

              const SizedBox(height: 16),

              // ── ACTIVE TOGGLE ──────────────────────────────────────────
              SwitchListTile.adaptive(
                value: _isActive,
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Entry is active',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                subtitle: const Text(
                  'Inactive entries won\'t trigger notifications',
                  style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                ),
                onChanged: (value) => setState(() => _isActive = value),
              ),

              if (!_isActive) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _cancelNoteController,
                  decoration: const InputDecoration(
                    hintText: 'Reason for cancellation (optional)',
                    filled: true,
                    fillColor: AppColors.surfaceLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // ── PRE-BILLING NOTIFICATION ──────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Notify before billing',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                    Row(
                    children: [
                      _NotifChip(
                        label: '3d',
                        selected: _notifyDaysBefore == 3,
                        onTap: () => setState(() => _notifyDaysBefore = 3),
                      ),
                      const SizedBox(width: 6),
                      _NotifChip(
                        label: '7d',
                        selected: _notifyDaysBefore == 7,
                        onTap: () => setState(() => _notifyDaysBefore = 7),
                      ),
                      const SizedBox(width: 6),
                      _NotifChip(
                        label: '14d',
                        selected: _notifyDaysBefore == 14,
                        onTap: () => setState(() => _notifyDaysBefore = 14),
                      ),
                    ],
                  ),
                ],
              ),

              if (widget.subscription?.lastPaymentDate != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 14, color: AppColors.success),
                    const SizedBox(width: 6),
                    Text(
                      'Last paid: ${DateFormat('d MMM yyyy').format(widget.subscription!.lastPaymentDate!)}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],

              if (widget.subscription?.isPriceIncreased == true) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.trending_up_rounded,
                        size: 14, color: AppColors.warning),
                    const SizedBox(width: 6),
                    Text(
                      'Price increased from ${widget.subscription!.previousAmount!.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: AppColors.warning,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 12),

              // ── SAVE BUTTON ────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    widget.subscription == null
                        ? 'Create Recurring Entry'
                        : 'Save Changes',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: AppColors.surfaceLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextBillDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => _nextBillDate = picked);
  }

  Future<void> _pickCustomEmoji() async {
    final controller = TextEditingController();
    final customEmoji = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Enter Custom Emoji',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: TextField(
          controller: controller,
          maxLength: 2,
          decoration: const InputDecoration(hintText: 'e.g. 🍕'),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (customEmoji != null && customEmoji.isNotEmpty) {
      setState(() => _iconKey = customEmoji);
    }
  }

  void _submit() {
    final name = _nameController.text.trim();
    final amount = double.tryParse(_amountController.text.trim());

    if (name.isEmpty || amount == null || amount <= 0) {
      context.showSnackBar('Enter a valid name and amount.');
      return;
    }

    final now = DateTime.now();
    final cancelledAt = !_isActive && widget.subscription?.isActive == true
        ? now
        : (!_isActive ? widget.subscription?.cancelledAt : null);

    Navigator.of(context).pop(
      SubscriptionFormResult(
        id: widget.subscription?.id,
        name: name,
        amount: amount,
        nextBillDate: _nextBillDate,
        iconKey: _iconKey,
        note: _noteController.text.trim(),
        isActive: _isActive,
        billingPeriod: _encodedPeriod,
        category: _category.isNotEmpty ? _category : 'Other',
        notifyDaysBefore: _notifyDaysBefore,
        lastPaymentDate: widget.subscription?.lastPaymentDate,
        priceHistory: widget.subscription?.priceHistory,
        cancellationNote: !_isActive
            ? (_cancelNoteController.text.trim().isNotEmpty
                ? _cancelNoteController.text.trim()
                : widget.subscription?.cancellationNote)
            : null,
        cancelledAt: cancelledAt,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: AppColors.textDark,
        fontWeight: FontWeight.w800,
        fontSize: 13,
      ),
    );
  }
}

/// Smart recurrence picker:
/// • Unit toggle row (Day / Week / Month) on top
/// • Curated count chip row below — options change per unit
/// • Auto-normalisation: 7 days → 1 week, 90 days → 3 months, etc.
/// • Alias badges on chips (Quarterly, Biweekly, Yearly)
class _SmartRecurrencePicker extends StatelessWidget {
  const _SmartRecurrencePicker({
    required this.count,
    required this.unit,
    required this.onCountTapped,
    required this.onUnitChanged,
  });

  final int count;
  final RecurrenceUnit unit;
  final ValueChanged<int> onCountTapped;
  final ValueChanged<RecurrenceUnit> onUnitChanged;

  static List<int> _optionsFor(RecurrenceUnit u) =>
      _SubscriptionEditorSheetState._countOptionsForUnit(u);

  static String? _alias(int c, RecurrenceUnit u) =>
      _SubscriptionEditorSheetState._aliasFor(c, u);

  @override
  Widget build(BuildContext context) {
    final options = _optionsFor(unit);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Unit toggle ───────────────────────────────────────────────────
        Container(
          width: double.infinity,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: RecurrenceUnit.values.map((u) {
              final isSelected = u == unit;
              final label = switch (u) {
                RecurrenceUnit.day => 'Day',
                RecurrenceUnit.week => 'Week',
                RecurrenceUnit.month => 'Month',
              };
              return Expanded(
                child: GestureDetector(
                  onTap: () => onUnitChanged(u),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryBlue
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.primaryBlue
                                    .withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 12),

        // ── Count chips ───────────────────────────────────────────────────
        Row(
          children: options.map((n) {
            final isSelected = n == count;
            final alias = _alias(n, unit);
            final chipLabel = switch (unit) {
              RecurrenceUnit.day => n == 1 ? '1 day' : '$n days',
              RecurrenceUnit.week => n == 1 ? '1 week' : '$n weeks',
              RecurrenceUnit.month => n == 1 ? '1 month' : '$n months',
            };

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () => onCountTapped(n),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryBlue
                          : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(14),
                      border: isSelected
                          ? null
                          : Border.all(
                              color: const Color(0xFFE2EAF4),
                              width: 1,
                            ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.primaryBlue
                                    .withValues(alpha: 0.22),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          chipLabel,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : AppColors.textDark,
                            fontWeight: FontWeight.w800,
                            fontSize: _chipFontSize(options.length),
                          ),
                        ),
                        if (alias != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            alias,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.75)
                                  : AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// Shrinks font slightly when there are more chips.
  double _chipFontSize(int optionCount) {
    if (optionCount <= 4) return 13;
    if (optionCount == 5) return 12;
    return 11;
  }
}

class _NotifChip extends StatelessWidget {
  const _NotifChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryBlue
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: selected
              ? null
              : Border.all(color: const Color(0xFFE2EAF4)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textDark,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
