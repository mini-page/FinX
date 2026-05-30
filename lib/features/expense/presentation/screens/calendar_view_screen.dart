import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../routes/app_routes.dart';
import '../../../../shared/widgets/app_page_header.dart';
import '../../data/models/expense_model.dart';
import '../provider/expense_providers.dart';
import 'package:xpens/features/settings/presentation/provider/preferences_providers.dart';

class CalendarViewScreen extends ConsumerStatefulWidget {
  const CalendarViewScreen({super.key, this.initialDate});

  final DateTime? initialDate;

  @override
  ConsumerState<CalendarViewScreen> createState() => _CalendarViewScreenState();
}

class _CalendarViewScreenState extends ConsumerState<CalendarViewScreen> {
  DateTime _currentMonth = DateTime.now();
  DateTime _selectedDate = DateTime.now();
  String _selectedView = 'Calendar'; // 'Calendar' or 'Timeline'
  String _calendarViewType = 'Week'; // 'Week', '2 weeks', 'Month'
  final Set<DateTime> _expandedTimelineDates = {};
  int _timelineMonthsCount = 1; // default to showing only current month, click load more to increment

  @override
  void initState() {
    super.initState();
    final initial = widget.initialDate ?? DateTime.now();
    _selectedDate = DateUtils.dateOnly(initial);
    _currentMonth = DateTime(initial.year, initial.month, 1);
  }

  DateTime _getStartOfWeek(DateTime date) {
    return date.subtract(Duration(days: date.weekday % 7));
  }

  void _previousPeriod() {
    HapticFeedback.lightImpact();
    setState(() {
      if (_calendarViewType == 'Week') {
        _selectedDate = _selectedDate.subtract(const Duration(days: 7));
      } else if (_calendarViewType == '2 weeks') {
        _selectedDate = _selectedDate.subtract(const Duration(days: 14));
      } else {
        // Month view
        int prevYear = _selectedDate.year;
        int prevMonth = _selectedDate.month - 1;
        if (prevMonth == 0) {
          prevMonth = 12;
          prevYear -= 1;
        }
        final daysInPrevMonth = DateUtils.getDaysInMonth(prevYear, prevMonth);
        final targetDay = _selectedDate.day.clamp(1, daysInPrevMonth);
        _selectedDate = DateTime(prevYear, prevMonth, targetDay);
      }
      _currentMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    });
  }

  void _nextPeriod() {
    HapticFeedback.lightImpact();
    setState(() {
      if (_calendarViewType == 'Week') {
        _selectedDate = _selectedDate.add(const Duration(days: 7));
      } else if (_calendarViewType == '2 weeks') {
        _selectedDate = _selectedDate.add(const Duration(days: 14));
      } else {
        // Month view
        int nextYear = _selectedDate.year;
        int nextMonth = _selectedDate.month + 1;
        if (nextMonth == 13) {
          nextMonth = 1;
          nextYear += 1;
        }
        final daysInNextMonth = DateUtils.getDaysInMonth(nextYear, nextMonth);
        final targetDay = _selectedDate.day.clamp(1, daysInNextMonth);
        _selectedDate = DateTime(nextYear, nextMonth, targetDay);
      }
      _currentMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    });
  }

