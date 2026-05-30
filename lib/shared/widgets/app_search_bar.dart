import 'package:flutter/material.dart';
import 'package:xpens/core/theme/app_colors.dart';

/// A premium, reusable search bar matching the Finance Tools design.
///
/// Features:
///   • Stadium border (BorderRadius.circular(30))
///   • Soft card shadow
///   • Built-in listener to toggle the "clear" suffix button automatically
///   • Integrated onChanged & onClear callbacks
class AppSearchBar extends StatefulWidget {
  const AppSearchBar({
    super.key,
    this.controller,
    this.onChanged,
    required this.hintText,
    this.onClear,
    this.focusNode,
    this.autoFocus = false,
    this.hasBorder = false,
  });

  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final String hintText;
  final VoidCallback? onClear;
  final FocusNode? focusNode;
  final bool autoFocus;
  final bool hasBorder;

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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: widget.hasBorder
            ? Border.all(color: const Color(0xFFE2E8F0))
            : null,
      ),
      child: TextField(
        controller: _controller,
        focusNode: widget.focusNode,
        autofocus: widget.autoFocus,
        onChanged: widget.onChanged,
        style: const TextStyle(
          color: AppColors.textDark,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.textMuted,
            size: 20,
          ),
          suffixIcon: _hasText
              ? IconButton(
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
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
    );
  }
}
