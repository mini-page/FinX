import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Universal Circular Back Button adhering to the Expensio design language.
/// Features a circular white background with a soft shadow and centered '<' icon.
class AppBackButton extends StatelessWidget {
  const AppBackButton({
    super.key,
    this.onPressed,
    this.backgroundColor = Colors.white,
    this.iconColor = AppColors.textDark,
    this.size = 38.0,
    this.iconSize = 16.0,
    this.tooltip = 'Back',
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
            onTap: onPressed ?? () => Navigator.of(context).maybePop(),
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
                  Icons.arrow_back_ios_new_rounded,
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
