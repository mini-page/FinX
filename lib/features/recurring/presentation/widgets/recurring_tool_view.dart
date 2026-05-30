import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../data/models/recurring_subscription_model.dart';
import 'package:xpens/features/settings/presentation/provider/preferences_providers.dart';
import '../provider/recurring_subscription_providers.dart';
import 'subscription_editor_sheet.dart';
import 'subscription_icons.dart';
import 'package:xpens/features/expense/presentation/widgets/ui_feedback.dart';
import 'package:xpens/features/expense/presentation/provider/expense_providers.dart';

class RecurringToolView extends ConsumerStatefulWidget {
  const RecurringToolView({super.key});

  @override
  ConsumerState<RecurringToolView> createState() => _RecurringToolViewState();
}

class _RecurringToolViewState extends ConsumerState<RecurringToolView> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final subscriptionState = ref.watch(recurringSubscriptionListProvider);
    final subscriptions = subscriptionState.value ?? const <RecurringSubscriptionModel>[];
    final currency = ref.watch(currencyFormatProvider);

    double getMonthlyEquivalent(RecurringSubscriptionModel sub) {
      switch (sub.billingPeriod.toLowerCase()) {
        case 'weekly':
          return sub.amount * 52 / 12;
        case 'quarterly':
          return sub.amount / 3;
        case 'yearly':
          return sub.amount / 12;
        case 'monthly':
        default:
          return sub.amount;
      }
    }

    final activeSubs = subscriptions.where((s) => s.isActive).toList();
    final activeCount = activeSubs.length;
    final totalMonthlyAmount = activeSubs.fold<double>(0.0, (sum, s) => sum + getMonthlyEquivalent(s));

    // Sort active ones by next renewal date
    final sortedActive = List<RecurringSubscriptionModel>.from(activeSubs)
      ..sort((a, b) => a.nextBillDate.compareTo(b.nextBillDate));

    // Calculate minimum days remaining for the bottom bar
    int minDays = -1;
    if (sortedActive.isNotEmpty) {
      minDays = max(0, sortedActive.first.nextBillDate.difference(DateTime.now()).inDays);
    }

    // Determine vertical list count based on expansion state
    final displayedSubscriptions = _showAll
        ? subscriptions
        : subscriptions.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Premium Header
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Subscriptions',
                    style: TextStyle(
                      color: AppColors.textDark,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$activeCount active • ${currency.format(totalMonthlyAmount)}/mo',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _openEditor(context),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primaryBlue,
                elevation: 0,
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        if (subscriptionState.hasError)
          const _StateCard(
            title: 'Unable to load subscriptions',
            message: 'The recurring list is unavailable right now.',
          )
        else if (subscriptionState.isLoading && subscriptions.isEmpty)
          const Center(child: Padding(
            padding: EdgeInsets.all(24.0),
            child: CircularProgressIndicator(),
          ))
        else if (subscriptions.isEmpty)
          const _StateCard(
            title: 'No recurring subscriptions',
            message: 'Create your first subscription to track upcoming bills.',
          )
        else ...[
          // ── Upcoming Section (Horizontal Cards) ──────────────────────────────
          if (sortedActive.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'Upcoming',
                      style: TextStyle(
                        color: AppColors.textDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        sortedActive.take(3).length.toString(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                const Text(
                  'View all →',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 146,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: min(3, sortedActive.length),
                itemBuilder: (context, index) {
                  final sub = sortedActive[index];
                  final days = max(0, sub.nextBillDate.difference(DateTime.now()).inDays);
                  return GestureDetector(
                    onTap: () => _openEditor(context, subscription: sub),
                    child: Container(
                      width: 170,
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.textDark, // aligned with AppColors
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: resolveSubscriptionIcon(
                                  sub.iconKey,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                days == 0
                                    ? 'Today'
                                    : days == 1
                                        ? 'Tomorrow'
                                        : '$days days',
                                style: const TextStyle(
                                  color: AppColors.success, // aligned with AppColors
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                currency.format(sub.amount),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _getBillingPeriodLabel(sub.billingPeriod),
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            sub.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textMuted, // aligned with AppColors
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            height: 28,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.success,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () {
                                _logSubscriptionPayment(context, ref, sub);
                              },
                              child: const Text(
                                'Log Payment',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ── All Subscriptions Section (Vertical List) ───────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'All Subscriptions',
                style: TextStyle(
                  color: AppColors.textDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (subscriptions.length > 4)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showAll = !_showAll;
                    });
                  },
                  child: Text(
                    _showAll ? 'Show less' : 'View all →',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayedSubscriptions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final sub = displayedSubscriptions[index];
              return _SubscriptionTile(
                subscription: sub,
                amountText: currency.format(sub.amount),
                onTap: () => _openEditor(context, subscription: sub),
                onDelete: () => _confirmDeleteSubscription(context, sub),
              );
            },
          ),
          const SizedBox(height: 20),

          // ── Bottom Summary Row ──────────────────────────────────────────────
          if (sortedActive.isNotEmpty && minDays >= 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.success, // aligned with AppColors
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Next renewal in $minDays day${minDays == 1 ? '' : 's'}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${currency.format(totalMonthlyAmount)} total',
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }

  Future<void> _openEditor(
    BuildContext context, {
    RecurringSubscriptionModel? subscription,
  }) async {
    final result = await showSubscriptionEditorSheet(
      context,
      subscription: subscription,
    );
    if (result == null) return;

    await ref.read(recurringSubscriptionControllerProvider).saveSubscription(
          id: result.id,
          name: result.name,
          amount: result.amount,
          nextBillDate: result.nextBillDate,
          iconKey: result.iconKey,
          note: result.note,
          isActive: result.isActive,
          billingPeriod: result.billingPeriod,
        );
  }

  Future<void> _confirmDeleteSubscription(
    BuildContext context,
    RecurringSubscriptionModel subscription,
  ) async {
    final confirmed = await confirmDestructiveAction(
      context,
      title: 'Delete recurring bill?',
      message: 'Remove ${subscription.name} from recurring bills? This clears its schedule from the tool.',
      confirmLabel: 'Delete bill',
    );
    if (!confirmed || !context.mounted) {
      return;
    }

    await ref.read(recurringSubscriptionControllerProvider).deleteSubscription(subscription.id);

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${subscription.name} removed.')),
    );
  }
}

class _SubscriptionTile extends StatelessWidget {
  const _SubscriptionTile({
    required this.subscription,
    required this.amountText,
    required this.onTap,
    required this.onDelete,
  });

  final RecurringSubscriptionModel subscription;
  final String amountText;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  Color _getSubscriptionColor(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('netflix')) return const Color(0xFFE50914);
    if (lower.contains('spotify')) return const Color(0xFF1DB954);
    if (lower.contains('dropbox')) return const Color(0xFF0061FE);
    if (lower.contains('youtube')) return const Color(0xFFFF0000);
    if (lower.contains('medium')) return const Color(0xFF24292E);
    if (lower.contains('notion')) return const Color(0xFF000000);
    if (lower.contains('apple') || lower.contains('icloud')) return const Color(0xFF1C1C1E);
    if (lower.contains('google')) return const Color(0xFF4285F4);
    if (lower.contains('amazon') || lower.contains('prime')) return const Color(0xFFFF9900);
    return AppColors.primaryBlue;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: <Widget>[
              // Circle brand-colored icon
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _getSubscriptionColor(subscription.name),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: resolveSubscriptionIcon(
                  subscription.iconKey,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      subscription.name,
                      style: const TextStyle(
                        color: AppColors.textDark,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('MMM d, yyyy').format(subscription.nextBillDate),
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        amountText,
                        style: const TextStyle(
                          color: AppColors.textDark,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded, size: 16, color: AppColors.textMuted),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onSelected: (value) {
                          if (value == 'delete') {
                            onDelete();
                          } else {
                            onTap();
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
                    ],
                  ),
                  Text(
                    _getBillingPeriodLabel(subscription.billingPeriod),
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({required this.title, required this.message});
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            message,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

String _getBillingPeriodLabel(String period) {
  switch (period.toLowerCase()) {
    case 'weekly':
      return '/ wk';
    case 'quarterly':
      return '/ qtr';
    case 'yearly':
      return '/ yr';
    case 'monthly':
    default:
      return '/ mo';
  }
}

Future<void> _logSubscriptionPayment(
  BuildContext context,
  WidgetRef ref,
  RecurringSubscriptionModel sub,
) async {
  HapticFeedback.mediumImpact();
  
  // 1. Add real expense transaction
  await ref.read(expenseControllerProvider).addExpense(
        amount: sub.amount,
        category: 'Bills',
        date: DateTime.now(),
        note: '${sub.name} Subscription Payment',
      );

  // 2. Advance the next bill date
  final nextBill = sub.calculateNextBillDate(sub.nextBillDate);

  // 3. Save changes to subscription
  await ref.read(recurringSubscriptionControllerProvider).saveSubscription(
        id: sub.id,
        name: sub.name,
        amount: sub.amount,
        nextBillDate: nextBill,
        iconKey: sub.iconKey,
        note: sub.note,
        isActive: sub.isActive,
        billingPeriod: sub.billingPeriod,
      );

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Logged payment of ${ref.read(currencyFormatProvider).format(sub.amount)} for ${sub.name}. Next due: ${DateFormat('MMM d, yyyy').format(nextBill)}.',
        ),
        backgroundColor: AppColors.textDark,
      ),
    );
  }
}

