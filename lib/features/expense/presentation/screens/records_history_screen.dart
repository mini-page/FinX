import 'package:flutter/services.dart';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'calendar_view_screen.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/context_extensions.dart';
import '../../../../core/utils/tag_parser.dart';
import '../../../../routes/app_routes.dart';
import '../../../../shared/widgets/app_filter_sheet.dart';
import '../../../../shared/widgets/universal_top_bar.dart';
import 'package:expensio/features/accounts/accounts.dart';
import '../../data/models/expense_model.dart';
import '../provider/expense_providers.dart';
import 'package:expensio/features/settings/presentation/provider/preferences_providers.dart';
import 'package:expensio/features/categories/presentation/widgets/expense_category.dart';
import '../widgets/ui_feedback.dart';
import 'records_history/records_cards.dart';
import 'records_history/records_expense_list.dart';
import 'records_history/records_filter.dart';
import 'records_history/records_filter_bar.dart';
import 'records_history/records_search_logic.dart';

export 'records_history/records_filter.dart';
export 'records_history/records_search_logic.dart';


enum HistoryQuickFilter {
  all,
  uncategorized,
  noAccount,
  expense,
  income,
  transfer,
  cash,
  highAmount,
  today,
  thisWeek,
  thisMonth,
  custom,
}

enum _SortOrder { newest, oldest, amountDesc, amountAsc }

class RecordsHistoryScreen extends ConsumerStatefulWidget {
  const RecordsHistoryScreen({
    super.key,
    this.initialTagFilter,
    this.autoFocusSearch = false,
    this.initialViewMode = 'List',
  });

  final String? initialTagFilter;
  final bool autoFocusSearch;
  final String initialViewMode;

  @override
  ConsumerState<RecordsHistoryScreen> createState() =>
      _RecordsHistoryScreenState();
}

class _RecordsHistoryScreenState extends ConsumerState<RecordsHistoryScreen> {
  static const String _allAccountsKey = '__all_accounts__';

  RecordsFilter _selectedFilter = RecordsFilter.all;
  HistoryQuickFilter _quickFilter = HistoryQuickFilter.all;
  String _selectedViewMode = 'List'; // 'List', 'Calendar', 'Timeline'
  String _selectedAccountFilter = _allAccountsKey;
  Set<String> _selectedCategoryFilters = {};
  String _tagFilter = '';
  _SortOrder _sortOrder = _SortOrder.newest;
  DateTimeRange? _customDateRange;
  bool _isSearchOpen = false;

  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  String _searchQuery = '';
  bool _isSelectionMode = false;
  final Set<String> _selectedExpenseIds = {};

