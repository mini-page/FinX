import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
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
import 'package:xpens/features/tags/tags.dart';
import '../../../../shared/widgets/currency_selector_sheet.dart';
import '../../../../shared/widgets/app_search_bar.dart';

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
    this.initialSubcategory,
    this.initialLatitude,
    this.initialLongitude,
  });

  final String? expenseId;
  final double? initialAmount;
  final String? initialCategory;
  final DateTime? initialDate;
  final String? initialNote;
  final String? initialAccountId;
  final String? initialToAccountId;
  final TransactionType initialType;
  final String? initialSubcategory;
  final double? initialLatitude;
  final double? initialLongitude;

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
  String? _selectedSubcategory;
  bool _isSaving = false;

  // Custom visual state variables for the redesigned layout
  bool _showCalculator = false;
  String? _activePreviewChip;
  bool _locationEnabled = false;
  double? _latitude;
  double? _longitude;
  bool _isFetchingLocation = false;
  String? _attachedFilePath;
  String? _attachedImagePath;
  late String _selectedCurrency;
  bool _shorthandExpandedFlash = false;

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
    _selectedSubcategory = widget.initialSubcategory;
    _locationEnabled = widget.initialLatitude != null && widget.initialLongitude != null;
    _latitude = widget.initialLatitude;
    _longitude = widget.initialLongitude;
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

  void _applyTagShorthand(TagShorthandModel tag) {
    HapticFeedback.mediumImpact();
    setState(() {
      _shorthandExpandedFlash = true;
    });
    Timer(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _shorthandExpandedFlash = false;
        });
      }
    });

    setState(() {
      if (tag.amount != null && tag.amount! > 0) {
        _amountExpression = formatAmountExpressionValue(tag.amount!);
        _amountController.text = _amountExpression;
      }
      if (tag.accountId != null) {
        _selectedAccountId = tag.accountId;
        _hasExplicitAccountChoice = true;
      }
      if (tag.categoryName != null) {
        final allExpense = ref.read(allExpenseCategoriesProvider);
        final isExpenseCategory = allExpense.any((c) => c.name == tag.categoryName);
        if (isExpenseCategory) {
          _selectedType = TransactionType.expense;
          _selectedExpenseCategory = tag.categoryName!;
        } else {
          final allIncome = ref.read(allIncomeCategoriesProvider);
          final isIncomeCategory = allIncome.any((c) => c.name == tag.categoryName);
          if (isIncomeCategory) {
            _selectedType = TransactionType.income;
            _selectedIncomeCategory = tag.categoryName!;
          } else {
            _selectedType = TransactionType.expense;
            _selectedExpenseCategory = tag.categoryName!;
          }
        }
      }
      if (tag.subcategoryName != null) {
        _selectedSubcategory = tag.subcategoryName;
      }
      if (tag.note != null && tag.note!.isNotEmpty) {
        _noteController.text = tag.note!;
        _noteController.selection = TextSelection.fromPosition(
          TextPosition(offset: _noteController.text.length),
        );
      }
    });
  }

  List<TagShorthandModel> _getMatchingShorthands() {
    final text = _noteController.text;
    if (!text.contains('?')) return const [];
    
    // Find the last segment starting with '?'
    final parts = text.split(RegExp(r'\s+'));
    final lastPart = parts.isNotEmpty ? parts.last : '';
    if (!lastPart.startsWith('?')) return const [];
    
    final query = lastPart.substring(1).toLowerCase();
    final allShorthands = ref.read(tagShorthandControllerProvider);
    
    if (query.isEmpty) {
      return allShorthands;
    }
    
    return allShorthands.where((tag) => tag.name.toLowerCase().contains(query)).toList();
  }

  void _selectShorthandSuggestion(TagShorthandModel tag) {
    final text = _noteController.text;
    final parts = text.split(RegExp(r'\s+'));
    if (parts.isNotEmpty) {
      final lastPart = parts.last;
      if (lastPart.startsWith('?')) {
        final textBeforeHash = text.substring(0, text.lastIndexOf(lastPart)).trim();
        _applyTagShorthand(tag);
        if (tag.note == null || tag.note!.isEmpty) {
          _noteController.text = textBeforeHash;
          _noteController.selection = TextSelection.fromPosition(
            TextPosition(offset: _noteController.text.length),
          );
        }
      }
    }
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
      setState(() {});
      return;
    }
    _tipsTimer.cancel();

    // Check tag shorthands for auto-expansion
    final shorthands = ref.read(tagShorthandControllerProvider);
    for (final tag in shorthands) {
      final trigger = '?${tag.name}';
      if (text.endsWith('$trigger ') || text == trigger) {
        final cleanText = text.substring(0, text.length - trigger.length).trim();
        _applyTagShorthand(tag);
        if (tag.note == null || tag.note!.isEmpty) {
          _noteController.text = cleanText;
          _noteController.selection = TextSelection.fromPosition(
            TextPosition(offset: _noteController.text.length),
          );
        }
        break;
      }
    }

    if (text.endsWith('@')) {
      setState(() => _activePreviewChip = 'Account');
    } else if (text.endsWith('/')) {
      setState(() => _activePreviewChip = 'Category');
    } else if (text.endsWith('?')) {
      setState(() => _activePreviewChip = 'Tags');
    } else if (text.endsWith('+')) {
      setState(() => _activePreviewChip = 'Split');
    } else if (text.endsWith('!')) {
      setState(() => _activePreviewChip = 'Recurring');
    } else {
      setState(() {});
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
    final subcategoriesMap = ref.watch(categorySubcategoriesProvider);
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
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      decoration: BoxDecoration(
                        color: _shorthandExpandedFlash 
                            ? AppColors.primaryBlue.withValues(alpha: 0.05) 
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _shorthandExpandedFlash 
                              ? AppColors.primaryBlue 
                              : const Color(0xFFE2E8F0),
                          width: _shorthandExpandedFlash ? 1.5 : 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _shorthandExpandedFlash
                                ? AppColors.primaryBlue.withValues(alpha: 0.1)
                                : const Color(0x0A000000),
                            blurRadius: _shorthandExpandedFlash ? 20 : 16,
                            offset: const Offset(0, 4),
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
                              if (_noteFocusNode.hasFocus && _getMatchingShorthands().isNotEmpty) ...[
                                SizedBox(
                                  height: 38,
                                  child: ListView(
                                    scrollDirection: Axis.horizontal,
                                    children: _getMatchingShorthands().map((tag) {
                                      return Padding(
                                        padding: const EdgeInsets.only(right: 8.0),
                                        child: ActionChip(
                                          label: Text('?${tag.name}'),
                                          labelStyle: const TextStyle(
                                            color: Color(0xFF475569),
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                          ),
                                          backgroundColor: const Color(0xFFF1F5F9),
                                          shape: const StadiumBorder(
                                            side: BorderSide(color: Color(0xFFE2E8F0)),
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                          onPressed: () {
                                            HapticFeedback.lightImpact();
                                            _selectShorthandSuggestion(tag);
                                          },
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
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
                              _buildAttachmentPreviewCard(),
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
                        _buildCategoryPreview(availableExpenseCategories, availableIncomeCategories, subcategoriesMap),
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
    return InkWell(
      onTap: () async {
        final selected = await showCurrencySelectorSheet(context, _selectedCurrency);
        if (selected != null) {
          setState(() {
            _selectedCurrency = selected;
          });
        }
      },
      borderRadius: BorderRadius.circular(12),
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
    final isFetching = _isFetchingLocation;
    const accentColor = AppColors.primaryBlue;
    const disabledBg = Color(0xFFF4F6FA);
    const disabledText = AppColors.textMuted;

    String labelText = 'Location';
    if (isFetching) {
      labelText = 'Fetching...';
    } else if (isSelected && _latitude != null && _longitude != null) {
      labelText = '${_latitude!.toStringAsFixed(2)}, ${_longitude!.toStringAsFixed(2)}';
    }

    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Material(
        color: isSelected ? accentColor : disabledBg,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: isFetching ? null : _toggleLocation,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isFetching) ...[
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.0,
                      valueColor: AlwaysStoppedAnimation<Color>(disabledText),
                    ),
                  ),
                ] else ...[
                  Icon(
                    isSelected ? Icons.location_on : Icons.location_on_outlined,
                    size: 16,
                    color: isSelected ? Colors.white : disabledText,
                  ),
                ],
                const SizedBox(width: 6),
                Text(
                  labelText,
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

  Future<void> _toggleLocation() async {
    if (_locationEnabled) {
      setState(() {
        _locationEnabled = false;
        _latitude = null;
        _longitude = null;
      });
      return;
    }

    setState(() {
      _isFetchingLocation = true;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location services are disabled. Please enable location services.'),
          ),
        );
        setState(() {
          _isFetchingLocation = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied.')),
          );
          setState(() {
            _isFetchingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permissions are permanently denied. Please enable them in system settings.'),
          ),
        );
        setState(() {
          _isFetchingLocation = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );

      if (!mounted) return;
      setState(() {
        _locationEnabled = true;
        _latitude = position.latitude;
        _longitude = position.longitude;
        _isFetchingLocation = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Location acquired: ${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isFetchingLocation = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch location: $e')),
      );
    }
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

  Widget _buildAttachmentPreviewCard() {
    if (_attachedImagePath == null && _attachedFilePath == null) {
      return const SizedBox.shrink();
    }

    final hasImage = _attachedImagePath != null;

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            if (hasImage)
              Image.file(
                File(_attachedImagePath!),
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
              )
            else
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.description_rounded, size: 36, color: AppColors.primaryBlue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _attachedFilePath ?? 'Document File',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            
            // Subtle black overlay on the image for visibility
            if (hasImage)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.2),
                      Colors.black.withOpacity(0.5),
                    ],
                  ),
                ),
              ),

            // Left overlay actions (Edit, Delete)
            Positioned(
              left: 12,
              bottom: 12,
              child: Row(
                children: [
                  // Edit Button
                  GestureDetector(
                    onTap: _showAttachmentOptions,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Delete Button
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _attachedImagePath = null;
                        _attachedFilePath = null;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.8),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Right overlay actions (Fullscreen view)
            Positioned(
              right: 12,
              bottom: 12,
              child: GestureDetector(
                onTap: _showAttachmentPreview,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.open_in_full_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'View',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
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
              itemCount: availableAccounts.length + 1,
              itemBuilder: (context, idx) {
                if (idx == availableAccounts.length) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ActionChip(
                      label: const Text('🔍 Search & Select'),
                      avatar: const Icon(
                        Icons.search,
                        size: 16,
                        color: AppColors.primaryBlue,
                      ),
                      labelStyle: const TextStyle(
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                      backgroundColor: Colors.white,
                      shape: const StadiumBorder(),
                      side: const BorderSide(color: AppColors.primaryBlue),
                      onPressed: () {
                        _showAccountSelectorSheet(context, availableAccounts);
                      },
                    ),
                  );
                }
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
    Map<String, List<String>> subcategoriesMap,
  ) {
    final categories = _selectedType == TransactionType.income
        ? availableIncomeCategories
        : availableExpenseCategories;

    final selectedCategory = _selectedType == TransactionType.income
        ? _selectedIncomeCategory
        : _selectedExpenseCategory;
    final subcats = subcategoriesMap[selectedCategory] ?? const <String>[];

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
              itemCount: categories.length + 1,
              itemBuilder: (context, idx) {
                if (idx == categories.length) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ActionChip(
                      label: const Text('🔍 Search & Select'),
                      avatar: Icon(
                        Icons.search,
                        size: 16,
                        color: activeColor,
                      ),
                      labelStyle: TextStyle(
                        color: activeColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                      backgroundColor: Colors.white,
                      shape: const StadiumBorder(),
                      side: BorderSide(color: activeColor),
                      onPressed: () {
                        _showCategorySelectorSheet(context, availableExpenseCategories, availableIncomeCategories, subcategoriesMap);
                      },
                    ),
                  );
                }
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
                          _selectedSubcategory = null;
                        }
                      });
                    },
                  ),
                );
              },
            ),
          ),
          if (subcats.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: Color(0xFFE2E8F0), height: 1),
            const SizedBox(height: 12),
            Text(
              'Select $selectedCategory Items',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: subcats.length,
                itemBuilder: (context, idx) {
                  final sub = subcats[idx];
                  final isSelected = _selectedSubcategory == sub;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      label: Text(sub),
                      selected: isSelected,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textDark,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                      selectedColor: activeColor,
                      backgroundColor: Colors.white,
                      checkmarkColor: Colors.white,
                      showCheckmark: false,
                      shape: StadiumBorder(
                        side: BorderSide(
                          color: isSelected ? Colors.transparent : const Color(0xFFE2E8F0),
                        ),
                      ),
                      padding: EdgeInsets.zero,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedSubcategory = sub;
                          } else {
                            _selectedSubcategory = null;
                          }
                        });
                      },
                    ),
                  );
                },
              ),
            ),
          ],
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

    final shorthands = ref.watch(tagShorthandControllerProvider);

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
          if (shorthands.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Custom Shorthands (Autofills details)',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.textDark,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showTagsSelectorSheet(context),
                  icon: const Icon(Icons.search, size: 16),
                  label: const Text('Search'),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: shorthands.map((tag) {
                return ActionChip(
                  label: Text('?${tag.name}'),
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: Color(0xFF475569),
                  ),
                  backgroundColor: const Color(0xFFF1F5F9),
                  shape: const StadiumBorder(
                    side: BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  onPressed: () => _applyTagShorthand(tag),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            const Divider(color: Color(0xFFE2E8F0), height: 1),
            const SizedBox(height: 16),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Popular Tags (Tap to add to notes)',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: AppColors.textDark,
                ),
              ),
              if (shorthands.isEmpty)
                TextButton.icon(
                  onPressed: () => _showTagsSelectorSheet(context),
                  icon: const Icon(Icons.search, size: 16),
                  label: const Text('Search'),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
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
                shape: const StadiumBorder(),
                side: const BorderSide(color: Color(0xFFDDD6FE)),
                onPressed: () {
                  final currentText = _noteController.text;
                  String cleanText = currentText;
                  if (cleanText.endsWith('?')) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Split Bill Settings',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: AppColors.textDark,
                ),
              ),
              TextButton.icon(
                onPressed: () => _showSplitSelectorSheet(context),
                icon: const Icon(Icons.edit_road_rounded, size: 16),
                label: const Text('Configure'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Split bill module will allow you to divide expenses between friends. Tap Configure to edit splits.',
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
            latitude: _locationEnabled ? _latitude : null,
            longitude: _locationEnabled ? _longitude : null,
          );
        } else {
          await controller.addTransfer(
            amount: amountState.amount,
            fromAccountId: selectedAccount!.id,
            toAccountId: toAccount!.id,
            date: _selectedDate,
            note: _noteController.text,
            latitude: _locationEnabled ? _latitude : null,
            longitude: _locationEnabled ? _longitude : null,
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
          subcategory: _selectedSubcategory,
          latitude: _locationEnabled ? _latitude : null,
          longitude: _locationEnabled ? _longitude : null,
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
          subcategory: _selectedSubcategory,
          latitude: _locationEnabled ? _latitude : null,
          longitude: _locationEnabled ? _longitude : null,
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

  void _showAccountSelectorSheet(BuildContext context, List<AccountModel> accountsList) {
    final currencyFormat = ref.read(currencyFormatProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return _AccountSelectorSheetContent(
          accountsList: accountsList,
          selectedAccountId: _selectedAccountId,
          currencyFormat: currencyFormat,
          onSelected: (accId) {
            setState(() {
              _selectedAccountId = accId;
              _hasExplicitAccountChoice = true;
            });
            Navigator.pop(ctx);
          },
        );
      },
    );
  }

  void _showCategorySelectorSheet(
    BuildContext context,
    List<ExpenseCategory> availableExpenseCategories,
    List<ExpenseCategory> availableIncomeCategories,
    Map<String, List<String>> subcategoriesMap,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return _CategorySelectorSheetContent(
          expenseCategories: availableExpenseCategories,
          incomeCategories: availableIncomeCategories,
          subcategoriesMap: subcategoriesMap,
          initialType: _selectedType,
          selectedExpenseCategory: _selectedExpenseCategory,
          selectedIncomeCategory: _selectedIncomeCategory,
          selectedSubcategory: _selectedSubcategory,
          onSelected: (type, category, subcategory) {
            setState(() {
              _selectedType = type;
              if (type == TransactionType.income) {
                _selectedIncomeCategory = category;
              } else {
                _selectedExpenseCategory = category;
              }
              _selectedSubcategory = subcategory;
            });
          },
        );
      },
    );
  }

  void _showTagsSelectorSheet(BuildContext context) {
    final shorthands = ref.read(tagShorthandControllerProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return _TagsSelectorSheetContent(
          shorthands: shorthands,
          onSelectShorthand: (tag) {
            _applyTagShorthand(tag);
            Navigator.pop(ctx);
          },
          onSelectPopularTag: (tag) {
            final currentText = _noteController.text;
            String cleanText = currentText;
            if (cleanText.endsWith('?')) {
              cleanText = cleanText.substring(0, cleanText.length - 1);
            }
            setState(() {
              _noteController.text = '$cleanText#$tag ';
              _noteController.selection = TextSelection.fromPosition(
                TextPosition(offset: _noteController.text.length),
              );
            });
            Navigator.pop(ctx);
          },
        );
      },
    );
  }

  void _showSplitSelectorSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return _SplitSelectorSheetContent(
          onConfigured: () {
            HapticFeedback.lightImpact();
          },
        );
      },
    );
  }
}

