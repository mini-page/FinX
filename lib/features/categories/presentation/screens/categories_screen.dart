import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/widgets/app_tab_switcher.dart';
import 'package:xpens/features/accounts/accounts.dart';
import '../../data/models/custom_category_model.dart';
import 'package:xpens/features/expense/data/models/expense_model.dart';
import '../provider/budget_providers.dart';
import '../provider/budget_state.dart';
import 'package:xpens/features/expense/presentation/provider/expense_providers.dart';
import 'package:xpens/features/settings/presentation/provider/preferences_providers.dart';
import 'package:xpens/features/expense/presentation/widgets/amount_visibility.dart';
import '../widgets/category_editor_sheet.dart';
import '../widgets/expense_category.dart';
import 'categories/budget_popup.dart';
import 'categories/categories_widgets.dart';

enum _BoardMode { expenses, income, accounts }

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final TextEditingController _searchController;
  _BoardMode _mode = _BoardMode.expenses;
  String _searchQuery = '';

  static const List<AppTabItem> _categoryTabs = <AppTabItem>[
    AppTabItem(label: 'Expense', icon: Icons.arrow_outward_rounded),
    AppTabItem(label: 'Income', icon: Icons.arrow_downward_rounded),
    AppTabItem(label: 'Account', icon: Icons.account_balance_wallet_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categoryTabs.length, vsync: this);
    _searchController = TextEditingController();
    _searchController.addListener(() {
      final q = _searchController.text;
      if (q != _searchQuery) setState(() => _searchQuery = q);
    });
    _tabController.addListener(() {
      final newIndex = _tabController.index;
      final newMode = _BoardMode.values[newIndex];
      if (_mode != newMode) {
        // Update state (including _searchQuery) first so the searchController
        // listener finds the query already empty and skips its own setState.
        setState(() {
          _mode = newMode;
          _searchQuery = '';
        });
        _searchController.clear();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Month-aware providers
    final selectedMonth = ref.watch(selectedMonthProvider);
    final monthStats = ref.watch(monthlyStatsForMonthProvider);
    final effectiveBudgets = ref.watch(effectiveMonthBudgetsProvider);
    final totalBudget = ref.watch(monthTotalBudgetProvider);
    final remainingBudget = ref.watch(monthRemainingBudgetProvider);

    // Infrastructure providers
    final budgetState = ref.watch(budgetTargetsProvider);
    final accountState = ref.watch(accountListProvider);
    final privacyModeEnabled = ref.watch(privacyModeEnabledProvider);
    final currency = ref.watch(currencyFormatProvider);
    final disabledExpenseCategories =
        ref.watch(disabledExpenseCategoriesProvider);
    final disabledIncomeCategories =
        ref.watch(disabledIncomeCategoriesProvider);
    final disabledAccountIds = ref.watch(disabledAccountIdsProvider);
    final allExpenseCategories = ref.watch(allExpenseCategoriesProvider);
    final allIncomeCategories = ref.watch(allIncomeCategoriesProvider);
    final customExpenseCategories =
        ref.watch(customExpenseCategoryListProvider);
    final customIncomeCategories = ref.watch(customIncomeCategoryListProvider);
    final accounts = accountState.value ?? const <AccountModel>[];

    final now = DateTime.now();
    final canSetBudget = selectedMonth.year > now.year ||
        (selectedMonth.year == now.year &&
            selectedMonth.month >= now.month);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _buildHeader(
          context: context,
          selectedMonth: selectedMonth,
          totalBudget: totalBudget,
          remainingBudget: remainingBudget,
          currency: currency,
          masked: privacyModeEnabled,
        ),
        if ((_mode == _BoardMode.expenses && budgetState.isLoading) ||
            (_mode == _BoardMode.accounts && accountState.isLoading))
          const LinearProgressIndicator(minHeight: 3),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: _BoardMode.values.map((mode) {
              final allCards = _buildCards(
                mode: mode,
                stats: monthStats,
                budgets: effectiveBudgets,
                accounts: accounts,
                disabledExpenseCategories: disabledExpenseCategories,
                disabledIncomeCategories: disabledIncomeCategories,
                disabledAccountIds: disabledAccountIds,
                allExpenseCategories: allExpenseCategories,
                allIncomeCategories: allIncomeCategories,
                customExpenseCategories: customExpenseCategories,
                customIncomeCategories: customIncomeCategories,
              );
              final filteredCards = _searchQuery.isEmpty
                  ? allCards
                  : allCards
                      .where((c) => c.title
                          .toLowerCase()
                          .contains(_searchQuery.toLowerCase()))
                      .toList(growable: false);
              return _buildModeScrollPane(
                mode: mode,
                cards: filteredCards,
                currency: currency,
                privacyModeEnabled: privacyModeEnabled,
                canSetBudget: canSetBudget,
              );
            }).toList(growable: false),
          ),
        ),
      ],
    );
  }

  // ── header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader({
    required BuildContext context,
    required DateTime selectedMonth,
    required double? totalBudget,
    required double? remainingBudget,
    required NumberFormat currency,
    required bool masked,
  }) {
    final monthLabel = DateFormat('MMMM yyyy').format(selectedMonth);
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            AppSpacing.lg, topPadding + AppSpacing.md, AppSpacing.lg, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // ── Row 1: month navigation + budget summary ──────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                _MonthNavButton(
                  icon: Icons.chevron_left_rounded,
                  onTap: _goToPreviousMonth,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  monthLabel,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                _MonthNavButton(
                  icon: Icons.chevron_right_rounded,
                  onTap: _goToNextMonth,
                ),
                const Spacer(),
                if (totalBudget != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        'Budget: ${maskAmount(currency.format(totalBudget), masked: masked)}',
                        style: const TextStyle(
                          color: AppColors.textDark,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (remainingBudget != null) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          remainingBudget >= 0
                              ? 'Remaining: ${maskAmount(currency.format(remainingBudget), masked: masked)}'
                              : 'Over by: ${maskAmount(currency.format(remainingBudget.abs()), masked: masked)}',
                          style: TextStyle(
                            color: remainingBudget >= 0
                                ? AppColors.success
                                : AppColors.danger,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // ── Search bar ────────────────────────────────────────────────
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search ${_modeName(_mode)}...',
                hintStyle: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppColors.textMuted, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded,
                            size: 18, color: AppColors.textMuted),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surfaceLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                isDense: true,
              ),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // ── Tab switcher ──────────────────────────────────────────────
            AppTabSwitcher(
              tabs: _categoryTabs,
              selected: _mode.index,
              onChanged: (index) {
                // Update mode + query in one setState, then clear the
                // controller so its listener finds the query already empty.
                setState(() {
                  _mode = _BoardMode.values[index];
                  _searchQuery = '';
                });
                _searchController.clear();
                _tabController.animateTo(index);
              },
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
        ),
      ),
    );
  }

  // ── scroll pane ────────────────────────────────────────────────────────────

  Widget _buildModeScrollPane({
    required _BoardMode mode,
    required List<CategoryGridData> cards,
    required NumberFormat currency,
    required bool privacyModeEnabled,
    required bool canSetBudget,
  }) {
    // index 0 = action bar, 1..N = category cards
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 130),
      itemCount: cards.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildActionBar(mode, canSetBudget);
        }
        final entry = cards[index - 1];
        return CategoryListCard(
          title: entry.title,
          icon: entry.icon,
          tone: entry.tone,
          amount: _displayAmount(
              entry.amount, entry.amountColor, currency,
              masked: privacyModeEnabled),
          progressLabel: entry.progressLabel,
          progress: entry.progress,
          isEnabled: entry.isEnabled,
          onTap: entry.onTap,
          onToggle: entry.onToggle,
          amountColor: entry.amountColor,
        );
      },
    );
  }

  // ── action bar ─────────────────────────────────────────────────────────────

  Widget _buildActionBar(_BoardMode mode, bool canSetBudget) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _ActionButton(
            icon: Icons.add_rounded,
            label: _actionTitle(mode),
            onTap: () => _handlePrimaryActionTapFor(mode),
          ),
        ),
        if (canSetBudget) ...<Widget>[
          const SizedBox(width: 10),
          Expanded(
            child: _ActionButton(
              icon: Icons.savings_outlined,
              label: 'Set Budget',
              accentColor: AppColors.success,
              onTap: _openSetBudgetPopup,
            ),
          ),
        ],
      ],
    );
  }

  // ── month navigation ───────────────────────────────────────────────────────

  void _goToPreviousMonth() {
    final current = ref.read(selectedMonthProvider);
    ref.read(selectedMonthProvider.notifier).setMonth(
          DateTime(current.year, current.month - 1),
        );
  }

  void _goToNextMonth() {
    final current = ref.read(selectedMonthProvider);
    ref.read(selectedMonthProvider.notifier).setMonth(
          DateTime(current.year, current.month + 1),
        );
  }

  // ── set budget popup ───────────────────────────────────────────────────────

  Future<void> _openSetBudgetPopup() async {
    final selectedMonth = ref.read(selectedMonthProvider);
    final currentTotal = ref.read(monthTotalBudgetProvider);
    await showSetBudgetPopup(
      context,
      selectedMonth: selectedMonth,
      currencySymbol: ref.read(currencySymbolProvider),
      currentTotal: currentTotal,
      onManual: (amount) =>
          ref.read(monthBudgetControllerProvider).saveMonthTotal(
                selectedMonth,
                amount,
              ),
      onCopyPrevious: () =>
          ref.read(monthBudgetControllerProvider).copyFromPreviousMonth(
                selectedMonth,
              ),
    );
  }

  List<CategoryGridData> _buildCards({
    required _BoardMode mode,
    required ExpenseStats stats,
    required Map<String, double> budgets,
    required List<AccountModel> accounts,
    required Set<String> disabledExpenseCategories,
    required Set<String> disabledIncomeCategories,
    required Set<String> disabledAccountIds,
    required List<ExpenseCategory> allExpenseCategories,
    required List<ExpenseCategory> allIncomeCategories,
    required List<CustomCategoryModel> customExpenseCategories,
    required List<CustomCategoryModel> customIncomeCategories,
  }) {
    final builtInExpenseNames = expenseCategories.map((c) => c.name).toSet();
    final builtInIncomeNames = incomeCategories.map((c) => c.name).toSet();

    switch (mode) {
      case _BoardMode.expenses:
        return allExpenseCategories.map(
          (category) {
            final amount = stats.categoryTotals[category.name] ?? 0;
            final budget = budgets[category.name] ?? 0;
            final isEnabled =
                !disabledExpenseCategories.contains(category.name);
            final isCustom = !builtInExpenseNames.contains(category.name);
            final customModel = isCustom
                ? customExpenseCategories
                    .where((c) => c.name == category.name)
                    .firstOrNull
                : null;
            return CategoryGridData(
              title: category.name,
              icon: category.icon,
              tone: category.color,
              amount: amount,
              amountColor: AppColors.textDark,
              progress: _progressForExpenseCategory(
                amount: amount,
                budget: budget,
                monthTotal: stats.monthTotal,
              ),
              isEnabled: isEnabled,
              progressLabel: _expenseProgressLabel(
                amount: amount,
                budget: budget,
                monthTotal: stats.monthTotal,
                enabled: isEnabled,
              ),
              onTap: isCustom && customModel != null
                  ? () => _openCustomCategoryEditor(
                        customModel,
                        TransactionType.expense,
                        budget,
                      )
                  : () => _openBuiltInCategoryEditor(
                        category,
                        budget,
                        TransactionType.expense,
                      ),
              onToggle: (value) =>
                  _setExpenseCategoryEnabled(category.name, value),
            );
          },
        ).toList(growable: false);
      case _BoardMode.income:
        return allIncomeCategories.map(
          (category) {
            final amount = stats.incomeCategoryTotals[category.name] ?? 0;
            final budget = budgets[category.name] ?? 0;
            final isEnabled = !disabledIncomeCategories.contains(category.name);
            final isCustom = !builtInIncomeNames.contains(category.name);
            final customModel = isCustom
                ? customIncomeCategories
                    .where((c) => c.name == category.name)
                    .firstOrNull
                : null;
            return CategoryGridData(
              title: category.name,
              icon: category.icon,
              tone: category.color,
              amount: amount,
              amountColor: AppColors.success,
              progress: _progressForIncomeCategory(
                amount: amount,
                monthTotal: stats.monthIncomeTotal,
              ),
              isEnabled: isEnabled,
              progressLabel: _incomeProgressLabel(
                amount: amount,
                monthTotal: stats.monthIncomeTotal,
                enabled: isEnabled,
              ),
              onTap: isCustom && customModel != null
                  ? () => _openCustomCategoryEditor(
                        customModel,
                        TransactionType.income,
                        budget,
                      )
                  : () => _openBuiltInCategoryEditor(
                        category,
                        budget,
                        TransactionType.income,
                      ),
              onToggle: (value) =>
                  _setIncomeCategoryEnabled(category.name, value),
            );
          },
        ).toList(growable: false);
      case _BoardMode.accounts:
        final totalAbsoluteBalance = accounts.fold<double>(
          0,
          (sum, account) => sum + account.balance.abs(),
        );

        return accounts.map(
          (account) {
            final isEnabled = !disabledAccountIds.contains(account.id);
            return CategoryGridData(
              title: account.name,
              icon: resolveAccountIcon(account.iconKey),
              tone: AppColors.primaryBlue,
              amount: account.balance,
              amountColor: account.balance < 0
                  ? AppColors.danger
                  : AppColors.primaryBlue,
              progress: totalAbsoluteBalance == 0
                  ? 0
                  : (account.balance.abs() / totalAbsoluteBalance),
              isEnabled: isEnabled,
              progressLabel: _accountProgressLabel(
                balance: account.balance,
                totalAbsoluteBalance: totalAbsoluteBalance,
                enabled: isEnabled,
              ),
              onTap: () => _openAccountEditor(account: account),
              onToggle: (value) => _setAccountEnabled(account.id, value),
            );
          },
        ).toList(growable: false);
    }
  }

  String _displayAmount(
    double amount,
    Color? amountColor,
    NumberFormat currency, {
    required bool masked,
  }) {
    if (amountColor == AppColors.success) {
      return '+${maskAmount(currency.format(amount), masked: masked)}';
    }

    if (amount < 0) {
      return '-${maskAmount(currency.format(amount.abs()), masked: masked)}';
    }

    return maskAmount(currency.format(amount), masked: masked);
  }

  String _modeName(_BoardMode mode) {
    switch (mode) {
      case _BoardMode.expenses:
        return 'expense categories';
      case _BoardMode.income:
        return 'income categories';
      case _BoardMode.accounts:
        return 'accounts';
    }
  }

  String _actionTitle(_BoardMode mode) {
    switch (mode) {
      case _BoardMode.expenses:
        return 'Add category';
      case _BoardMode.income:
        return 'Add category';
      case _BoardMode.accounts:
        return 'Add account';
    }
  }

  void _handlePrimaryActionTapFor(_BoardMode mode) {
    switch (mode) {
      case _BoardMode.expenses:
        _openCategoryCreator(TransactionType.expense);
        return;
      case _BoardMode.income:
        _openCategoryCreator(TransactionType.income);
        return;
      case _BoardMode.accounts:
        _openAccountEditor();
        return;
    }
  }

  String _expenseProgressLabel({
    required double amount,
    required double budget,
    required double monthTotal,
    required bool enabled,
  }) {
    if (!enabled) {
      return 'Disabled in composer';
    }
    if (budget > 0) {
      if (amount <= 0) {
        return 'Budget tracked';
      }
      final share = ((amount / budget) * 100).round();
      return '$share% of budget';
    }
    if (monthTotal <= 0 || amount <= 0) {
      return 'No spending yet';
    }
    final share = ((amount / monthTotal) * 100).round();
    return '$share% of monthly spend';
  }

  String _incomeProgressLabel({
    required double amount,
    required double monthTotal,
    required bool enabled,
  }) {
    if (!enabled) {
      return 'Disabled in composer';
    }
    if (monthTotal <= 0 || amount <= 0) {
      return 'No income yet';
    }

    final share = ((amount / monthTotal) * 100).round();
    return '$share% of monthly income';
  }

  String _accountProgressLabel({
    required double balance,
    required double totalAbsoluteBalance,
    required bool enabled,
  }) {
    if (!enabled) {
      return 'Disabled in composer';
    }
    if (totalAbsoluteBalance <= 0 || balance == 0) {
      return 'No balance yet';
    }
    final share = ((balance.abs() / totalAbsoluteBalance) * 100).round();
    return '$share% of tracked balance';
  }

  double _progressForExpenseCategory({
    required double amount,
    required double budget,
    required double monthTotal,
  }) {
    if (budget > 0) {
      return (amount / budget).clamp(0, 1);
    }
    if (monthTotal <= 0 || amount <= 0) {
      return 0;
    }
    return (amount / monthTotal).clamp(0, 1);
  }

  double _progressForIncomeCategory({
    required double amount,
    required double monthTotal,
  }) {
    if (monthTotal <= 0 || amount <= 0) {
      return 0;
    }
    return (amount / monthTotal).clamp(0, 1);
  }

  Future<void> _setExpenseCategoryEnabled(
      String categoryName, bool enabled) async {
    try {
      await ref
          .read(appPreferencesControllerProvider)
          .setExpenseCategoryEnabled(categoryName, enabled);
    } catch (_) {
      _showFeedback('Could not update $categoryName.');
    }
  }

  Future<void> _setIncomeCategoryEnabled(
      String categoryName, bool enabled) async {
    try {
      await ref
          .read(appPreferencesControllerProvider)
          .setIncomeCategoryEnabled(categoryName, enabled);
    } catch (_) {
      _showFeedback('Could not update $categoryName.');
    }
  }

  Future<void> _setAccountEnabled(String accountId, bool enabled) async {
    try {
      await ref.read(appPreferencesControllerProvider).setAccountEnabled(
            accountId,
            enabled,
          );
    } catch (_) {
      _showFeedback('Could not update the account state.');
    }
  }

  Future<void> _openCategoryCreator(TransactionType type) async {
    final result = await showCategoryEditorSheet(
      context,
      currencySymbol: ref.read(currencySymbolProvider),
    );
    if (result == null || !mounted) return;

    final newCategory = CustomCategoryModel.create(
      name: result.name,
      iconKey: result.iconKey,
      colorHex: result.colorHex,
    );

    final controller = ref.read(appPreferencesControllerProvider);
    if (type == TransactionType.expense) {
      await controller.addExpenseCategory(newCategory);
    } else {
      await controller.addIncomeCategory(newCategory);
    }

    if (result.monthlyLimit != null && result.monthlyLimit! > 0) {
      await ref.read(budgetControllerProvider).saveBudget(
            category: result.name,
            monthlyLimit: result.monthlyLimit!,
          );
    }

    if (!mounted) return;
    _showFeedback('${result.name} created.');
  }

  Future<void> _openCustomCategoryEditor(
    CustomCategoryModel existing,
    TransactionType type,
    double currentBudget,
  ) async {
    final result = await showCategoryEditorSheet(
      context,
      editName: existing.name,
      editIconKey: existing.iconKey,
      editColorHex: existing.colorHex,
      editMonthlyLimit: currentBudget > 0 ? currentBudget : null,
      currencySymbol: ref.read(currencySymbolProvider),
    );
    if (result == null || !mounted) return;

    final controller = ref.read(appPreferencesControllerProvider);

    if (result.isDelete) {
      if (type == TransactionType.expense) {
        await controller.removeExpenseCategory(existing.id);
      } else {
        await controller.removeIncomeCategory(existing.id);
      }
      if (!mounted) return;
      _showFeedback('${existing.name} deleted.');
      return;
    }

    final updated = existing.copyWith(
      name: result.name,
      iconKey: result.iconKey,
      colorHex: result.colorHex,
    );

    if (type == TransactionType.expense) {
      await controller.updateExpenseCategory(updated);
    } else {
      await controller.updateIncomeCategory(updated);
    }

    if (result.monthlyLimit != null) {
      await ref.read(budgetControllerProvider).saveBudget(
            category: result.name,
            monthlyLimit: result.monthlyLimit!,
          );
    }

    if (!mounted) return;
    _showFeedback('${result.name} updated.');
  }

  Future<void> _openBuiltInCategoryEditor(
    ExpenseCategory category,
    double currentBudget,
    TransactionType type,
  ) async {
    final result = await showCategoryEditorSheet(
      context,
      editName: category.name,
      editIconKey: category.iconKey,
      editColorHex: category.colorHex,
      editMonthlyLimit: currentBudget > 0 ? currentBudget : null,
      isBuiltIn: true,
      currencySymbol: ref.read(currencySymbolProvider),
    );
    if (result == null || !mounted) return;

    final override = BuiltInCategoryOverride(
      name: category.name,
      iconKey: result.iconKey,
      colorHex: result.colorHex,
    );

    final controller = ref.read(appPreferencesControllerProvider);
    if (type == TransactionType.expense) {
      await controller.saveBuiltInExpenseCategoryOverride(override);
    } else {
      await controller.saveBuiltInIncomeCategoryOverride(override);
    }

    if (result.monthlyLimit != null) {
      await ref.read(budgetControllerProvider).saveBudget(
            category: category.name,
            monthlyLimit: result.monthlyLimit!,
          );
    }

    if (!mounted) return;
    _showFeedback('${category.name} updated.');
  }

  Future<void> _openAccountEditor({AccountModel? account}) async {
    final result = await showAccountEditorSheet(context, account: account);
    if (result == null) {
      return;
    }

    await ref.read(accountControllerProvider).saveAccount(
          id: result.id,
          name: result.name,
          iconKey: result.iconKey,
          balance: result.balance,
        );

    if (!mounted) {
      return;
    }

    if (ref.read(accountListProvider).hasError) {
      _showFeedback('Could not save ${result.name}.');
      return;
    }

    _showFeedback(account == null
        ? '${result.name} created.'
        : '${result.name} updated.');
  }

  void _showFeedback(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

// ── private widgets ───────────────────────────────────────────────────────────

class _MonthNavButton extends StatelessWidget {
  const _MonthNavButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.lightBlueBg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: AppColors.primaryBlue, size: 20),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.accentColor = AppColors.primaryBlue,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadii.md);
    return Material(
      color: accentColor.withValues(alpha: 0.1),
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 18, color: accentColor),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
