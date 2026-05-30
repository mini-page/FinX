import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';

/// A consistent sticky page header used across all main screens.
///
/// Structure (top → bottom):
///   • Safe-area top padding
///   • [eyebrow]  — 12sp uppercase blue label (e.g. "ANALYTICS")
///   • Title row  — [title] (28sp bold) + optional [trailing] widget
///   • [subtitle] — optional secondary label below the title row
///   • [bottom]   — optional pinned widget (tab bar, pill switch, etc.)
///
/// The header has a white background with a subtle bottom shadow so it
/// visually separates from the scrollable content below it.
class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.trailing,
    this.bottom,
  });

  /// Short uppercase label rendered above the title (e.g. "ANALYTICS").
  final String eyebrow;

  /// Main title text. Can be dynamic (e.g. a formatted currency amount).
  final String title;

  /// Optional secondary label rendered below the title row.
  final String? subtitle;

  /// Optional widget pinned to the right of the title row (icon buttons, etc.).
  final Widget? trailing;

  /// Optional widget rendered below the title section (tab bar, pill switch, etc.).
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          topPadding + AppSpacing.md,
          AppSpacing.lg,
          bottom != null ? AppSpacing.sm : AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Eyebrow
            Text(
              eyebrow.toUpperCase(),
              style: const TextStyle(
                color: AppColors.primaryBlue,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.8,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),

            // Title row
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
                ),
                if (trailing != null) ...<Widget>[
                  const SizedBox(width: AppSpacing.sm),
                  trailing!,
                ],
              ],
            ),

            // Subtitle
            if (subtitle != null) ...<Widget>[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],

            // Bottom slot (tab bar, pill switch, etc.)
            if (bottom != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              bottom!,
              const SizedBox(height: AppSpacing.xs),
            ],
          ],
        ),
      ),
    );
  }
}

class GradientAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GradientAppBar({
    super.key,
    required this.title,
    this.showBackButton = true,
    this.actions,
    this.bottom,
  });

  final dynamic title; // Can be String or Widget
  final bool showBackButton;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0.0),
      );

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFEDE9FE), // Soft Lavender/Purple
              Color(0xFFFAF5FF), // Lighter Purple
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ),
      leading: showBackButton
          ? Center(
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.chevron_left_rounded,
                    color: AppColors.textDark,
                    size: 22,
                  ),
                ),
              ),
            )
          : null,
      title: title is Widget
          ? title as Widget
          : Text(
              title as String,
              style: const TextStyle(
                color: AppColors.textDark,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
      actions: actions,
      bottom: bottom,
    );
  }
}

