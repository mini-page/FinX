import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/context_extensions.dart';
import '../../../../core/utils/tag_parser.dart';
import '../../../../routes/app_routes.dart';
import '../../../../shared/widgets/app_filter_sheet.dart';
import 'package:xpens/features/accounts/accounts.dart';
import '../../data/models/expense_model.dart';
import '../provider/expense_providers.dart';
import 'package:xpens/features/settings/presentation/provider/preferences_providers.dart';
import 'package:xpens/features/categories/presentation/widgets/expense_category.dart';
import '../widgets/ui_feedback.dart';
import 'records_history/records_cards.dart';
import 'records_history/records_expense_list.dart';
import 'records_history/records_filter.dart';
import 'records_history/records_filter_bar.dart';
import 'records_history/records_search_logic.dart';

export 'records_history/records_filter.dart';
export 'records_history/records_search_logic.dart';

enum _SortOrder { newest, oldest, amountDesc, amountAsc }

class RecordsHistoryScreen extends ConsumerStatefulWidget {
  const RecordsHistoryScreen({
    super.key,
    this.initialTagFilter,
    this.autoFocusSearch = false,
  });

  final String? initialTagFilter;

  /// When `true`, the search bar is automatically focused on mount and the
  /// soft keyboard is raised — replicating the old TransactionSearchScreen
  /// entry point.  When `false` (default), the screen opens as the normal
  /// records browser.
  final bool autoFocusSearch;

  @override
  ConsumerState<RecordsHistoryScreen> createState() =>
      _RecordsHistoryScreenState();
}

class _RecordsHistoryScreenState extends ConsumerState<RecordsHistoryScreen> {
  static const String _allAccountsKey = '__all_accounts__';

