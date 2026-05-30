import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:xpens/core/theme/app_colors.dart';
import 'package:xpens/features/settings/presentation/provider/preferences_providers.dart';
import 'package:xpens/shared/widgets/app_page_header.dart';
import '../accounts/accounts_widgets.dart';

class AccountsBoardScreen extends ConsumerWidget {
  const AccountsBoardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(currencyFormatProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: const GradientAppBar(
        title: 'Accounts & Balances',
      ),
      body: CustomScrollView(
        slivers: [
          SliverAccountsTabView(currency: currency),
        ],
      ),
    );
  }
}