class _AccountSelectorSheetContent extends StatefulWidget {
  const _AccountSelectorSheetContent({
    required this.accountsList,
    required this.selectedAccountId,
    required this.onSelected,
    required this.currencyFormat,
  });

  final List<AccountModel> accountsList;
  final String? selectedAccountId;
  final ValueChanged<String> onSelected;
  final NumberFormat currencyFormat;

  @override
  State<_AccountSelectorSheetContent> createState() => _AccountSelectorSheetContentState();
}

class _AccountSelectorSheetContentState extends State<_AccountSelectorSheetContent> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final filtered = widget.accountsList.where((acc) {
      return acc.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPadding + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Select Account',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textDark),
          ),
          const SizedBox(height: 4),
          const Text(
            'Choose the account for this transaction.',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          AppSearchBar(
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
              });
            },
            onClear: () {
              setState(() {
                _searchQuery = '';
              });
            },
            hintText: 'Search account...',
            hasBorder: true,
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.4,
            ),
            child: filtered.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.0),
                      child: Text(
                        'No accounts found.',
                        style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600),
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final acc = filtered[index];
                      final isSelected = widget.selectedAccountId == acc.id;
                      return GestureDetector(
                        onTap: () => widget.onSelected(acc.id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primaryBlue.withOpacity(0.04) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? AppColors.primaryBlue : const Color(0xFFE2E8F0),
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.primaryBlue.withOpacity(0.1) : const Color(0xFFF1F5F9),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  resolveAccountIcon(acc.iconKey),
                                  color: isSelected ? AppColors.primaryBlue : AppColors.textDark,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      acc.name,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textDark,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Balance: ${widget.currencyFormat.format(acc.balance)}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textMuted,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.primaryBlue,
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
    );
  }
}

