import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_tokens.dart';
import 'package:xpens/features/expense/data/models/expense_model.dart';
import 'package:xpens/features/expense/presentation/widgets/amount_visibility.dart';
import 'package:xpens/features/categories/presentation/widgets/expense_category.dart';

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
    final dayCounts = <int, int>{};
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
      dayCounts.update(localDate.day, (value) => value + 1, ifAbsent: () => 1);

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

    final sixMonthStart = DateTime(now.year, now.month - 5);
    final monthlyTrendMap = <String, _MutableTrendBucket>{};
    for (int index = 0; index < 6; index++) {
      final month = DateTime(sixMonthStart.year, sixMonthStart.month + index);
      monthlyTrendMap[_monthKey(month)] = _MutableTrendBucket(month: month);
    }

    for (final transaction in expenses) {
      final localDate = transaction.date.toLocal();
      final month = DateTime(localDate.year, localDate.month);
      final bucket = monthlyTrendMap[_monthKey(month)];
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

    int busiestDay = 0;
    int busiestDayCount = 0;
    dayCounts.forEach((day, count) {
      if (count > busiestDayCount) {
        busiestDay = day;
        busiestDayCount = count;
      }
    });

    final busiestDayLabel = busiestDay == 0
        ? 'No activity yet'
        : DateFormat('d MMM').format(
            DateTime(range.start.year, range.start.month, busiestDay),
          );

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
      monthlyTrend: monthlyTrendMap.values
          .map((bucket) => bucket.toImmutable())
          .toList(growable: false),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Legend
        const Row(
          children: <Widget>[
            _LegendChip(label: 'Expense', color: AppColors.danger),
            SizedBox(width: AppSpacing.sm),
            _LegendChip(label: 'Income', color: AppColors.success),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // Chart
        SizedBox(
          height: 260,
          child: maxValue <= 0
              ? const _ChartEmptyState(
                  message:
                      'Add transactions over time to reveal your cash-flow trend.',
                )
              : LineChart(
                  LineChartData(
                    minX: 0,
                    maxX: (snapshot.monthlyTrend.length - 1).toDouble(),
                    minY: 0,
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
                          reservedSize: 48,
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
                            return SideTitleWidget(
                              meta: meta,
                              child: Text(
                                DateFormat('MMM').format(
                                  snapshot.monthlyTrend[index].month,
                                ),
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    lineTouchData: const LineTouchData(
                      enabled: false,
                      handleBuiltInTouches: false,
                    ),
                    lineBarsData: <LineChartBarData>[
                      _curvedLine(
                        spots: snapshot.monthlyTrend
                            .asMap()
                            .entries
                            .map((entry) => FlSpot(
                                  entry.key.toDouble(),
                                  entry.value.expense,
                                ))
                            .toList(growable: false),
                        color: AppColors.danger,
                      ),
                      _curvedLine(
                        spots: snapshot.monthlyTrend
                            .asMap()
                            .entries
                            .map((entry) => FlSpot(
                                  entry.key.toDouble(),
                                  entry.value.income,
                                ))
                            .toList(growable: false),
                        color: AppColors.success,
                      ),
                    ],
                  ),
                  duration: const Duration(milliseconds: 280),
                ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Metrics grid
        _MetricGrid(
          children: <Widget>[
            AnalyticsMetricTile(
              label: 'Expense',
              value: expenseText,
              accent: AppColors.danger,
            ),
            AnalyticsMetricTile(
              label: 'Income',
              value: incomeText,
              accent: AppColors.success,
            ),
            AnalyticsMetricTile(
              label: 'Net',
              value: netText,
              accent: AppColors.primaryBlue,
            ),
            AnalyticsMetricTile(
              label: 'Savings',
              value: savingsText,
              accent: AppColors.accentMint,
              icon: Icons.trending_up_rounded,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // Insight
        AnalyticsInsightCard(text: _flowInsight(snapshot, currencyFormat)),
      ],
    );
  }

  static LineChartBarData _curvedLine({
    required List<FlSpot> spots,
    required Color color,
  }) {
    return LineChartBarData(
      isCurved: true,
      barWidth: 3.5,
      color: color,
      spots: spots,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            color.withValues(alpha: 0.18),
            color.withValues(alpha: 0.02),
          ],
        ),
      ),
    );
  }

  static String _flowInsight(
    AnalyticsSnapshot snapshot,
    NumberFormat currencyFormat,
  ) {
    if (!snapshot.hasTransactions) {
      return 'Start adding transactions to see flow insights here.';
    }
    final parts = <String>[];
    if (snapshot.monthNetTotal >= 0) {
      parts.add(
        'Net positive by ${currencyFormat.format(snapshot.monthNetTotal.abs())} this month.',
      );
    } else {
      parts.add(
        'Net negative by ${currencyFormat.format(snapshot.monthNetTotal.abs())} this month.',
      );
    }
    if (snapshot.savingsRate > 0) {
      parts.add(
        'Saving ${(snapshot.savingsRate * 100).round()}% of your income.',
      );
    }
    return parts.join('\n');
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

    final avgText = maskAmount(
      currencyFormat.format(snapshot.averageExpenseTransaction),
      masked: privacyModeEnabled,
    );
    final largestText = maskAmount(
      snapshot.largestExpense != null
          ? currencyFormat.format(snapshot.largestExpense!.amount)
          : '—',
      masked: privacyModeEnabled,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Chart + legend
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
        const SizedBox(height: AppSpacing.lg),

        // Metrics grid
        _MetricGrid(
          children: <Widget>[
            AnalyticsMetricTile(
              label: 'Top Category',
              value: snapshot.topExpenseCategory,
              accent: AppColors.danger,
              icon: Icons.category_outlined,
            ),
            AnalyticsMetricTile(
              label: 'Avg / Txn',
              value: avgText,
              accent: AppColors.primaryBlue,
            ),
            AnalyticsMetricTile(
              label: 'Transactions',
              value: '${snapshot.transactionCount}',
              accent: AppColors.textSecondary,
              icon: Icons.receipt_long_outlined,
            ),
            AnalyticsMetricTile(
              label: 'Largest',
              value: largestText,
              accent: AppColors.warning,
              icon: Icons.arrow_upward_rounded,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // Insight
        AnalyticsInsightCard(text: _spendInsight(snapshot, currencyFormat)),
      ],
    );
  }

  static String _spendInsight(
    AnalyticsSnapshot snapshot,
    NumberFormat currencyFormat,
  ) {
    if (snapshot.expenseMix.isEmpty) {
      return 'Start adding expenses to get spend insights.';
    }
    final topCategory = snapshot.topExpenseCategory;
    final topAmount = currencyFormat.format(snapshot.topExpenseCategoryAmount);
    final share = snapshot.monthExpenseTotal <= 0
        ? 0
        : ((snapshot.topExpenseCategoryAmount / snapshot.monthExpenseTotal) *
                100)
            .round();
    return 'Top spend: $topCategory at $topAmount — $share% of total expenses.';
  }
}

/// Habit tab: weekday bar chart + metrics + insight.
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

    final largestExpenseText = maskAmount(
      snapshot.largestExpense != null
          ? currencyFormat.format(snapshot.largestExpense!.amount)
          : '—',
      masked: privacyModeEnabled,
    );
    final largestIncomeText = maskAmount(
      snapshot.largestIncome != null
          ? currencyFormat.format(snapshot.largestIncome!.amount)
          : '—',
      masked: privacyModeEnabled,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
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
        const SizedBox(height: AppSpacing.lg),

        // Metrics grid
        _MetricGrid(
          children: <Widget>[
            AnalyticsMetricTile(
              label: 'Busiest Day',
              value: snapshot.busiestDayLabel,
              accent: AppColors.danger,
              icon: Icons.local_fire_department_rounded,
            ),
            AnalyticsMetricTile(
              label: 'Active Days',
              value: '${snapshot.activeDays}',
              accent: AppColors.primaryBlue,
              icon: Icons.calendar_today_rounded,
            ),
            AnalyticsMetricTile(
              label: 'Top Expense',
              value: largestExpenseText,
              accent: AppColors.warning,
              icon: Icons.arrow_upward_rounded,
            ),
            AnalyticsMetricTile(
              label: 'Top Income',
              value: largestIncomeText,
              accent: AppColors.success,
              icon: Icons.arrow_downward_rounded,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // Insight
        AnalyticsInsightCard(text: _habitInsight(snapshot)),
      ],
    );
  }

  static String _habitInsight(AnalyticsSnapshot snapshot) {
    if (!snapshot.hasTransactions) {
      return 'Start tracking your spending to discover daily patterns.';
    }
    final parts = <String>[];
    if (snapshot.busiestDayCount > 0) {
      parts.add(
        'Your busiest day was ${snapshot.busiestDayLabel} with ${snapshot.busiestDayCount} transactions.',
      );
    }
    if (snapshot.activeDays > 0) {
      parts.add(
        'You logged activity on ${snapshot.activeDays} days this month.',
      );
    }
    return parts.isEmpty
        ? 'Keep tracking to uncover spending habits.'
        : parts.join('\n');
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
