import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/context_extensions.dart';

/// Result returned from [showCategoryEditorSheet].
class CategoryEditorResult {
  const CategoryEditorResult({
    required this.name,
    required this.iconKey,
    required this.colorHex,
    this.monthlyLimit,
    this.isDelete = false,
  });

  final String name;
  final String iconKey;

  /// 6-char hex string without '#'.
  final String colorHex;

  /// Monthly spending limit. `null` = none / leave unchanged. `0` = remove limit.
  final double? monthlyLimit;

  /// `true` only when the user confirmed deletion of a custom category.
  final bool isDelete;
}

/// Predefined icon options shown in the category editor.
/// Add new entries here to extend the picker — no other changes needed.
const List<({String key, IconData icon})> categoryIconOptions = [
  (key: 'restaurant', icon: Icons.restaurant_outlined),
  (key: 'transport', icon: Icons.directions_bus_outlined),
  (key: 'shopping', icon: Icons.shopping_bag_outlined),
  (key: 'home', icon: Icons.home_outlined),
  (key: 'health', icon: Icons.health_and_safety_outlined),
  (key: 'education', icon: Icons.school_outlined),
  (key: 'entertainment', icon: Icons.movie_outlined),
  (key: 'gym', icon: Icons.fitness_center_outlined),
  (key: 'pets', icon: Icons.pets_outlined),
  (key: 'gift', icon: Icons.card_giftcard_outlined),
  (key: 'work', icon: Icons.work_outline_rounded),
  (key: 'star', icon: Icons.star_outline_rounded),
  (key: 'beauty', icon: Icons.auto_awesome_outlined),
  (key: 'social', icon: Icons.more_horiz_rounded),
  (key: 'travel', icon: Icons.flight_takeoff_outlined),
  (key: 'widgets', icon: Icons.widgets_outlined),
  (key: 'watch', icon: Icons.watch_outlined),
  (key: 'award', icon: Icons.emoji_events_outlined),
  (key: 'coupon', icon: Icons.confirmation_num_outlined),
  (key: 'lottery', icon: Icons.casino_outlined),
  (key: 'refund', icon: Icons.replay_circle_filled_outlined),
  (key: 'sale', icon: Icons.sell_outlined),
  (key: 'savings', icon: Icons.savings_outlined),
  (key: 'invest', icon: Icons.trending_up_rounded),
  (key: 'rent', icon: Icons.house_outlined),
  (key: 'bill', icon: Icons.receipt_outlined),
  (key: 'phone', icon: Icons.phone_android_outlined),
  (key: 'game', icon: Icons.sports_esports_outlined),
  (key: 'food', icon: Icons.fastfood_outlined),
  (key: 'coffee', icon: Icons.coffee_outlined),
  (key: 'music', icon: Icons.music_note_outlined),
  (key: 'sport', icon: Icons.sports_outlined),
  (key: 'car', icon: Icons.directions_car_outlined),
];

/// Predefined colour hex strings (no '#') for category colours.
const List<String> categoryColorOptions = [
  'FFB648',
  '61A7FF',
  'FF8C7A',
  'FF72B6',
  '9B8CFF',
  '4BB7A6',
  '7B8BAA',
  '6D8FFF',
  '85FFB8',
  'FFE38A',
  'B4EFB4',
  'FFC0CB',
];

/// Shows a bottom sheet for creating or editing a category.
///
/// • **Create mode**: pass nothing — name, icon, colour, optional limit.
/// • **Custom edit mode**: pass [editName]/[editIconKey]/[editColorHex] — also shows Delete.
/// • **Built-in edit mode**: same params + `isBuiltIn: true` — name is read-only, no Delete.
///
/// Returns [CategoryEditorResult] on save, or `null` on cancel.
Future<CategoryEditorResult?> showCategoryEditorSheet(
  BuildContext context, {
  String? editName,
  String? editIconKey,
  String? editColorHex,
  double? editMonthlyLimit,
  bool isBuiltIn = false,
  String currencySymbol = '₹',
}) {
  return showModalBottomSheet<CategoryEditorResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _CategoryEditorSheet(
      editName: editName,
      editIconKey: editIconKey,
      editColorHex: editColorHex,
      editMonthlyLimit: editMonthlyLimit,
      isBuiltIn: isBuiltIn,
      currencySymbol: currencySymbol,
    ),
  );
}

class _CategoryEditorSheet extends StatefulWidget {
  const _CategoryEditorSheet({
    this.editName,
    this.editIconKey,
    this.editColorHex,
    this.editMonthlyLimit,
    this.isBuiltIn = false,
    this.currencySymbol = '₹',
  });

  final String? editName;
  final String? editIconKey;
  final String? editColorHex;
  final double? editMonthlyLimit;
  final bool isBuiltIn;
  final String currencySymbol;

  bool get isEditing => editName != null;

  @override
  State<_CategoryEditorSheet> createState() => _CategoryEditorSheetState();
}

