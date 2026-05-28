import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../data/models/expense_model.dart';

extension TransactionTypeX on TransactionType {
  bool get isIncome => this == TransactionType.income;
  bool get isTransfer => this == TransactionType.transfer;
}

class AddExpenseTopButton extends StatelessWidget {
  const AddExpenseTopButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.color = AppColors.textMuted,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF5F7FB),
      shape: const CircleBorder(),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: color),
          ),
        ),
      ),
    );
  }
}

class AddExpenseModeTab extends StatelessWidget {
  const AddExpenseModeTab({
    super.key,
    required this.label,
    required this.icon,
    required this.activeColor,
    required this.inactiveColor,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color activeColor;
  final Color inactiveColor;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Center(
            child: SizedBox(
              height: 18,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeOutCubic,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(scale: animation, child: child),
                  );
                },
                child: isSelected
                    ? Text(
                        label,
                        key: ValueKey<String>(label),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: activeColor,
            fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      )
                    : Icon(
                        icon,
                        key: ValueKey<IconData>(icon),
                        size: 18,
                        color: inactiveColor,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AddExpenseInfoCapsule extends StatelessWidget {
  const AddExpenseInfoCapsule({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.centerContent = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool centerContent;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF7F8FB),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            mainAxisAlignment: centerContent
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: <Widget>[
              Icon(icon, size: 18, color: AppColors.textMuted),
              const SizedBox(width: 10),
              if (centerContent)
                Text(
                  label,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w700,
                  ),
                )
              else
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w700,
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

class AddExpenseSelectionCapsule extends StatelessWidget {
  const AddExpenseSelectionCapsule({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.background,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final Color background;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: iconColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              if (onTap != null) ...<Widget>[
                const SizedBox(width: 8),
                Icon(
                  Icons.expand_more_rounded,
                  color: iconColor.withValues(alpha: 0.78),
                  size: 18,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class AddExpenseKeypadButton extends StatelessWidget {
  const AddExpenseKeypadButton({
    super.key,
    required this.onTap,
    required this.child,
    this.backgroundColor = Colors.white,
    this.foregroundColor = AppColors.textDark,
    this.isEnabled = true,
  });

  final VoidCallback? onTap;
  final Widget child;
  final Color backgroundColor;
  final Color foregroundColor;
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    final resolvedForeground =
        isEnabled ? foregroundColor : foregroundColor.withValues(alpha: 0.34);
    final resolvedBackground =
        isEnabled ? backgroundColor : backgroundColor.withValues(alpha: 0.45);

    return Material(
      color: resolvedBackground,
      borderRadius: BorderRadius.circular(26),
      shadowColor: AppColors.cardShadow,
      elevation: isEnabled ? 2 : 0,
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        borderRadius: BorderRadius.circular(26),
        child: DefaultTextStyle(
          style: TextStyle(
            color: resolvedForeground,
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
          child: IconTheme(
            data: IconThemeData(color: resolvedForeground, size: 28),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
