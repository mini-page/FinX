import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_tokens.dart';
import 'package:xpens/features/expense/data/models/expense_model.dart';
import 'package:xpens/features/expense/presentation/widgets/amount_visibility.dart';
import 'package:xpens/features/categories/presentation/widgets/expense_category.dart';
import 'package:xpens/features/accounts/data/models/account_model.dart';
import 'package:xpens/features/expense/presentation/widgets/transaction_card.dart';

// ---------------------------------------------------------------------------
// Data models (unchanged)
// ---------------------------------------------------------------------------

class AnalyticsSnapshot {
  AnalyticsSnapshot({
    required this.periodLabel,
    required this.monthExpenseTotal,
    required this.monthIncomeTotal,
    required this.monthNetTotal,
    required this.transactionCount,
    required this.transferCount,
    required this.activeDays,
    required this.averageExpenseTransaction,
    required this.savingsRate,
    required this.monthlyTrend,
    required this.weekdaySpending,
    required this.expenseMix,
    required this.topExpenseCategory,
    required this.topExpenseCategoryAmount,
    required this.busiestDayLabel,
    required this.busiestDayCount,
    required this.largestExpense,
    required this.largestIncome,
    required this.transactions,
    required this.dailyAverage,
    required this.projectedExpense,
    required this.totalPeriodDays,
    required this.elapsedPeriodDays,
  });

  factory AnalyticsSnapshot.fromExpenses(
    List<ExpenseModel> expenses, {
    String rangeLabel = 'This Month',
    List<ExpenseCategory> extraExpenseCategories = const [],
  }) {
    final now = DateTime.now();
    final ({DateTime start, DateTime end, String label}) range =
        AnalyticsSnapshot._rangeFor(rangeLabel, now);

    final monthTransactions = expenses.where((expense) {
      final localDate = expense.date.toLocal();
      final dateOnly = DateUtils.dateOnly(localDate);
      return !dateOnly.isBefore(DateUtils.dateOnly(range.start)) &&
          !dateOnly.isAfter(DateUtils.dateOnly(range.end));
    }).toList(growable: false)
      ..sort((left, right) => left.date.compareTo(right.date));

    final expenseMixMap = <String, double>{};
    final weekdaySpendingMap = <int, double>{
      for (int weekday = 1; weekday <= 7; weekday++) weekday: 0,
    };
    final dayCounts = <DateTime, int>{};
    final activeDayKeys = <String>{};

    double monthExpenseTotal = 0;
    double monthIncomeTotal = 0;
    int transferCount = 0;
    int expenseCount = 0;
    ExpenseModel? largestExpense;
    ExpenseModel? largestIncome;

    for (final transaction in monthTransactions) {
      final localDate = transaction.date.toLocal();
      final dayKey = DateFormat('yyyy-MM-dd').format(localDate);
      activeDayKeys.add(dayKey);
      final dateOnly = DateUtils.dateOnly(localDate);
      dayCounts.update(dateOnly, (value) => value + 1, ifAbsent: () => 1);

      switch (transaction.type) {
        case TransactionType.transfer:
          transferCount++;
          break;
        case TransactionType.income:
          monthIncomeTotal += transaction.amount;
          if (largestIncome == null ||
              transaction.amount > largestIncome.amount) {
            largestIncome = transaction;
          }
          break;
        case TransactionType.expense:
          monthExpenseTotal += transaction.amount;
          expenseCount++;
          weekdaySpendingMap.update(
            localDate.weekday,
            (value) => value + transaction.amount,
          );
          expenseMixMap.update(
            transaction.category,
            (value) => value + transaction.amount,
            ifAbsent: () => transaction.amount,
          );
          if (largestExpense == null ||
              transaction.amount > largestExpense.amount) {
            largestExpense = transaction;
          }
          break;
      }
    }

    final sortedMix = expenseMixMap.entries.toList(growable: false)
      ..sort((left, right) => right.value.compareTo(left.value));

    final daysDiff = range.end.difference(range.start).inDays;
    final List<MonthlyTrendPoint> trendPoints;

    if (daysDiff <= 31) {
      final trendMap = <String, _MutableTrendBucket>{};
      final daysCount = daysDiff + 1;
      for (int i = 0; i < daysCount; i++) {
        final date = range.start.add(Duration(days: i));
        final key = DateFormat('yyyy-MM-dd').format(date);
        trendMap[key] = _MutableTrendBucket(month: date);
      }

      for (final transaction in monthTransactions) {
        final localDate = transaction.date.toLocal();
        final dateOnly = DateUtils.dateOnly(localDate);
        final key = DateFormat('yyyy-MM-dd').format(dateOnly);
        final bucket = trendMap[key];
        if (bucket == null) {
          continue;
        }

        bucket.transactionCount += 1;
        switch (transaction.type) {
          case TransactionType.expense:
            bucket.expense += transaction.amount;
            break;
          case TransactionType.income:
            bucket.income += transaction.amount;
            break;
          case TransactionType.transfer:
            break;
        }
      }
      trendPoints = trendMap.values
          .map((bucket) => bucket.toImmutable())
          .toList(growable: false);
    } else {
      final trendMap = <String, _MutableTrendBucket>{};
      final sixMonthStart = DateTime(now.year, now.month - 5);
      for (int index = 0; index < 6; index++) {
        final month = DateTime(sixMonthStart.year, sixMonthStart.month + index);
        trendMap[_monthKey(month)] = _MutableTrendBucket(month: month);
      }

      for (final transaction in expenses) {
        final localDate = transaction.date.toLocal();
        final month = DateTime(localDate.year, localDate.month);
        final bucket = trendMap[_monthKey(month)];
        if (bucket == null) {
          continue;
        }

        bucket.transactionCount += 1;
        switch (transaction.type) {
          case TransactionType.expense:
            bucket.expense += transaction.amount;
            break;
          case TransactionType.income:
            bucket.income += transaction.amount;
            break;
          case TransactionType.transfer:
            break;
        }
      }
      trendPoints = trendMap.values
          .map((bucket) => bucket.toImmutable())
          .toList(growable: false);
    }

    DateTime? busiestDay;
    int busiestDayCount = 0;
    dayCounts.forEach((day, count) {
      if (count > busiestDayCount) {
        busiestDay = day;
        busiestDayCount = count;
      }
    });

    final busiestDayLabel = busiestDay == null
        ? 'No activity yet'
        : DateFormat('d MMM').format(busiestDay!);

    final totalPeriodDays = range.end.difference(range.start).inDays + 1;
    final elapsedDays = range.end.isAfter(now)
        ? now.difference(range.start).inDays + 1
        : totalPeriodDays;
    final elapsedPeriodDays = elapsedDays.clamp(1, totalPeriodDays);
    final dailyAverage = elapsedPeriodDays == 0 ? 0.0 : monthExpenseTotal / elapsedPeriodDays;
    final projectedExpense = dailyAverage * totalPeriodDays;

    return AnalyticsSnapshot(
      periodLabel: range.label,
      monthExpenseTotal: monthExpenseTotal,
      monthIncomeTotal: monthIncomeTotal,
      monthNetTotal: monthIncomeTotal - monthExpenseTotal,
      transactionCount: monthTransactions.length,
      transferCount: transferCount,
      activeDays: activeDayKeys.length,
      averageExpenseTransaction:
          expenseCount == 0 ? 0 : monthExpenseTotal / expenseCount,
      savingsRate: monthIncomeTotal <= 0
          ? 0
          : ((monthIncomeTotal - monthExpenseTotal) / monthIncomeTotal)
              .clamp(-1, 1),
      monthlyTrend: trendPoints,
      weekdaySpending: weekdaySpendingMap.entries
          .map(
            (entry) => WeekdaySpendingPoint(
              weekday: entry.key,
              amount: entry.value,
            ),
          )
          .toList(growable: false),
      expenseMix: sortedMix
          .map(
            (entry) => CategoryMixPoint(
              label: entry.key,
              amount: entry.value,
              color: resolveExpenseCategory(
                entry.key,
                extraExpenseCategories,
              ).color,
            ),
          )
          .toList(growable: false),
      topExpenseCategory:
          sortedMix.isEmpty ? 'No expense category yet' : sortedMix.first.key,
      topExpenseCategoryAmount: sortedMix.isEmpty ? 0 : sortedMix.first.value,
      busiestDayLabel: busiestDayLabel,
      busiestDayCount: busiestDayCount,
      largestExpense: largestExpense,
      largestIncome: largestIncome,
      transactions: monthTransactions,
      dailyAverage: dailyAverage,
      projectedExpense: projectedExpense,
      totalPeriodDays: totalPeriodDays,
      elapsedPeriodDays: elapsedPeriodDays,
    );
  }

