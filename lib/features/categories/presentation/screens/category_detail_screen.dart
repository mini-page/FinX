import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:expensio/core/theme/app_colors.dart';
import 'package:expensio/routes/app_routes.dart';
import 'package:expensio/features/expense/data/models/expense_model.dart';
import 'package:expensio/features/expense/presentation/provider/expense_providers.dart';
import 'package:expensio/features/categories/data/models/custom_category_model.dart';
import 'package:expensio/features/categories/presentation/provider/budget_providers.dart';
import 'package:expensio/features/categories/presentation/provider/budget_state.dart';
import 'package:expensio/features/categories/presentation/widgets/category_editor_sheet.dart';
import 'package:expensio/features/categories/presentation/widgets/expense_category.dart';
import 'package:expensio/features/categories/presentation/screens/categories/budget_popup.dart';
import 'package:expensio/features/settings/presentation/provider/preferences_providers.dart';
import 'package:expensio/features/accounts/data/models/account_model.dart';
import 'package:expensio/features/accounts/presentation/provider/account_providers.dart';

class CategoryDetailScreen extends ConsumerStatefulWidget {
  const CategoryDetailScreen({
    super.key,
    required this.categoryName,
    required this.type,
    this.customModel,
  });

  final String categoryName;
  final TransactionType type;
  final CustomCategoryModel? customModel;

