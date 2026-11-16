import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../categories/presentation/widgets/category_editor_sheet.dart';
import '../../../../categories/presentation/widgets/expense_category.dart';
import '../../../data/models/expense_model.dart';
import '../../../../../shared/widgets/app_search_bar.dart';

class CategorySelectionResult {
  const CategorySelectionResult({
    required this.type,
    required this.categoryName,
    this.subcategoryName,
    this.isUncategorised = false,
  });

  final TransactionType type;
  final String categoryName;
  final String? subcategoryName;
  final bool isUncategorised;

  static const uncategorised = CategorySelectionResult(
    type: TransactionType.expense,
    categoryName: 'Uncategorised',
    isUncategorised: true,
  );
}

/// Themed Category Selection Bottom Sheet matching 1000040658.png.
/// Displays categories as cards in a list, each with its subcategories underneath.
Future<CategorySelectionResult?> showCategorySelectionSheet({
  required BuildContext context,
  required List<ExpenseCategory> expenseCategories,
  required List<ExpenseCategory> incomeCategories,
  required Map<String, List<String>> subcategoriesMap,
  required TransactionType initialType,
  String? selectedCategory,
  String? selectedSubcategory,
}) {
  return showModalBottomSheet<CategorySelectionResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => CategorySelectionSheet(
      expenseCategories: expenseCategories,
      incomeCategories: incomeCategories,
      subcategoriesMap: subcategoriesMap,
      initialType: initialType,
      selectedCategory: selectedCategory,
      selectedSubcategory: selectedSubcategory,
    ),
  );
}

class CategorySelectionSheet extends StatefulWidget {
  const CategorySelectionSheet({
    super.key,
    required this.expenseCategories,
    required this.incomeCategories,
    required this.subcategoriesMap,
    required this.initialType,
    this.selectedCategory,
    this.selectedSubcategory,
  });

  final List<ExpenseCategory> expenseCategories;
  final List<ExpenseCategory> incomeCategories;
  final Map<String, List<String>> subcategoriesMap;
  final TransactionType initialType;
  final String? selectedCategory;
  final String? selectedSubcategory;

  static final List<ExpenseCategory> transferCategories = [
    ExpenseCategory(name: 'Cash Withdrawal', icon: Icons.local_atm_rounded, color: const Color(0xFF10B981)),
    ExpenseCategory(name: 'Credit Card Bill', icon: Icons.credit_card_rounded, color: const Color(0xFF3B82F6)),
    ExpenseCategory(name: 'Self Bank Transfer', icon: Icons.sync_alt_rounded, color: const Color(0xFF8B5CF6)),
    ExpenseCategory(name: 'Wallet Top-up', icon: Icons.account_balance_wallet_rounded, color: const Color(0xFFF59E0B)),
    ExpenseCategory(name: 'Loan Repayment', icon: Icons.payments_rounded, color: const Color(0xFFEC4899)),
    ExpenseCategory(name: 'Investment', icon: Icons.trending_up_rounded, color: const Color(0xFF6366F1)),
    ExpenseCategory(name: 'Other Transfer', icon: Icons.swap_horiz_rounded, color: const Color(0xFF64748B)),
  ];

  @override
  State<CategorySelectionSheet> createState() => _CategorySelectionSheetState();
}

