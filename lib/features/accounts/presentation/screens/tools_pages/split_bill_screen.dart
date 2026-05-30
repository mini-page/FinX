import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:xpens/core/theme/app_colors.dart';
import 'package:xpens/shared/widgets/app_page_header.dart';
import '../../widgets/split_bill_tool_view.dart';

class SplitBillScreen extends ConsumerWidget {
  const SplitBillScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: const GradientAppBar(
        title: 'Split Bill',
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: SplitBillToolView(),
      ),
    );
  }
}
