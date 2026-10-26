import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'app_back_button.dart';
import 'app_search_bar.dart';

/// Embedded Icon-Only Split Capsule for Filter and Sort inside/alongside Search Bar
class FilterSortIconCapsule extends StatelessWidget {
  const FilterSortIconCapsule({
    super.key,
    this.sortIcon = Icons.swap_vert_rounded,
    this.isFilterActive = false,
    this.onFilterTap,
    this.onSortTap,
  });

  final IconData sortIcon;
  final bool isFilterActive;
  final VoidCallback? onFilterTap;
  final VoidCallback? onSortTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9D5FF), width: 1.1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Filter Icon
          if (onFilterTap != null)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onFilterTap,
                borderRadius: BorderRadius.horizontal(
                  left: const Radius.circular(16),
                  right: onSortTap == null ? const Radius.circular(16) : Radius.zero,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        Icons.tune_rounded,
                        size: 16,
                        color: isFilterActive ? AppColors.accentPink : AppColors.accentPurple,
                      ),
                      if (isFilterActive)
                        Positioned(
                          top: -2,
                          right: -2,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.accentPink,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

          if (onFilterTap != null && onSortTap != null)
            Container(
              width: 1,
              height: 14,
              color: const Color(0xFFE2E8F0),
            ),

          // Sort Icon
          if (onSortTap != null)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onSortTap,
                borderRadius: BorderRadius.horizontal(
                  left: onFilterTap == null ? const Radius.circular(16) : Radius.zero,
                  right: const Radius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Icon(
                    sortIcon,
                    size: 16,
                    color: AppColors.accentPink,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Backward compatibility Split Capsule for Filter and Sort options with text labels
class FilterSortSplitCapsule extends StatelessWidget {
  const FilterSortSplitCapsule({
    super.key,
    this.filterLabel = 'Filter',
    this.sortLabel = 'Sort',
    this.isFilterActive = false,
    this.onFilterTap,
    this.onSortTap,
  });

  final String filterLabel;
  final String sortLabel;
  final bool isFilterActive;
  final VoidCallback? onFilterTap;
  final VoidCallback? onSortTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE9D5FF), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C8B5CF6),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Filter Option
          InkWell(
            onTap: onFilterTap,
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 14,
                    color: isFilterActive ? AppColors.accentPink : AppColors.accentPurple,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    filterLabel,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: isFilterActive ? AppColors.accentPinkDark : AppColors.textDark,
                    ),
                  ),
                  if (isFilterActive) ...[
                    const SizedBox(width: 4),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.accentPink,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Divider
          Container(
            width: 1,
            height: 16,
            color: const Color(0xFFE2E8F0),
          ),

          // Sort Option
          InkWell(
            onTap: onSortTap,
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.swap_vert_rounded,
                    size: 15,
                    color: AppColors.accentPink,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    sortLabel,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Universal Top Bar adhering to Expensio design principles
class UniversalTopBar extends StatelessWidget {
  const UniversalTopBar({
    super.key,
    required this.title,
    this.showBackButton,
    this.onBackPressed,
    this.isSearchOpen = false,
    this.onSearchToggle,
    this.showSearchToggle,
    this.alwaysShowSearch,
    this.itemCount,
    this.searchController,
    this.searchHint = 'Search...',
    this.onSearchChanged,
    this.onSearchClear,
    this.actions,
    this.filterLabel,
    this.sortLabel,
    this.sortIcon,
    this.isFilterActive = false,
    this.onFilterTap,
    this.onSortTap,
    this.customFilterBar,
    this.trailingInSearchBar,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 16, 12),
  });

  final String title;
  final bool? showBackButton;
  final VoidCallback? onBackPressed;

  final bool isSearchOpen;
  final ValueChanged<bool>? onSearchToggle;
  final bool? showSearchToggle;
  final bool? alwaysShowSearch;
  final int? itemCount;

  final TextEditingController? searchController;
  final String searchHint;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onSearchClear;

  final List<Widget>? actions;

  // Split Capsule options
  final String? filterLabel;
  final String? sortLabel;
  final IconData? sortIcon;
  final bool isFilterActive;
  final VoidCallback? onFilterTap;
  final VoidCallback? onSortTap;

  final Widget? customFilterBar;
  final Widget? trailingInSearchBar;
  final EdgeInsetsGeometry padding;

  bool _shouldShowSearch(BuildContext context) {
    if (alwaysShowSearch != null) return alwaysShowSearch!;
    if (showSearchToggle != null) return showSearchToggle!;
    if (itemCount != null) return itemCount! > 10;
    return onSearchToggle != null;
  }

  @override
  Widget build(BuildContext context) {
    final canPop = showBackButton ?? Navigator.of(context).canPop();
    final shouldShowSearch = _shouldShowSearch(context);
    final hasCapsule = onFilterTap != null || onSortTap != null;

    final Widget? searchTrailing = trailingInSearchBar ??
        (hasCapsule
            ? FilterSortIconCapsule(
                sortIcon: sortIcon ?? Icons.swap_vert_rounded,
                isFilterActive: isFilterActive,
                onFilterTap: onFilterTap,
                onSortTap: onSortTap,
              )
            : null);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Main Top Bar Row
        Padding(
          padding: padding,
          child: Row(
            children: [
              // Universal Circular Back Button with white background and '<'
              if (canPop) ...[
                AppBackButton(onPressed: onBackPressed),
                const SizedBox(width: 14),
              ],

              // Left-Aligned Title
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark,
                    letterSpacing: -0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Right-Aligned Actions & Search Toggle
              if (actions != null) ...actions!,

              if (shouldShowSearch && onSearchToggle != null) ...[
                const SizedBox(width: 8),
                Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () => onSearchToggle!(!isSearchOpen),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: isSearchOpen
                            ? AppColors.accentPurple.withValues(alpha: 0.12)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSearchOpen
                              ? AppColors.accentPurple.withValues(alpha: 0.3)
                              : const Color(0xFFF1F5F9),
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
                          isSearchOpen ? Icons.close_rounded : Icons.search_rounded,
                          size: 19,
                          color: isSearchOpen ? AppColors.accentPurple : AppColors.textDark,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // Expandable Smooth Search Area
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeInOutCubic,
          alignment: Alignment.topCenter,
          child: isSearchOpen
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: isSearchOpen ? 1.0 : 0.0,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppSearchBar(
                          controller: searchController,
                          hintText: searchHint,
                          onChanged: onSearchChanged,
                          onClear: onSearchClear,
                          trailing: searchTrailing,
                        ),
                        if (customFilterBar != null) ...[
                          const SizedBox(height: 10),
                          customFilterBar!,
                        ],
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// Universal Expensio Scaffold providing standard lavender/pink background gradient
class UniversalScreenScaffold extends StatelessWidget {
  const UniversalScreenScaffold({
    super.key,
    required this.topBar,
    required this.body,
    this.floatingActionButton,
    this.bottomNavigationBar,
  });

  final UniversalTopBar topBar;
  final Widget body;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      backgroundColor: AppColors.backgroundLight,
      body: Stack(
        children: [
          // Background Gradient matching Finance Tools
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFEDE9FE), // Soft Lavender
                    Color(0xFFFCE7F3), // Soft Pink
                    AppColors.backgroundLight,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.28, 0.65],
                ),
              ),
            ),
          ),

          // Content Area with SafeArea
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                topBar,
                Expanded(child: body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