  /// Converts a named range label into an inclusive [start, end] date range.
  static ({DateTime start, DateTime end, String label}) _rangeFor(
    String label,
    DateTime now,
  ) {
    switch (label) {
      case 'This Week':
        final weekStart =
            DateUtils.dateOnly(now).subtract(Duration(days: now.weekday - 1));
        return (
          start: weekStart,
          end: DateUtils.dateOnly(now),
          label: label,
        );
      case 'Last 2 Weeks':
      case '2 Weeks':
        final start =
            DateUtils.dateOnly(now).subtract(const Duration(days: 13));
        return (
          start: start,
          end: DateUtils.dateOnly(now),
          label: 'Last 2 Weeks',
        );
      case 'Last Month':
        final firstOfLastMonth = DateTime(now.year, now.month - 1);
        final lastOfLastMonth = DateTime(now.year, now.month, 0);
        return (
          start: firstOfLastMonth,
          end: lastOfLastMonth,
          label: DateFormat('MMMM yyyy').format(firstOfLastMonth),
        );
      case 'Last 3 Months':
        final start = DateTime(now.year, now.month - 2);
        return (
          start: start,
          end: DateUtils.dateOnly(now),
          label: label,
        );
      case 'This Year':
        return (
          start: DateTime(now.year),
          end: DateUtils.dateOnly(now),
          label: DateFormat('yyyy').format(now),
        );
      case 'All Time':
        return (
          start: DateTime(2000),
          end: DateUtils.dateOnly(now),
          label: 'All Time',
        );
      case 'This Month':
      default:
        return (
          start: DateTime(now.year, now.month),
          end: DateUtils.dateOnly(now),
          label: DateFormat('MMMM yyyy').format(now),
        );
    }
  }

