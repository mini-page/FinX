import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_tokens.dart';
import '../../../../../shared/widgets/app_toggle_switch.dart';

class CategoryGridCard extends StatelessWidget {
  const CategoryGridCard({
    super.key,
    required this.title,
    required this.icon,
    required this.tone,
    required this.amount,
    required this.progress,
    required this.isEnabled,
    required this.onToggle,
    this.onTap,
    this.progressLabel,
    this.amountColor,
  });

  final String title;
  final IconData icon;
  final Color tone;
  final String amount;
  final String? progressLabel;
  final double progress;
  final bool isEnabled;
  final VoidCallback? onTap;
  final ValueChanged<bool> onToggle;
  final Color? amountColor;

  @override
  Widget build(BuildContext context) {
    final resolvedAmountColor = amountColor ?? AppColors.textDark;
    final resolvedProgressColor = isEnabled ? tone : AppColors.disabledContent;
    final radius = BorderRadius.circular(AppRadii.lg);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: isEnabled ? 1 : 0.6,
      child: Material(
        color: Colors.white,
        borderRadius: radius,
        shadowColor: AppColors.cardShadow,
        elevation: 2,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    _IconBadge(icon: icon, tone: tone, enabled: isEnabled),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    AppToggleSwitch(
                      value: isEnabled,
                      activeColor: AppColors.primaryBlue,
                      onChanged: onToggle,
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  amount,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: resolvedAmountColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
                if (progressLabel != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    progressLabel!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xs),
                _ProgressBar(value: progress, color: resolvedProgressColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AddCategoryCard extends StatelessWidget {
  const AddCategoryCard({
    super.key,
    required this.onTap,
    required this.title,
    required this.detail,
  });

  final VoidCallback onTap;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      shadowColor: AppColors.cardShadow,
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.lightBlueBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: AppColors.primaryBlue,
                  size: 22,
                ),
              ),
              const Spacer(),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textDark,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                detail,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CategoryListCard extends StatelessWidget {
  const CategoryListCard({
    super.key,
    required this.title,
    required this.icon,
    required this.tone,
    required this.amount,
    required this.progress,
    required this.isEnabled,
    required this.onToggle,
    this.onTap,
    this.progressLabel,
    this.amountColor,
    this.subcategories = const <String>[],
    this.onAddSubcategory,
    this.onRemoveSubcategory,
  });

  final String title;
  final IconData icon;
  final Color tone;
  final String amount;
  final String? progressLabel;
  final double progress;
  final bool isEnabled;
  final VoidCallback? onTap;
  final ValueChanged<bool> onToggle;
  final Color? amountColor;
  final List<String> subcategories;
  final void Function(String)? onAddSubcategory;
  final void Function(String)? onRemoveSubcategory;

  void _showAddSubcategoryDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Add Subcategory to $title', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'e.g. breakfast, train, coffee',
            isDense: true,
          ),
          autofocus: true,
          textInputAction: TextInputAction.done,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final val = controller.text.trim();
              if (val.isNotEmpty) {
                onAddSubcategory?.call(val);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, String sub) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Subcategory', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        content: Text('Are you sure you want to delete subcategory "$sub"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              onRemoveSubcategory?.call(sub);
              Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resolvedAmountColor = amountColor ?? AppColors.textDark;
    final resolvedProgressColor = isEnabled ? tone : AppColors.disabledContent;
    final radius = BorderRadius.circular(AppRadii.lg);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: isEnabled ? 1 : 0.6,
      child: Material(
        color: Colors.white,
        borderRadius: radius,
        shadowColor: AppColors.cardShadow,
        elevation: 2,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: <Widget>[
                    _IconBadge(icon: icon, tone: tone, enabled: isEnabled),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textDark,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                          if (progressLabel != null) ...<Widget>[
                            const SizedBox(height: 3),
                            Text(
                              progressLabel!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.xs),
                          _ProgressBar(
                              value: progress, color: resolvedProgressColor),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          amount,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: resolvedAmountColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            height: 1,
                            fontFeatures: const <FontFeature>[
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        AppToggleSwitch(
                          value: isEnabled,
                          activeColor: AppColors.primaryBlue,
                          onChanged: onToggle,
                        ),
                      ],
                    ),
                  ],
                ),
                if (isEnabled && (subcategories.isNotEmpty || onAddSubcategory != null)) ...[
                  const SizedBox(height: AppSpacing.xs),
                  const Divider(color: Color(0xFFF1F5F9), height: 1, thickness: 1),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: subcategories.length + (onAddSubcategory != null ? 1 : 0),
                      itemBuilder: (context, index) {
                        final showAdd = onAddSubcategory != null;

                        if (showAdd && index == 0) {
                          // The + Add chip (first place always)
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ActionChip(
                              label: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add_rounded, size: 14, color: AppColors.primaryBlue),
                                  SizedBox(width: 4),
                                  Text(
                                    'Add',
                                    style: TextStyle(
                                      color: AppColors.primaryBlue,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                              backgroundColor: AppColors.lightBlueBg,
                              side: BorderSide.none,
                              shape: const StadiumBorder(),
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              onPressed: () => _showAddSubcategoryDialog(context),
                            ),
                          );
                        }

                        final subIndex = showAdd ? index - 1 : index;
                        final sub = subcategories[subIndex];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: GestureDetector(
                            onLongPress: onRemoveSubcategory != null ? () {
                              _showDeleteConfirm(context, sub);
                            } : null,
                            child: Chip(
                              label: Text(sub),
                              labelStyle: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                              backgroundColor: const Color(0xFFF1F5F9),
                              side: BorderSide.none,
                              shape: const StadiumBorder(),
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AddCategoryListCard extends StatelessWidget {
  const AddCategoryListCard({
    super.key,
    required this.onTap,
    required this.title,
    required this.detail,
  });

  final VoidCallback onTap;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadii.lg);
    return Material(
      color: Colors.white,
      borderRadius: radius,
      shadowColor: AppColors.cardShadow,
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.lightBlueBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: AppColors.primaryBlue,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textDark,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CategoryGridData {
  const CategoryGridData({
    required this.title,
    required this.icon,
    required this.tone,
    required this.amount,
    required this.progress,
    required this.isEnabled,
    required this.onToggle,
    this.onTap,
    this.progressLabel,
    this.amountColor,
    this.subcategories = const <String>[],
  });

  final String title;
  final IconData icon;
  final Color tone;
  final double amount;
  final double progress;
  final bool isEnabled;
  final String? progressLabel;
  final VoidCallback? onTap;
  final ValueChanged<bool> onToggle;
  final Color? amountColor;
  final List<String> subcategories;
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({
    required this.icon,
    required this.tone,
    required this.enabled,
  });

  final IconData icon;
  final Color tone;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: (enabled ? tone : AppColors.textMuted).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        icon,
        color: enabled ? tone : AppColors.textMuted,
        size: 20,
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.value,
    required this.color,
  });

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 7,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Container(color: AppColors.backgroundLight),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: clamped,
              child: Container(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
