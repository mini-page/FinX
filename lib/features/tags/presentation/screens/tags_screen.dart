import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xpens/core/theme/app_colors.dart';
import 'package:xpens/features/accounts/presentation/provider/account_providers.dart';
import 'package:xpens/features/accounts/data/models/account_model.dart';
import 'package:xpens/features/categories/presentation/widgets/expense_category.dart';
import 'package:xpens/features/settings/presentation/provider/preferences_providers.dart';
import '../../data/models/tag_shorthand_model.dart';
import 'package:xpens/shared/widgets/app_page_header.dart';
import '../provider/tag_providers.dart';

class TagsScreen extends ConsumerWidget {
  const TagsScreen({super.key});

  void _showEditor(BuildContext context, WidgetRef ref, [TagShorthandModel? tag]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => TagShorthandEditorSheet(tag: tag),
    );
  }

  void _showDeleteConfirm(BuildContext context, WidgetRef ref, TagShorthandModel tag) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Shorthand', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        content: Text('Are you sure you want to delete the shorthand tag "?${tag.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(tagShorthandControllerProvider.notifier).deleteTag(tag.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(tagShorthandControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: const GradientAppBar(
        title: 'Tags & Shorthands',
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Text(
              'Configure tags that auto-expand into full transactions when typed or chosen.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ),
          const Divider(color: Color(0xFFE2E8F0), height: 1, thickness: 1),

            Expanded(
              child: tags.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 36,
                              backgroundColor: AppColors.lightBlueBg,
                              child: const Icon(Icons.label_outline_rounded, size: 32, color: AppColors.primaryBlue),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No shorthands configured',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Create tags like ?dinner mapped to Category: Food, Account: Cash, and Amount: 100.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      itemCount: tags.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final tag = tags[index];
                        
                        // Resolve category color and icon for custom tag styling
                        final allCategories = [...expenseCategories, ...incomeCategories];
                        Color categoryColor = AppColors.primaryBlue;
                        IconData categoryIcon = Icons.grid_view_rounded;
                        if (tag.categoryName != null) {
                          final match = allCategories.firstWhere(
                            (c) => c.name == tag.categoryName,
                            orElse: () => allCategories.first,
                          );
                          categoryColor = match.color;
                          categoryIcon = match.icon;
                        }

                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: const [
                              BoxShadow(
                                color: AppColors.cardShadow,
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: InkWell(
                              onTap: () => _showEditor(context, ref, tag),
                              onLongPress: () => _showDeleteConfirm(context, ref, tag),
                              child: Container(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            '?${tag.name}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 13,
                                              color: Color(0xFF475569),
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                          onPressed: () => _showDeleteConfirm(context, ref, tag),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    // Configured mappings wrap
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        if (tag.amount != null)
                                          _buildMappingChip(
                                            icon: Icons.attach_money_rounded,
                                            label: '\u20B9${tag.amount!.toStringAsFixed(0)}',
                                            color: Colors.green,
                                          ),
                                        if (tag.accountId != null)
                                          _buildMappingChip(
                                            icon: Icons.account_balance_wallet_rounded,
                                            label: tag.accountId!,
                                            color: Colors.blueAccent,
                                          ),
                                        if (tag.categoryName != null)
                                          _buildMappingChip(
                                            icon: categoryIcon,
                                            label: tag.categoryName!,
                                            color: categoryColor,
                                          ),
                                        if (tag.subcategoryName != null)
                                          _buildMappingChip(
                                            icon: Icons.subdirectory_arrow_right_rounded,
                                            label: tag.subcategoryName!,
                                            color: Colors.indigo,
                                          ),
                                        if (tag.note != null && tag.note!.isNotEmpty)
                                          _buildMappingChip(
                                            icon: Icons.notes_rounded,
                                            label: tag.note!,
                                            color: Colors.grey,
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      floatingActionButton: FloatingActionButton(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: AppColors.primaryBlue,
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
        onPressed: () => _showEditor(context, ref),
      ),
    );
  }

  Widget _buildMappingChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF64748B)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }
}

class TagShorthandEditorSheet extends ConsumerStatefulWidget {
  const TagShorthandEditorSheet({super.key, this.tag});

  final TagShorthandModel? tag;

  @override
  ConsumerState<TagShorthandEditorSheet> createState() => _TagShorthandEditorSheetState();
}

class _TagShorthandEditorSheetState extends ConsumerState<TagShorthandEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;

  String? _selectedAccountId;
  String? _selectedCategoryName;
  String? _selectedSubcategoryName;

  @override
  void initState() {
    super.initState();
    final t = widget.tag;
    _nameController = TextEditingController(text: t?.name ?? '');
    _amountController = TextEditingController(
      text: t?.amount != null ? t!.amount!.toStringAsFixed(0) : '',
    );
    _noteController = TextEditingController(text: t?.note ?? '');
    _selectedAccountId = t?.accountId;
    _selectedCategoryName = t?.categoryName;
    _selectedSubcategoryName = t?.subcategoryName;

    _nameController.addListener(_onFieldChanged);
    _amountController.addListener(_onFieldChanged);
    _noteController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _nameController.removeListener(_onFieldChanged);
    _amountController.removeListener(_onFieldChanged);
    _noteController.removeListener(_onFieldChanged);
    _nameController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    setState(() {});
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.replaceAll('?', '').trim();
    final amount = double.tryParse(_amountController.text.trim());
    final note = _noteController.text.trim();

    if (widget.tag == null) {
      ref.read(tagShorthandControllerProvider.notifier).addTag(
            name: name,
            amount: amount,
            accountId: _selectedAccountId,
            categoryName: _selectedCategoryName,
            subcategoryName: _selectedSubcategoryName,
            note: note.isNotEmpty ? note : null,
          );
    } else {
      final updated = widget.tag!.copyWith(
        name: name,
        amount: amount,
        clearAmount: amount == null,
        accountId: _selectedAccountId,
        clearAccountId: _selectedAccountId == null,
        categoryName: _selectedCategoryName,
        clearCategoryName: _selectedCategoryName == null,
        subcategoryName: _selectedSubcategoryName,
        clearSubcategoryName: _selectedSubcategoryName == null,
        note: note.isNotEmpty ? note : null,
        clearNote: note.isEmpty,
      );
      ref.read(tagShorthandControllerProvider.notifier).updateTag(updated);
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountListProvider).value ?? const <AccountModel>[];
    final subcategoriesMap = ref.watch(categorySubcategoriesProvider);
    final allCategories = [...expenseCategories, ...incomeCategories];

    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding + 20),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Text(
                    widget.tag == null ? 'New Shorthand Tag' : 'Edit Shorthand Tag',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textDark),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Live Preview Simulator Card
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.psychology_rounded, size: 16, color: AppColors.primaryBlue),
                        const SizedBox(width: 6),
                        const Text(
                          'Live Expansion Preview',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _nameController.text.trim().isNotEmpty 
                                ? AppColors.success.withValues(alpha: 0.1) 
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _nameController.text.trim().isNotEmpty ? 'Ready' : 'Draft',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: _nameController.text.trim().isNotEmpty 
                                  ? AppColors.success 
                                  : AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.label_rounded, size: 18, color: AppColors.primaryBlue),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _nameController.text.trim().isEmpty 
                                    ? 'Enter trigger name...' 
                                    : 'typing: "?${_nameController.text.replaceAll('?', '').trim()}"',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _nameController.text.trim().isEmpty 
                                      ? AppColors.textMuted 
                                      : AppColors.textDark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (_amountController.text.isEmpty &&
                                  _selectedAccountId == null &&
                                  _selectedCategoryName == null &&
                                  _noteController.text.isEmpty)
                                const Text(
                                  'Configure fields below to see mappings.',
                                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                                )
                              else
                                Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: [
                                    if (_amountController.text.isNotEmpty)
                                      _buildPreviewBadge(
                                        icon: Icons.attach_money_rounded,
                                        text: '₹${_amountController.text}',
                                        color: Colors.green,
                                      ),
                                    if (_selectedAccountId != null)
                                      _buildPreviewBadge(
                                        icon: Icons.account_balance_wallet_rounded,
                                        text: _selectedAccountId!,
                                        color: Colors.blueAccent,
                                      ),
                                    if (_selectedCategoryName != null)
                                      _buildPreviewBadge(
                                        icon: Icons.grid_view_rounded,
                                        text: _selectedCategoryName!,
                                        color: Colors.orange,
                                      ),
                                    if (_selectedSubcategoryName != null)
                                      _buildPreviewBadge(
                                        icon: Icons.subdirectory_arrow_right_rounded,
                                        text: _selectedSubcategoryName!,
                                        color: Colors.indigo,
                                      ),
                                    if (_noteController.text.isNotEmpty)
                                      _buildPreviewBadge(
                                        icon: Icons.notes_rounded,
                                        text: _noteController.text,
                                        color: Colors.grey,
                                      ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Shorthand trigger name input
              const Text('Tag Trigger Name', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  hintText: 'e.g. dinner, uber, tea',
                  prefixText: '?',
                  prefixStyle: TextStyle(fontWeight: FontWeight.w800, color: AppColors.primaryBlue),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  isDense: true,
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Trigger name is required';
                  }
                  if (val.trim().contains(' ')) {
                    return 'Shorthand cannot contain spaces';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Amount input
              const Text('Autofill Amount (Optional)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  hintText: 'e.g. 100, 250',
                  prefixText: '\u20B9 ',
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 16),

              // Account picker dropdown
              const Text('Autofill Account (Optional)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedAccountId,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  isDense: true,
                ),
                hint: const Text('Select account'),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('None / Don\'t autofill', style: TextStyle(color: AppColors.textMuted)),
                  ),
                  ...accounts.map((a) {
                    return DropdownMenuItem<String>(
                      value: a.name,
                      child: Text(a.name),
                    );
                  }),
                ],
                onChanged: (val) {
                  setState(() {
                    _selectedAccountId = val;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Category picker dropdown
              const Text('Autofill Category (Optional)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedCategoryName,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  isDense: true,
                ),
                hint: const Text('Select category'),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('None / Don\'t autofill', style: TextStyle(color: AppColors.textMuted)),
                  ),
                  ...allCategories.map((c) {
                    final typeString = expenseCategories.contains(c) ? 'Expense' : 'Income';
                    return DropdownMenuItem<String>(
                      value: c.name,
                      child: Text('${c.name} ($typeString)'),
                    );
                  }),
                ],
                onChanged: (val) {
                  setState(() {
                    _selectedCategoryName = val;
                    _selectedSubcategoryName = null; // Clear subcategory on change
                  });
                },
              ),
              const SizedBox(height: 16),

              // Subcategory selection (if category is set and has subcategories)
              if (_selectedCategoryName != null &&
                  subcategoriesMap[_selectedCategoryName] != null &&
                  subcategoriesMap[_selectedCategoryName]!.isNotEmpty) ...[
                const Text('Autofill Item / Subcategory (Optional)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: subcategoriesMap[_selectedCategoryName]!.map((sub) {
                      final isSelected = _selectedSubcategoryName == sub;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(sub),
                          selected: isSelected,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : AppColors.textDark,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                          selectedColor: AppColors.primaryBlue,
                          backgroundColor: const Color(0xFFF1F5F9),
                          side: BorderSide.none,
                          shape: const StadiumBorder(),
                          onSelected: (selected) {
                            setState(() {
                              _selectedSubcategoryName = selected ? sub : null;
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Custom Note input
              const Text('Autofill Note (Optional)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(
                  hintText: 'e.g. breakfast, grocery list',
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 24),

              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Save Shorthand', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewBadge({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
