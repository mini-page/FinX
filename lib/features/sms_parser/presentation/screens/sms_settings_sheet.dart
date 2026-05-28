import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_tokens.dart';
import '../../../../../routes/app_routes.dart';
import '../../../expense/data/models/expense_model.dart';
import 'package:xpens/features/accounts/presentation/provider/account_providers.dart';
import 'package:xpens/features/settings/presentation/provider/preferences_providers.dart';
import 'package:xpens/features/categories/presentation/widgets/expense_category.dart';
import '../../data/sms_queue_item.dart';
import '../../data/sms_transaction.dart';
import '../../domain/sms_broadcast_service.dart';
import '../../domain/sms_monitoring_service.dart';
import '../../domain/sms_parser_engine.dart';
import '../provider/sms_providers.dart';
import '../../../../shared/widgets/app_toggle_switch.dart';

/// Shows the SMS Parsing management sheet as a modal bottom sheet.
Future<void> showSmsSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const SmsSettingsSheet(),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheet root
// ─────────────────────────────────────────────────────────────────────────────

class SmsSettingsSheet extends ConsumerStatefulWidget {
  const SmsSettingsSheet({super.key});

  @override
  ConsumerState<SmsSettingsSheet> createState() => _SmsSettingsSheetState();
}

class _SmsSettingsSheetState extends ConsumerState<SmsSettingsSheet> {
  // Paste-to-test
  final TextEditingController _senderCtrl =
      TextEditingController(text: 'VK-HDFCBANKТ');
  final TextEditingController _bodyCtrl = TextEditingController();
  bool _showManualEntry = false;
  bool _checkingPermission = false;
  bool? _permissionGranted;
  StreamSubscription<SmsMessage>? _smsSub;

  @override
  void initState() {
    super.initState();
    _checkPermission();
    // Subscribe to incoming SMS from the broadcast service
    SmsBroadcastService.initialize();
    _smsSub = SmsBroadcastService.messages.listen(_onSmsBroadcast);
  }

  void _onSmsBroadcast(SmsMessage msg) {
    if (!mounted) return;
    ref.read(smsQueueProvider.notifier).ingest(
          sender: msg.sender,
          body: msg.body,
          receivedAt: msg.timestamp,
        );
  }

  Future<void> _checkPermission() async {
    setState(() => _checkingPermission = true);
    final granted = await SmsPermissionHelper.isGranted();
    if (mounted) {
      setState(() {
        _permissionGranted = granted;
        _checkingPermission = false;
      });
    }
  }