  RecordsFilter _selectedFilter = RecordsFilter.all;
  String _selectedAccountFilter = _allAccountsKey;
  Set<String> _selectedCategoryFilters = {};
  String _tagFilter = '';
  _SortOrder _sortOrder = _SortOrder.newest;
  DateTimeRange? _customDateRange;

  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
    if (widget.initialTagFilter != null) {
      _tagFilter = widget.initialTagFilter!;
    }
    if (widget.autoFocusSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expenseState = ref.watch(expenseListProvider);
    final accountState = ref.watch(accountListProvider);
    final privacyModeEnabled = ref.watch(privacyModeEnabledProvider);
    final expenses = expenseState.value ?? const <ExpenseModel>[];
    final accounts = accountState.value ?? const <AccountModel>[];
    final accountMap = {for (final a in accounts) a.id: a};
    final currency = ref.watch(currencyFormatProvider);
    final locale = ref.watch(localeProvider);
    final currencySymbol = ref.watch(currencySymbolProvider);

    // Collect unique categories for filter
    final allCategories =
        expenses.map((e) => e.category).toSet().toList(growable: false)..sort();

    final filteredExpenses = _filterExpenses(expenses, accountMap);
    final groupedExpenses = _groupExpenses(filteredExpenses);
    final filteredTotal = filteredExpenses.fold<double>(
      0,
      (sum, expense) => sum + expense.signedAmount,
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.autoFocusSearch ? 'Search' : 'Records',
          style: const TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          // Sort button
          IconButton(
            icon: Icon(
              Icons.sort_rounded,
              color: _sortOrder != _SortOrder.newest
                  ? AppColors.primaryBlue
                  : AppColors.textDark,
            ),
            tooltip: 'Sort',
            onPressed: () => _showSortSheet(context),
          ),
          // CSV export
          IconButton(
            icon: const Icon(Icons.download_rounded, color: AppColors.textDark),
            tooltip: 'Export CSV',
            onPressed: () =>
                _exportCsv(context, filteredExpenses, locale, currencySymbol),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // ── Search bar ──────────────────────────────────────────────────
              _RecordsSearchBar(
                controller: _searchController,
                focusNode: _searchFocusNode,
                hasText: _searchQuery.isNotEmpty,
                hint: widget.autoFocusSearch
                    ? 'e.g. coffee OR food, NOT rent…'
                    : 'Search records…',
                onChanged: (value) => setState(() => _searchQuery = value),
                onClear: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              ),
              const SizedBox(height: 14),
              // ── Summary card ─────────────────────────────────────────────────
              RecordsSummaryCard(
                filteredTotal: filteredTotal,
                transactionCount: filteredExpenses.length,
                currency: currency,
                privacyModeEnabled: privacyModeEnabled,
              ),
              const SizedBox(height: 14),
              // ── Date / type filter chips ──────────────────────────────────────
              RecordsFilterChips(
                selectedFilter: _selectedFilter,
                onFilterSelected: (filter) {
                  setState(() {
                    _selectedFilter = filter;
                    if (filter != RecordsFilter.custom) {
                      _customDateRange = null;
                    }
                  });
                },
                labelForFilter: _labelForFilter,
                onCustomDateRange: () => _pickCustomDateRange(context),
                customDateRange: _customDateRange,
              ),
              const SizedBox(height: 10),
              // ── Account + Category + Tag row ─────────────────────────────────
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterPill(
                      icon: Icons.account_balance_wallet_outlined,
                      label: _accountFilterLabel(accountMap),
                      isActive: _selectedAccountFilter != _allAccountsKey,
                      onTap: () => _showAccountSheet(context, accounts),
                    ),
                    const SizedBox(width: 10),
                    _FilterPill(
                      icon: Icons.category_outlined,
                      label: _selectedCategoryFilters.isEmpty
                          ? 'Category'
                          : _selectedCategoryFilters.length == 1
                              ? _selectedCategoryFilters.first
                              : '${_selectedCategoryFilters.length} categories',
                      isActive: _selectedCategoryFilters.isNotEmpty,
                      onTap: () => _showCategorySheet(context, allCategories),
                    ),
                    if (_tagFilter.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      InputChip(
                        label: Text('#$_tagFilter'),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () => setState(() => _tagFilter = ''),
                        selected: true,
                        backgroundColor:
                            AppColors.primaryBlue.withValues(alpha: 0.1),
                        labelStyle: const TextStyle(
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                        ),
                        side: BorderSide(
                          color: AppColors.primaryBlue.withValues(alpha: 0.24),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // ── Transaction list ─────────────────────────────────────────────
              Expanded(
                child: expenseState.hasError
                    ? const RecordsStateCard(
                        title: 'Unable to load records',
                        message:
                            'The transaction history is not available right now.',
                      )
                    : expenseState.isLoading && expenses.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : filteredExpenses.isEmpty
                            ? _buildEmptyState()
                            : RecordsExpenseList(
                                groupedExpenses: groupedExpenses,
                                accounts: accounts,
                                privacyModeEnabled: privacyModeEnabled,
                                groupLabel: _groupLabel,
                                accountLabelFor: _accountLabelFor,
                                onEdit: (expense) =>
                                    _openEditExpenseScreen(context, expense),
                                onDelete: (expense) => _confirmDeleteExpense(
                                    context, ref, expense),
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    if (_searchQuery.isNotEmpty) {
      return RecordsStateCard(
        title: 'No results for "$_searchQuery"',
        message: 'Try adjusting your search or filters.',
      );
    }
    return const RecordsStateCard(
      title: 'No matching transactions',
      message: 'Try another filter or add a new expense.',
    );
  }

  List<ExpenseModel> _filterExpenses(
    List<ExpenseModel> expenses,
    Map<String, AccountModel> accountMap,
  ) {
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);
    final weekStart = today.subtract(Duration(days: now.weekday - 1));
    final parsedQuery = SearchQuery.parse(_searchQuery);

    final filtered = expenses.where((expense) {
      final localDate = expense.date.toLocal();
      final dateOnly = DateUtils.dateOnly(localDate);

      if (_selectedAccountFilter != _allAccountsKey &&
          expense.accountId != _selectedAccountFilter) {
        return false;
      }

      if (_selectedCategoryFilters.isNotEmpty &&
          !_selectedCategoryFilters.contains(expense.category)) {
        return false;
      }

      if (_tagFilter.isNotEmpty) {
        final tags = TagParser.extractTags(expense.note);
        if (!tags.contains(_tagFilter.toLowerCase())) return false;
      }

      switch (_selectedFilter) {
        case RecordsFilter.today:
          if (!DateUtils.isSameDay(dateOnly, today)) return false;
        case RecordsFilter.week:
          if (dateOnly.isBefore(weekStart) || dateOnly.isAfter(today)) {
            return false;
          }
        case RecordsFilter.month:
          if (dateOnly.year != today.year || dateOnly.month != today.month) {
            return false;
          }
        case RecordsFilter.future:
          if (!dateOnly.isAfter(today)) return false;
        case RecordsFilter.custom:
          if (_customDateRange != null) {
            if (dateOnly.isBefore(_customDateRange!.start) ||
                dateOnly.isAfter(_customDateRange!.end)) {
              return false;
            }
          }
        case RecordsFilter.all:
          break;
      }

      if (!parsedQuery.isEmpty &&
          !parsedQuery.matchesExpense(expense, accountMap)) {
        return false;
      }

      return true;
    }).toList(growable: false);

    final result = List<ExpenseModel>.from(filtered);
    switch (_sortOrder) {
      case _SortOrder.newest:
        result.sort((a, b) => b.date.compareTo(a.date));
      case _SortOrder.oldest:
        result.sort((a, b) => a.date.compareTo(b.date));
      case _SortOrder.amountDesc:
        result.sort((a, b) => b.amount.compareTo(a.amount));
      case _SortOrder.amountAsc:
        result.sort((a, b) => a.amount.compareTo(b.amount));
    }
    return result;
  }

  SplayTreeMap<DateTime, List<ExpenseModel>> _groupExpenses(
    List<ExpenseModel> expenses,
  ) {
    final grouped = SplayTreeMap<DateTime, List<ExpenseModel>>(
      (left, right) => right.compareTo(left),
    );

    for (final expense in expenses) {
      final key = DateUtils.dateOnly(expense.date.toLocal());
      grouped.putIfAbsent(key, () => <ExpenseModel>[]).add(expense);
    }

    return grouped;
  }

  String _labelForFilter(RecordsFilter filter) {
    switch (filter) {
      case RecordsFilter.today:
        return 'Today';
      case RecordsFilter.week:
        return 'This Week';
      case RecordsFilter.month:
        return 'This Month';
      case RecordsFilter.future:
        return 'Future';
      case RecordsFilter.custom:
        if (_customDateRange != null) {
          final fmt = DateFormat('d MMM');
          return '${fmt.format(_customDateRange!.start)}–${fmt.format(_customDateRange!.end)}';
        }
        return 'Custom';
      case RecordsFilter.all:
        return 'All';
    }
  }

  String _accountFilterLabel(Map<String, AccountModel> accountMap) {
    if (_selectedAccountFilter == _allAccountsKey) {
      return 'All accounts';
    }
    return accountMap[_selectedAccountFilter]?.name ?? 'Archived account';
  }

  String _groupLabel(DateTime date) {
    final today = DateUtils.dateOnly(DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));
    if (DateUtils.isSameDay(date, today)) {
      return 'Today';
    }
    if (DateUtils.isSameDay(date, yesterday)) {
      return 'Yesterday';
    }
    return DateFormat('EEE, d MMM yyyy').format(date);
  }

  String? _accountLabelFor(ExpenseModel expense, List<AccountModel> accounts) {
    if (expense.accountId == null) {
      return null;
    }
    for (final a in accounts) {
      if (a.id == expense.accountId) {
        return a.name;
      }
    }
    return 'Archived Account';
  }

  Future<void> _openEditExpenseScreen(
    BuildContext context,
    ExpenseModel expense,
  ) {
    return AppRoutes.pushEditExpense(
      context,
      expenseId: expense.id,
      initialAmount: expense.amount,
      initialCategory: expense.category,
      initialDate: expense.date.toLocal(),
      initialNote: expense.note,
      initialAccountId: expense.accountId,
      initialToAccountId: expense.toAccountId,
      initialType: expense.type,
    );
  }

  Future<void> _showSortSheet(BuildContext context) async {
    final chosen = await showSingleSelectSheet<_SortOrder>(
      context: context,
      title: 'Sort by',
      selectedValue: _sortOrder,
      items: const <FilterSheetItem<_SortOrder>>[
        FilterSheetItem(
          value: _SortOrder.newest,
          label: 'Newest first',
          icon: Icons.arrow_downward_rounded,
          iconColor: AppColors.primaryBlue,
        ),
        FilterSheetItem(
          value: _SortOrder.oldest,
          label: 'Oldest first',
          icon: Icons.arrow_upward_rounded,
          iconColor: AppColors.primaryBlue,
        ),
        FilterSheetItem(
          value: _SortOrder.amountDesc,
          label: 'Amount (high → low)',
          icon: Icons.trending_down_rounded,
          iconColor: AppColors.danger,
        ),
        FilterSheetItem(
          value: _SortOrder.amountAsc,
          label: 'Amount (low → high)',
          icon: Icons.trending_up_rounded,
          iconColor: AppColors.success,
        ),
      ],
    );
    if (chosen != null && mounted) {
      setState(() => _sortOrder = chosen);
    }
  }

  Future<void> _showAccountSheet(
    BuildContext context,
    List<AccountModel> accounts,
  ) async {
    final chosen = await showSingleSelectSheet<String>(
      context: context,
      title: 'Filter by account',
      selectedValue: _selectedAccountFilter,
      items: <FilterSheetItem<String>>[
        const FilterSheetItem(
          value: _allAccountsKey,
          label: 'All accounts',
          icon: Icons.account_balance_wallet_outlined,
          iconColor: AppColors.primaryBlue,
        ),
        ...accounts.map(
          (a) => FilterSheetItem<String>(
            value: a.id,
            label: a.name,
            icon: resolveAccountIcon(a.iconKey),
            iconColor: AppColors.primaryBlue,
          ),
        ),
      ],
    );
    if (chosen != null && mounted) {
      setState(() => _selectedAccountFilter = chosen);
    }
  }

  Future<void> _showCategorySheet(
    BuildContext context,
    List<String> allCategories,
  ) async {
    final allExpCats = ref.read(allExpenseCategoriesProvider);
    final allIncCats = ref.read(allIncomeCategoriesProvider);
    final allKnown = [...allExpCats, ...allIncCats];

    final items = allCategories.map((name) {
      ExpenseCategory? cat;
      for (final c in allKnown) {
        if (c.name == name) {
          cat = c;
          break;
        }
      }
      return FilterSheetItem<String>(
        value: name,
        label: name,
        icon: cat?.icon ?? Icons.category_outlined,
        iconColor: cat?.color,
      );
    }).toList(growable: false);

    final chosen = await showMultiSelectSheet<String>(
      context: context,
      title: 'Filter by category',
      items: items,
      selectedValues: _selectedCategoryFilters,
      searchable: allCategories.length > 5,
    );
    if (chosen != null && mounted) {
      setState(() => _selectedCategoryFilters = chosen);
    }
  }

  Future<void> _confirmDeleteExpense(
    BuildContext context,
    WidgetRef ref,
    ExpenseModel expense,
  ) async {
    final label = expense.note.isEmpty ? expense.category : expense.note;
    final confirmed = await confirmDestructiveAction(
      context,
      title: 'Delete transaction?',
      message: 'Remove "$label" from your records? This cannot be undone.',
      confirmLabel: 'Delete txn',
    );
    if (!confirmed || !context.mounted) {
      return;
    }

    await ref.read(expenseControllerProvider).deleteExpense(expense.id);

    if (!context.mounted) {
      return;
    }

    context.showSnackBar(
      'Transaction removed.',
      type: AppFeedbackType.success,
    );
  }

  Future<void> _pickCustomDateRange(BuildContext context) async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _customDateRange,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primaryBlue),
        ),
        child: child!,
      ),
    );
    if (range != null) {
      setState(() {
        _customDateRange = range;
        _selectedFilter = RecordsFilter.custom;
      });
    }
  }