  Future<void> _selectMonth(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day.clamp(1, 28)),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Select date',
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateUtils.dateOnly(picked);
        _currentMonth = DateTime(picked.year, picked.month, 1);
      });
    }
  }

  String _formatDayAmount(double amount) {
    final absVal = amount.abs();
    if (absVal >= 100000) {
      return '${(absVal / 100000).toStringAsFixed(0)}L';
    } else if (absVal >= 1000) {
      return '${(absVal / 1000).toStringAsFixed(0)}k';
    }
    return absVal.toStringAsFixed(0);
  }

  IconData _getCategoryIcon(String category, TransactionType type) {
    final catLower = category.toLowerCase();
    if (catLower.contains('food') || catLower.contains('dinner') || catLower.contains('lunch') || catLower.contains('cafe')) {
      return Icons.restaurant_rounded;
    }
    if (catLower.contains('travel') || catLower.contains('uber') || catLower.contains('taxi') || catLower.contains('flight') || catLower.contains('car')) {
      return Icons.directions_car_rounded;
    }
    if (catLower.contains('shop') || catLower.contains('grocer') || catLower.contains('clothes') || catLower.contains('buy')) {
      return Icons.shopping_bag_rounded;
    }
    if (catLower.contains('bill') || catLower.contains('electri') || catLower.contains('water') || catLower.contains('rent') || catLower.contains('sub')) {
      return Icons.receipt_long_rounded;
    }
    if (catLower.contains('movie') || catLower.contains('show') || catLower.contains('entertain') || catLower.contains('game')) {
      return Icons.sports_esports_rounded;
    }
    if (catLower.contains('salary') || catLower.contains('income') || catLower.contains('paycheck')) {
      return Icons.account_balance_rounded;
    }
    if (catLower.contains('gift') || catLower.contains('present')) {
      return Icons.card_giftcard_rounded;
    }
    if (type == TransactionType.transfer) {
      return Icons.swap_horiz_rounded;
    }
    if (type == TransactionType.income) {
      return Icons.arrow_downward_rounded;
    }
    return Icons.payments_rounded;
  }

  Color _getCategoryColor(String category, TransactionType type) {
    final catLower = category.toLowerCase();
    if (catLower.contains('food') || catLower.contains('dinner') || catLower.contains('cafe')) {
      return const Color(0xFFF97316); // Orange
    }
    if (catLower.contains('travel') || catLower.contains('uber') || catLower.contains('car')) {
      return const Color(0xFF06B6D4); // Cyan
    }
    if (catLower.contains('shop')) {
      return const Color(0xFFEC4899); // Pink
    }
    if (catLower.contains('bill') || catLower.contains('rent')) {
      return const Color(0xFF3B82F6); // Blue
    }
    if (catLower.contains('salary') || catLower.contains('income')) {
      return const Color(0xFF10B981); // Green
    }
    if (type == TransactionType.income) {
      return const Color(0xFF10B981);
    }
    return const Color(0xFF64748B); // Slate
  }

  @override
  Widget build(BuildContext context) {
    final expenses = ref.watch(expenseListProvider).value ?? const <ExpenseModel>[];
    final currency = ref.watch(currencyFormatProvider);

    // Filter active month expenses
    final filteredExpenses = expenses.where((e) {
      final localDate = e.date.toLocal();
      return localDate.year == _currentMonth.year && localDate.month == _currentMonth.month;
    }).toList();



    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: const GradientAppBar(
        title: 'Calendar View',
      ),
      body: Column(
        children: [
          // Top Swapper Row: Pill switch and Cycle View toggle
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                _CalendarPillSwitch(
                  selectedView: _selectedView,
                  onChanged: (view) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _selectedView = view;
                    });
                  },
                ),
                const Spacer(),
                // Cycle View Mode Pill Switcher (Toggles by tapping directly)
                if (_selectedView == 'Calendar')
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        if (_calendarViewType == 'Month') {
                          _calendarViewType = 'Week';
                        } else if (_calendarViewType == 'Week') {
                          _calendarViewType = '2 weeks';
                        } else {
                          _calendarViewType = 'Month';
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF), // light blue
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.primaryBlue.withOpacity(0.2), width: 1),
                      ),
                      child: Text(
                        _calendarViewType,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Period navigation row (Only appears when Calendar mode is active)
          if (_selectedView == 'Calendar')
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, color: AppColors.textDark, size: 28),
                    onPressed: _previousPeriod,
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _selectMonth(context),
                    child: Text(
                      DateFormat('MMMM yyyy').format(_selectedDate),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (!DateUtils.isSameDay(_selectedDate, DateTime.now())) ...[
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _selectedDate = DateUtils.dateOnly(DateTime.now());
                          _currentMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Today',
                          style: TextStyle(
                            color: AppColors.primaryBlue,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, color: AppColors.textDark, size: 28),
                    onPressed: _nextPeriod,
                  ),
                ],
              ),
            ),

          // Main body view
          Expanded(
            child: _selectedView == 'Calendar'
                ? _buildCalendarGridSection(filteredExpenses, expenses, currency)
                : _buildTimelineSection(expenses, currency),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required Color color,
    required Color bgColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Calendar Grid Section ──────────────────────────────────────────────────
  Widget _buildCalendarGridSection(
    List<ExpenseModel> monthExpenses,
    List<ExpenseModel> allExpenses,
    NumberFormat currencyFormat,
  ) {
    final List<DateTime> daysToRender = [];
    int prefixDays = 0;

    if (_calendarViewType == 'Month') {
      final firstDay = DateTime(_selectedDate.year, _selectedDate.month, 1);
      final totalDays = DateUtils.getDaysInMonth(_selectedDate.year, _selectedDate.month);
      prefixDays = firstDay.weekday % 7; // Sunday is 7 -> 0 offset
      
      for (int i = 0; i < prefixDays; i++) {
        daysToRender.add(DateTime(1970)); // dummy date spacer
      }
      for (int d = 1; d <= totalDays; d++) {
        daysToRender.add(DateTime(_selectedDate.year, _selectedDate.month, d));
      }
    } else if (_calendarViewType == 'Week') {
      final startOfWeek = _getStartOfWeek(_selectedDate);
      for (int i = 0; i < 7; i++) {
        daysToRender.add(startOfWeek.add(Duration(days: i)));
      }
    } else if (_calendarViewType == '2 weeks') {
      final sundayOfSelected = _getStartOfWeek(_selectedDate);
      final sundayOfPrev = sundayOfSelected.subtract(const Duration(days: 7));
      for (int i = 0; i < 14; i++) {
        daysToRender.add(sundayOfPrev.add(Duration(days: i)));
      }
    }

    final weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Column(
      children: [
        // Greyish card containing the header and date grid
        GestureDetector(
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity == null) return;
            if (details.primaryVelocity! < 0) {
              // Swiped left -> Next month/period
              _nextPeriod();
            } else if (details.primaryVelocity! > 0) {
              // Swiped right -> Previous month/period
              _previousPeriod();
            }
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9).withOpacity(0.6), // Beautiful light blue-grey card
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
              // Weekday header row
              Container(
                color: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: weekdays.map((day) {
                    return Expanded(
                      child: Text(
                        day,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 6),

              // Grid View
              Container(
                color: Colors.transparent,
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 4,
                    childAspectRatio: 0.75, // adjusted ratio to give vertical space for capsules and prevent overflow
                  ),
                  itemCount: daysToRender.length,
                  itemBuilder: (context, index) {
                    final cellDate = daysToRender[index];
                    if (cellDate.year == 1970) {
                      return const SizedBox.shrink();
                    }

                    final isSelected = DateUtils.isSameDay(cellDate, _selectedDate);
                    final isToday = DateUtils.isSameDay(cellDate, DateTime.now());

                    // Filter transactions on this day from all transactions
                    final dayTxns = allExpenses.where((e) {
                      return DateUtils.isSameDay(e.date.toLocal(), cellDate);
                    }).toList();

                    // Net total on this day
                    double dayNet = 0;
                    for (final t in dayTxns) {
                      if (t.type == TransactionType.income) {
                        dayNet += t.amount;
                      } else if (t.type == TransactionType.expense) {
                        dayNet -= t.amount;
                      }
                    }

                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _selectedDate = DateUtils.dateOnly(cellDate);
                          _currentMonth = DateTime(cellDate.year, cellDate.month, 1);
                        });
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Date number circle
                          Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFE2E8F0) // Sleek mockup selected day background
                                      : Colors.transparent,
                                  shape: BoxShape.circle,
                                  border: isToday && !isSelected
                                      ? Border.all(color: AppColors.primaryBlue.withOpacity(0.4), width: 1.5)
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  cellDate.day.toString(),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: isSelected || isToday
                                        ? FontWeight.w900
                                        : FontWeight.w700,
                                    color: isToday && !isSelected
                                        ? AppColors.primaryBlue
                                        : AppColors.textDark,
                                  ),
                                ),
                              ),

                              // Dynamic Category Badge on Top-Right if selected and has transactions
                              if (isSelected && dayTxns.isNotEmpty)
                                Positioned(
                                  top: -2,
                                  right: -2,
                                  child: Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: _getCategoryColor(dayTxns.first.category, dayTxns.first.type),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 1),
                                    ),
                                    alignment: Alignment.center,
                                    child: Icon(
                                      _getCategoryIcon(dayTxns.first.category, dayTxns.first.type),
                                      color: Colors.white,
                                      size: 8,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 3),

                          // Net capsule underneath
                          if (dayTxns.isNotEmpty && dayNet != 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: dayNet > 0
                                    ? const Color(0xFFD1FAE5) // light green capsule
                                    : const Color(0xFFFEE2E2), // light red capsule
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                dayNet > 0
                                    ? '+₹${_formatDayAmount(dayNet)}'
                                    : '₹${_formatDayAmount(dayNet)}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: dayNet > 0
                                      ? const Color(0xFF065F46)
                                      : const Color(0xFF991B1B),
                                  letterSpacing: -0.2,
                                ),
                              ),
                            )
                          else
                            const SizedBox(height: 11), // spacer matching height of capsule
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),

        // Stats / Metrics row (placed dynamically below the grid)
        () {
          double totalIncome = 0;
          double totalExpense = 0;
          for (final exp in monthExpenses) {
            if (exp.type == TransactionType.income) {
              totalIncome += exp.amount;
            } else if (exp.type == TransactionType.expense) {
              totalExpense += exp.amount;
            }
          }

          return Container(
            color: Colors.transparent,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Income',
                    value: '+${currencyFormat.format(totalIncome)}',
                    color: const Color(0xFF059669),
                    bgColor: const Color(0xFFECFDF5),
                    icon: Icons.arrow_upward_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Expense',
                    value: '-${currencyFormat.format(totalExpense)}',
                    color: const Color(0xFFDC2626),
                    bgColor: const Color(0xFFFEF2F2),
                    icon: Icons.arrow_downward_rounded,
                  ),
                ),
              ],
            ),
          );
        }(),

        // Divider
        const Divider(color: Color(0xFFE2E8F0), height: 1),

        // Date selection title & Day list header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('EEEE, d MMMM').format(_selectedDate),
                style: const TextStyle(
                  color: AppColors.textDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Icon(Icons.arrow_right_alt_rounded, color: AppColors.textMuted, size: 20),
            ],
          ),
        ),

        // Dynamic transaction items list for selectedDate
        Expanded(
          child: _buildDayTransactionsList(allExpenses, currencyFormat),
        ),
      ],
    );
  }

  Widget _buildDayTransactionsList(List<ExpenseModel> allExpenses, NumberFormat currencyFormat) {
    final dayTxns = allExpenses.where((e) {
      return DateUtils.isSameDay(e.date.toLocal(), _selectedDate);
    }).toList();

    if (dayTxns.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_note_rounded, size: 48, color: Color(0xFFCBD5E1)),
            SizedBox(height: 8),
            Text(
              'No transactions logged today.',
              style: TextStyle(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: dayTxns.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final tx = dayTxns[index];
        final isIncome = tx.type == TransactionType.income;
        final isTransfer = tx.type == TransactionType.transfer;

        return GestureDetector(
          onTap: () => AppRoutes.pushEditExpense(
            context,
            expenseId: tx.id,
            initialAmount: tx.amount,
            initialCategory: tx.category,
            initialDate: tx.date.toLocal(),
            initialNote: tx.note,
            initialAccountId: tx.accountId,
            initialToAccountId: tx.toAccountId,
            initialType: tx.type,
            initialSubcategory: tx.subcategory,
            initialLatitude: tx.latitude,
            initialLongitude: tx.longitude,
          ),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                // Category Icon bubble
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _getCategoryColor(tx.category, tx.type).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getCategoryIcon(tx.category, tx.type),
                    color: _getCategoryColor(tx.category, tx.type),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),

                // Note/Category detail
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tx.note.isNotEmpty ? tx.note : tx.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textDark,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (tx.note.isNotEmpty) ...[
                            Text(
                              tx.category,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text('•', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 10)),
                            const SizedBox(width: 6),
                          ],
                          if (tx.subcategory != null) ...[
                            Text(
                              tx.subcategory!,
                              style: const TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text('•', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 10)),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            DateFormat('h:mm a').format(tx.date.toLocal()),
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Amount
                Text(
                  isIncome
                      ? '+${currencyFormat.format(tx.amount)}'
                      : isTransfer
                          ? currencyFormat.format(tx.amount)
                          : '-${currencyFormat.format(tx.amount)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: isIncome
                        ? const Color(0xFF059669)
                        : isTransfer
                            ? const Color(0xFF8B5CF6)
                            : const Color(0xFFDC2626),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Timeline Section ───────────────────────────────────────────────────────
  Widget _buildTimelineSection(List<ExpenseModel> allExpenses, NumberFormat currencyFormat) {
    // Filter transactions from selected months
    final limitMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1).subtract(const Duration(seconds: 1));
    // Determine the start boundary based on how many months user expanded
    final startMonth = DateTime(_currentMonth.year, _currentMonth.month - _timelineMonthsCount + 1, 1);

    final filtered = allExpenses.where((e) {
      final d = e.date.toLocal();
      return d.isAfter(startMonth) && d.isBefore(limitMonth);
    }).toList();

    double totalIncome = 0;
    double totalExpense = 0;
    for (final exp in filtered) {
      if (exp.type == TransactionType.income) {
        totalIncome += exp.amount;
      } else if (exp.type == TransactionType.expense) {
        totalExpense += exp.amount;
      }
    }

    // Group by Day Date
    final Map<DateTime, List<ExpenseModel>> groupedByDay = {};
    for (final tx in filtered) {
      final day = DateUtils.dateOnly(tx.date.toLocal());
      if (!groupedByDay.containsKey(day)) {
        groupedByDay[day] = [];
      }
      groupedByDay[day]!.add(tx);
    }

    final sortedDates = groupedByDay.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(
      children: [
        // Stats / Metrics row
        Container(
          color: Colors.transparent,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'Income',
                  value: '+${currencyFormat.format(totalIncome)}',
                  color: const Color(0xFF059669),
                  bgColor: const Color(0xFFECFDF5),
                  icon: Icons.arrow_upward_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricCard(
                  title: 'Expense',
                  value: '-${currencyFormat.format(totalExpense)}',
                  color: const Color(0xFFDC2626),
                  bgColor: const Color(0xFFFEF2F2),
                  icon: Icons.arrow_downward_rounded,
                ),
              ),
            ],
          ),
        ),
        const Divider(color: Color(0xFFE2E8F0), height: 1),
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.timeline_rounded, size: 48, color: Color(0xFFCBD5E1)),
                      SizedBox(height: 8),
                      Text(
                        'No logged transactions in this range.',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: sortedDates.length + 1,
                  itemBuilder: (context, index) {
                    if (index == sortedDates.length) {
                      // View More button
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Center(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              setState(() {
                                _timelineMonthsCount += 1;
                              });
                            },
                            icon: const Icon(Icons.expand_more_rounded),
                            label: const Text('View More Months'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.primaryBlue,
                              elevation: 0,
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                          ),
                        ),
                      );
                    }

                    final cellDate = sortedDates[index];
                    final dayTxns = groupedByDay[cellDate]!;

                    // Group net totals
                    double netSum = 0;
                    final Set<String> categories = {};
                    for (final t in dayTxns) {
                      categories.add(t.category);
                      if (t.type == TransactionType.income) {
                        netSum += t.amount;
                      } else if (t.type == TransactionType.expense) {
                        netSum -= t.amount;
                      }
                    }

                    final isNetIncome = netSum > 0;
                    final showMonthHeader = index == 0 ||
                        sortedDates[index].month != sortedDates[index - 1].month ||
                        sortedDates[index].year != sortedDates[index - 1].year;

                    final isExpanded = _expandedTimelineDates.contains(cellDate);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showMonthHeader) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            child: Text(
                              DateFormat('MMMM yyyy').format(cellDate),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF64748B),
                                letterSpacing: 1.1,
                              ),
                            ),
                          ),
                        ],

                        // Daily Card Row with Timeline Left Line
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Timeline Side Bar
                              SizedBox(
                                width: 50,
                                child: Stack(
                                  alignment: Alignment.topCenter,
                                  children: [
                                    // Vertical connector line
                                    Positioned(
                                      top: 0,
                                      bottom: 0,
                                      child: Container(
                                        width: 1.5,
                                        color: const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    // Indicator bubble/badge
                                    Positioned(
                                      top: 12,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: isNetIncome
                                                  ? const Color(0xFFD1FAE5)
                                                  : const Color(0xFFFEE2E2),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Text(
                                              cellDate.day.toString(),
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w900,
                                                color: isNetIncome
                                                    ? const Color(0xFF065F46)
                                                    : const Color(0xFF991B1B),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            DateFormat('E').format(cellDate),
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textMuted,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Day summary Card content
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: GestureDetector(
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      setState(() {
                                        if (isExpanded) {
                                          _expandedTimelineDates.remove(cellDate);
                                        } else {
                                          _expandedTimelineDates.add(cellDate);
                                        }
                                      });
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: isExpanded ? AppColors.primaryBlue : const Color(0xFFE2E8F0),
                                          width: isExpanded ? 1.5 : 1.0,
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x05000000),
                                            blurRadius: 10,
                                            offset: Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              // Circle status indicator
                                              Container(
                                                padding: const EdgeInsets.all(6),
                                                decoration: BoxDecoration(
                                                  color: isNetIncome
                                                      ? const Color(0xFFECFDF5)
                                                      : const Color(0xFFFEF2F2),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  isNetIncome ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                                  color: isNetIncome ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                                  size: 14,
                                                ),
                                              ),
                                              const SizedBox(width: 10),

                                              // Day text / Amount totals
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      isNetIncome
                                                          ? '+${currencyFormat.format(netSum)}'
                                                          : '-${currencyFormat.format(netSum.abs())}',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w900,
                                                        color: isNetIncome
                                                            ? const Color(0xFF059669)
                                                            : const Color(0xFFDC2626),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      '${dayTxns.length} transaction${dayTxns.length == 1 ? '' : 's'}',
                                                      style: const TextStyle(
                                                        color: AppColors.textMuted,
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),

                                              // Icons list row
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: categories.take(3).map((cat) {
                                                  return Container(
                                                    width: 28,
                                                    height: 28,
                                                    margin: const EdgeInsets.only(left: 4),
                                                    decoration: BoxDecoration(
                                                      color: _getCategoryColor(cat, TransactionType.expense).withOpacity(0.06),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Icon(
                                                      _getCategoryIcon(cat, TransactionType.expense),
                                                      color: _getCategoryColor(cat, TransactionType.expense),
                                                      size: 12,
                                                    ),
                                                  );
                                                }).toList(),
                                              ),

                                              if (categories.length > 3) ...[
                                                Container(
                                                  width: 24,
                                                  height: 24,
                                                  margin: const EdgeInsets.only(left: 4),
                                                  decoration: const BoxDecoration(
                                                    color: Color(0xFFF1F5F9),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  alignment: Alignment.center,
                                                  child: Text(
                                                    '+${categories.length - 3}',
                                                    style: const TextStyle(
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.w800,
                                                      color: AppColors.textMuted,
                                                    ),
                                                  ),
                                                ),
                                              ],

                                              const SizedBox(width: 8),
                                              Icon(
                                                isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                                color: AppColors.textMuted,
                                                size: 18,
                                              ),
                                            ],
                                          ),

                                          // Expanded detailed list of items
                                          if (isExpanded) ...[
                                            const SizedBox(height: 12),
                                            const Divider(color: Color(0xFFE2E8F0), height: 1),
                                            const SizedBox(height: 8),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: List.generate(dayTxns.length, (subIdx) {
                                                final item = dayTxns[subIdx];
                                                final isInc = item.type == TransactionType.income;
                                                final isTrans = item.type == TransactionType.transfer;

                                                return Padding(
                                                  padding: EdgeInsets.only(bottom: subIdx == dayTxns.length - 1 ? 0.0 : 6.0),
                                                  child: GestureDetector(
                                                    onTap: () => AppRoutes.pushEditExpense(
                                                      context,
                                                      expenseId: item.id,
                                                      initialAmount: item.amount,
                                                      initialCategory: item.category,
                                                      initialDate: item.date.toLocal(),
                                                      initialNote: item.note,
                                                      initialAccountId: item.accountId,
                                                      initialToAccountId: item.toAccountId,
                                                      initialType: item.type,
                                                      initialSubcategory: item.subcategory,
                                                      initialLatitude: item.latitude,
                                                      initialLongitude: item.longitude,
                                                    ),
                                                    child: Padding(
                                                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                            _getCategoryIcon(item.category, item.type),
                                                            color: _getCategoryColor(item.category, item.type),
                                                            size: 14,
                                                          ),
                                                          const SizedBox(width: 8),
                                                          Expanded(
                                                            child: Text(
                                                              item.note.isNotEmpty ? item.note : item.category,
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                              style: const TextStyle(
                                                                fontSize: 12,
                                                                fontWeight: FontWeight.w700,
                                                                color: AppColors.textDark,
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(width: 8),
                                                          Text(
                                                            isInc
                                                                ? '+${currencyFormat.format(item.amount)}'
                                                                : isTrans
                                                                    ? currencyFormat.format(item.amount)
                                                                    : '-${currencyFormat.format(item.amount)}',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              fontWeight: FontWeight.w800,
                                                              color: isInc
                                                                  ? const Color(0xFF059669)
                                                                  : isTrans
                                                                      ? const Color(0xFF8B5CF6)
                                                                      : const Color(0xFFDC2626),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ── Custom Pill Toggle ───────────────────────────────────────────────────────
class _CalendarPillSwitch extends StatelessWidget {
  const _CalendarPillSwitch({
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
          _buildOption('Calendar'),
          _buildOption('Timeline'),
        ],
      ),
    );
  }

  Widget _buildOption(String view) {
    final isSelected = selectedView == view;
    return GestureDetector(
      onTap: () => onChanged(view),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x0F000000),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          view,
          style: TextStyle(
            color: isSelected ? AppColors.primaryBlue : AppColors.textMuted,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
