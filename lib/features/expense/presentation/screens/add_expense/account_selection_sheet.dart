import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../accounts/data/models/account_model.dart';
import '../../../../accounts/presentation/widgets/account_editor_sheet.dart';
import '../../../../accounts/presentation/widgets/account_icons.dart';
import '../../../../../shared/widgets/app_search_bar.dart';

/// Modal bottom sheet for choosing an account.
class AccountSelectionSheet extends StatefulWidget {
  const AccountSelectionSheet({
    super.key,
    required this.accountsList,
    required this.selectedAccountId,
    required this.currencyFormat,
    this.title = 'Select Account',
    this.subtitle = 'Choose the account for this transaction.',
  });

  final List<AccountModel> accountsList;
  final String? selectedAccountId;
  final NumberFormat currencyFormat;
  final String title;
  final String subtitle;

  @override
  State<AccountSelectionSheet> createState() => _AccountSelectionSheetState();
}

class _AccountSelectionSheetState extends State<AccountSelectionSheet> {
  String _searchQuery = '';

  void _onAddNewAccount() async {
    HapticFeedback.lightImpact();
    final created = await showAccountEditorSheet(context);
    if (created != null && mounted) {
      Navigator.of(context).pop(created);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final filtered = widget.accountsList.where((acc) {
      return acc.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Container(
      padding: EdgeInsets.fromLTRB(20, 14, 20, bottomPadding + 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textDark,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                tooltip: 'Close',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Search + Add Account Row
          Row(
            children: [
              Expanded(
                child: AppSearchBar(
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim();
                    });
                  },
                  onClear: () {
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                  hintText: 'Search account...',
                  hasBorder: true,
                ),
              ),
              const SizedBox(width: 10),
              Material(
                color: AppColors.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: _onAddNewAccount,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.add_rounded, size: 18, color: AppColors.primaryBlue),
                        SizedBox(width: 4),
                        Text(
                          'Add',
                          style: TextStyle(
                            color: AppColors.primaryBlue,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Accounts List
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.45,
            ),
            child: filtered.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 28.0),
                      child: Text(
                        'No accounts found.',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final acc = filtered[index];
                      final isSelected = widget.selectedAccountId == acc.id;

                      return Material(
                        color: isSelected
                            ? AppColors.primaryBlue.withValues(alpha: 0.05)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.of(context).pop(acc);
                          },
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primaryBlue
                                    : const Color(0xFFE2E8F0),
                                width: isSelected ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primaryBlue.withValues(alpha: 0.12)
                                        : Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Icon(
                                    resolveAccountIcon(acc.iconKey),
                                    color: isSelected
                                        ? AppColors.primaryBlue
                                        : AppColors.textDark,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        acc.name,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textDark,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Balance: ${widget.currencyFormat.format(acc.balance)}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textMuted,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: AppColors.primaryBlue,
                                    size: 22,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Helper method to open [AccountSelectionSheet]
Future<AccountModel?> showAccountSelectionSheet({
  required BuildContext context,
  required List<AccountModel> accountsList,
  required NumberFormat currencyFormat,
  String? selectedAccountId,
  String title = 'Select Account',
  String subtitle = 'Choose the account for this transaction.',
}) {
  HapticFeedback.lightImpact();
  return showModalBottomSheet<AccountModel>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x66000000),
    builder: (ctx) => AccountSelectionSheet(
      accountsList: accountsList,
      selectedAccountId: selectedAccountId,
      currencyFormat: currencyFormat,
      title: title,
      subtitle: subtitle,
    ),
  );
}
