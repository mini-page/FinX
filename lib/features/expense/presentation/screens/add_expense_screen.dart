import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import 'package:xpens/features/accounts/accounts.dart';
import '../../data/models/expense_model.dart';
import '../provider/expense_providers.dart';
import 'package:xpens/features/settings/presentation/provider/preferences_providers.dart';
import 'package:xpens/features/categories/presentation/widgets/expense_category.dart';
import 'add_expense/add_expense_widgets.dart';
import 'add_expense/amount_expression.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:xpens/features/sms_parser/domain/sms_parser_engine.dart';
import 'package:xpens/routes/app_routes.dart';
import 'voice_entry_screen.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  const AddExpenseScreen({
    super.key,
    this.expenseId,
    this.initialAmount,
    this.initialCategory,
    this.initialDate,
    this.initialNote,
    this.initialAccountId,
    this.initialToAccountId,
    this.initialType = TransactionType.expense,
    this.payUpiUri,
  });

  final String? expenseId;
  final double? initialAmount;
  final String? initialCategory;
  final DateTime? initialDate;
  final String? initialNote;
  final String? initialAccountId;
  final String? initialToAccountId;
  final TransactionType initialType;

  /// When non-null the screen starts in "Pay via UPI" mode.
  ///
  /// The save button is replaced with an **Open UPI App** button that hands
  /// the user off to their preferred UPI app with only the payee VPA
  /// (no pre-filled amount), avoiding the fraud-score spike that
  /// externally-injected payment requests trigger in GPay / PhonePe / Paytm.
  /// After the user returns from the UPI app, a "Did the payment go through?"
  /// dialog is shown before the transaction is saved.
  final String? payUpiUri;

  bool get isEditing => expenseId != null;

  /// Whether the screen was opened for the "Pay via UPI" flow.
  bool get isPayMode => payUpiUri != null;

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen>
    with WidgetsBindingObserver {
  late final TextEditingController _noteController;
  late final FocusNode _noteFocusNode;
  late final TextEditingController _amountController;
  late final FocusNode _amountFocusNode;
  late String _amountExpression;
  late String _selectedExpenseCategory;
  late String _selectedIncomeCategory;
  late DateTime _selectedDate;
  late TransactionType _selectedType;
  String? _selectedAccountId;
  String? _toAccountId;
  late bool _hasExplicitAccountChoice;
  bool _isSaving = false;

  // Custom visual state variables for the redesigned layout
  bool _showCalculator = false;
  String? _activePreviewChip;
  bool _locationEnabled = false;
  String? _attachedFilePath;
  String? _attachedImagePath;
  late String _selectedCurrency;

  // Visual tips timer variables
  final List<String> _tips = [
    'Add a note...',
    'Type @ to choose Account...',
    'Type / to choose Category...',
    'Type # to add Tags...',
    'Type + to split bill...',
    'Type ! to repeat/recurring...',
  ];
  int _currentTipIndex = 0;
  late Timer _tipsTimer;
  String _currentHintText = 'Add a note...';

  /// True once the user has returned from the UPI app AND confirmed the payment.
  bool _paymentDone = false;

  /// True while the UPI launch is in progress.
  bool _isLaunching = false;

  /// Set when the app resumes after a UPI-app handoff so the post-frame
  /// callback can show the "Did the payment go through?" dialog.
  bool _pendingPaymentConfirm = false;

  @override
  void initState() {
    super.initState();
    if (widget.isPayMode) {
      WidgetsBinding.instance.addObserver(this);
    }
    final now = DateTime.now();
    final seedDate = widget.initialDate ?? now;
    final shouldInjectCurrentTime = widget.initialDate != null &&
        seedDate.hour == 0 &&
        seedDate.minute == 0 &&
        seedDate.second == 0 &&
        seedDate.millisecond == 0 &&
        seedDate.microsecond == 0;

    _selectedDate = DateTime(
      seedDate.year,
      seedDate.month,
      seedDate.day,
      shouldInjectCurrentTime ? now.hour : seedDate.hour,
      shouldInjectCurrentTime ? now.minute : seedDate.minute,
    );
    _selectedType = widget.initialType;
    final double? initAmt = widget.initialAmount;
    _amountExpression = (initAmt != null && initAmt > 0)
        ? normalizeAmountSeed(initAmt)
        : '';
    _amountController = TextEditingController(text: _amountExpression);
    _amountFocusNode = FocusNode();
    _selectedCurrency = '₹';

    _selectedExpenseCategory = (_selectedType == TransactionType.expense
            ? widget.initialCategory
            : null) ??
        expenseCategories.first.name;
    _selectedIncomeCategory = (_selectedType == TransactionType.income
            ? widget.initialCategory
            : null) ??
        incomeCategories.first.name;
    _selectedAccountId = widget.initialAccountId;
    _toAccountId = widget.initialToAccountId;
    _hasExplicitAccountChoice =
        widget.initialAccountId != null || widget.isEditing;
    _noteController = TextEditingController(text: widget.initialNote ?? '')
      ..addListener(_onNoteControllerChanged);
    _noteFocusNode = FocusNode()..addListener(_handleNoteFocusChanged);

    _tipsTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        setState(() {
          _currentTipIndex = (_currentTipIndex + 1) % _tips.length;
          _currentHintText = _tips[_currentTipIndex];
        });
      }
    });
  }

  void _onNoteControllerChanged() {
    final text = _noteController.text;
    if (text.isEmpty) {
      if (_tipsTimer.isActive) return;
      _tipsTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
        if (mounted) {
          setState(() {
            _currentTipIndex = (_currentTipIndex + 1) % _tips.length;
            _currentHintText = _tips[_currentTipIndex];
          });
        }
      });
      return;
    }
    _tipsTimer.cancel();
    if (text.endsWith('@')) {
      setState(() => _activePreviewChip = 'Account');
    } else if (text.endsWith('/') || text.endsWith('?')) {
      setState(() => _activePreviewChip = 'Category');
    } else if (text.endsWith('#')) {
      setState(() => _activePreviewChip = 'Tags');
    } else if (text.endsWith('+')) {
      setState(() => _activePreviewChip = 'Split');
    } else if (text.endsWith('!')) {
      setState(() => _activePreviewChip = 'Recurring');
    }
  }

  void _parseUnifiedQuery(
    String query, {
    required List<AccountModel> accounts,
    required List<ExpenseCategory> expenseCategories,
    required List<ExpenseCategory> incomeCategories,
  }) {
    if (query.isEmpty) return;

    final tokens = query.split(RegExp(r'\s+'));
    String? parsedAccountId;
    String? parsedCategory;
    final List<String> parsedTags = [];
    final List<String> parsedSplits = [];
    String? parsedRecurring;
    final List<String> noteWords = [];

    for (int i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      if (token.isEmpty) continue;

      if (token.startsWith('@') && token.length > 1) {
        final name = token.substring(1).toLowerCase();
        for (final acc in accounts) {
          if (acc.name.toLowerCase().contains(name)) {
            parsedAccountId = acc.id;
            break;
          }
        }
      } else if (token.startsWith('/') && token.length > 1) {
        final name = token.substring(1).toLowerCase();
        final cats = _selectedType == TransactionType.income ? incomeCategories : expenseCategories;
        for (final cat in cats) {
          if (cat.name.toLowerCase().contains(name)) {
            parsedCategory = cat.name;
            break;
          }
        }
      } else if (token.startsWith('#') && token.length > 1) {
        parsedTags.add(token);
      } else if (token.startsWith('+') && token.length > 1 && !RegExp(r'^\d').hasMatch(token.substring(1))) {
        parsedSplits.add(token.substring(1));
      } else if (token.startsWith('!') && token.length > 1) {
        parsedRecurring = token.substring(1);
      } else {
        // Skip numbers and math operators at the start
        final isMath = RegExp(r'^[\d\.\+\-\*\/x]+$').hasMatch(token);
        if (i == 0 || (isMath && noteWords.isEmpty)) {
          continue;
        }
        noteWords.add(token);
      }
    }

    setState(() {
      if (parsedAccountId != null) {
        _selectedAccountId = parsedAccountId;
        _hasExplicitAccountChoice = true;
      }
      if (parsedCategory != null) {
        if (_selectedType == TransactionType.income) {
          _selectedIncomeCategory = parsedCategory;
        } else {
          _selectedExpenseCategory = parsedCategory;
        }
      }
      
      // Construct note: note words + tags + splits
      final List<String> noteParts = [];
      if (noteWords.isNotEmpty) {
        noteParts.add(noteWords.join(' '));
      }
      if (parsedTags.isNotEmpty) {
        noteParts.add(parsedTags.join(' '));
      }
      if (parsedSplits.isNotEmpty) {
        noteParts.add(parsedSplits.map((s) => '+$s').join(' '));
      }
      if (parsedRecurring != null) {
        noteParts.add('!$parsedRecurring');
      }

      if (noteParts.isNotEmpty) {
        final noteText = noteParts.join(' ');
        if (_noteController.text != noteText) {
          _noteController.text = noteText;
        }
      }
    });
  }

  @override
  void dispose() {
    _tipsTimer.cancel();
    if (widget.isPayMode) {
      WidgetsBinding.instance.removeObserver(this);
    }
    _noteController.removeListener(_onNoteControllerChanged);
    _noteFocusNode
      ..removeListener(_handleNoteFocusChanged)
      ..dispose();
    _noteController.dispose();
    _amountController.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When the user returns from the UPI app, schedule a confirmation dialog.
    if (widget.isPayMode &&
        !_paymentDone &&
        _isLaunching &&
        state == AppLifecycleState.resumed) {
      setState(() {
        _isLaunching = false;
        _pendingPaymentConfirm = true;
      });
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _askPaymentConfirmation());
    }
  }

  Future<void> _askPaymentConfirmation() async {
    if (!mounted || !_pendingPaymentConfirm) return;
    setState(() => _pendingPaymentConfirm = false);

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Payment Complete?'),
        content: const Text(
          'Did the payment go through in your UPI app?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('No, Retry'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Yes, Save'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (confirmed == true) {
      setState(() => _paymentDone = true);
      _saveExpense();
    }
    // If "No, Retry", _paymentDone stays false and the "Pay via UPI" button
    // is shown again.
  }

  @override
  Widget build(BuildContext context) {
    final accounts =
        ref.watch(accountListProvider).value ?? const <AccountModel>[];
    final disabledExpenseCategories =
        ref.watch(disabledExpenseCategoriesProvider);
    final disabledIncomeCategories =
        ref.watch(disabledIncomeCategoriesProvider);
    final disabledAccountIds = ref.watch(disabledAccountIdsProvider);
    final allExpenseCategories = ref.watch(allExpenseCategoriesProvider);
    final allIncomeCategories = ref.watch(allIncomeCategoriesProvider);
    final availableExpenseCategories = allExpenseCategories
        .where((category) => !disabledExpenseCategories.contains(category.name))
        .toList(growable: false);
    final availableIncomeCategories = allIncomeCategories
        .where((category) => !disabledIncomeCategories.contains(category.name))
        .toList(growable: false);
    final availableAccounts = accounts
        .where((account) => !disabledAccountIds.contains(account.id))
        .toList(growable: false);
    _queueDefaultSelections(
      availableAccounts,
      availableExpenseCategories,
      availableIncomeCategories,
    );

    final selectionAccounts = widget.isEditing ? accounts : availableAccounts;
    final selectedAccount = _resolveSelectedAccount(selectionAccounts);
    final toAccount = _resolveToAccount(selectionAccounts);
    final amountState = evaluateAmountExpression(_amountExpression);
    final canSubmit = _canSubmit(
      amountState: amountState,
      selectedAccount: selectedAccount,
      toAccount: toAccount,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // Top row - Header with close button and type tabs
                    Row(
                      children: <Widget>[
                        AddExpenseTopButton(
                          icon: Icons.close_rounded,
                          onTap: () => Navigator.of(context).pop(),
                          tooltip: 'Close',
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4F6FA),
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                  child: AddExpenseModeTab(
                                    label: 'Expense',
                                    icon: Icons.arrow_outward_rounded,
                                    activeColor: const Color(0xFFC23358),
                                    inactiveColor: const Color(0xFFC23358),
                                    isSelected: _selectedType == TransactionType.expense,
                                    onTap: () => _switchType(TransactionType.expense),
                                  ),
                                ),
                                Expanded(
                                  child: AddExpenseModeTab(
                                    label: 'Income',
                                    icon: Icons.arrow_downward_rounded,
                                    activeColor: AppColors.success,
                                    inactiveColor: AppColors.success,
                                    isSelected: _selectedType == TransactionType.income,
                                    onTap: () => _switchType(TransactionType.income),
                                  ),
                                ),
                                Expanded(
                                  child: AddExpenseModeTab(
                                    label: 'Transfer',
                                    icon: Icons.sync_alt_rounded,
                                    activeColor: AppColors.primaryBlue,
                                    inactiveColor: AppColors.primaryBlue,
                                    isSelected: _selectedType == TransactionType.transfer,
                                    onTap: () => _switchType(TransactionType.transfer),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Premium Unified Input Card
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0A000000),
                            blurRadius: 16,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Top Row: Currency Dropdown + Amount Input + Calculator Toggle
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  _buildCurrencySwitcher(),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: _amountController,
                                      focusNode: _amountFocusNode,
                                      keyboardType: TextInputType.text,
                                      readOnly: _showCalculator,
                                      showCursor: true,
                                      autofocus: true,
                                      cursorWidth: 3.0,
                                      cursorHeight: 28.0,
                                      cursorRadius: const Radius.circular(2),
                                      cursorColor: _selectedType.isIncome
                                          ? AppColors.success
                                          : _selectedType.isTransfer
                                              ? AppColors.primaryBlue
                                              : const Color(0xFFC23358),
                                      textAlign: TextAlign.left,
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: _selectedType.isIncome
                                            ? AppColors.success
                                            : _selectedType.isTransfer
                                                ? AppColors.primaryBlue
                                                : AppColors.textDark,
                                      ),
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        hintText: '',
                                        isDense: true,
                                      ),
                                      onChanged: (val) {
                                        // Check if the input is a pasted SMS transaction notification
                                        if (val.length > 20 && SmsParserEngine.isTransactionalMessage(val)) {
                                          final parsed = SmsParserEngine.parse(
                                            senderAddress: 'PASTED',
                                            body: val,
                                            receivedAt: DateTime.now(),
                                          );
                                          if (parsed != null) {
                                            setState(() {
                                              _amountExpression = formatAmountExpressionValue(parsed.amount);
                                              _selectedType = parsed.type;
                                              if (parsed.type == TransactionType.income) {
                                                if (parsed.suggestedCategory != null) {
                                                  _selectedIncomeCategory = parsed.suggestedCategory!;
                                                }
                                              } else {
                                                if (parsed.suggestedCategory != null) {
                                                  _selectedExpenseCategory = parsed.suggestedCategory!;
                                                }
                                              }
                                              _noteController.text = parsed.notes;
                                              _syncAmountController();
                                            });
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('SMS transaction parsed & auto-filled!'),
                                                backgroundColor: AppColors.success,
                                              ),
                                            );
                                            return;
                                          }
                                        }

                                        setState(() {
                                          _amountExpression = val;
                                        });
                                        _parseUnifiedQuery(
                                          val,
                                          accounts: selectionAccounts,
                                          expenseCategories: availableExpenseCategories,
                                          incomeCategories: availableIncomeCategories,
                                        );
                                      },
                                    ),
                                  ),

                                ],
                              ),
                            ],
                          ),
                          const Divider(height: 24, thickness: 1, color: Color(0xFFEDF2F7)),

                          // Second Row: Note field with tips support
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: _noteController,
                                focusNode: _noteFocusNode,
                                textAlign: TextAlign.left,
                                textInputAction: TextInputAction.done,
                                decoration: InputDecoration(
                                  hintText: _currentHintText,
                                  hintStyle: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24, thickness: 1, color: Color(0xFFEDF2F7)),

                          // Third Row: Action chips row with accent colors, custom location and scan chips
                          Row(
                            children: [
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      _buildActionChip('@ Account'),
                                      _buildActionChip('/ Category'),
                                      _buildActionChip('# tags'),
                                      _buildActionChip('+ Splits'),
                                      _buildActionChip('! Recurring'),
                                      _buildLocationChip(),
                                      _buildActionChip('% Scan'),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Date/Time + Location Row (Location toggle moved to chips, only DateTime left)
                    _buildDateTimeAndLocationRow(),

                    // Middle Section (Dynamic Preview Panel)
                    if (_activePreviewChip != null) ...[
                      const SizedBox(height: 12),
                      if (_activePreviewChip == 'Account')
                        _buildAccountPreview(selectionAccounts),
                      if (_activePreviewChip == 'Category')
                        _buildCategoryPreview(availableExpenseCategories, availableIncomeCategories),
                      if (_activePreviewChip == 'Tags')
                        _buildTagsPreview(),
                      if (_activePreviewChip == 'Split')
                        _buildSplitPreview(),
                      if (_activePreviewChip == 'Scan')
                        _buildScanPreview(),
                      if (_activePreviewChip == 'Recurring')
                        _buildRecurringPreview(),
                    ],

                  ],
                ),
              ),
            ),
            // Custom calculator keypad (bottom space when toggled)
            if (_showCalculator) _buildCalculatorGrid(amountState: amountState),
            // Bottom Save Button (sticky at the bottom)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: _buildSaveButton(canSubmit: canSubmit),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalculatorGrid({required AmountExpressionResult amountState}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (amountState.previewAmount > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '= $_selectedCurrency${amountState.previewAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: AppColors.primaryBlue,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.6,
            children: <Widget>[
              AddExpenseKeypadButton(
                onTap: _clearAmount,
                backgroundColor: const Color(0xFFFFE7EC),
                foregroundColor: const Color(0xFFC23358),
                child: const Text('C'),
              ),
              _buildOperatorKey('/'),
              _buildOperatorKey('*'),
              AddExpenseKeypadButton(
                onTap: _backspace,
                backgroundColor: const Color(0xFFFFE7EC),
                foregroundColor: const Color(0xFFC23358),
                child: const Icon(Icons.backspace_outlined),
              ),
              _buildDigitKey('7'),
              _buildDigitKey('8'),
              _buildDigitKey('9'),
              _buildOperatorKey('-'),
              _buildDigitKey('4'),
              _buildDigitKey('5'),
              _buildDigitKey('6'),
              _buildOperatorKey('+'),
              _buildDigitKey('1'),
              _buildDigitKey('2'),
              _buildDigitKey('3'),
              AddExpenseKeypadButton(
                onTap: amountState.canEvaluate ? _applyExpression : null,
                isEnabled: amountState.canEvaluate,
                backgroundColor: const Color(0xFFEFF5FF),
                foregroundColor: AppColors.primaryBlue,
                child: const Text('='),
              ),
              _buildDigitKey('00'),
              _buildDigitKey('0'),
              AddExpenseKeypadButton(
                onTap: _appendDecimal,
                child: const Text('.'),
              ),
              AddExpenseKeypadButton(
                onTap: () {
                  setState(() {
                    _showCalculator = false;
                    _amountFocusNode.requestFocus();
                  });
                },
                backgroundColor: const Color(0xFFF1F4FB),
                foregroundColor: AppColors.textDark,
                child: const Icon(Icons.keyboard_hide_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencySwitcher() {
    return PopupMenuButton<String>(
      initialValue: _selectedCurrency,
      onSelected: (val) {
        setState(() {
          _selectedCurrency = val;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F6FA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _selectedCurrency,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
      itemBuilder: (context) {
        return <PopupMenuEntry<String>>[
          const PopupMenuItem<String>(value: '₹', child: Text('₹')),
          const PopupMenuItem<String>(value: '\$', child: Text('\$')),
          const PopupMenuItem<String>(value: '€', child: Text('€')),
          const PopupMenuItem<String>(value: '£', child: Text('£')),
          const PopupMenuItem<String>(value: '¥', child: Text('¥')),
        ];
      },
    );
  }

  Widget _buildActionChip(String label) {
    // Extract base label for selection check and color coding
    final clean = label.replaceAll(RegExp(r'[^a-zA-Z]'), '').toLowerCase();
    String baseLabel = '';
    if (clean.contains('account')) {
      baseLabel = 'Account';
    } else if (clean.contains('category')) {
      baseLabel = 'Category';
    } else if (clean.contains('tags') || clean.contains('tag')) {
      baseLabel = 'Tags';
    } else if (clean.contains('splits') || clean.contains('split')) {
      baseLabel = 'Split';
    } else if (clean.contains('recurring') || clean.contains('repeat')) {
      baseLabel = 'Recurring';
    } else if (clean.contains('scan')) {
      baseLabel = 'Scan';
    }

    final isSelected = _activePreviewChip == baseLabel;

    Color accentColor;
    Color tintColor;
    switch (baseLabel) {
      case 'Account':
        accentColor = AppColors.primaryBlue;
        tintColor = const Color(0xFFEFF5FF);
        break;
      case 'Category':
        accentColor = _selectedType.isIncome ? AppColors.success : const Color(0xFFC23358);
        tintColor = _selectedType.isIncome ? const Color(0xFFE8F5E9) : const Color(0xFFFFF0F3);
        break;
      case 'Tags':
        accentColor = const Color(0xFF7C3AED); // Purple
        tintColor = const Color(0xFFF3E8FF);
        break;
      case 'Split':
        accentColor = const Color(0xFFF97316); // Orange
        tintColor = const Color(0xFFFFEDD5);
        break;
      case 'Scan':
        accentColor = const Color(0xFF0D9488); // Teal
        tintColor = const Color(0xFFE6F4F1);
        break;
      case 'Recurring':
      default:
        accentColor = const Color(0xFF4F46E5); // Indigo
        tintColor = const Color(0xFFEEF2FF);
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Material(
        color: isSelected ? accentColor : tintColor,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () {
            setState(() {
              _activePreviewChip = isSelected ? null : baseLabel;
            });
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : accentColor,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationChip() {
    final isSelected = _locationEnabled;
    const accentColor = AppColors.primaryBlue;
    const disabledBg = Color(0xFFF4F6FA);
    const disabledText = AppColors.textMuted;

    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Material(
        color: isSelected ? accentColor : disabledBg,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () {
            setState(() {
              _locationEnabled = !_locationEnabled;
            });
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSelected ? Icons.location_on : Icons.location_on_outlined,
                  size: 16,
                  color: isSelected ? Colors.white : disabledText,
                ),
                const SizedBox(width: 6),
                Text(
                  'Location',
                  style: TextStyle(
                    color: isSelected ? Colors.white : disabledText,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTipsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lightbulb_rounded, color: Colors.orangeAccent),
            SizedBox(width: 8),
            Text('Quick Tips'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You can type command symbols in the note field to quickly select fields:'),
            SizedBox(height: 12),
            Text('• @ = Account'),
            Text('• / = Category'),
            Text('• # = Tags'),
            Text('• + = Split'),
            Text('• ! = Recurring'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickUnifiedDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (pickedDate == null) return;
    if (!mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDate),
    );
    if (pickedTime == null) return;
    setState(() {
      _selectedDate = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Widget _buildUnifiedDateTimePicker() {
    return InkWell(
      onTap: _pickUnifiedDateTime,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF5FF),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.calendar_today_rounded,
              size: 16,
              color: AppColors.primaryBlue,
            ),
            const SizedBox(width: 8),
            Text(
              DateFormat('EEE, d MMM, h:mm a').format(_selectedDate),
              style: const TextStyle(
                color: AppColors.primaryBlue,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachPill() {
    if (_attachedImagePath != null) {
      return GestureDetector(
        onTap: _showAttachmentPreview,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF5FF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.primaryBlue.withValues(alpha: 0.3),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(
              File(_attachedImagePath!),
              width: 28,
              height: 28,
              fit: BoxFit.cover,
            ),
          ),
        ),
      );
    }
    if (_attachedFilePath != null) {
      return InkWell(
        onTap: _showAttachmentPreview,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF5FF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.primaryBlue.withValues(alpha: 0.3),
            ),
          ),
          child: const Icon(
            Icons.description_rounded,
            size: 16,
            color: AppColors.primaryBlue,
          ),
        ),
      );
    }
    return InkWell(
      onTap: _showAttachmentOptions,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Icon(
          Icons.attach_file_rounded,
          size: 16,
          color: AppColors.textMuted,
        ),
      ),
    );
  }

  Widget _buildVoicePill() {
    return InkWell(
      onTap: () async {
        final parsed = await showVoiceEntrySheet(context, returnResult: true);
        if (parsed != null && mounted) {
          setState(() {
            _amountExpression = formatAmountExpressionValue(parsed.amount);
            _selectedType = parsed.type;
            if (parsed.type == TransactionType.income) {
              _selectedIncomeCategory = parsed.category.isNotEmpty
                  ? parsed.category
                  : _selectedIncomeCategory;
            } else {
              _selectedExpenseCategory = parsed.category.isNotEmpty
                  ? parsed.category
                  : _selectedExpenseCategory;
            }
            if (parsed.note.isNotEmpty) {
              _noteController.text = parsed.note;
            }
            if (parsed.date != null) {
              _selectedDate = parsed.date!;
            }
            _syncAmountController();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Voice command imported successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Icon(
          Icons.mic_none_rounded,
          size: 16,
          color: AppColors.textMuted,
        ),
      ),
    );
  }

  Widget _buildCalcTogglePill() {
    return InkWell(
      onTap: () {
        setState(() {
          _showCalculator = !_showCalculator;
          _amountFocusNode.requestFocus();
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: _showCalculator
              ? const Color(0xFFEFF5FF)
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _showCalculator
                ? AppColors.primaryBlue.withValues(alpha: 0.3)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Icon(
          Icons.calculate_outlined,
          size: 16,
          color: _showCalculator
              ? AppColors.primaryBlue
              : AppColors.textMuted,
        ),
      ),
    );
  }

  Widget _buildDateTimeAndLocationRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          _buildUnifiedDateTimePicker(),
          const Spacer(),
          _buildAttachPill(),
          const SizedBox(width: 8),
          _buildVoicePill(),
          const SizedBox(width: 8),
          _buildCalcTogglePill(),
        ],
      ),
    );
  }

  Widget _buildAccountPreview(List<AccountModel> availableAccounts) {
    if (availableAccounts.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: Text(
            'No accounts available.',
            style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Account',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: availableAccounts.length,
              itemBuilder: (context, idx) {
                final acc = availableAccounts[idx];
                final isSelected = _selectedAccountId == acc.id;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(acc.name),
                    selected: isSelected,
                    avatar: Icon(
                      resolveAccountIcon(acc.iconKey),
                      size: 16,
                      color: isSelected ? Colors.white : AppColors.primaryBlue,
                    ),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                    selectedColor: AppColors.primaryBlue,
                    backgroundColor: Colors.white,
                    showCheckmark: false,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedAccountId = acc.id;
                          _hasExplicitAccountChoice = true;
                        }
                      });
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPreview(
    List<ExpenseCategory> availableExpenseCategories,
    List<ExpenseCategory> availableIncomeCategories,
  ) {
    final categories = _selectedType == TransactionType.income
        ? availableIncomeCategories
        : availableExpenseCategories;

    if (categories.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: Text(
            'No categories available.',
            style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    final activeColor = _selectedType.isIncome
        ? AppColors.success
        : const Color(0xFFC23358);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select ${_selectedType.name.toUpperCase()} Category',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              itemBuilder: (context, idx) {
                final cat = categories[idx];
                final isSelected = _selectedType == TransactionType.income
                    ? _selectedIncomeCategory == cat.name
                    : _selectedExpenseCategory == cat.name;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(cat.name),
                    selected: isSelected,
                    avatar: Icon(
                      cat.icon,
                      size: 16,
                      color: isSelected ? Colors.white : cat.color,
                    ),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                    selectedColor: activeColor,
                    backgroundColor: Colors.white,
                    showCheckmark: false,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          if (_selectedType == TransactionType.income) {
                            _selectedIncomeCategory = cat.name;
                          } else {
                            _selectedExpenseCategory = cat.name;
                          }
                        }
                      });
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagsPreview() {
    final popularTags = [
      'Food',
      'Travel',
      'Shopping',
      'Bills',
      'Entertainment',
      'Work',
      'Personal'
    ];
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Popular Tags (Tap to add to notes)',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: popularTags.map((tag) {
              return ActionChip(
                label: Text('#$tag'),
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: Color(0xFF7C3AED),
                ),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFDDD6FE)),
                ),
                onPressed: () {
                  final currentText = _noteController.text;
                  String cleanText = currentText;
                  if (cleanText.endsWith('#')) {
                    cleanText = cleanText.substring(0, cleanText.length - 1);
                  }
                  setState(() {
                    _noteController.text = '$cleanText#$tag ';
                    _noteController.selection = TextSelection.fromPosition(
                      TextPosition(offset: _noteController.text.length),
                    );
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSplitPreview() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Split Bill Settings',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Split bill module will allow you to divide expenses between friends. Tap to configure groups.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildScanPreview() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Scan Receipt',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Extract amount, date, and items automatically using OCR scanner.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.4),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D9488),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _launchScanner,
            icon: const Icon(Icons.camera_alt_rounded, size: 16),
            label: const Text('Launch Scanner', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildRecurringPreview() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recurring & Repeats',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Setup monthly subscriptions, scheduled bills, or recurring salary deposits here.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton({required bool canSubmit}) {
    final isUpi = widget.isPayMode && !_paymentDone;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: canSubmit ? 2 : 0,
        ),
        onPressed: canSubmit
            ? (isUpi ? _launchUpiPayment : _saveExpense)
            : null,
        icon: _isSaving || _isLaunching
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.check_rounded, size: 20),
        label: Text(
          isUpi ? 'Pay via UPI' : 'Save Transaction',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  AddExpenseKeypadButton _buildDigitKey(String value) {
    return AddExpenseKeypadButton(
      onTap: () => _appendDigit(value),
      child: Text(value),
    );
  }

  AddExpenseKeypadButton _buildOperatorKey(String operator) {
    return AddExpenseKeypadButton(
      onTap: () => _appendOperator(operator),
      backgroundColor: const Color(0xFFF1F4FB),
      foregroundColor: AppColors.textDark,
      child: Text(operator),
    );
  }

  void _handleNoteFocusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _queueDefaultSelections(
    List<AccountModel> availableAccounts,
    List<ExpenseCategory> availableExpenseCategories,
    List<ExpenseCategory> availableIncomeCategories,
  ) {
    if (widget.isEditing) {
      return;
    }
    final nextExpenseCategory = _resolveEnabledCategoryName(
      _selectedExpenseCategory,
      availableExpenseCategories,
    );
    final nextIncomeCategory = _resolveEnabledCategoryName(
      _selectedIncomeCategory,
      availableIncomeCategories,
    );
    final nextAccountId = _resolveEnabledAccountId(
      _selectedAccountId,
      availableAccounts,
    );
    final needsUpdate = nextExpenseCategory != _selectedExpenseCategory ||
        nextIncomeCategory != _selectedIncomeCategory ||
        nextAccountId != _selectedAccountId ||
        (!_hasExplicitAccountChoice && availableAccounts.isNotEmpty);

    if (!needsUpdate) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.isEditing) {
        return;
      }
      setState(() {
        _selectedExpenseCategory = nextExpenseCategory;
        _selectedIncomeCategory = nextIncomeCategory;
        _selectedAccountId = nextAccountId;
        _hasExplicitAccountChoice =
            _hasExplicitAccountChoice || availableAccounts.isNotEmpty;
        if (_selectedType == TransactionType.transfer) {
          _ensureTransferAccounts(availableAccounts);
        }
      });
    });
  }

  AccountModel? _resolveSelectedAccount(List<AccountModel> accounts) {
    if (accounts.isEmpty) {
      return null;
    }
    if (_hasExplicitAccountChoice && _selectedAccountId == null) {
      return null;
    }
    final desiredId = _selectedAccountId ?? widget.initialAccountId;
    if (desiredId == null) {
      return accounts.first;
    }
    for (final account in accounts) {
      if (account.id == desiredId) {
        return account;
      }
    }
    return accounts.first;
  }

  AccountModel? _resolveToAccount(List<AccountModel> accounts) {
    if (accounts.isEmpty || _toAccountId == null) {
      return null;
    }
    for (final account in accounts) {
      if (account.id == _toAccountId) {
        return account;
      }
    }
    return null;
  }

  String _resolveEnabledCategoryName(
    String currentValue,
    List<ExpenseCategory> availableCategories,
  ) {
    if (availableCategories.isEmpty) {
      return '';
    }
    for (final category in availableCategories) {
      if (category.name == currentValue) {
        return currentValue;
      }
    }
    return availableCategories.first.name;
  }

  String? _resolveEnabledAccountId(
    String? currentValue,
    List<AccountModel> availableAccounts,
  ) {
    if (availableAccounts.isEmpty) {
      return null;
    }
    for (final account in availableAccounts) {
      if (account.id == currentValue) {
        return currentValue;
      }
    }
    return availableAccounts.first.id;
  }


  String? _validationMessage({
    required AmountExpressionResult amountState,
    required AccountModel? selectedAccount,
    required AccountModel? toAccount,
  }) {
    if (_isSaving) {
      return null;
    }
    if (amountState.errorText case final String error) {
      return error;
    }
    if (_selectedType == TransactionType.expense &&
        _selectedExpenseCategory.isEmpty) {
      return 'Enable at least one expense category.';
    }
    if (_selectedType == TransactionType.income &&
        _selectedIncomeCategory.isEmpty) {
      return 'Enable at least one income category.';
    }
    if (_selectedType == TransactionType.transfer) {
      if (selectedAccount == null || toAccount == null) {
        return 'Choose both accounts.';
      }
      if (selectedAccount.id == toAccount.id) {
        return 'Pick two different accounts.';
      }
    }
    return null;
  }

  bool _canSubmit({
    required AmountExpressionResult amountState,
    required AccountModel? selectedAccount,
    required AccountModel? toAccount,
  }) {
    return !_isSaving &&
        amountState.canSubmit &&
        _validationMessage(
              amountState: amountState,
              selectedAccount: selectedAccount,
              toAccount: toAccount,
            ) ==
            null;
  }

  void _syncAmountController() {
    _amountController.text = _amountExpression;
    _amountController.selection = TextSelection.fromPosition(
      TextPosition(offset: _amountExpression.length),
    );
  }

  void _appendDigit(String value) {
    setState(() {
      if (_amountExpression == '0' || _amountExpression.isEmpty) {
        if (value == '00') return;
        _amountExpression = value;
        return;
      }

      final currentSegment = _currentSegment(_amountExpression);
      if (currentSegment == '0') {
        if (value == '00') return;
        _amountExpression =
            _amountExpression.substring(0, _amountExpression.length - 1) +
                value;
        return;
      }

      if (currentSegment.isEmpty && _endsWithOperator(_amountExpression)) {
        _amountExpression += value;
        return;
      }

      _amountExpression += value;
    });
    _syncAmountController();
  }

  void _appendDecimal() {
    setState(() {
      final currentSegment = _currentSegment(_amountExpression);
      if (currentSegment.contains('.')) {
        return;
      }
      if (_amountExpression == '0' || _amountExpression.isEmpty) {
        _amountExpression = '0.';
        return;
      }
      if (_endsWithOperator(_amountExpression)) {
        _amountExpression += '0.';
        return;
      }
      _amountExpression += '.';
    });
    _syncAmountController();
  }

  void _appendOperator(String operator) {
    setState(() {
      if (_amountExpression.isEmpty || _amountExpression == '0') {
        return;
      }
      if (_endsWithOperator(_amountExpression)) {
        _amountExpression =
            '${_amountExpression.substring(0, _amountExpression.length - 1)}$operator';
        return;
      }
      if (_amountExpression.endsWith('.')) {
        _amountExpression += '0';
      }
      _amountExpression += operator;
    });
    _syncAmountController();
  }

  void _applyExpression() {
    final result = evaluateAmountExpression(_amountExpression);
    if (!result.canEvaluate) {
      return;
    }
    setState(() {
      _amountExpression = formatAmountExpressionValue(result.amount);
    });
    _syncAmountController();
  }

  void _backspace() {
    setState(() {
      if (_amountExpression.length <= 1) {
        _amountExpression = '';
        return;
      }
      _amountExpression =
          _amountExpression.substring(0, _amountExpression.length - 1);
    });
    _syncAmountController();
  }

  void _clearAmount() {
    setState(() {
      _amountExpression = '';
    });
    _syncAmountController();
  }

  String _currentSegment(String expression) {
    final plusIndex = expression.lastIndexOf('+');
    final minusIndex = expression.lastIndexOf('-');
    final multIndex = expression.lastIndexOf('*');
    final divIndex = expression.lastIndexOf('/');
    
    int maxIndex = plusIndex;
    if (minusIndex > maxIndex) maxIndex = minusIndex;
    if (multIndex > maxIndex) maxIndex = multIndex;
    if (divIndex > maxIndex) maxIndex = divIndex;
    
    if (maxIndex == -1) {
      return expression;
    }
    return expression.substring(maxIndex + 1);
  }

  bool _endsWithOperator(String expression) {
    return expression.endsWith('+') ||
        expression.endsWith('-') ||
        expression.endsWith('*') ||
        expression.endsWith('/');
  }

  void _switchType(TransactionType type) {
    if (_selectedType == type) {
      return;
    }

    final accounts =
        ref.read(accountListProvider).value ?? const <AccountModel>[];
    final disabledExpenseCategories =
        ref.read(disabledExpenseCategoriesProvider);
    final disabledIncomeCategories = ref.read(disabledIncomeCategoriesProvider);
    final disabledAccountIds = ref.read(disabledAccountIdsProvider);
    final allExpenseCategories = ref.read(allExpenseCategoriesProvider);
    final allIncomeCategories = ref.read(allIncomeCategoriesProvider);
    final availableExpenseCategories = allExpenseCategories
        .where((category) => !disabledExpenseCategories.contains(category.name))
        .toList(growable: false);
    final availableIncomeCategories = allIncomeCategories
        .where((category) => !disabledIncomeCategories.contains(category.name))
        .toList(growable: false);
    final availableAccounts = accounts
        .where((account) => !disabledAccountIds.contains(account.id))
        .toList(growable: false);

    setState(() {
      _selectedType = type;
      if (type == TransactionType.transfer) {
        _ensureTransferAccounts(availableAccounts);
      }
      if (type != TransactionType.transfer) {
        _selectedExpenseCategory = _resolveEnabledCategoryName(
          _selectedExpenseCategory,
          availableExpenseCategories,
        );
      }
      if (type == TransactionType.income) {
        _selectedIncomeCategory = _resolveEnabledCategoryName(
          _selectedIncomeCategory,
          availableIncomeCategories,
        );
      }
    });
  }

  void _ensureTransferAccounts(List<AccountModel> accounts) {
    if (accounts.isEmpty) {
      return;
    }

    _selectedAccountId ??= accounts.first.id;
    if (_toAccountId == null || _toAccountId == _selectedAccountId) {
      for (final account in accounts) {
        if (account.id != _selectedAccountId) {
          _toAccountId = account.id;
          return;
        }
      }
      _toAccountId = accounts.first.id;
    }
  }


  Future<void> _launchUpiPayment() async {
    if (_isLaunching || widget.payUpiUri == null) return;

    final baseUri = Uri.parse(widget.payUpiUri!);
    final params = Map<String, String>.from(baseUri.queryParameters);

    // Validate that payee VPA (pa) is present — mandatory for any UPI app.
    final paRaw = params['pa'];
    final pa = paRaw?.trim() ?? '';
    if (pa.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid QR: payee UPI ID is missing.'),
        ),
      );
      return;
    }

    // Build a "safe" launch URI with ONLY pa + pn.
    // Omitting am/tn/cu avoids the fraud-score spike that most UPI apps
    // apply to externally-prefilled payment requests.  The user enters the
    // amount themselves inside their trusted payment app.
    final safeParams = <String, String>{'pa': pa};
    final pn = params['pn']?.trim();
    if (pn != null && pn.isNotEmpty) safeParams['pn'] = pn;

    final launchUri = Uri(
      scheme: baseUri.scheme,
      host: baseUri.host,
      path: baseUri.path,
      queryParameters: safeParams,
    );

    final payeeName = pn ?? pa;
    final amountState = evaluateAmountExpression(_amountExpression);
    // Build an optional hint shown in the dialog body. Leading space is
    // intentional — it is appended directly to the "pay $payeeName." sentence.
    final amountHint = amountState.previewAmount > 0
        ? ' Enter ₹${amountState.previewAmount.toStringAsFixed(2)} when prompted.'
        : '';

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Open UPI App'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Your UPI app will open to pay $payeeName.$amountHint',
            ),
            const SizedBox(height: 8),
            Text(
              'UPI ID: $pa',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Open'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLaunching = true);

    final launched = await launchUrl(
      launchUri,
      mode: LaunchMode.externalApplication,
    );

    if (!mounted) return;

    if (!launched) {
      setState(() => _isLaunching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No UPI app found. Please install Google Pay, '
              'PhonePe, or Paytm.'),
        ),
      );
    }
    // If launched, _isLaunching stays true until didChangeAppLifecycleState
    // fires on resume, which schedules the "Payment Complete?" dialog.
  }

  Future<void> _saveExpense() async {
    if (_isSaving) {
      return;
    }

    final amountState = evaluateAmountExpression(_amountExpression);
    final accounts =
        ref.read(accountListProvider).value ?? const <AccountModel>[];
    final disabledAccountIds = ref.read(disabledAccountIdsProvider);
    final selectionAccounts = widget.isEditing
        ? accounts
        : accounts
            .where((account) => !disabledAccountIds.contains(account.id))
            .toList(growable: false);
    final selectedAccount = _resolveSelectedAccount(selectionAccounts);
    final toAccount = _resolveToAccount(selectionAccounts);
    final validationMessage = _validationMessage(
      amountState: amountState,
      selectedAccount: selectedAccount,
      toAccount: toAccount,
    );

    if (validationMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validationMessage)));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final controller = ref.read(expenseControllerProvider);
      if (_selectedType == TransactionType.transfer) {
        if (widget.isEditing) {
          await controller.updateExpense(
            id: widget.expenseId!,
            amount: amountState.amount,
            category: 'Transfer',
            date: _selectedDate,
            note: _noteController.text,
            accountId: selectedAccount?.id,
            toAccountId: toAccount?.id,
            type: TransactionType.transfer,
          );
        } else {
          await controller.addTransfer(
            amount: amountState.amount,
            fromAccountId: selectedAccount!.id,
            toAccountId: toAccount!.id,
            date: _selectedDate,
            note: _noteController.text,
          );
        }
      } else if (widget.isEditing) {
        await controller.updateExpense(
          id: widget.expenseId!,
          amount: amountState.amount,
          category: _selectedType.isIncome
              ? _selectedIncomeCategory
              : _selectedExpenseCategory,
          date: _selectedDate,
          note: _noteController.text,
          accountId: selectedAccount?.id,
          type: _selectedType,
        );
      } else {
        await controller.addExpense(
          amount: amountState.amount,
          category: _selectedType.isIncome
              ? _selectedIncomeCategory
              : _selectedExpenseCategory,
          date: _selectedDate,
          note: _noteController.text,
          accountId: selectedAccount?.id,
          type: _selectedType,
        );
      }

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primaryBlue),
                title: const Text('Click', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Take a photo with camera'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickFromCamera();
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder_open_rounded, color: AppColors.primaryBlue),
                title: const Text('Pick', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Choose from gallery or files'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickFromGallery();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickFromCamera() async {
    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(source: ImageSource.camera);
      if (photo != null) {
        setState(() {
          _attachedImagePath = photo.path;
          _attachedFilePath = photo.name;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error taking photo: $e'),
            backgroundColor: const Color(0xFFC23358),
          ),
        );
      }
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _attachedImagePath = image.path;
          _attachedFilePath = image.name;
        });
        return;
      }
    } catch (_) {}
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null) {
        setState(() {
          _attachedFilePath = result.files.single.name;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking file: $e'),
            backgroundColor: const Color(0xFFC23358),
          ),
        );
      }
    }
  }

  void _showAttachmentPreview() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    setState(() {
                      _attachedImagePath = null;
                      _attachedFilePath = null;
                    });
                  },
                ),
              ],
            ),
            Expanded(
              child: _attachedImagePath != null
                  ? InteractiveViewer(
                      child: Center(
                        child: Image.file(
                          File(_attachedImagePath!),
                          fit: BoxFit.contain,
                        ),
                      ),
                    )
                  : Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.description_rounded, color: Colors.white54, size: 48),
                          const SizedBox(height: 12),
                          Text(
                            _attachedFilePath ?? '',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchScanner() async {
    final result = await AppRoutes.pushUnifiedScanner(context, returnResult: true);
    if (result != null && mounted) {
      setState(() {
        if (result['amount'] != null) {
          final amt = result['amount'];
          _amountExpression = formatAmountExpressionValue(amt is double ? amt : double.parse(amt.toString()));
          _syncAmountController();
        }
        if (result['note'] != null) {
          _noteController.text = result['note'].toString();
        }
        if (result['category'] != null) {
          final cat = result['category'].toString();
          if (_selectedType == TransactionType.income) {
            _selectedIncomeCategory = cat;
          } else {
            _selectedExpenseCategory = cat;
          }
        }
        if (result['type'] != null && result['type'] is TransactionType) {
          _selectedType = result['type'] as TransactionType;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scan results imported successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }
}


