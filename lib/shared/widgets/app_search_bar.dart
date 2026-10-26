import 'package:flutter/material.dart';
import 'package:expensio/core/theme/app_colors.dart';

class AppSearchBar extends StatefulWidget {
  const AppSearchBar({
    super.key,
    this.controller,
    this.onChanged,
    this.hintText = 'Search…',
    this.onClear,
    this.focusNode,
    this.autoFocus = false,
    this.hasBorder = false,
    this.prefixIcon,
    this.backgroundColor = Colors.white,
    this.borderRadius = 30,
    this.height,
    this.contentPadding,
    this.shadow,
    this.textStyle,
    this.hintStyle,
    this.prefixIconColor,
    this.trailing,
  });

  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final String hintText;
  final VoidCallback? onClear;
  final FocusNode? focusNode;
  final bool autoFocus;
  final bool hasBorder;

  /// Optional trailing widget embedded on the right inside the search bar (e.g. filter/sort capsule).
  final Widget? trailing;

  /// Override the search icon (default Icons.search_rounded).
  final Widget? prefixIcon;

  /// Background colour (default white).
  final Color backgroundColor;

  /// Border radius of the container (default 30 — stadium).
  final double borderRadius;

  /// Fixed height for compact layouts (default null = auto).
  final double? height;

  /// Override the default horizontal/vertical padding.
  final EdgeInsetsGeometry? contentPadding;

  /// Override the default box shadow (default has a soft shadow).
  final BoxShadow? shadow;

  /// Override the input text style.
  final TextStyle? textStyle;

  /// Override the hint text style.
  final TextStyle? hintStyle;

  /// Override the prefix icon colour (default AppColors.textMuted).
  final Color? prefixIconColor;

  @override
  State<AppSearchBar> createState() => _AppSearchBarState();
}

class _AppSearchBarState extends State<AppSearchBar> {
  late final TextEditingController _controller;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _hasText = _controller.text.isNotEmpty;
    _controller.addListener(_textListener);
  }

  void _textListener() {
    final isNotEmpty = _controller.text.isNotEmpty;
    if (_hasText != isNotEmpty) {
      setState(() {
        _hasText = isNotEmpty;
      });
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    } else {
      _controller.removeListener(_textListener);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shadow = widget.shadow ?? BoxShadow(
      color: Colors.black.withValues(alpha: 0.03),
      blurRadius: 12,
      offset: const Offset(0, 4),
    );

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        boxShadow: [shadow],
        border: widget.hasBorder
            ? Border.all(color: const Color(0xFFE2E8F0))
            : null,
      ),
      child: TextField(
        controller: _controller,
        focusNode: widget.focusNode,
        autofocus: widget.autoFocus,
        onChanged: widget.onChanged,
        style: widget.textStyle ?? const TextStyle(
          color: AppColors.textDark,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: widget.hintStyle ?? const TextStyle(
            color: AppColors.textMuted,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: widget.prefixIcon ?? const Icon(
            Icons.search_rounded,
            color: AppColors.textMuted,
            size: 20,
          ),
          suffixIcon: (_hasText || widget.trailing != null)
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_hasText)
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: AppColors.textMuted,
                        ),
                        onPressed: () {
                          _controller.clear();
                          widget.onChanged?.call('');
                          widget.onClear?.call();
                        },
                      ),
                    if (widget.trailing != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: widget.trailing!,
                      ),
                  ],
                )
              : (widget.prefixIcon != null ? const SizedBox(width: 0) : null),
          border: InputBorder.none,
          contentPadding: widget.contentPadding ??
              const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
    );
  }
}
