import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';

/// Universal Circular Close ('✕') Button adhering to the Expensio design language.
/// Designed as a companion to [AppBackButton], featuring a circular background,
/// soft border, subtle shadow, and light tactile haptic feedback on tap.
class AppCloseButton extends StatelessWidget {
  const AppCloseButton({
    super.key,
    this.onPressed,
    this.backgroundColor = Colors.white,
    this.iconColor = AppColors.textDark,
    this.size = 36.0,
    this.iconSize = 16.0,
    this.tooltip = 'Close',
  });

  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color iconColor;
  final double size;
  final double iconSize;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () {
              HapticFeedback.lightImpact();
              if (onPressed != null) {
                onPressed!();
              } else {
                Navigator.of(context).maybePop();
              }
            },
            child: Ink(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: backgroundColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFF1F5F9),
                  width: 1.0,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0E000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  Icons.close_rounded,
                  size: iconSize,
                  color: iconColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