  final String periodLabel;
  final double monthExpenseTotal;
  final double monthIncomeTotal;
  final double monthNetTotal;
  final int transactionCount;
  final int transferCount;
  final int activeDays;
  final double averageExpenseTransaction;
  final double savingsRate;
  final List<MonthlyTrendPoint> monthlyTrend;
  final List<WeekdaySpendingPoint> weekdaySpending;
  final List<CategoryMixPoint> expenseMix;
  final String topExpenseCategory;
  final double topExpenseCategoryAmount;
  final String busiestDayLabel;
  final int busiestDayCount;
  final ExpenseModel? largestExpense;
  final ExpenseModel? largestIncome;
  final List<ExpenseModel> transactions;
  final double dailyAverage;
  final double projectedExpense;
  final int totalPeriodDays;
  final int elapsedPeriodDays;

  bool get hasTransactions => transactionCount > 0;
}

class MonthlyTrendPoint {
  const MonthlyTrendPoint({
    required this.month,
    required this.expense,
    required this.income,
    required this.transactionCount,
  });

  final DateTime month;
  final double expense;
  final double income;
  final int transactionCount;
}

class WeekdaySpendingPoint {
  const WeekdaySpendingPoint({
    required this.weekday,
    required this.amount,
  });

  final int weekday;
  final double amount;
}

