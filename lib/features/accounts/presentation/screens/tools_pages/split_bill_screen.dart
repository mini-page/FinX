import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:expensio/core/theme/app_colors.dart';
import 'package:expensio/shared/widgets/app_page_header.dart';
import '../../widgets/split_bill_tool_view.dart';

class SplitBillScreen extends ConsumerWidget {
  const SplitBillScreen({super.key, this.showBackButton = true});

  final bool showBackButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: GradientAppBar(
        title: 'Split Bill',
        showBackButton: showBackButton,
      ),
      body: const SplitBillToolView(),
    );
  }
}
