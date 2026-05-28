import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_colors.dart';

class HomeDateStrip extends StatefulWidget {
  const HomeDateStrip({
    super.key,
    required this.visibleDates,
    required this.selectedDate,
    required this.selectedTotalText,
    required this.transactionCount,
    required this.onDateSelected,
    required this.onPrevious,
    required this.onNext,
    required this.isOnToday,
    required this.onJumpToToday,
  });

  final List<DateTime> visibleDates;
  final DateTime selectedDate;
  final String selectedTotalText;
  final int transactionCount;
  final bool isOnToday;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onJumpToToday;

  @override
  State<HomeDateStrip> createState() => _HomeDateStripState();
}

class _HomeDateStripState extends State<HomeDateStrip> {
  late ScrollController _scrollController;
  late List<DateTime> _scrollableDates;
  bool _initialScrollDone = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollableDates = _buildScrollableDates();
  }

  @override
  void didUpdateWidget(HomeDateStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isSameDateList(oldWidget.visibleDates, widget.visibleDates)) {
      _scrollableDates = _buildScrollableDates();
      _initialScrollDone = false;
    }
    if (oldWidget.selectedDate != widget.selectedDate && _initialScrollDone) {
      _scrollToSelected();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialScrollDone) {
      _initialScrollDone = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSelected();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool _isSameDateList(List<DateTime> a, List<DateTime> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (!DateUtils.isSameDay(a[i], b[i])) return false;
    }
    return true;
  }

  List<DateTime> _buildScrollableDates() {
    final start = widget.visibleDates.first;
    final end = widget.visibleDates.last;
    final expandedStart = start.subtract(const Duration(days: 7));
    final expandedEnd = end.add(const Duration(days: 7));
    final days = expandedEnd.difference(expandedStart).inDays;
    return List<DateTime>.generate(
      days + 1,
      (i) => expandedStart.add(Duration(days: i)),
    );
  }

  void _scrollToSelected() {
    if (!_scrollController.hasClients) return;
    final index = _scrollableDates.indexWhere(
      (d) => DateUtils.isSameDay(d, widget.selectedDate),
    );
    if (index == -1) return;
    final itemWidth = 50.0;
    final viewportWidth = _scrollController.position.viewportDimension;
    final targetOffset = (index * itemWidth) - (viewportWidth / 2) + (itemWidth / 2);
    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final monthFormat = DateFormat('MMM yyyy');
    final weekdayFormat = DateFormat('E');

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
          Row(
            children: <Widget>[
              Text(
                monthFormat.format(widget.selectedDate),
                style: const TextStyle(
                  color: AppColors.textDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              if (!widget.isOnToday)
                GestureDetector(
                  onTap: widget.onJumpToToday,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.1),
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
              const SizedBox(width: 4),
              _NavArrow(
                icon: Icons.arrow_back_rounded,
                onTap: widget.onPrevious,
              ),
              const SizedBox(width: 4),
              _NavArrow(
                icon: Icons.arrow_forward_rounded,
                onTap: widget.onNext,
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 52,
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              itemCount: _scrollableDates.length,
              itemBuilder: (context, index) {
                final date = _scrollableDates[index];
                final isSelected = DateUtils.isSameDay(date, widget.selectedDate);
                final isToday = DateUtils.isSameDay(date, DateTime.now());
                return GestureDetector(
                  onTap: () => widget.onDateSelected(date),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 46,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? AppColors.accentLime
                          : Colors.transparent,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          weekdayFormat.format(date).substring(0, 1).toUpperCase(),
                          style: TextStyle(
                            color: isSelected
                                ? AppColors.accentLimeDark
                                : AppColors.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          date.day.toString(),
                          style: TextStyle(
                            color: isSelected
                                ? AppColors.accentLimeDark
                                : isToday
                                    ? AppColors.primaryBlue
                                    : AppColors.textDark,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '${widget.transactionCount} txn${widget.transactionCount == 1 ? '' : 's'}',
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
                    widget.selectedTotalText,
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

class _NavArrow extends StatelessWidget {
  const _NavArrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 18, color: AppColors.textMuted),
        ),
      ),
    );
  }
}