  Future<void> _exportCsv(
    BuildContext context,
    List<ExpenseModel> expenses,
    String locale,
    String currencySymbol,
  ) async {
    if (expenses.isEmpty) {
      context.showSnackBar(
        'No transactions to export.',
        type: AppFeedbackType.warning,
      );
      return;
    }

    final dateFmt = DateFormat('yyyy-MM-dd HH:mm', locale);
    final buffer = StringBuffer();
    buffer.writeln('Date,Type,Category,Note,Amount,Tags');

    for (final e in expenses) {
      final date = dateFmt.format(e.date.toLocal());
      final type = e.type.name;
      final category = _csvEscape(e.category);
      final note = _csvEscape(TagParser.stripTags(e.note));
      final amount = e.isIncome
          ? e.amount.toStringAsFixed(2)
          : (-e.amount).toStringAsFixed(2);
      final tags = TagParser.extractTags(e.note).map((t) => '#$t').join(' ');
      buffer.writeln('$date,$type,$category,$note,$amount,$tags');
    }

    await Share.share(
      buffer.toString(),
      subject: 'XPens Transactions Export',
    );
  }

  String _csvEscape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}

/// Styled search bar used in both browse and search modes.
class _RecordsSearchBar extends StatelessWidget {
  const _RecordsSearchBar({
    required this.controller,
    required this.focusNode,
    required this.hasText,
    required this.hint,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasText;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        style: const TextStyle(
          fontSize: 15,
          color: AppColors.textDark,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.primaryBlue,
          ),
          suffixIcon: hasText
              ? IconButton(
                  icon: const Icon(
                    Icons.clear_rounded,
                    color: AppColors.textMuted,
                  ),
                  onPressed: onClear,
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

/// Pill button used in the account/category filter row.
class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color:
              isActive ? AppColors.primaryBlue.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
          border: isActive
              ? Border.all(color: AppColors.primaryBlue, width: 1.5)
              : Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              size: 18,
              color: isActive ? AppColors.primaryBlue : AppColors.textMuted,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isActive ? AppColors.primaryBlue : AppColors.textDark,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: isActive ? AppColors.primaryBlue : AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
