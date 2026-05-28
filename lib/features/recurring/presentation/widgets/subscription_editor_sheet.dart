import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/context_extensions.dart';
import '../../data/models/recurring_subscription_model.dart';
import 'subscription_icons.dart';

class SubscriptionFormResult {
  const SubscriptionFormResult({
    this.id,
    required this.name,
    required this.amount,
    required this.nextBillDate,
    required this.iconKey,
    required this.note,
    required this.isActive,
  });

  final String? id;
  final String name;
  final double amount;
  final DateTime nextBillDate;
  final String iconKey;
  final String note;
  final bool isActive;
}

Future<SubscriptionFormResult?> showSubscriptionEditorSheet(
  BuildContext context, {
  RecurringSubscriptionModel? subscription,
}) {
  return showModalBottomSheet<SubscriptionFormResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _SubscriptionEditorSheet(subscription: subscription),
  );
}

class _SubscriptionEditorSheet extends StatefulWidget {
  const _SubscriptionEditorSheet({this.subscription});

  final RecurringSubscriptionModel? subscription;

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

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.subscription?.name ?? '',
    );
    _amountController = TextEditingController(
      text: widget.subscription?.amount.toStringAsFixed(0) ?? '',
    );
    _noteController = TextEditingController(
      text: widget.subscription?.note ?? '',
    );

    _nextBillDate = widget.subscription?.nextBillDate ?? DateTime.now();
    _iconKey =
        widget.subscription?.iconKey ?? subscriptionIconOptions.first.key;
    _isActive = widget.subscription?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.only(bottom: insets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Center(
              child: SizedBox(
                width: 46,
                child: Divider(thickness: 4, color: AppColors.backgroundLight),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              widget.subscription == null
                  ? 'Add Recurring Subscription'
                  : 'Edit Subscription',
              style: const TextStyle(
                color: AppColors.textDark,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Store the next bill date and amount so recurring payments stay visible.',
              style: TextStyle(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: _inputDecoration('Subscription name'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: _inputDecoration('Amount').copyWith(prefixText: '₹ '),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _noteController,
              decoration: _inputDecoration('Note (optional)'),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.event_outlined,
                        color: AppColors.primaryBlue),
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
            const Text(
              'Icon',
              style: TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: subscriptionIconOptions.map((option) {
                final isSelected = option.key == _iconKey;
                return ChoiceChip(
                  label: Icon(
                    option.icon,
                    color: isSelected ? Colors.white : AppColors.primaryBlue,
                  ),
                  selected: isSelected,
                  selectedColor: AppColors.primaryBlue,
                  backgroundColor: AppColors.lightBlueBg,
                  onSelected: (_) => setState(() => _iconKey = option.key),
                );
              }).toList(growable: false),
            ),
            const SizedBox(height: 16),
            SwitchListTile.adaptive(
              value: _isActive,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Subscription active',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              onChanged: (value) => setState(() => _isActive = value),
            ),
            const SizedBox(height: 12),
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
                      ? 'Create Subscription'
                      : 'Save Changes',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
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
        borderRadius: BorderRadius.circular(18),
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
    if (picked == null) {
      return;
    }
    setState(() => _nextBillDate = picked);
  }

  void _submit() {
    final name = _nameController.text.trim();
    final amount = double.tryParse(_amountController.text.trim());

    if (name.isEmpty || amount == null || amount <= 0) {
      context.showSnackBar('Enter a valid subscription name and amount.');
      return;
    }

    Navigator.of(context).pop(
      SubscriptionFormResult(
        id: widget.subscription?.id,
        name: name,
        amount: amount,
        nextBillDate: _nextBillDate,
        iconKey: _iconKey,
        note: _noteController.text.trim(),
        isActive: _isActive,
      ),
    );
  }
}
