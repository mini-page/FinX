import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';

class PowerFab extends StatelessWidget {
  const PowerFab({
    super.key,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.onQuickAdd,
  });

  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onQuickAdd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (onTap != null) {
          onTap!();
        } else {
          onQuickAdd?.call();
        }
      },
      onDoubleTap: onDoubleTap != null
          ? () {
              HapticFeedback.mediumImpact();
              onDoubleTap!();
            }
          : null,
      onLongPress: onLongPress != null
          ? () {
              HapticFeedback.heavyImpact();
              onLongPress!();
            }
          : null,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.primaryBlue,
          shape: BoxShape.circle,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.primaryBlue.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.add_rounded,
          color: Colors.white,
          size: 32,
        ),
      ),
    );
  }
}
