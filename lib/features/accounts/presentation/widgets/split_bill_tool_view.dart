import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:xpens/core/theme/app_colors.dart';
import 'package:xpens/core/theme/app_tokens.dart';
import 'package:xpens/features/settings/presentation/provider/preferences_providers.dart';

class SplitBillToolView extends ConsumerStatefulWidget {
  const SplitBillToolView({super.key});

  @override
  ConsumerState<SplitBillToolView> createState() => _SplitBillToolViewState();
}

class _SplitBillToolViewState extends ConsumerState<SplitBillToolView> {
  final TextEditingController _amountController = TextEditingController();
  int _peopleCount = 2;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final symbol = ref.watch(currencySymbolProvider);

    final currency = ref.watch(currencyFormatProvider);
    final totalAmount = double.tryParse(_amountController.text) ?? 0;
    final perPerson = _peopleCount <= 0 ? 0 : totalAmount / _peopleCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Split Bill',
          style: AppTextStyles.sectionHeading,
        ),
        const Text(
          'Calculate fair shares instantly',
          style: AppTextStyles.sectionSubtitle,
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Total amount',
            hintText: 'Enter amount',
            prefixText: '$symbol ',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.lg),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
          child: Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  'People',
                  style: AppTextStyles.bodyStrong,
                ),
              ),
              _StepperButton(
                icon: Icons.remove_rounded,
                onTap: _peopleCount > 1
                    ? () => setState(() => _peopleCount -= 1)
                    : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Text(
                  '$_peopleCount',
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _StepperButton(
                icon: Icons.add_rounded,
                onTap: () => setState(() => _peopleCount += 1),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: <Color>[
                AppColors.primaryBlue,
                AppColors.primaryBlueLight,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppRadii.xl),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryBlue.withValues(alpha: 0.2),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Per person',
                style: TextStyle(
                  color: AppColors.overlayWhiteStrong,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                currency.format(perPerson),
                style: AppTextStyles.cardValue,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color:
          onTap == null ? AppColors.surfaceDisabled : AppColors.surfaceAccent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(
            icon,
            color: onTap == null
                ? AppColors.disabledContent
                : AppColors.primaryBlue,
            size: 18,
          ),
        ),
      ),
    );
  }
}