  @override
  void dispose() {
    _smsSub?.cancel();
    _senderCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(smsParsingEnabledProvider);
    final queue = ref.watch(smsQueueProvider);
    final pending =
        queue.where((i) => i.status == SmsQueueStatus.pending).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: ListView(
          controller: scrollCtrl,
          padding: EdgeInsets.fromLTRB(
            24,
            16,
            24,
            24 + MediaQuery.of(context).viewInsets.bottom,
          ),
          children: <Widget>[
            // ── Drag handle ──────────────────────────────────────────
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAccent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Header ────────────────────────────────────────────────
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.sms_outlined,
                    color: AppColors.primaryBlue,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'SMS Parsing',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        'Auto-detect transactions from bank SMS',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded,
                      color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Enable toggle ─────────────────────────────────────────
            _ToggleCard(
              enabled: enabled,
              permissionGranted: _permissionGranted,
              checking: _checkingPermission,
              onChanged: _handleToggle,
              onRequestPermission: _requestPermission,
            ),
            const SizedBox(height: 20),

            // ── Default account / category ────────────────────────────
            if (enabled) ...<Widget>[
              _DefaultsCard(),
              const SizedBox(height: 20),
            ],

            // ── Pending queue ─────────────────────────────────────────
            if (pending.isNotEmpty) ...<Widget>[
              _SectionLabel(
                  label: 'Pending (${pending.length})',
                  trailing: TextButton(
                    onPressed: () =>
                        ref.read(smsQueueControllerProvider).dismissAll(),
                    child: const Text(
                      'Dismiss all',
                      style: TextStyle(color: AppColors.danger, fontSize: 12),
                    ),
                  )),
              ...pending.map(
                (item) => _QueueItemCard(
                  item: item,
                  onConfirm: () => _confirm(item.transaction),
                  onEdit: () => _edit(item.transaction),
                  onDismiss: () => ref
                      .read(smsQueueControllerProvider)
                      .dismiss(item.transaction.id),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ── Manual paste / test ───────────────────────────────────
            _ManualEntrySection(
              expanded: _showManualEntry,
              senderCtrl: _senderCtrl,
              bodyCtrl: _bodyCtrl,
              onToggle: () =>
                  setState(() => _showManualEntry = !_showManualEntry),
              onParse: _parseManual,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _handleToggle(bool value) async {
    final controller = ref.read(appPreferencesControllerProvider);
    if (value) {
      // Ensure permission before enabling
      if (_permissionGranted != true) {
        final granted = await _requestPermission();
        if (!granted) return;
      }
      await controller.setSmsParsingEnabled(true);
      await SmsMonitoringService.start();
    } else {
      await controller.setSmsParsingEnabled(false);
      await SmsMonitoringService.stop();
    }
  }

  Future<bool> _requestPermission() async {
    final status = await Permission.sms.request();
    if (mounted) setState(() => _permissionGranted = status.isGranted);
    if (!status.isGranted && status.isPermanentlyDenied) {
      if (mounted) {
        _showSettingsDialog();
      }
    }
    return status.isGranted;
  }

  void _showSettingsDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('SMS Permission Required'),
        content: const Text(
          'XPens needs SMS read permission to detect bank transactions automatically. '
          'Please enable it in app settings.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirm(SmsTransaction tx) async {
    await ref.read(smsQueueControllerProvider).confirmWithDefaults(tx);
  }

  Future<void> _edit(SmsTransaction tx) async {
    ref.read(smsQueueControllerProvider).markEditing(tx.id);
    final fill = ref.read(smsQueueControllerProvider).prefillFor(tx);
    if (!mounted) return;
    Navigator.of(context).pop();
    await AppRoutes.pushAddExpense(
      context,
      initialAmount: fill.amount,
      initialCategory: fill.category,
      initialDate: fill.date,
      initialNote: fill.note,
      initialAccountId: fill.accountId,
      initialType: fill.type,
    );
    ref.read(smsQueueControllerProvider).dismiss(tx.id);
  }

  void _parseManual() {
    final sender = _senderCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    if (body.isEmpty) return;

    final item = ref.read(smsQueueControllerProvider).ingestManual(
          sender: sender.isEmpty ? 'MANUAL' : sender,
          body: body,
        );
    if (item == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not detect a transaction in this message.'),
          backgroundColor: AppColors.danger,
        ),
      );
    } else {
      _bodyCtrl.clear();
      setState(() => _showManualEntry = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _ToggleCard extends StatelessWidget {
  const _ToggleCard({
    required this.enabled,
    required this.permissionGranted,
    required this.checking,
    required this.onChanged,
    required this.onRequestPermission,
  });

  final bool enabled;
  final bool? permissionGranted;
  final bool checking;
  final Future<void> Function(bool) onChanged;
  final Future<bool> Function() onRequestPermission;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.surfaceAccent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Enable SMS Parsing',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Detect bank transactions from incoming SMS',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              AppToggleSwitch(
                value: enabled,
                onChanged: onChanged,
              ),
            ],
          ),
          if (!checking && permissionGranted == false) ...<Widget>[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.warning_amber_rounded,
                      color: AppColors.warning, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'SMS permission not granted. Tap to allow.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.warning,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: onRequestPermission,
                    child: const Text(
                      'Allow',
                      style: TextStyle(
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Default account / category picker ─────────────────────────────────────────

class _DefaultsCard extends ConsumerWidget {
  const _DefaultsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountListProvider).value ?? const [];
    final prefs = ref.watch(appPreferencesProvider).value;
    final defaultAccountId = prefs?.smsDefaultAccountId ?? '';
    final defaultCategory = prefs?.smsDefaultCategory ?? '';
    final controller = ref.read(appPreferencesControllerProvider);
    final allExpenseCategories = ref.watch(allExpenseCategoriesProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.surfaceAccent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Auto-Confirm Defaults',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Used when confirming with defaults',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),

          // Default account
          _PickerRow(
            label: 'Account',
            icon: Icons.account_balance_wallet_outlined,
            value: accounts
                    .where((a) => a.id == defaultAccountId)
                    .map((a) => a.name)
                    .firstOrNull ??
                'App Default',
            onTap: accounts.isEmpty
                ? null
                : () => _pickAccount(
                    context, accounts, defaultAccountId, controller),
          ),
          const SizedBox(height: 8),

          // Default category
          _PickerRow(
            label: 'Category',
            icon: Icons.category_outlined,
            value: defaultCategory.isNotEmpty ? defaultCategory : 'Other',
            onTap: () => _pickCategory(
                context, allExpenseCategories, defaultCategory, controller),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAccount(
    BuildContext context,
    List accounts,
    String current,
    AppPreferencesController controller,
  ) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Default Account'),
        children: <Widget>[
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(''),
            child: const Text('App Default'),
          ),
          ...accounts.map(
            (a) => SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(a.id as String),
              child: Text(a.name as String),
            ),
          ),
        ],
      ),
    );
    if (selected != null) {
      await controller.setSmsDefaultAccountId(selected);
    }
  }

  Future<void> _pickCategory(
    BuildContext context,
    List<ExpenseCategory> categories,
    String current,
    AppPreferencesController controller,
  ) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Default Category'),
        children: categories
            .map(
              (c) => SimpleDialogOption(
                onPressed: () => Navigator.of(ctx).pop(c.name),
                child: Text(c.name),
              ),
            )
            .toList(growable: false),
      ),
    );
    if (selected != null) {
      await controller.setSmsDefaultCategory(selected);
    }
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.label,
    required this.icon,
    required this.value,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 16, color: AppColors.textMuted),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textDark,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (onTap != null) ...<Widget>[
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded,
                  size: 16, color: AppColors.textMuted),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Queue item card ────────────────────────────────────────────────────────────

class _QueueItemCard extends StatelessWidget {
  const _QueueItemCard({
    required this.item,
    required this.onConfirm,
    required this.onEdit,
    required this.onDismiss,
  });

  final SmsQueueItem item;
  final VoidCallback onConfirm;
  final VoidCallback onEdit;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final tx = item.transaction;
    final isIncome = tx.type == TransactionType.income;
    final typeColor = isIncome ? AppColors.success : AppColors.danger;
    final typeLabel = isIncome ? 'Income' : 'Expense';
    final isLowConf = tx.confidence < SmsParserEngine.kMinConfidence;
    final fmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(
          color: isLowConf
              ? AppColors.warning.withValues(alpha: 0.4)
              : AppColors.surfaceAccent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Amount + type row
          Row(
            children: <Widget>[
              Text(
                fmt.format(tx.amount),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: typeColor,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  typeLabel,
                  style: TextStyle(
                    color: typeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Spacer(),
              if (isLowConf)
                const Tooltip(
                  message: 'Low confidence — please review',
                  child: Icon(Icons.warning_amber_rounded,
                      size: 18, color: AppColors.warning),
                ),
              IconButton(
                onPressed: onDismiss,
                icon: const Icon(Icons.close_rounded,
                    size: 18, color: AppColors.textMuted),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Notes / sender
          Text(
            tx.notes,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            DateFormat('MMM d, hh:mm a').format(tx.timestamp),
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),

          // Action buttons
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryBlue,
                    side: const BorderSide(color: AppColors.primaryBlue),
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onConfirm,
                  icon: const Icon(Icons.check_rounded, size: 14),
                  label: const Text('Confirm'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Manual entry section ──────────────────────────────────────────────────────

class _ManualEntrySection extends StatelessWidget {
  const _ManualEntrySection({
    required this.expanded,
    required this.senderCtrl,
    required this.bodyCtrl,
    required this.onToggle,
    required this.onParse,
  });

  final bool expanded;
  final TextEditingController senderCtrl;
  final TextEditingController bodyCtrl;
  final VoidCallback onToggle;
  final VoidCallback onParse;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: <Widget>[
                const Icon(Icons.science_outlined,
                    size: 16, color: AppColors.textMuted),
                const SizedBox(width: 6),
                const Text(
                  'Test / Paste SMS manually',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textMuted,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        if (expanded) ...<Widget>[
          const SizedBox(height: 12),
          TextField(
            controller: senderCtrl,
            decoration: const InputDecoration(
              labelText: 'Sender ID (e.g. VK-HDFCBANKТ)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: bodyCtrl,
            decoration: const InputDecoration(
              labelText: 'SMS body',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            maxLines: 4,
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onParse,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
              ),
              child: const Text(
                'Parse & Add to Queue',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: <Widget>[
          Text(
            label,
            style: AppTextStyles.sectionHeading,
          ),
          if (trailing != null) ...<Widget>[
            const Spacer(),
            trailing!,
          ],
        ],
      ),
    );
  }
}
