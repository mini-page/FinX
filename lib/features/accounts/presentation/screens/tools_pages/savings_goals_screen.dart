import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:xpens/core/theme/app_colors.dart';
import 'package:xpens/shared/widgets/app_page_header.dart';
import '../accounts/tools_tab_widgets.dart';

class SavingsGoalsScreen extends ConsumerWidget {
  const SavingsGoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: const GradientAppBar(
        title: 'Savings Goals',
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: GoalsToolView(),
      ),
    );
  }
}
