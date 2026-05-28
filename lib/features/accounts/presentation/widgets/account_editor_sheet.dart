import 'package:flutter/material.dart';

import 'package:xpens/core/theme/app_colors.dart';
import 'package:xpens/core/utils/context_extensions.dart';
import 'package:xpens/features/accounts/data/models/account_model.dart';
import 'package:xpens/features/accounts/presentation/widgets/account_icons.dart';

class AccountFormResult {
  const AccountFormResult({
    this.id,
    required this.name,
    required this.iconKey,
    required this.balance,
  });

  final String? id;
  final String name;
  final String iconKey;
  final double balance;
}

Future<AccountFormResult?> showAccountEditorSheet(
  BuildContext context, {
  AccountModel? account,
}) {
  return showModalBottomSheet<AccountFormResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _AccountEditorSheet(account: account),
  );
}

class _AccountEditorSheet extends StatefulWidget {
  const _AccountEditorSheet({this.account});

  final AccountModel? account;

  @override
  State<_AccountEditorSheet> createState() => _AccountEditorSheetState();
}

class _AccountEditorSheetState extends State<_AccountEditorSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _balanceController;
  late String _iconKey;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.account?.name ?? '');
    _balanceController = TextEditingController(
      text: widget.account?.balance.toStringAsFixed(0) ?? '0',
    );
    _iconKey = widget.account?.iconKey ?? accountIconOptions.first.key;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
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
              widget.account == null ? 'Add Account' : 'Edit Account',
              style: const TextStyle(
                color: AppColors.textDark,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Store a real account name, icon, and current balance for the accounts tab.',
              style: TextStyle(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: _inputDecoration('Account name'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _balanceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: _inputDecoration(
                'Current balance',
              ).copyWith(prefixText: '₹ '),
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
              children: accountIconOptions.map((option) {
                final isSelected = option.key == _iconKey;
                return ChoiceChip(
                  label: Icon(
                    option.icon,
                    color: isSelected ? Colors.white : AppColors.primaryBlue,
                  ),
                  selected: isSelected,
                  selectedColor: AppColors.primaryBlue,
                  backgroundColor: AppColors.lightBlueBg,
                  onSelected: (_) {
                    setState(() {
                      _iconKey = option.key;
                    });
                  },
                );
              }).toList(growable: false),
            ),
            const SizedBox(height: 22),
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
                  widget.account == null ? 'Create Account' : 'Save Changes',
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

  void _submit() {
    final name = _nameController.text.trim();
    final balance = double.tryParse(_balanceController.text.trim());

    if (name.isEmpty || balance == null) {
      context.showSnackBar('Enter a valid account name and balance.');
      return;
    }

    Navigator.of(context).pop(
      AccountFormResult(
        id: widget.account?.id,
        name: name,
        iconKey: _iconKey,
        balance: balance,
      ),
    );
  }
}