class CategoryMixPoint {
  const CategoryMixPoint({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final double amount;
  final Color color;
}

// ---------------------------------------------------------------------------
// Shared layout widgets
// ---------------------------------------------------------------------------

/// Premium glass-morphism card with gradient background and layered shadow.
class AnalyticsGlassCard extends StatelessWidget {
  const AnalyticsGlassCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.hero),
        gradient: const LinearGradient(
          colors: <Color>[Colors.white, AppColors.surfaceMuted],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 30,
            spreadRadius: 2,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Compact metric tile with tinted background and column layout.
class AnalyticsMetricTile extends StatelessWidget {
  const AnalyticsMetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.accent,
    this.icon,
  });

  final String label;
  final String value;
  final Color accent;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    // Concentric radius: outer card hero(32) − padding(20) = 12 → AppRadii.sm(10)
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        color: accent.withValues(alpha: 0.08),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (icon != null) ...[
                Icon(icon, color: accent, size: 16),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textDark,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Insight card with 💡 emoji and dynamic text.
class AnalyticsInsightCard extends StatelessWidget {
  const AnalyticsInsightCard({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    // Concentric radius: outer hero(32) − padding(20) = 12 → AppRadii.sm(10)
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        color: AppColors.backgroundLight,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Text('💡', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 15,
                height: 1.45,
                color: AppColors.textDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab content widgets
// ---------------------------------------------------------------------------

/// Flow tab: 6-month income vs expense line chart + metrics + insight.
class FlowTabContent extends StatelessWidget {
  const FlowTabContent({
    super.key,
    required this.snapshot,
    required this.currencyFormat,
    required this.privacyModeEnabled,
  });

  final AnalyticsSnapshot snapshot;
  final NumberFormat currencyFormat;
  final bool privacyModeEnabled;

  @override
  Widget build(BuildContext context) {
    final maxValue = snapshot.monthlyTrend.fold<double>(
      0,
      (current, point) {
        final pointMax =
            point.expense > point.income ? point.expense : point.income;
        return pointMax > current ? pointMax : current;
      },
    );
    final axisMax = _niceAxisMax(maxValue);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Top row: Title/subtitle (left) and Legend (right)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            const Text(
              'Cash Flow Dynamics',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            Row(
              children: const <Widget>[
                _LegendChip(label: 'Income', color: Color(0xFF7C4DFF)),
                SizedBox(width: AppSpacing.sm),
                _LegendChip(label: 'Expense', color: AppColors.accentMint),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        // Double Bar Chart
        SizedBox(
          height: 240,
          child: maxValue <= 0
              ? const _ChartEmptyState(
                  message:
                      'Add transactions over time to reveal your cash-flow trend.',
                )
              : BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: axisMax,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: axisMax / 4,
                      getDrawingHorizontalLine: (_) => const FlLine(
                        color: AppColors.backgroundLight,
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(),
                      rightTitles: const AxisTitles(),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: !privacyModeEnabled,
                          reservedSize: 44,
                          interval: axisMax / 4,
                          getTitlesWidget: (value, meta) {
                            return SideTitleWidget(
                              meta: meta,
                              child: Text(
                                _compactCurrency(value, currencyFormat),
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 ||
                                index >= snapshot.monthlyTrend.length) {
                              return const SizedBox.shrink();
                            }
                            final date = snapshot.monthlyTrend[index].month;
                            String text = '';
                            if (snapshot.monthlyTrend.length == 6) {
                              text = DateFormat('MMM').format(date);
                            } else if (snapshot.monthlyTrend.length <= 7) {
                              text = DateFormat('E').format(date);
                            } else if (snapshot.monthlyTrend.length <= 15) {
                              if (index % 2 == 0) {
                                text = DateFormat('d/M').format(date);
                              }
                            } else {
                              if (index % 5 == 0 || index == snapshot.monthlyTrend.length - 1) {
                                text = DateFormat('d/M').format(date);
                              }
                            }
                            return SideTitleWidget(
                              meta: meta,
                              child: Text(
                                text,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => AppColors.textDark,
                        tooltipBorderRadius: BorderRadius.circular(12),
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final type = rodIndex == 0 ? 'Income' : 'Expense';
                          return BarTooltipItem(
                            '$type\n' + maskAmount(
                              currencyFormat.format(rod.toY),
                              masked: privacyModeEnabled,
                            ),
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          );
                        },
                      ),
                    ),
                    barGroups: snapshot.monthlyTrend.asMap().entries.map((entry) {
                      final index = entry.key;
                      final point = entry.value;
                      return BarChartGroupData(
                        x: index,
                        barsSpace: 4,
                        barRods: <BarChartRodData>[
                          BarChartRodData(
                            toY: point.income,
                            color: const Color(0xFF7C4DFF),
                            width: 6,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          BarChartRodData(
                            toY: point.expense,
                            color: AppColors.accentMint,
                            width: 6,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ],
                      );
                    }).toList(growable: false),
                  ),
                  duration: const Duration(milliseconds: 280),
                ),
        ),
      ],
    );
  }
}

/// Spend tab: category donut chart + legend + metrics + insight.
class SpendTabContent extends StatelessWidget {
  const SpendTabContent({
    super.key,
    required this.snapshot,
    required this.currencyFormat,
    required this.privacyModeEnabled,
  });

  final AnalyticsSnapshot snapshot;
  final NumberFormat currencyFormat;
  final bool privacyModeEnabled;

  @override
  Widget build(BuildContext context) {
    final topMix = snapshot.expenseMix.take(5).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Category Share',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (topMix.isEmpty)
          const SizedBox(
            height: 200,
            child: _ChartEmptyState(
              message: 'Add expense transactions to see category breakdown.',
            ),
          )
        else ...[
          SizedBox(
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                PieChart(
                  PieChartData(
                    sectionsSpace: 4,
                    centerSpaceRadius: 56,
                    startDegreeOffset: -90,
                    pieTouchData: PieTouchData(enabled: false),
                    sections: topMix.map((entry) {
                      final share = snapshot.monthExpenseTotal <= 0
                          ? 0.0
                          : (entry.amount / snapshot.monthExpenseTotal) * 100;
                      return PieChartSectionData(
                        value: entry.amount,
                        color: entry.color,
                        showTitle: false,
                        radius: 28,
                        badgeWidget: share >= 12
                            ? Text(
                                '${share.round()}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              )
                            : null,
                        badgePositionPercentageOffset: 1.18,
                      );
                    }).toList(growable: false),
                  ),
                  duration: const Duration(milliseconds: 280),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Text(
                      'TOP SHARE',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      topMix.first.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textDark,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Category legend
          ...topMix.map((entry) {
            final share = snapshot.monthExpenseTotal <= 0
                ? 0.0
                : (entry.amount / snapshot.monthExpenseTotal) * 100;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: entry.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      entry.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '${share.round()}%',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }
}

class HabitTabContent extends StatelessWidget {
  const HabitTabContent({
    super.key,
    required this.snapshot,
    required this.currencyFormat,
    required this.privacyModeEnabled,
  });

  final AnalyticsSnapshot snapshot;
  final NumberFormat currencyFormat;
  final bool privacyModeEnabled;

  @override
  Widget build(BuildContext context) {
    final maxValue = snapshot.weekdaySpending.fold<double>(
      0,
      (current, point) => point.amount > current ? point.amount : current,
    );
    final axisMax = _niceAxisMax(maxValue);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Weekly Distribution',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        // Chart
        SizedBox(
          height: 220,
          child: maxValue <= 0
              ? const _ChartEmptyState(
                  message:
                      'Keep tracking to see which days your wallet feels the most pressure.',
                )
              : BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: axisMax,
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(),
                      rightTitles: const AxisTitles(),
                      leftTitles: const AxisTitles(),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 32,
                          getTitlesWidget: (value, meta) {
                            final weekday = value.toInt();
                            final label = switch (weekday) {
                              1 => 'M',
                              2 => 'T',
                              3 => 'W',
                              4 => 'T',
                              5 => 'F',
                              6 => 'S',
                              7 => 'S',
                              _ => '',
                            };
                            return SideTitleWidget(
                              meta: meta,
                              space: 8,
                              child: Text(
                                label,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => AppColors.textDark,
                        tooltipBorderRadius: BorderRadius.circular(12),
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          return BarTooltipItem(
                            maskAmount(
                              currencyFormat.format(rod.toY),
                              masked: privacyModeEnabled,
                            ),
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          );
                        },
                      ),
                    ),
                    barGroups: snapshot.weekdaySpending.map((point) {
                      return BarChartGroupData(
                        x: point.weekday,
                        barRods: <BarChartRodData>[
                          BarChartRodData(
                            toY: point.amount,
                            width: 18,
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: <Color>[
                                AppColors.primaryBlueSoft,
                                AppColors.primaryBlue,
                              ],
                            ),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(8),
                              bottom: Radius.circular(3),
                            ),
                            backDrawRodData: BackgroundBarChartRodData(
                              show: true,
                              toY: axisMax,
                              color: AppColors.backgroundLight,
                            ),
                          ),
                        ],
                      );
                    }).toList(growable: false),
                  ),
                  duration: const Duration(milliseconds: 280),
                ),
        ),
      ],
    );
  }


}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

class _LegendChip extends StatelessWidget {
  const _LegendChip({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ChartEmptyState extends StatelessWidget {
  const _ChartEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w600,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

/// 2×2 grid for metric tiles with consistent spacing.
class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.children})
      : assert(children.length >= 2, '_MetricGrid needs at least 2 children');

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: children[0]),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: children[1]),
          ],
        ),
        if (children.length > 2) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(child: children[2]),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                  child: children.length > 3
                      ? children[3]
                      : const SizedBox.shrink()),
            ],
          ),
        ],
      ],
    );
  }
}

String _monthKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}';