class _CategoryEditorSheetState extends State<_CategoryEditorSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _limitController;
  late String _iconKey;
  late String _colorHex;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.editName ?? '');
    _limitController = TextEditingController(
      text: widget.editMonthlyLimit != null && widget.editMonthlyLimit! > 0
          ? widget.editMonthlyLimit!.toStringAsFixed(0)
          : '',
    );
    _iconKey = widget.editIconKey ?? categoryIconOptions.first.key;
    _colorHex = widget.editColorHex ?? categoryColorOptions.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _limitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets;
    final isEditing = widget.isEditing;

    return Padding(
      padding: EdgeInsets.only(bottom: insets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Center(
                child: SizedBox(
                  width: 46,
                  child:
                      Divider(thickness: 4, color: AppColors.backgroundLight),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                isEditing ? 'Edit Category' : 'Add Category',
                style: const TextStyle(
                  color: AppColors.textDark,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isEditing
                    ? 'Customise the icon, colour and monthly limit.'
                    : 'Give your custom category a name, icon, colour and optional monthly limit.',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),

              // Name field — read-only label for built-in categories
              if (widget.isBuiltIn)
                _readOnlyNameDisplay(widget.editName ?? '')
              else
                TextField(
                  controller: _nameController,
                  autofocus: !isEditing,
                  textCapitalization: TextCapitalization.words,
                  decoration: _inputDecoration('Category name'),
                ),
              const SizedBox(height: 18),

              // Icon picker — 2-row horizontal scroll
              const Text(
                'Icon',
                style: TextStyle(
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              _buildIconPicker(),
              const SizedBox(height: 18),

              // Colour picker
              const Text(
                'Colour',
                style: TextStyle(
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: categoryColorOptions.map((hex) {
                  final color = Color(int.parse('FF$hex', radix: 16));
                  final isSelected = hex == _colorHex;
                  return GestureDetector(
                    onTap: () => setState(() => _colorHex = hex),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(
                                color: AppColors.textDark,
                                width: 3,
                              )
                            : null,
                        boxShadow: isSelected
                            ? const <BoxShadow>[
                                BoxShadow(
                                  color: AppColors.cardShadow,
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 18,
                            )
                          : null,
                    ),
                  );
                }).toList(growable: false),
              ),
              const SizedBox(height: 18),

              // Monthly limit
              const Text(
                'Monthly Limit',
                style: TextStyle(
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _limitController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: _inputDecoration('Leave blank for no limit')
                    .copyWith(prefixText: '${widget.currencySymbol} '),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    isEditing ? 'Save Changes' : 'Create Category',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              if (isEditing && !widget.isBuiltIn) ...<Widget>[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _delete,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      'Delete Category',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Two-row horizontally scrollable icon picker.
  Widget _buildIconPicker() {
    const double chipSize = 52;
    const double chipSpacing = 10;
    final mid = (categoryIconOptions.length / 2).ceil();
    final topRow = categoryIconOptions.sublist(0, mid);
    final bottomRow = categoryIconOptions.sublist(mid);

    return SizedBox(
      height: chipSize * 2 + chipSpacing,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(children: topRow.map(_buildIconChip).toList(growable: false)),
            const SizedBox(height: chipSpacing),
            Row(
                children:
                    bottomRow.map(_buildIconChip).toList(growable: false)),
          ],
        ),
      ),
    );
  }

  Widget _buildIconChip(({String key, IconData icon}) option) {
    final isSelected = option.key == _iconKey;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: ChoiceChip(
        label: Icon(
          option.icon,
          color: isSelected ? Colors.white : AppColors.primaryBlue,
        ),
        selected: isSelected,
        selectedColor: AppColors.primaryBlue,
        backgroundColor: AppColors.lightBlueBg,
        onSelected: (_) => setState(() => _iconKey = option.key),
      ),
    );
  }

  Widget _readOnlyNameDisplay(String name) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        name,
        style: const TextStyle(
          color: AppColors.textDark,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: AppColors.surfaceLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
    );
  }

  void _submit() {
    final name = widget.isBuiltIn
        ? (widget.editName ?? '')
        : _nameController.text.trim();
    if (name.isEmpty) {
      context.showSnackBar('Enter a category name.');
      return;
    }

    final limitText = _limitController.text.trim();
    double? monthlyLimit;
    if (limitText.isNotEmpty) {
      final parsed = double.tryParse(limitText);
      if (parsed == null || parsed < 0) {
        context.showSnackBar('Enter a valid monthly limit.');
        return;
      }
      monthlyLimit = parsed;
    }

    Navigator.of(context).pop(
      CategoryEditorResult(
        name: name,
        iconKey: _iconKey,
        colorHex: _colorHex,
        monthlyLimit: monthlyLimit,
      ),
    );
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: const Text(
          'This will remove the category. Past transactions using it will still show the category name.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Delete',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      Navigator.of(context).pop(
        CategoryEditorResult(
          name: widget.editName ?? '',
          iconKey: _iconKey,
          colorHex: _colorHex,
          isDelete: true,
        ),
      );
    }
  }
}
