import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import 'app_search_bar.dart';

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------

/// A single selectable item shown inside a filter/choice bottom sheet.
class FilterSheetItem<T> {
  const FilterSheetItem({
    required this.value,
    required this.label,
    this.icon,
    this.iconColor,
  });

  final T value;
  final String label;
  final IconData? icon;

  /// Background tint for the leading icon container. Falls back to
  /// [AppColors.lightBlueBg] when not supplied.
  final Color? iconColor;
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Shows a **single-select** modal bottom sheet with a soft scrim so the
/// background dims when the sheet opens.
///
/// Returns the selected value or `null` if the user dismisses the sheet.
Future<T?> showSingleSelectSheet<T>({
  required BuildContext context,
  required String title,
  required List<FilterSheetItem<T>> items,
  required T? selectedValue,
  bool searchable = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x55000000),
    builder: (_) => _SingleSelectSheet<T>(
      title: title,
      items: items,
      selectedValue: selectedValue,
      searchable: searchable,
    ),
  );
}

/// Shows a **multi-select** modal bottom sheet with a soft scrim.
///
/// Returns the updated set of selected values, or `null` if the user
/// dismisses the sheet without applying changes.
Future<Set<T>?> showMultiSelectSheet<T>({
  required BuildContext context,
  required String title,
  required List<FilterSheetItem<T>> items,
  required Set<T> selectedValues,
  bool searchable = false,
}) {
  return showModalBottomSheet<Set<T>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x55000000),
    builder: (_) => _MultiSelectSheet<T>(
      title: title,
      items: items,
      initialSelectedValues: selectedValues,
      searchable: searchable,
    ),
  );
}

// ---------------------------------------------------------------------------
// Internal sheet surface
// ---------------------------------------------------------------------------

/// White rounded surface shared by both sheet variants.
class _SheetSurface extends StatelessWidget {
  const _SheetSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.xxl),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 32,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// Search bar used inside the sheet
// ---------------------------------------------------------------------------

class _SheetSearchBar extends StatelessWidget {
  const _SheetSearchBar({
    required this.controller,
    required this.hint,
  });

  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return AppSearchBar(
      controller: controller,
      hintText: hint,
      height: 44,
      hasBorder: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
    );
  }
}

// ---------------------------------------------------------------------------
// Leading icon
// ---------------------------------------------------------------------------

class _ItemIcon extends StatelessWidget {
  const _ItemIcon({required this.icon, this.tint});

  final IconData icon;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final bg = (tint ?? AppColors.primaryBlue).withValues(alpha: 0.12);
    final fg = tint ?? AppColors.primaryBlue;
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Icon(icon, size: 18, color: fg),
    );
  }
}

// ---------------------------------------------------------------------------
// Single-select sheet
// ---------------------------------------------------------------------------

class _SingleSelectSheet<T> extends StatefulWidget {
  const _SingleSelectSheet({
    required this.title,
    required this.items,
    required this.selectedValue,
    required this.searchable,
  });

  final String title;
  final List<FilterSheetItem<T>> items;
  final T? selectedValue;
  final bool searchable;

  @override
  State<_SingleSelectSheet<T>> createState() => _SingleSelectSheetState<T>();
}