  @override
  ConsumerState<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends ConsumerState<CategoryDetailScreen> {
  late String _currentName;

  @override
  void initState() {
    super.initState();
    _currentName = widget.categoryName;
  }

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(currencyFormatProvider);
    final expenses = ref.watch(expenseListProvider).value ?? const <ExpenseModel>[];
    final accounts = ref.watch(accountListProvider).value ?? const <AccountModel>[];
    final accountMap = {for (final a in accounts) a.id: a};
    final now = DateTime.now();

    // Find category metadata
    final allCats = widget.type == TransactionType.expense
        ? ref.watch(allExpenseCategoriesProvider)
        : ref.watch(allIncomeCategoriesProvider);
    final catInfo = allCats.where((c) => c.name.toLowerCase() == _currentName.toLowerCase()).firstOrNull;
    final catColor = catInfo?.color ?? AppColors.primaryBlue;
    final catIcon = catInfo?.icon ?? Icons.category_rounded;

    // Filter transactions for this category
    final categoryTransactions = expenses.where((e) {
      return e.category.toLowerCase() == _currentName.toLowerCase() && e.type == widget.type;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    // Calculate month & all-time totals
    double monthTotal = 0.0;
    double allTimeTotal = 0.0;
    for (final e in categoryTransactions) {
      allTimeTotal += e.amount;
      if (e.date.year == now.year && e.date.month == now.month) {
        monthTotal += e.amount;
      }
    }

    // Budget info if expense
    final budgets = ref.watch(effectiveMonthBudgetsProvider);
    final budgetLimit = budgets[_currentName] ?? 0.0;
    final hasBudget = budgetLimit > 0;
    final budgetProgress = hasBudget ? (monthTotal / budgetLimit).clamp(0.0, 1.0) : 0.0;
    final isOverBudget = hasBudget && monthTotal > budgetLimit;

    // Subcategories
    final subcategoriesMap = ref.watch(categorySubcategoriesProvider);
    final subcategories = subcategoriesMap[_currentName] ?? const <String>[];

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            margin: const EdgeInsets.only(left: 12),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.chevron_left_rounded,
              color: AppColors.textDark,
              size: 22,
            ),
          ),
        ),
        title: Text(
          _currentName,
          style: const TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.textDark, size: 20),
            tooltip: 'Edit Category',
            onPressed: () => _editCategory(catInfo, budgetLimit),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 20),
            tooltip: 'Delete Category',
            onPressed: _confirmDelete,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          // ── Hero Banner ───────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: catColor.withValues(alpha: 0.14),
                  child: Icon(catIcon, color: catColor, size: 30),
                ),
                const SizedBox(height: 12),
                Text(
                  _currentName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.type == TransactionType.expense
                        ? AppColors.danger.withValues(alpha: 0.1)
                        : AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.type == TransactionType.expense ? 'Expense Category' : 'Income Category',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: widget.type == TransactionType.expense ? AppColors.danger : AppColors.success,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('MMMM').format(now),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              currency.format(monthTotal),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: widget.type == TransactionType.expense ? AppColors.textDark : AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'All-Time Total',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              currency.format(allTimeTotal),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Budget Card (Expense Only) ────────────────────────────────────
          if (widget.type == TransactionType.expense) ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.savings_outlined,
                            size: 18,
                            color: isOverBudget ? AppColors.danger : AppColors.primaryBlue,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Monthly Budget',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: _openSetBudgetPopup,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          hasBudget ? 'Edit Limit' : 'Set Limit',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (hasBudget) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: budgetProgress,
                        minHeight: 8,
                        backgroundColor: const Color(0xFFF1F5F9),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isOverBudget ? AppColors.danger : catColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${(budgetProgress * 100).toInt()}% of ${currency.format(budgetLimit)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isOverBudget ? AppColors.danger : AppColors.textMuted,
                          ),
                        ),
                        Text(
                          isOverBudget
                              ? '${currency.format(monthTotal - budgetLimit)} over limit'
                              : '${currency.format(budgetLimit - monthTotal)} left',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isOverBudget ? AppColors.danger : AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    const Text(
                      'No spending budget set for this category.',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Subcategories Section ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Subcategories',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    InkWell(
                      onTap: _addSubcategoryDialog,
                      borderRadius: BorderRadius.circular(8),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Row(
                          children: [
                            Icon(Icons.add_circle_outline_rounded, size: 15, color: AppColors.primaryBlue),
                            SizedBox(width: 4),
                            Text(
                              'Add',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (subcategories.isEmpty)
                  const Text(
                    'No subcategories yet. Tap Add to create tags like "Lunch", "Coffee", etc.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: subcategories.map((sub) {
                      return Chip(
                        label: Text(
                          sub,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textDark),
                        ),
                        backgroundColor: const Color(0xFFF1F5F9),
                        deleteIcon: const Icon(Icons.close_rounded, size: 14, color: AppColors.textMuted),
                        onDeleted: () {
                          ref.read(appPreferencesControllerProvider).removeSubcategory(_currentName, sub);
                        },
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: BorderSide.none,
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Transactions Section ──────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Transactions (${categoryTransactions.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (categoryTransactions.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 36),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.receipt_long_outlined, size: 42, color: AppColors.textMuted.withValues(alpha: 0.5)),
                  const SizedBox(height: 10),
                  const Text(
                    'No transactions recorded in this category.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: categoryTransactions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final txn = categoryTransactions[index];
                final account = txn.accountId != null ? accountMap[txn.accountId] : null;
                return InkWell(
                  onTap: () {
                    AppRoutes.pushEditExpense(
                      context,
                      expenseId: txn.id,
                      initialAmount: txn.amount,
                      initialCategory: txn.category,
                      initialDate: txn.date.toLocal(),
                      initialNote: txn.note,
                      initialAccountId: txn.accountId,
                      initialToAccountId: txn.toAccountId,
                      initialType: txn.type,
                      initialSubcategory: txn.subcategory,
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: catColor.withValues(alpha: 0.12),
                          child: Icon(catIcon, color: catColor, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                txn.note.isNotEmpty ? txn.note : txn.category,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: AppColors.textDark,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Text(
                                    DateFormat('d MMM yyyy').format(txn.date),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textMuted,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (account != null) ...[
                                    const Text(' • ', style: TextStyle(color: AppColors.textMuted)),
                                    Text(
                                      account.name,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.primaryBlue,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${widget.type == TransactionType.income ? '+' : '-'}${currency.format(txn.amount)}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: widget.type == TransactionType.income ? AppColors.success : AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _openSetBudgetPopup() async {
    final now = DateTime.now();
    final currentTotal = ref.read(monthTotalBudgetProvider);
    await showSetBudgetPopup(
      context,
      selectedMonth: now,
      currencySymbol: ref.read(currencySymbolProvider),
      currentTotal: currentTotal,
      onManual: (amount) => ref.read(budgetControllerProvider).saveBudget(
            category: _currentName,
            monthlyLimit: amount,
          ),
      onCopyPrevious: () => ref.read(budgetControllerProvider).saveBudget(
            category: _currentName,
            monthlyLimit: 0,
          ),
    );
  }

  Future<void> _addSubcategoryDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Subcategory', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. Lunch, Groceries, Taxi',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primaryBlue),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      await ref.read(appPreferencesControllerProvider).addSubcategory(_currentName, result);
    }
  }

  Future<void> _editCategory(ExpenseCategory? catInfo, double currentBudget) async {
    final result = await showCategoryEditorSheet(
      context,
      editName: _currentName,
      editIconKey: catInfo?.iconKey,
      editColorHex: catInfo?.colorHex,
      editMonthlyLimit: currentBudget > 0 ? currentBudget : null,
      isBuiltIn: widget.customModel == null,
      currencySymbol: ref.read(currencySymbolProvider),
    );

    if (result == null || !mounted) return;

    final controller = ref.read(appPreferencesControllerProvider);

    if (result.isDelete) {
      await _deleteCategoryConfirmed();
      return;
    }

    if (widget.customModel != null) {
      final updated = widget.customModel!.copyWith(
        name: result.name,
        iconKey: result.iconKey,
        colorHex: result.colorHex,
      );
      if (widget.type == TransactionType.expense) {
        await controller.updateExpenseCategory(updated);
      } else {
        await controller.updateIncomeCategory(updated);
      }
    } else {
      final override = BuiltInCategoryOverride(
        name: _currentName,
        iconKey: result.iconKey,
        colorHex: result.colorHex,
      );
      if (widget.type == TransactionType.expense) {
        await controller.saveBuiltInExpenseCategoryOverride(override);
      } else {
        await controller.saveBuiltInIncomeCategoryOverride(override);
      }
    }

    if (result.monthlyLimit != null) {
      await ref.read(budgetControllerProvider).saveBudget(
            category: result.name,
            monthlyLimit: result.monthlyLimit!,
          );
    }

    setState(() {
      _currentName = result.name;
    });
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Category', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to delete "$_currentName"? Past transactions in this category will remain intact.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _deleteCategoryConfirmed();
    }
  }

  Future<void> _deleteCategoryConfirmed() async {
    final controller = ref.read(appPreferencesControllerProvider);
    await controller.deleteCategory(
      name: _currentName,
      isExpense: widget.type == TransactionType.expense,
      customId: widget.customModel?.id,
    );

    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$_currentName deleted.')),
    );
  }
}