  void _onToggleSelectExpense(ExpenseModel expense) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedExpenseIds.contains(expense.id)) {
        _selectedExpenseIds.remove(expense.id);
        if (_selectedExpenseIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedExpenseIds.add(expense.id);
      }
    });
  }

  void _onExpenseLongPress(ExpenseModel expense) {
    HapticFeedback.heavyImpact();
    setState(() {
      _isSelectionMode = true;
      _selectedExpenseIds.add(expense.id);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedExpenseIds.clear();
    });
  }

  Future<void> _bulkDeleteSelected(BuildContext context) async {
    HapticFeedback.mediumImpact();
    final count = _selectedExpenseIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $count Transactions?'),
        content: const Text(
          'This will permanently delete the selected transactions and update your account balances.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final controller = ref.read(expenseControllerProvider);
      for (final id in _selectedExpenseIds) {
        await controller.deleteExpense(id);
      }
      _exitSelectionMode();
    }
  }

  void _bulkShareSelected(List<ExpenseModel> allExpenses, NumberFormat currency) {
    HapticFeedback.lightImpact();
    final selected = allExpenses.where((e) => _selectedExpenseIds.contains(e.id)).toList();
    if (selected.isEmpty) return;

    final buffer = StringBuffer();
    buffer.writeln('📋 Expensio Transaction Summary (${selected.length} items):\n');
    double total = 0;
    for (final exp in selected) {
      final sign = exp.isIncome ? '+' : '-';
      buffer.writeln('• ${DateFormat('d MMM, h:mm a').format(exp.date)}: $sign${currency.format(exp.amount)} (${exp.category}) ${exp.note}');
      total += exp.signedAmount;
    }
    buffer.writeln('\nTotal Net: ${currency.format(total)}');
    SharePlus.instance.share(ShareParams(text: buffer.toString()));
  }


  @override
  void initState() {
    super.initState();
    _selectedViewMode = widget.initialViewMode;
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
    if (widget.initialTagFilter != null) {
      _tagFilter = widget.initialTagFilter!;
    }
    if (widget.autoFocusSearch) {
      _isSearchOpen = true;
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

  String _sortOrderLabel(_SortOrder order) {
    switch (order) {
      case _SortOrder.newest:
        return 'Newest';
      case _SortOrder.oldest:
        return 'Oldest';
      case _SortOrder.amountDesc:
        return 'Amount ↓';
      case _SortOrder.amountAsc:
        return 'Amount ↑';
    }
  }

  IconData _sortOrderIcon(_SortOrder order) {
    switch (order) {
      case _SortOrder.newest:
        return Icons.arrow_downward_rounded;
      case _SortOrder.oldest:
        return Icons.arrow_upward_rounded;
      case _SortOrder.amountDesc:
        return Icons.trending_down_rounded;
      case _SortOrder.amountAsc:
        return Icons.trending_up_rounded;
    }
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

    return Stack(
      children: [
        UniversalScreenScaffold(
      topBar: _isSelectionMode
          ? UniversalTopBar(
              title: '${_selectedExpenseIds.length} Selected',
              showBackButton: true,
              onBackPressed: _exitSelectionMode,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textDark),
                  onPressed: _exitSelectionMode,
                ),
              ],
            )
          : UniversalTopBar(
              title: _isSelectionMode ? '${_selectedExpenseIds.length} Selected' : 'History',
              isSearchOpen: _isSearchOpen,
              onSearchToggle: (open) {
                setState(() {
                  _isSearchOpen = open;
                  if (!open) {
                    _searchQuery = '';
                    _searchController.clear();
                  }
                });
              },
              alwaysShowSearch: true,
              searchController: _searchController,
              searchHint: widget.autoFocusSearch
                  ? 'Search history…'
                  : 'Search history…',
              onSearchChanged: (value) => setState(() => _searchQuery = value),
              onSearchClear: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              actions: [
                IconButton(
                  icon: const Icon(Icons.download_rounded, color: AppColors.textDark),
                  tooltip: 'Export CSV',
                  onPressed: () =>
                      _exportCsv(context, filteredExpenses, locale, currencySymbol),
                ),
              ],
              filterLabel: _selectedCategoryFilters.isNotEmpty
                  ? '${_selectedCategoryFilters.length} Cats'
                  : (_selectedAccountFilter != _allAccountsKey ? 'Account' : 'Filter'),
              isFilterActive: _selectedCategoryFilters.isNotEmpty ||
                  _selectedAccountFilter != _allAccountsKey,
              onFilterTap: () => _showCategorySheet(context, allCategories),
              sortLabel: _sortOrderLabel(_sortOrder),
              sortIcon: _sortOrderIcon(_sortOrder),
              onSortTap: () => _showSortSheet(context),
            ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // ── Mode Switcher & Inline Net Badge ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _HistoryModePillSwitch(
                  selectedView: _selectedViewMode,
                  onChanged: (view) {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedViewMode = view);
                  },
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${filteredExpenses.length} txns',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '•  ${filteredTotal >= 0 ? '+' : ''}${currency.format(filteredTotal)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_selectedViewMode == 'Calendar')
              const Expanded(
                child: CalendarViewScreen(showHeader: false, initialView: 'Calendar'),
              )
            else if (_selectedViewMode == 'Timeline')
              const Expanded(
                child: CalendarViewScreen(showHeader: false, initialView: 'Timeline'),
              )
            else ...[
              // ── Sleek Clean Quick Filters ──
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildQuickFilterPill('All', HistoryQuickFilter.all),
                    const SizedBox(width: 8),
                    _buildQuickFilterPill('Expense', HistoryQuickFilter.expense),
                    const SizedBox(width: 8),
                    _buildQuickFilterPill('Income', HistoryQuickFilter.income),
                    const SizedBox(width: 8),
                    _buildQuickFilterPill('Transfer', HistoryQuickFilter.transfer),
                    const SizedBox(width: 8),
                    _buildQuickFilterPill('This Month', HistoryQuickFilter.thisMonth),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _openAdvancedFilterSheet(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: (_quickFilter != HistoryQuickFilter.all &&
                                  _quickFilter != HistoryQuickFilter.expense &&
                                  _quickFilter != HistoryQuickFilter.income &&
                                  _quickFilter != HistoryQuickFilter.transfer &&
                                  _quickFilter != HistoryQuickFilter.thisMonth)
                              ? AppColors.primaryBlue.withValues(alpha: 0.12)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: (_quickFilter != HistoryQuickFilter.all &&
                                    _quickFilter != HistoryQuickFilter.expense &&
                                    _quickFilter != HistoryQuickFilter.income &&
                                    _quickFilter != HistoryQuickFilter.transfer &&
                                    _quickFilter != HistoryQuickFilter.thisMonth)
                                ? AppColors.primaryBlue
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.tune_rounded,
                              size: 14,
                              color: (_quickFilter != HistoryQuickFilter.all &&
                                      _quickFilter != HistoryQuickFilter.expense &&
                                      _quickFilter != HistoryQuickFilter.income &&
                                      _quickFilter != HistoryQuickFilter.transfer &&
                                      _quickFilter != HistoryQuickFilter.thisMonth)
                                  ? AppColors.primaryBlue
                                  : AppColors.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              (_quickFilter != HistoryQuickFilter.all &&
                                      _quickFilter != HistoryQuickFilter.expense &&
                                      _quickFilter != HistoryQuickFilter.income &&
                                      _quickFilter != HistoryQuickFilter.transfer &&
                                      _quickFilter != HistoryQuickFilter.thisMonth)
                                  ? _quickFilterLabel(_quickFilter)
                                  : 'More Filters',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: (_quickFilter != HistoryQuickFilter.all &&
                                        _quickFilter != HistoryQuickFilter.expense &&
                                        _quickFilter != HistoryQuickFilter.income &&
                                        _quickFilter != HistoryQuickFilter.transfer &&
                                        _quickFilter != HistoryQuickFilter.thisMonth)
                                    ? AppColors.primaryBlue
                                    : AppColors.textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_tagFilter.isNotEmpty) ...[
                const SizedBox(height: 8),
                InputChip(
                  label: Text('#$_tagFilter'),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () => setState(() => _tagFilter = ''),
                  selected: true,
                  backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.1),
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
              const SizedBox(height: 12),
              // ── Transaction list ───────────────────────────────────────────
              Expanded(
                child: expenseState.hasError
                    ? const RecordsStateCard(
                        title: 'Unable to load records',
                        message: 'The transaction history is not available right now.',
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
                                isSelectable: _isSelectionMode,
                                selectedExpenseIds: _selectedExpenseIds,
                                onToggleSelect: _onToggleSelectExpense,
                                onLongPress: _onExpenseLongPress,
                                onEdit: (expense) => _openEditExpenseScreen(context, expense),
                                onDelete: (expense) => _confirmDeleteExpense(context, ref, expense),
                              ),
              ),
            ],
          ],
        ),
      ),
    ),
    if (_isSelectionMode)
      Positioned(
        bottom: 24,
        left: 20,
        right: 20,
        child: SafeArea(
          child: Center(
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue,
                borderRadius: BorderRadius.circular(26),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x330052FF),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.share_outlined, color: Colors.white, size: 20),
                    label: const Text(
                      'Share',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    onPressed: () => _bulkShareSelected(expenses, currency),
                  ),
                  Container(
                    width: 1,
                    height: 24,
                    color: Colors.white24,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 20),
                    label: const Text(
                      'Delete',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    onPressed: () => _bulkDeleteSelected(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
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

      // Check quick filter
      switch (_quickFilter) {
        case HistoryQuickFilter.all:
          break;
        case HistoryQuickFilter.uncategorized:
          final cat = expense.category.trim().toLowerCase();
          if (cat.isNotEmpty && cat != 'uncategorized' && cat != 'uncategorised') {
            return false;
          }
          break;
        case HistoryQuickFilter.noAccount:
          if (expense.accountId != null && expense.accountId!.isNotEmpty) {
            return false;
          }
          break;
        case HistoryQuickFilter.expense:
          if (expense.type != TransactionType.expense) return false;
          break;
        case HistoryQuickFilter.income:
          if (expense.type != TransactionType.income) return false;
          break;
        case HistoryQuickFilter.transfer:
          if (expense.type != TransactionType.transfer) return false;
          break;
        case HistoryQuickFilter.cash:
          final accName = accountMap[expense.accountId]?.name.toLowerCase() ?? '';
          final note = expense.note.toLowerCase();
          if (!accName.contains('cash') && !note.contains('cash')) return false;
          break;
        case HistoryQuickFilter.highAmount:
          if (expense.amount < 1000) return false;
          break;
        case HistoryQuickFilter.today:
          if (!DateUtils.isSameDay(dateOnly, today)) return false;
          break;
        case HistoryQuickFilter.thisWeek:
          if (dateOnly.isBefore(weekStart) || dateOnly.isAfter(today.add(const Duration(days: 1)))) {
            return false;
          }
          break;
        case HistoryQuickFilter.thisMonth:
          if (dateOnly.year != today.year || dateOnly.month != today.month) {
            return false;
          }
          break;
        case HistoryQuickFilter.custom:
          if (_customDateRange != null) {
            if (dateOnly.isBefore(_customDateRange!.start) ||
                dateOnly.isAfter(_customDateRange!.end)) {
              return false;
            }
          }
          break;
      }

      // Check legacy filter
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
      initialSubcategory: expense.subcategory,
      initialLatitude: expense.latitude,
      initialLongitude: expense.longitude,
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

    await SharePlus.instance.share(
      ShareParams(
        text: buffer.toString(),
        subject: 'Expensio Transactions Export',
      ),
    );
  }

  String _quickFilterLabel(HistoryQuickFilter filter) {
    switch (filter) {
      case HistoryQuickFilter.all:
        return 'All';
      case HistoryQuickFilter.today:
        return 'Today';
      case HistoryQuickFilter.thisWeek:
        return 'This Week';
      case HistoryQuickFilter.thisMonth:
        return 'This Month';
      case HistoryQuickFilter.uncategorized:
        return 'Uncategorised';
      case HistoryQuickFilter.noAccount:
        return 'No Account';
      case HistoryQuickFilter.expense:
        return 'Expense';
      case HistoryQuickFilter.income:
        return 'Income';
      case HistoryQuickFilter.transfer:
        return 'Transfer';
      case HistoryQuickFilter.cash:
        return 'Cash Only';
      case HistoryQuickFilter.highAmount:
        return 'High (>₹1k)';
      case HistoryQuickFilter.custom:
        if (_customDateRange != null) {
          final fmt = DateFormat('d MMM');
          return '${fmt.format(_customDateRange!.start)}–${fmt.format(_customDateRange!.end)}';
        }
        return 'Custom';
    }
  }

  Future<void> _openAdvancedFilterSheet(BuildContext context) async {
    final chosen = await showSingleSelectSheet<HistoryQuickFilter>(
      context: context,
      title: 'Filter History',
      selectedValue: _quickFilter,
      items: const [
        FilterSheetItem(value: HistoryQuickFilter.all, label: 'All Transactions', icon: Icons.all_inclusive_rounded),
        FilterSheetItem(value: HistoryQuickFilter.today, label: 'Today', icon: Icons.today_rounded),
        FilterSheetItem(value: HistoryQuickFilter.thisWeek, label: 'This Week', icon: Icons.date_range_rounded),
        FilterSheetItem(value: HistoryQuickFilter.thisMonth, label: 'This Month', icon: Icons.calendar_month_rounded),
        FilterSheetItem(value: HistoryQuickFilter.expense, label: 'Expenses Only', icon: Icons.arrow_outward_rounded, iconColor: AppColors.danger),
        FilterSheetItem(value: HistoryQuickFilter.income, label: 'Income Only', icon: Icons.arrow_downward_rounded, iconColor: AppColors.success),
        FilterSheetItem(value: HistoryQuickFilter.transfer, label: 'Transfers Only', icon: Icons.swap_horiz_rounded, iconColor: AppColors.primaryBlue),
        FilterSheetItem(value: HistoryQuickFilter.cash, label: 'Cash Only', icon: Icons.payments_outlined),
        FilterSheetItem(value: HistoryQuickFilter.highAmount, label: 'High Amount (> ₹1,000)', icon: Icons.trending_up_rounded),
        FilterSheetItem(value: HistoryQuickFilter.uncategorized, label: 'Uncategorised', icon: Icons.help_outline_rounded),
        FilterSheetItem(value: HistoryQuickFilter.noAccount, label: 'No Account', icon: Icons.account_balance_wallet_outlined),
        FilterSheetItem(value: HistoryQuickFilter.custom, label: 'Custom Date Range…', icon: Icons.edit_calendar_rounded),
      ],
    );

    if (chosen != null && mounted) {
      if (chosen == HistoryQuickFilter.custom) {
        if (!context.mounted) return;
        await _pickCustomDateRange(context);
      } else {
        setState(() {
          _quickFilter = chosen;
          _customDateRange = null;
        });
      }
    }
  }

  Widget _buildQuickFilterPill(
    String label,
    HistoryQuickFilter filter, {
    VoidCallback? onTapOverride,
  }) {
    final isSelected = _quickFilter == filter;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        if (onTapOverride != null) {
          onTapOverride();
        }
        setState(() {
          _quickFilter = filter;
          if (filter != HistoryQuickFilter.custom) {
            _customDateRange = null;
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryBlue : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primaryBlue : const Color(0xFFE2E8F0),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primaryBlue.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textDark,
          ),
        ),
      ),
    );
  }

  String _csvEscape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
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

class _HistoryModePillSwitch extends StatelessWidget {
  const _HistoryModePillSwitch({
    required this.selectedView,
    required this.onChanged,
  });

  final String selectedView;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildOption('List', Icons.view_list_rounded),
          _buildOption('Calendar', Icons.calendar_month_rounded),
          _buildOption('Timeline', Icons.timeline_rounded),
        ],
      ),
    );
  }

  Widget _buildOption(String view, IconData icon) {
    final isSelected = selectedView == view;
    return GestureDetector(
      onTap: () => onChanged(view),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x10000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? AppColors.primaryBlue : AppColors.textMuted,
            ),
            const SizedBox(width: 5),
            Text(
              view,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? AppColors.primaryBlue : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