class _SingleSelectSheetState<T> extends State<_SingleSelectSheet<T>> {
  late final TextEditingController _searchCtrl;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<FilterSheetItem<T>> get _filtered {
    if (_query.isEmpty) return widget.items;
    return widget.items
        .where((item) => item.label.toLowerCase().contains(_query))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.viewInsetsOf(context).bottom;
    final filtered = _filtered;

    return SafeArea(
      minimum: EdgeInsets.only(bottom: bottomPad),
      child: _SheetSurface(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.textMuted, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            if (widget.searchable)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
                child: _SheetSearchBar(controller: _searchCtrl, hint: 'Search…'),
              ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.55,
              ),
              child: filtered.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(AppSpacing.xl),
                      child: Text(
                        'No results',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        0,
                        AppSpacing.lg,
                        AppSpacing.lg,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        final isSelected = item.value == widget.selectedValue;
                        return InkWell(
                          onTap: () => Navigator.of(context).pop(item.value),
                          borderRadius:
                              BorderRadius.circular(AppRadii.sm),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              children: <Widget>[
                                if (item.icon != null) ...<Widget>[
                                  _ItemIcon(
                                      icon: item.icon!,
                                      tint: item.iconColor),
                                  const SizedBox(width: AppSpacing.sm),
                                ],
                                Expanded(
                                  child: Text(
                                    item.label,
                                    style: TextStyle(
                                      color: isSelected
                                          ? AppColors.primaryBlue
                                          : AppColors.textDark,
                                      fontWeight: isSelected
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: AppColors.primaryBlue,
                                    size: 20,
                                  )
                                else
                                  const Icon(
                                    Icons.radio_button_unchecked_rounded,
                                    color: AppColors.textMuted,
                                    size: 20,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Multi-select sheet
// ---------------------------------------------------------------------------

class _MultiSelectSheet<T> extends StatefulWidget {
  const _MultiSelectSheet({
    required this.title,
    required this.items,
    required this.initialSelectedValues,
    required this.searchable,
  });

  final String title;
  final List<FilterSheetItem<T>> items;
  final Set<T> initialSelectedValues;
  final bool searchable;

  @override
  State<_MultiSelectSheet<T>> createState() => _MultiSelectSheetState<T>();
}

class _MultiSelectSheetState<T> extends State<_MultiSelectSheet<T>> {
  late final Set<T> _selected;
  late final TextEditingController _searchCtrl;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selected = Set.of(widget.initialSelectedValues);
    _searchCtrl = TextEditingController();
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<FilterSheetItem<T>> get _filtered {
    if (_query.isEmpty) return widget.items;
    return widget.items
        .where((item) => item.label.toLowerCase().contains(_query))
        .toList(growable: false);
  }

  void _toggle(T value) {
    setState(() {
      if (_selected.contains(value)) {
        _selected.remove(value);
      } else {
        _selected.add(value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.viewInsetsOf(context).bottom;
    final filtered = _filtered;

    return SafeArea(
      minimum: EdgeInsets.only(bottom: bottomPad),
      child: _SheetSurface(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
              ),
            ),
            // Title + Apply button row
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.sm, AppSpacing.sm),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  if (_selected.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        setState(_selected.clear);
                      },
                      child: const Text(
                        'Clear',
                        style: TextStyle(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(Set.of(_selected)),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                    ),
                    child: const Text(
                      'Apply',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ],
              ),
            ),
            if (widget.searchable)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
                child: _SheetSearchBar(controller: _searchCtrl, hint: 'Search…'),
              ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.55,
              ),
              child: filtered.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(AppSpacing.xl),
                      child: Text(
                        'No results',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        0,
                        AppSpacing.lg,
                        AppSpacing.lg,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        final isSelected = _selected.contains(item.value);
                        return InkWell(
                          onTap: () => _toggle(item.value),
                          borderRadius: BorderRadius.circular(AppRadii.sm),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            child: Row(
                              children: <Widget>[
                                if (item.icon != null) ...<Widget>[
                                  _ItemIcon(
                                      icon: item.icon!,
                                      tint: item.iconColor),
                                  const SizedBox(width: AppSpacing.sm),
                                ],
                                Expanded(
                                  child: Text(
                                    item.label,
                                    style: TextStyle(
                                      color: isSelected
                                          ? AppColors.primaryBlue
                                          : AppColors.textDark,
                                      fontWeight: isSelected
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                _Checkbox(isSelected: isSelected),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Blue filled checkbox
// ---------------------------------------------------------------------------

class _Checkbox extends StatelessWidget {
  const _Checkbox({required this.isSelected});

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primaryBlue : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isSelected ? AppColors.primaryBlue : AppColors.textMuted,
          width: 2,
        ),
      ),
      child: isSelected
          ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
          : null,
    );
  }
}
