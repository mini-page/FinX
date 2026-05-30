import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../data/models/expense_model.dart';

class HomeDateStrip extends StatelessWidget {
  const HomeDateStrip({
    super.key,
    required this.expenses,
    required this.selectedDate,
    required this.selectedTotalText,
    required this.transactionCount,
    required this.onDateSelected,
    required this.onPrevious,
    required this.onNext,
    required this.isOnToday,
    required this.onJumpToToday,
    this.onMonthTap,
  });

  final List<ExpenseModel> expenses;
  final DateTime selectedDate;
  final String selectedTotalText;
  final int transactionCount;
  final bool isOnToday;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onJumpToToday;
  final ValueChanged<DateTime>? onMonthTap;

  DateTime _getStartOfWeek(DateTime date) {
    return date.subtract(Duration(days: date.weekday % 7));
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

  @override
  Widget build(BuildContext context) {
    final monthFormat = DateFormat('MMMM yyyy');
    final sunday = _getStartOfWeek(selectedDate);
    final weekDates = List<DateTime>.generate(7, (i) => sunday.add(Duration(days: i)));
    final weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          // Header row (Month Title & Today & Go to Calendar Arrow)
          Row(
            children: <Widget>[
              Text(
                monthFormat.format(selectedDate),
                style: const TextStyle(
                  color: AppColors.textDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              if (!isOnToday)
                GestureDetector(
                  onTap: onJumpToToday,
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
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              // Leads to Calendar View
              GestureDetector(
                onTap: () => onMonthTap?.call(selectedDate),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textDark,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Weekly Calendar Card (Swipeable to navigate weeks)
          GestureDetector(
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity == null) return;
              if (details.primaryVelocity! < 0) {
                // Swiped left -> Next week
                onNext();
              } else if (details.primaryVelocity! > 0) {
                // Swiped right -> Previous week
                onPrevious();
              }
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9).withOpacity(0.6), // Beautiful light blue-grey card
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  // Weekday names header
                  Row(
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
                  const SizedBox(height: 6),

                  // Days numbers & capsules
                  Row(
                    children: weekDates.map((date) {
                      final isSelected = DateUtils.isSameDay(date, selectedDate);
                      final isToday = DateUtils.isSameDay(date, DateTime.now());

                      // Filter transactions on this day from list
                      final dayTxns = expenses.where((e) {
                        return DateUtils.isSameDay(e.date.toLocal(), date);
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

                      return Expanded(
                        child: GestureDetector(
                          onTap: () => onDateSelected(date), // Select locally on Home Screen
                          child: Column(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFE2E8F0) // Sleek selected circle
                                      : Colors.transparent,
                                  shape: BoxShape.circle,
                                  border: isToday && !isSelected
                                      ? Border.all(color: AppColors.primaryBlue.withOpacity(0.4), width: 1.5)
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  date.day.toString(),
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
                              const SizedBox(height: 3),
                              if (dayTxns.isNotEmpty && dayNet != 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: dayNet > 0
                                        ? const Color(0xFFD1FAE5) // light green
                                        : const Color(0xFFFEE2E2), // light red
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    dayNet > 0
                                        ? '+₹${_formatDayAmount(dayNet)}'
                                        : '₹${_formatDayAmount(dayNet)}',
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                      color: dayNet > 0
                                          ? const Color(0xFF065F46)
                                          : const Color(0xFF991B1B),
                                    ),
                                  ),
                                )
                              else
                                const SizedBox(height: 10), // spacer
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Daily details / totals row (count on left, net spending total on right)
          Row(
            children: [
              Text(
                '$transactionCount transaction${transactionCount == 1 ? '' : 's'}',
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    selectedTotalText,
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