class _MutableTrendBucket {
  _MutableTrendBucket({required this.month});
  final DateTime month;
  double expense = 0;
  double income = 0;
  int transactionCount = 0;

  MonthlyTrendPoint toImmutable() => MonthlyTrendPoint(
        month: month,
        expense: expense,
        income: income,
        transactionCount: transactionCount,
      );
}

double _niceAxisMax(double maxValue) {
  if (maxValue <= 0) return 100;
  if (maxValue < 100) return 100;
  if (maxValue < 500) return 500;
  if (maxValue < 1000) return 1000;
  if (maxValue < 5000) return 5000;
  if (maxValue < 10000) return 10000;
  return (maxValue * 1.2 / 1000).ceil() * 1000.0;
}

String _compactCurrency(double value, NumberFormat format) {
  if (value >= 1000000) {
    return '${format.currencySymbol}${(value / 1000000).toStringAsFixed(1)}M';
  } else if (value >= 1000) {
    return '${format.currencySymbol}${(value / 1000).toStringAsFixed(1)}k';
  } else {
    return '${format.currencySymbol}${value.toInt()}';
  }
}

/// Renders the range picker modal bottom sheet
Future<String?> showStatsRangePicker(BuildContext context, String currentRange) async {
  final rangeOptions = <String>[
    'This Week',
    'Last 2 Weeks',
    'This Month',
    'This Year',
    'All Time',
  ];

  return await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.white,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppRadii.xxl),
      ),
    ),
    builder: (_) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: rangeOptions.map((option) {
            final active = option == currentRange;
            return ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 2,
              ),
              tileColor: active ? AppColors.surfaceAccent : Colors.transparent,
              title: Text(
                option,
                style: TextStyle(
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? AppColors.primaryBlue : AppColors.textDark,
                ),
              ),
              trailing: active
                  ? const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.primaryBlue,
                    )
                  : null,
              onTap: () => Navigator.pop(context, option),
            );
          }).toList(growable: false),
        ),
      );
    },
  );
}

/// Renders the mockup summary cards (Income, Expenses, Net Flow, Savings Rate)
class StatsSummaryCards extends StatelessWidget {
  const StatsSummaryCards({
    super.key,
    required this.snapshot,
    required this.currencyFormat,
    required this.privacyModeEnabled,
  });

  final AnalyticsSnapshot snapshot;
  final NumberFormat currencyFormat;
  final bool privacyModeEnabled;

