import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import 'app_close_button.dart';

/// Shows a standardized Expensio Modal Bottom Sheet adhering to the design language.
/// Includes top rounded corners, soft backdrop scrim, top drag handle, and right close button.
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required Widget child,
  String? title,
  String? subtitle,
  Widget? trailingAction,
  bool isDismissible = true,
  bool enableDrag = true,
  bool isScrollControlled = true,
  double? maxHeightFraction,
}) {
  HapticFeedback.lightImpact();
  return showModalBottomSheet<T>(
    context: context,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x55000000),
    builder: (modalContext) => AppBottomSheetContainer(
      title: title,
      subtitle: subtitle,
      trailingAction: trailingAction,
      maxHeightFraction: maxHeightFraction ?? 0.85,
      child: child,
    ),
  );
}

/// Standardized container for modal bottom sheets.
class AppBottomSheetContainer extends StatelessWidget {
  const AppBottomSheetContainer({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.trailingAction,
    this.maxHeightFraction = 0.85,
    this.contentPadding = const EdgeInsets.fromLTRB(20, 8, 20, 24),
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final Widget? trailingAction;
  final double maxHeightFraction;
  final EdgeInsetsGeometry contentPadding;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final maxHeight = mediaQuery.size.height * maxHeightFraction;

    return AnimatedPadding(
      padding: mediaQuery.viewInsets,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Color(0x1A09386D),
              blurRadius: 30,
              offset: Offset(0, -6),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Drag Handle Pill ───────────────────────────────────────────
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Top Title & Actions Bar ────────────────────────────────────
              if (title != null || trailingAction != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (title != null)
                              Text(
                                title!,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textDark,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            if (subtitle != null && subtitle!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                subtitle!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (trailingAction != null) ...[
                        trailingAction!,
                        const SizedBox(width: 8),
                      ],
                      const AppCloseButton(),
                    ],
                  ),
                ),

              if (title != null)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFFF1F5F9),
                  ),
                ),

              // ── Content ───────────────────────────────────────────────────
              Flexible(
                child: Padding(
                  padding: contentPadding,
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