class _CategorySelectionSheetState extends State<CategorySelectionSheet> {
  late TransactionType _activeType;
  String _searchQuery = '';
  final TextEditingController _newSubcatController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _activeType = widget.initialType;
  }

  @override
  void dispose() {
    _newSubcatController.dispose();
    super.dispose();
  }

  void _onAddNewCategory() async {
    HapticFeedback.lightImpact();
    final created = await showCategoryEditorSheet(context);
    if (created != null && mounted) {
      Navigator.of(context).pop(
        CategorySelectionResult(
          type: _activeType,
          categoryName: created.name,
        ),
      );
    }
  }

  void _onAddNewSubcategory(String categoryName) async {
    _newSubcatController.clear();
    final sub = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Subcategory to $categoryName'),
        content: TextField(
          controller: _newSubcatController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. Dinner, Snacks, Uber',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final text = _newSubcatController.text.trim();
              if (text.isNotEmpty) Navigator.of(ctx).pop(text);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (sub != null && sub.isNotEmpty && mounted) {
      Navigator.of(context).pop(
        CategorySelectionResult(
          type: _activeType,
          categoryName: categoryName,
          subcategoryName: sub,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF13171F) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E2430) : Colors.white;
    final textDark = isDark ? Colors.white : AppColors.textDark;
    final textMuted = isDark ? const Color(0xFF94A3B8) : AppColors.textMuted;
    final border = isDark ? const Color(0xFF2D3748) : const Color(0xFFE2E8F0);

    final isTransfer = _activeType == TransactionType.transfer;
    final isIncome = _activeType == TransactionType.income;
    final baseCategories = isIncome
        ? widget.incomeCategories
        : widget.expenseCategories;

    final filteredCategories = isTransfer
        ? CategorySelectionSheet.transferCategories.where((c) {
            return c.name.toLowerCase().contains(_searchQuery);
          }).toList()
        : baseCategories.where((c) {
            return c.name.toLowerCase().contains(_searchQuery);
          }).toList();

    final isUncategorisedSelected = widget.selectedCategory == null ||
        widget.selectedCategory!.isEmpty ||
        widget.selectedCategory!.toLowerCase() == 'uncategorised';

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header Row
            Row(
              children: [
                Expanded(
                  child: Text(
                    isTransfer
                        ? 'Select Transfer Type'
                        : isIncome
                            ? 'Select Income Category'
                            : 'Select Category',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: textDark,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).pop(
                      CategorySelectionResult(
                        type: _activeType,
                        categoryName: 'Uncategorised',
                        isUncategorised: true,
                      ),
                    );
                  },
                  child: Text(
                    'Clear',
                    style: TextStyle(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: textMuted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Search Bar & [+ Add Category]
            Row(
              children: [
                Expanded(
                  child: AppSearchBar(
                    hintText: 'Search categories...',
                    onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                  ),
                ),
                if (!isTransfer) ...[
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    onPressed: _onAddNewCategory,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('New', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // Pinned Uncategorised Button
            InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.of(context).pop(
                  CategorySelectionResult(
                    type: _activeType,
                    categoryName: 'Uncategorised',
                    isUncategorised: true,
                  ),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isUncategorisedSelected
                      ? AppColors.primaryBlue.withValues(alpha: isDark ? 0.2 : 0.1)
                      : cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isUncategorisedSelected ? AppColors.primaryBlue : border,
                    width: isUncategorisedSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF64748B).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.help_outline_rounded, color: Color(0xFF64748B), size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Uncategorised',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: textDark,
                        ),
                      ),
                    ),
                    if (isUncategorisedSelected)
                      const Icon(Icons.check_circle_rounded, color: AppColors.primaryBlue, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Category Cards List with Subcategories (1000040658.png)
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.52,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: filteredCategories.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final cat = filteredCategories[i];
                  final isSelected = widget.selectedCategory == cat.name;
                  final subcategories = widget.subcategoriesMap[cat.name] ?? const <String>[];

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isSelected ? AppColors.primaryBlue : border,
                        width: isSelected ? 1.5 : 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category Header Row
                        InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            Navigator.of(context).pop(
                              CategorySelectionResult(
                                type: _activeType,
                                categoryName: cat.name,
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: cat.color.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(cat.icon, color: cat.color, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    cat.name,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: textDark,
                                    ),
                                  ),
                                ),
                                if (isSelected && (widget.selectedSubcategory == null || widget.selectedSubcategory!.isEmpty))
                                  const Icon(Icons.check_circle_rounded, color: AppColors.primaryBlue, size: 22),
                              ],
                            ),
                          ),
                        ),

                        // Subcategories Row (1000040658.png)
                        if (subcategories.isNotEmpty || !isTransfer) ...[
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              children: [
                                if (!isTransfer) ...[
                                  InkWell(
                                    onTap: () => _onAddNewSubcategory(cat.name),
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryBlue.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.add_rounded, size: 14, color: AppColors.primaryBlue),
                                          SizedBox(width: 4),
                                          Text(
                                            'Add',
                                            style: TextStyle(
                                              color: AppColors.primaryBlue,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                ...subcategories.map((sub) {
                                  final isSubSelected = isSelected && widget.selectedSubcategory == sub;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: InkWell(
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        Navigator.of(context).pop(
                                          CategorySelectionResult(
                                            type: _activeType,
                                            categoryName: cat.name,
                                            subcategoryName: sub,
                                          ),
                                        );
                                      },
                                      borderRadius: BorderRadius.circular(16),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: isSubSelected
                                              ? cat.color.withValues(alpha: 0.2)
                                              : (isDark ? const Color(0xFF13171F) : const Color(0xFFF1F5F9)),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color: isSubSelected ? cat.color : Colors.transparent,
                                          ),
                                        ),
                                        child: Text(
                                          sub,
                                          style: TextStyle(
                                            color: isSubSelected ? cat.color : textDark,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