  @override
  Widget build(BuildContext context) {
    final expenseText = maskAmount(
      currencyFormat.format(snapshot.monthExpenseTotal),
      masked: privacyModeEnabled,
    );
    final incomeText = maskAmount(
      currencyFormat.format(snapshot.monthIncomeTotal),
      masked: privacyModeEnabled,
    );
    final netText = maskAmount(
      '${snapshot.monthNetTotal >= 0 ? '+' : ''}${currencyFormat.format(snapshot.monthNetTotal.abs())}',
      masked: privacyModeEnabled,
    );
    final savingsText = maskAmount(
      '${(snapshot.savingsRate * 100).round()}%',
      masked: privacyModeEnabled,
    );

    return Column(
      children: [
        Row(
          children: <Widget>[
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C4DFF).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE8EAF6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.savings_rounded,
                        color: Color(0xFF7C4DFF),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            incomeText,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                          const Text(
                            'Income',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.accentMint.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE8F5E9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        color: AppColors.accentMint,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            expenseText,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                          const Text(
                            'Expenses',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: <Widget>[
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEFF5FF),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        snapshot.monthNetTotal >= 0
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                        color: snapshot.monthNetTotal >= 0
                            ? AppColors.success
                            : AppColors.danger,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            netText,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: snapshot.monthNetTotal >= 0
                                  ? AppColors.success
                                  : AppColors.danger,
                            ),
                          ),
                          const Text(
                            'Net Flow',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFF8E1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.percent_rounded,
                        color: AppColors.warning,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            savingsText,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                          const Text(
                            'Savings Rate',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Renders the smart insights metrics 2x2 grid
class StatsInsightsGrid extends StatelessWidget {
  const StatsInsightsGrid({
    super.key,
    required this.snapshot,
    required this.currencyFormat,
    required this.privacyModeEnabled,
  });

  final AnalyticsSnapshot snapshot;
  final NumberFormat currencyFormat;
  final bool privacyModeEnabled;

  @override
  Widget build(BuildContext context) {
    final averageText = maskAmount(
      currencyFormat.format(snapshot.averageExpenseTransaction),
      masked: privacyModeEnabled,
    );
    final largestText = maskAmount(
      snapshot.largestExpense != null
          ? currencyFormat.format(snapshot.largestExpense!.amount)
          : '—',
      masked: privacyModeEnabled,
    );

    return _MetricGrid(
      children: [
        AnalyticsMetricTile(
          label: 'Active Days',
          value: '${snapshot.activeDays} logged',
          accent: AppColors.primaryBlue,
          icon: Icons.calendar_today_rounded,
        ),
        AnalyticsMetricTile(
          label: 'Busiest Day',
          value: snapshot.busiestDayCount > 0 
              ? '${snapshot.busiestDayLabel} (${snapshot.busiestDayCount})'
              : '—',
          accent: AppColors.danger,
          icon: Icons.local_fire_department_rounded,
        ),
        AnalyticsMetricTile(
          label: 'Avg / Txn',
          value: averageText,
          accent: AppColors.warning,
          icon: Icons.calculate_rounded,
        ),
        AnalyticsMetricTile(
          label: 'Largest Expense',
          value: largestText,
          accent: AppColors.success,
          icon: Icons.arrow_upward_rounded,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Mockup-aligned Dashboard Widgets
// ---------------------------------------------------------------------------

/// Renders the mockup overview card with 6 period statistics
class StatsOverviewMetrics extends StatelessWidget {
  const StatsOverviewMetrics({
    super.key,
    required this.snapshot,
    required this.currencyFormat,
    required this.privacyModeEnabled,
  });

  final AnalyticsSnapshot snapshot;
  final NumberFormat currencyFormat;
  final bool privacyModeEnabled;

  @override
  Widget build(BuildContext context) {
    final incomeText = maskAmount(
      currencyFormat.format(snapshot.monthIncomeTotal),
      masked: privacyModeEnabled,
    );
    final expenseText = maskAmount(
      currencyFormat.format(snapshot.monthExpenseTotal),
      masked: privacyModeEnabled,
    );
    final netText = maskAmount(
      '${snapshot.monthNetTotal >= 0 ? '+' : ''}${currencyFormat.format(snapshot.monthNetTotal.abs())}',
      masked: privacyModeEnabled,
    );
    final dailyAvgText = maskAmount(
      currencyFormat.format(snapshot.dailyAverage),
      masked: privacyModeEnabled,
    );
    final txnText = '${snapshot.transactionCount}';
    final projectedText = maskAmount(
      currencyFormat.format(snapshot.projectedExpense),
      masked: privacyModeEnabled,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Row 1: Income, Expense, Net Flow
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      'INCOME',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          incomeText,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.success,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_upward_rounded,
                          size: 14,
                          color: AppColors.success,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _buildDivider(),
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      'EXPENSE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          expenseText,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.danger,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_downward_rounded,
                          size: 14,
                          color: AppColors.danger,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _buildDivider(),
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      'NET FLOW',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          netText,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: snapshot.monthNetTotal >= 0
                                ? AppColors.success
                                : AppColors.danger,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          snapshot.monthNetTotal >= 0
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded,
                          size: 14,
                          color: snapshot.monthNetTotal >= 0
                              ? AppColors.success
                              : AppColors.danger,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.grey.shade100, height: 1),
          const SizedBox(height: 16),
          // Row 2: Daily Avg, Transactions, Projected
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.trending_up_rounded, size: 14, color: Colors.blue.shade400),
                        const SizedBox(width: 4),
                        const Text(
                          'DAILY AVG',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dailyAvgText,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
              ),
              _buildDivider(),
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.list_alt_rounded, size: 14, color: Colors.purple.shade400),
                        const SizedBox(width: 4),
                        const Text(
                          'TRANSACTIONS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      txnText,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
              ),
              _buildDivider(),
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.track_changes_rounded, size: 14, color: Colors.orange.shade400),
                        const SizedBox(width: 4),
                        const Text(
                          'PROJECTED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      projectedText,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 30,
      width: 1,
      color: Colors.grey.shade100,
    );
  }
}

/// Renders the Salary Insights card (Received, Remaining, and linear spending progress bar)
class StatsSalaryInsights extends StatelessWidget {
  const StatsSalaryInsights({
    super.key,
    required this.snapshot,
    required this.currencyFormat,
    required this.privacyModeEnabled,
  });

  final AnalyticsSnapshot snapshot;
  final NumberFormat currencyFormat;
  final bool privacyModeEnabled;

  @override
  Widget build(BuildContext context) {
    final double receivedAmount = snapshot.monthIncomeTotal;
    final double remainingAmount = snapshot.monthNetTotal;
    final double progress = receivedAmount > 0
        ? (snapshot.monthExpenseTotal / receivedAmount).clamp(0.0, 1.0)
        : 0.0;

    final receivedText = maskAmount(
      currencyFormat.format(receivedAmount),
      masked: privacyModeEnabled,
    );
    final remainingText = maskAmount(
      currencyFormat.format(remainingAmount.clamp(0.0, double.infinity)),
      masked: privacyModeEnabled,
    );
    final percentageText = '${(progress * 100).round()}%';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            spreadRadius: 1,
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
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: AppColors.success,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Salary / Income Insights',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'RECEIVED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        receivedText,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'REMAINING',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        remainingText,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Spending Progress',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                percentageText,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.grey.shade100,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders the daily line chart trend showing spending over time
class SpendingTrendCard extends StatefulWidget {
  const SpendingTrendCard({
    super.key,
    required this.snapshot,
    required this.currencyFormat,
    required this.privacyModeEnabled,
  });

  final AnalyticsSnapshot snapshot;
  final NumberFormat currencyFormat;
  final bool privacyModeEnabled;

  @override
  State<SpendingTrendCard> createState() => _SpendingTrendCardState();
}

class _SpendingTrendCardState extends State<SpendingTrendCard> {
  String _selectedType = 'Expense';

  @override
  Widget build(BuildContext context) {
    final hasData = widget.snapshot.monthlyTrend.isNotEmpty;
    final maxValue = widget.snapshot.monthlyTrend.fold<double>(
      0,
      (current, point) {
        double val = 0;
        if (_selectedType == 'Expense') {
          val = point.expense;
        } else if (_selectedType == 'Income') {
          val = point.income;
        } else {
          val = point.expense > point.income ? point.expense : point.income;
        }
        return val > current ? val : current;
      },
    );
    final axisMax = _niceAxisMax(maxValue);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            spreadRadius: 1,
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
                'Spending Trend',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200, width: 1),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedType,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryBlue,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Expense', child: Text('Expense')),
                      DropdownMenuItem(value: 'Income', child: Text('Income')),
                      DropdownMenuItem(value: 'Both', child: Text('Both')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedType = val);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: !hasData || maxValue <= 0
                ? const _ChartEmptyState(
                    message: 'Add transactions to see your spending trend.',
                  )
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: axisMax > 0 ? axisMax / 4 : 1.0,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: Colors.grey.shade100,
                          strokeWidth: 1,
                          dashArray: const [4, 4],
                        ),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(),
                        rightTitles: const AxisTitles(),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: !widget.privacyModeEnabled,
                            reservedSize: 40,
                            interval: axisMax > 0 ? axisMax / 4 : 1.0,
                            getTitlesWidget: (value, _) {
                              if (value == 0) return const SizedBox();
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Text(
                                  _compactCurrency(value, widget.currencyFormat),
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey.shade400,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 22,
                            interval: (widget.snapshot.monthlyTrend.length / 4).clamp(1.0, double.infinity),
                            getTitlesWidget: (value, _) {
                              final index = value.toInt();
                              if (index < 0 || index >= widget.snapshot.monthlyTrend.length) {
                                return const SizedBox();
                              }
                              final date = widget.snapshot.monthlyTrend[index].month;
                              return Text(
                                DateFormat('d MMM').format(date),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade400,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (_) => Colors.black.withValues(alpha: 0.8),
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((spot) {
                              final index = spot.x.toInt();
                              final point = widget.snapshot.monthlyTrend[index];
                              final dateStr = DateFormat('d MMMM').format(point.month);
                              final valStr = widget.currencyFormat.format(spot.y);
                              return LineTooltipItem(
                                '$dateStr\n$valStr',
                                const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ),
                      lineBarsData: [
                        if (_selectedType == 'Expense' || _selectedType == 'Both')
                          LineChartBarData(
                            spots: List.generate(
                              widget.snapshot.monthlyTrend.length,
                              (i) => FlSpot(i.toDouble(), widget.snapshot.monthlyTrend[i].expense),
                            ),
                            isCurved: true,
                            barWidth: 3,
                            color: AppColors.danger,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.danger.withValues(alpha: 0.2),
                                  AppColors.danger.withValues(alpha: 0.0),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        if (_selectedType == 'Income' || _selectedType == 'Both')
                          LineChartBarData(
                            spots: List.generate(
                              widget.snapshot.monthlyTrend.length,
                              (i) => FlSpot(i.toDouble(), widget.snapshot.monthlyTrend[i].income),
                            ),
                            isCurved: true,
                            barWidth: 3,
                            color: AppColors.success,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.success.withValues(alpha: 0.2),
                                  AppColors.success.withValues(alpha: 0.0),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_selectedType == 'Expense' || _selectedType == 'Both') ...[
                const _LegendChip(label: 'Expense', color: AppColors.danger),
                const SizedBox(width: 12),
              ],
              if (_selectedType == 'Income' || _selectedType == 'Both')
                const _LegendChip(label: 'Income', color: AppColors.success),
            ],
          ),
        ],
      ),
    );
  }
}

/// Donut chart breakdown analysis with interactive Category percentages
class StatsBreakdownAnalysis extends StatefulWidget {
  const StatsBreakdownAnalysis({
    super.key,
    required this.snapshot,
    required this.currencyFormat,
    required this.privacyModeEnabled,
  });

  final AnalyticsSnapshot snapshot;
  final NumberFormat currencyFormat;
  final bool privacyModeEnabled;

  @override
  State<StatsBreakdownAnalysis> createState() => _StatsBreakdownAnalysisState();
}

class _StatsBreakdownAnalysisState extends State<StatsBreakdownAnalysis> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final mixData = widget.snapshot.expenseMix;
    final totalSpent = widget.snapshot.monthExpenseTotal;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            spreadRadius: 1,
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
                'Breakdown Analysis',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    _buildToggleButton(0, 'Categories'),
                    _buildToggleButton(1, 'Accounts'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (mixData.isEmpty || totalSpent <= 0)
            const SizedBox(
              height: 160,
              child: _ChartEmptyState(
                message: 'No breakdown data available for this period.',
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  flex: 4,
                  child: SizedBox(
                    height: 150,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        startDegreeOffset: -90,
                        sections: mixData.map((item) {
                          return PieChartSectionData(
                            color: item.color,
                            value: item.amount,
                            radius: 18,
                            showTitle: false,
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 6,
                  child: Column(
                    children: List.generate(mixData.take(5).length, (index) {
                      final item = mixData[index];
                      final pct = totalSpent > 0 ? (item.amount / totalSpent) * 100 : 0.0;
                      final amountText = maskAmount(
                        widget.currencyFormat.format(item.amount),
                        masked: widget.privacyModeEnabled,
                      );
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: item.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.label,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textDark,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${pct.toStringAsFixed(1)}%',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade400),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              amountText,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildToggleButton(int tabIndex, String label) {
    final active = _selectedTab == tabIndex;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = tabIndex),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? AppColors.primaryBlue : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Budget Utilization widget showing progress limits
class StatsBudgetUtilization extends StatelessWidget {
  const StatsBudgetUtilization({
    super.key,
    required this.snapshot,
    required this.categoryBudgets,
    required this.currencyFormat,
    required this.privacyModeEnabled,
  });

  final AnalyticsSnapshot snapshot;
  final Map<String, double> categoryBudgets;
  final NumberFormat currencyFormat;
  final bool privacyModeEnabled;

  @override
  Widget build(BuildContext context) {
    final list = <Widget>[];

    categoryBudgets.forEach((category, limit) {
      if (limit <= 0) return;
      final spent = snapshot.expenseMix.firstWhere(
        (mix) => mix.label == category,
        orElse: () => CategoryMixPoint(label: category, amount: 0.0, color: Colors.grey),
      ).amount;

      final pct = limit > 0 ? (spent / limit) * 100 : 0.0;
      final spentText = maskAmount(currencyFormat.format(spent), masked: privacyModeEnabled);
      final limitText = maskAmount(currencyFormat.format(limit), masked: privacyModeEnabled);
      final pctText = '${pct.round()}%';
      final color = pct > 90 ? AppColors.danger : (pct > 75 ? AppColors.warning : AppColors.success);

      list.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    category,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        '$spentText / $limitText',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        pctText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (spent / limit).clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: Colors.grey.shade100,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ],
          ),
        ),
      );
    });

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            spreadRadius: 1,
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
                'Budget Utilization',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              Text(
                'View All',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.blue.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No budgets set. Set monthly category limits in Categories screen.',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            Column(children: list),
        ],
      ),
    );
  }
}

/// Largest transactions list for quick period audits
class StatsTopTransactions extends StatelessWidget {
  const StatsTopTransactions({
    super.key,
    required this.snapshot,
    required this.accountsMap,
    required this.currencyFormat,
    required this.privacyModeEnabled,
    required this.onEdit,
    required this.onDelete,
  });

  final AnalyticsSnapshot snapshot;
  final Map<String, AccountModel> accountsMap;
  final NumberFormat currencyFormat;
  final bool privacyModeEnabled;
  final Function(ExpenseModel) onEdit;
  final Function(ExpenseModel) onDelete;

  @override
  Widget build(BuildContext context) {
    final expenses = snapshot.transactions.where((t) => t.type == TransactionType.expense).toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top Transactions',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 12),
          if (expenses.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No expense records found in this range.',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            Column(
              children: List.generate(expenses.take(3).length, (index) {
                final expense = expenses[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: TransactionCard(
                    expense: expense,
                    accountLabel: accountsMap[expense.accountId]?.name ?? 'Archived Account',
                    maskAmounts: privacyModeEnabled,
                    onEdit: () => onEdit(expense),
                    onDelete: () => onDelete(expense),
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }
}

