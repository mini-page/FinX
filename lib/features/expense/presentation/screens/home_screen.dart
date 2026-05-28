import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../routes/app_routes.dart';
import 'package:xpens/features/accounts/data/models/account_model.dart';
import '../../data/models/expense_model.dart';
import 'package:xpens/features/accounts/presentation/provider/account_providers.dart';
import '../provider/expense_providers.dart';
import '../provider/notifications_provider.dart';
import 'package:xpens/features/settings/presentation/provider/preferences_providers.dart';
import '../widgets/transaction_card.dart';
import '../widgets/ui_feedback.dart';
import 'home/home_date_strip.dart';
import 'home/home_header.dart';
import 'home/home_misc_widgets.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late DateTime _selectedDate;
  late DateTime _windowStart;

  @override
  void initState() {
    super.initState();
    final today = DateUtils.dateOnly(DateTime.now());
    _selectedDate = today;
    _windowStart = today.subtract(const Duration(days: 3));
  }

  @override
  Widget build(BuildContext context) {
    final expenseState = ref.watch(expenseListProvider);
    final expenses = expenseState.value ?? const <ExpenseModel>[];
    final accounts =
        ref.watch(accountListProvider).value ?? const <AccountModel>[];
    final accountsMap = {for (final a in accounts) a.id: a};
    final stats = ref.watch(statsProvider);
    final accountSummary = ref.watch(accountSummaryProvider);
    final privacyModeEnabled = ref.watch(privacyModeEnabledProvider);

    final currencyFormat = ref.watch(currencyFormatProvider);
    final today = DateUtils.dateOnly(DateTime.now());
    final isOnToday = DateUtils.isSameDay(_selectedDate, today);
    final visibleDates = List<DateTime>.generate(
      7,
      (index) => _windowStart.add(Duration(days: index)),
    );
    final selectedExpenses = expenses
        .where((expense) => _isSameLocalDay(expense.date, _selectedDate))
        .toList(growable: false)
      ..sort((left, right) => right.date.compareTo(left.date));
    final selectedTotal = selectedExpenses.fold<double>(
      0,
      (sum, expense) => sum + expense.signedAmount,
    );

    // Locale-aware quick amounts (H4) merged with user-defined custom amounts
    final locale = ref.watch(localeProvider);
    final localeAmounts = _localeQuickAmounts(locale);
    final customAmounts = ref.watch(customQuickAmountsProvider);
    final hiddenDefaults = ref.watch(hiddenDefaultAmountsProvider);
    // Merge: locale defaults (minus hidden and minus any already-custom) first,
    // then ALL custom amounts — sorted ascending so newly-added amounts slot
    // into the right position.  Custom amounts are always shown even if their
    // value coincidentally matches a locale default.
    final quickAmounts = [
      ...localeAmounts.where(
        (a) => !hiddenDefaults.contains(a) && !customAmounts.contains(a),
      ),
      ...customAmounts,
    ]..sort();

    final unreadCount = ref.watch(unreadNotificationCountProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // ── Sticky top bar (menu · logo · search · bell) ─────────────────
        HomeTopBar(
          onSearchPressed: () => AppRoutes.pushTransactionSearch(context),
          onNotificationPressed: () => AppRoutes.pushNotifications(context),
          unreadCount: unreadCount,
        ),

        // ── Everything below scrolls ──────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Blue hero card (balance, metrics)
                HomeHeader(
                  stats: stats,
                  accountSummary: accountSummary,
                  currencyFormat: currencyFormat,
                  privacyModeEnabled: privacyModeEnabled,
                  onTogglePrivacy: () {
                    ref
                        .read(appPreferencesControllerProvider)
                        .setPrivacyMode(!privacyModeEnabled);
                  },
                  quickAmounts: quickAmounts,
                  onAmountTap: (amount) => _openAddExpenseScreen(
                    context,
                    initialAmount: amount,
                    initialDate: _selectedDate,
                  ),
                  onAmountLongPress: (amount) => _showChipOptions(
                    context,
                    amount: amount,
                    isLocaleDefault: localeAmounts.contains(amount) &&
                        !customAmounts.contains(amount),
                    customAmounts: customAmounts,
                    hiddenDefaults: hiddenDefaults,
                    quickAmounts: quickAmounts,
                  ),
                  onAddAmountTap: () => _showAddCustomAmountDialog(
                    context,
                    customAmounts: customAmounts,
                    quickAmounts: quickAmounts,
                  ),
                ),

                // ── Scrollable content ────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      HomeDateStrip(
                        visibleDates: visibleDates,
                        selectedDate: _selectedDate,
                        isOnToday: isOnToday,
                        selectedTotalText: formatSignedCurrencyForHome(
                          selectedTotal,
                          currencyFormat,
                          masked: privacyModeEnabled,
                        ),
                        transactionCount: selectedExpenses.length,
                        onDateSelected: (date) {
                          setState(() {
                            _selectedDate = date;
                          });
                        },
                        onPrevious: () => _shiftWindow(-7),
                        onNext: () => _shiftWindow(7),
                        onJumpToToday: _jumpToToday,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: <Widget>[
                          const Text(
                            'RECENT TRANSACTIONS',
                            style: TextStyle(
                              color: AppColors.primaryBlue,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => _openRecordsHistoryScreen(context),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              textStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            child: const Text('View All'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (expenseState.hasError)
                        const HomeEmptyCard(
                          title: 'Storage unavailable',
                          message:
                              'The expense list could not be loaded right now.',
                        )
                      else if (expenseState.isLoading && expenses.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (expenses.isEmpty)
                        const HomeEmptyCard(
                          title: 'No expenses yet',
                          message:
                              'Tap the blue add button or choose a quick amount to record your first transaction.',
                        )
                      else if (selectedExpenses.isEmpty)
                        HomeEmptyCard(
                          title: _emptyTitleFor(_selectedDate),
                          message: _emptyMessageFor(_selectedDate),
                        )
                      else
                        ...selectedExpenses.map((expense) {
                          return TransactionCard(
                            expense: expense,
                            accountLabel:
                                _accountLabelFor(expense, accountsMap),
                            maskAmounts: privacyModeEnabled,
                            onEdit: () =>
                                _openEditExpenseScreen(context, expense),
                            onDelete: () => _confirmDeleteExpense(expense),
                          );
                        }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openAddExpenseScreen(
    BuildContext context, {
    double? initialAmount,
    String? initialCategory,
    DateTime? initialDate,
  }) {
    return AppRoutes.pushAddExpense(
      context,
      initialAmount: initialAmount,
      initialCategory: initialCategory,
      initialDate: initialDate,
    );
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

  Future<void> _openRecordsHistoryScreen(BuildContext context) {
    return AppRoutes.pushRecordsHistory(context);
  }

  void _shiftWindow(int days) {
    setState(() {
      _windowStart = _windowStart.add(Duration(days: days));
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
  }

  void _jumpToToday() {
    final today = DateUtils.dateOnly(DateTime.now());
    setState(() {
      _selectedDate = today;
      _windowStart = today.subtract(const Duration(days: 3));
    });
  }

  /// Returns locale-appropriate quick-add amounts (H4).
  List<double> _localeQuickAmounts(String locale) {
    if (locale.contains('IN') || locale.contains('hi')) {
      return [50, 100, 250, 500, 1000];
    }
    if (locale.contains('JP') || locale.contains('ja')) {
      return [100, 500, 1000, 5000, 10000];
    }
    if (locale.contains('AE') || locale.contains('ar')) {
      return [5, 10, 25, 50, 100];
    }
    // US / EU / default
    return [5, 10, 20, 50, 100];
  }

  bool _isSameLocalDay(DateTime expenseDate, DateTime targetDate) {
    final localDate = expenseDate.toLocal();
    return localDate.year == targetDate.year &&
        localDate.month == targetDate.month &&
        localDate.day == targetDate.day;
  }

  String _emptyTitleFor(DateTime date) {
    if (_isToday(date)) {
      return 'No transactions yet today';
    }
    if (date.isAfter(DateUtils.dateOnly(DateTime.now()))) {
      return 'No planned transactions';
    }
    return 'No transactions on this day';
  }

  String _emptyMessageFor(DateTime date) {
    if (_isToday(date)) {
      return 'Use the quick add flow to record today\'s first expense.';
    }
    if (date.isAfter(DateUtils.dateOnly(DateTime.now()))) {
      return 'Future days are available here so users can review scheduled spending once it exists.';
    }
    return 'Swipe across the date strip or jump back to today to review another day.';
  }

  bool _isToday(DateTime date) {
    final today = DateUtils.dateOnly(DateTime.now());
    return date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
  }

  String? _accountLabelFor(
    ExpenseModel expense,
    Map<String, AccountModel> accountsMap,
  ) {
    if (expense.accountId == null) {
      return null;
    }

    return accountsMap[expense.accountId]?.name ?? 'Archived Account';
  }

  Future<void> _confirmDeleteExpense(ExpenseModel expense) async {
    final label = expense.note.isEmpty ? expense.category : expense.note;
    final confirmed = await confirmDestructiveAction(
      context,
      title: 'Delete transaction?',
      message: 'Remove "$label" from your records? This cannot be undone.',
      confirmLabel: 'Delete txn',
    );
    if (!confirmed || !mounted) {
      return;
    }

    await ref.read(expenseControllerProvider).deleteExpense(expense.id);

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Transaction removed.')));
  }

  Future<void> _showAddCustomAmountDialog(
    BuildContext context, {
    required List<double> customAmounts,
    required List<double> quickAmounts,
  }) async {
    final controller = TextEditingController();

    final newAmount = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.viewInsetsOf(ctx).bottom + 16,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: controller,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: 'Amount, e.g. 75',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.grey.withValues(alpha: 0.35),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.grey.withValues(alpha: 0.35),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(ctx)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.7),
                    ),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () {
                final parsed = double.tryParse(controller.text.trim());
                if (parsed != null && parsed > 0) {
                  Navigator.of(ctx).pop(parsed);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (newAmount == null || !mounted) return;

    // Duplicate guard — value already visible as a chip.
    if (quickAmounts.contains(newAmount)) return;

    final updated = [...customAmounts, newAmount]..sort();
    await ref
        .read(appPreferencesControllerProvider)
        .setCustomQuickAmounts(updated);
  }

  Future<void> _showChipOptions(
    BuildContext context, {
    required double amount,
    required bool isLocaleDefault,
    required List<double> customAmounts,
    required List<double> hiddenDefaults,
    required List<double> quickAmounts,
  }) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit'),
                onTap: () => Navigator.of(ctx).pop('edit'),
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: Colors.red,
                ),
                title: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () => Navigator.of(ctx).pop('delete'),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted) return;

    if (action == 'delete') {
      if (isLocaleDefault) {
        final updated = [...hiddenDefaults, amount];
        await ref
            .read(appPreferencesControllerProvider)
            .setHiddenDefaultAmounts(updated);
      } else {
        final updated = customAmounts.where((a) => a != amount).toList();
        await ref
            .read(appPreferencesControllerProvider)
            .setCustomQuickAmounts(updated);
      }
    } else if (action == 'edit') {
      if (!context.mounted) return;
      await _showEditAmountDialog(
        context,
        currentAmount: amount,
        isLocaleDefault: isLocaleDefault,
        customAmounts: customAmounts,
        hiddenDefaults: hiddenDefaults,
        quickAmounts: quickAmounts,
      );
    }
  }

  Future<void> _showEditAmountDialog(
    BuildContext context, {
    required double currentAmount,
    required bool isLocaleDefault,
    required List<double> customAmounts,
    required List<double> hiddenDefaults,
    required List<double> quickAmounts,
  }) async {
    final displayText = currentAmount % 1 == 0
        ? currentAmount.toInt().toString()
        : currentAmount.toString();
    final controller = TextEditingController(text: displayText);

    final newAmount = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.viewInsetsOf(ctx).bottom + 16,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: controller,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: 'New amount',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.grey.withValues(alpha: 0.35),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.grey.withValues(alpha: 0.35),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(ctx)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.7),
                    ),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () {
                final parsed = double.tryParse(controller.text.trim());
                if (parsed != null && parsed > 0) {
                  Navigator.of(ctx).pop(parsed);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (newAmount == null || !mounted) return;

    // Duplicate guard — skip if the new value is already visible as another chip.
    if (newAmount != currentAmount && quickAmounts.contains(newAmount)) return;

    if (isLocaleDefault) {
      // Hide the old locale default and add the edited value as a custom amount.
      final updatedHidden = [...hiddenDefaults, currentAmount];
      final updatedCustom = [...customAmounts, newAmount]..sort();
      await ref
          .read(appPreferencesControllerProvider)
          .setHiddenDefaultAmounts(updatedHidden);
      if (!mounted) return;
      await ref
          .read(appPreferencesControllerProvider)
          .setCustomQuickAmounts(updatedCustom);
    } else {
      final updated = [
        ...customAmounts.where((a) => a != currentAmount),
        newAmount,
      ]..sort();
      await ref
          .read(appPreferencesControllerProvider)
          .setCustomQuickAmounts(updated);
    }
  }
}