class _CategorySelectorSheetContent extends StatefulWidget {
  const _CategorySelectorSheetContent({
    required this.expenseCategories,
    required this.incomeCategories,
    required this.subcategoriesMap,
    required this.initialType,
    required this.selectedExpenseCategory,
    required this.selectedIncomeCategory,
    required this.selectedSubcategory,
    required this.onSelected,
  });

  final List<ExpenseCategory> expenseCategories;
  final List<ExpenseCategory> incomeCategories;
  final Map<String, List<String>> subcategoriesMap;
  final TransactionType initialType;
  final String selectedExpenseCategory;
  final String selectedIncomeCategory;
  final String? selectedSubcategory;
  final Function(TransactionType type, String category, String? subcategory) onSelected;

  @override
  State<_CategorySelectorSheetContent> createState() => _CategorySelectorSheetContentState();
}

class _CategorySelectorSheetContentState extends State<_CategorySelectorSheetContent> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  String? _tempSelectedCategory;
  String? _tempSelectedSubcategory;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialType == TransactionType.income ? 1 : 0,
    );
    _tempSelectedCategory = widget.initialType == TransactionType.income
        ? widget.selectedIncomeCategory
        : widget.selectedExpenseCategory;
    _tempSelectedSubcategory = widget.selectedSubcategory;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPadding + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Select Category',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textDark),
          ),
          const SizedBox(height: 16),
          
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0F000000),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              labelColor: AppColors.textDark,
              unselectedLabelColor: AppColors.textMuted,
              labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              onTap: (index) {
                setState(() {
                  _tempSelectedCategory = null;
                  _tempSelectedSubcategory = null;
                });
              },
              tabs: const [
                Tab(text: 'Expense'),
                Tab(text: 'Income'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          AppSearchBar(
            onChanged: (val) {
              setState(() {
                _searchQuery = val.trim().toLowerCase();
              });
            },
            onClear: () {
              setState(() {
                _searchQuery = '';
              });
            },
            hintText: 'Search categories...',
            hasBorder: true,
          ),
          const SizedBox(height: 16),

          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.45,
            ),
            child: AnimatedBuilder(
              animation: _tabController,
              builder: (context, _) {
                final isIncome = _tabController.index == 1;
                final categories = isIncome ? widget.incomeCategories : widget.expenseCategories;
                
                final filtered = categories.where((cat) {
                  return cat.name.toLowerCase().contains(_searchQuery);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.0),
                      child: Text(
                        'No categories found.',
                        style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600),
                      ),
                    ),
                  );
                }

                final activeColor = isIncome ? AppColors.success : const Color(0xFFC23358);

                return ListView.separated(
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, idx) {
                    final cat = filtered[idx];
                    final isSelectedCategory = _tempSelectedCategory == cat.name;
                    final subcategories = widget.subcategoriesMap[cat.name] ?? const <String>[];

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: isSelectedCategory ? activeColor.withOpacity(0.04) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelectedCategory ? activeColor : const Color(0xFFE2E8F0),
                          width: isSelectedCategory ? 1.5 : 1.0,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: cat.color.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(cat.icon, color: cat.color, size: 18),
                            ),
                            title: Text(
                              cat.name,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textDark),
                            ),
                            trailing: isSelectedCategory
                                ? Icon(Icons.check_circle_rounded, color: activeColor, size: 20)
                                : const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                            onTap: () {
                              setState(() {
                                _tempSelectedCategory = cat.name;
                                _tempSelectedSubcategory = null;
                              });
                              if (subcategories.isEmpty) {
                                widget.onSelected(
                                  isIncome ? TransactionType.income : TransactionType.expense,
                                  cat.name,
                                  null,
                                );
                              }
                            },
                          ),
                          
                          if (isSelectedCategory && subcategories.isNotEmpty) ...[
                            const Divider(color: Color(0xFFE2E8F0), height: 1),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Select Subcategory / Item (Optional)',
                                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      ...subcategories.map((sub) {
                                        final isSubSelected = _tempSelectedSubcategory == sub;
                                        return ChoiceChip(
                                          label: Text(sub),
                                          selected: isSubSelected,
                                          labelStyle: TextStyle(
                                            color: isSubSelected ? Colors.white : AppColors.textDark,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 11,
                                          ),
                                          selectedColor: activeColor,
                                          backgroundColor: const Color(0xFFF1F5F9),
                                          side: BorderSide.none,
                                          shape: const StadiumBorder(),
                                          showCheckmark: false,
                                          onSelected: (selected) {
                                            setState(() {
                                              _tempSelectedSubcategory = selected ? sub : null;
                                            });
                                            widget.onSelected(
                                              isIncome ? TransactionType.income : TransactionType.expense,
                                              cat.name,
                                              _tempSelectedSubcategory,
                                            );
                                          },
                                        );
                                      }),
                                      
                                      ChoiceChip(
                                        label: const Text('None / Select Category Only'),
                                        selected: false,
                                        labelStyle: TextStyle(
                                          color: activeColor,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 11,
                                        ),
                                        backgroundColor: activeColor.withOpacity(0.1),
                                        side: BorderSide(color: activeColor.withOpacity(0.3)),
                                        shape: const StadiumBorder(),
                                        onSelected: (_) {
                                          widget.onSelected(
                                            isIncome ? TransactionType.income : TransactionType.expense,
                                            cat.name,
                                            null,
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TagsSelectorSheetContent extends StatefulWidget {
  const _TagsSelectorSheetContent({
    required this.shorthands,
    required this.onSelectShorthand,
    required this.onSelectPopularTag,
  });

  final List<TagShorthandModel> shorthands;
  final ValueChanged<TagShorthandModel> onSelectShorthand;
  final ValueChanged<String> onSelectPopularTag;

  @override
  State<_TagsSelectorSheetContent> createState() => _TagsSelectorSheetContentState();
}

class _TagsSelectorSheetContentState extends State<_TagsSelectorSheetContent> {
  String _searchQuery = '';
  final List<String> popularTags = [
    'Food',
    'Travel',
    'Shopping',
    'Bills',
    'Entertainment',
    'Work',
    'Personal'
  ];

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    
    final filteredShorthands = widget.shorthands.where((tag) {
      return tag.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    final filteredPopular = popularTags.where((tag) {
      return tag.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPadding + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Tags & Shorthands',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textDark),
          ),
          const SizedBox(height: 4),
          const Text(
            'Autofill mapping details or append a tag to your note.',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),

          AppSearchBar(
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
              });
            },
            onClear: () {
              setState(() {
                _searchQuery = '';
              });
            },
            hintText: 'Search tags or shorthands...',
            hasBorder: true,
          ),
          const SizedBox(height: 16),

          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.45,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (filteredShorthands.isNotEmpty) ...[
                    const Text(
                      'Custom Shorthands (Autofills details)',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.textDark),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: filteredShorthands.map((tag) {
                        return ActionChip(
                          label: Text('?${tag.name}'),
                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: Color(0xFF475569),
                          ),
                          backgroundColor: const Color(0xFFF1F5F9),
                          shape: const StadiumBorder(
                            side: BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          onPressed: () => widget.onSelectShorthand(tag),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    const Divider(color: Color(0xFFE2E8F0), height: 1),
                    const SizedBox(height: 16),
                  ],

                  if (filteredPopular.isNotEmpty) ...[
                    const Text(
                      'Popular Tags (Appends to note)',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.textDark),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: filteredPopular.map((tag) {
                        return ActionChip(
                          label: Text('#$tag'),
                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: Color(0xFF7C3AED),
                          ),
                          backgroundColor: Colors.white,
                          shape: const StadiumBorder(),
                          side: const BorderSide(color: Color(0xFFDDD6FE)),
                          onPressed: () => widget.onSelectPopularTag(tag),
                        );
                      }).toList(),
                    ),
                  ],

                  if (filteredShorthands.isEmpty && filteredPopular.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24.0),
                        child: Text(
                          'No tags or shorthands found.',
                          style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600),
                        ),
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

class _SplitSelectorSheetContent extends StatefulWidget {
  const _SplitSelectorSheetContent({
    required this.onConfigured,
  });

  final VoidCallback onConfigured;

  @override
  State<_SplitSelectorSheetContent> createState() => _SplitSelectorSheetContentState();
}

class _SplitSelectorSheetContentState extends State<_SplitSelectorSheetContent> {
  int _membersCount = 2;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPadding + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Split Bill',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textDark),
          ),
          const SizedBox(height: 4),
          const Text(
            'Divide this expense between group members or friends.',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Number of Members',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textDark),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.primaryBlue),
                    onPressed: _membersCount > 2
                        ? () {
                            setState(() {
                              _membersCount--;
                            });
                          }
                        : null,
                  ),
                  Text(
                    '$_membersCount',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.textDark),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primaryBlue),
                    onPressed: () {
                      setState(() {
                        _membersCount++;
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.pie_chart_outline_rounded, color: Color(0xFFF97316), size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Each member will pay: 1/$_membersCount share',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: () {
                widget.onConfigured();
                Navigator.pop(context);
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF97316),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text(
                'Confirm Split',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


