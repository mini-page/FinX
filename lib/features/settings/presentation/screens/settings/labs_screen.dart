import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../shared/widgets/app_page_header.dart';
import 'settings_widgets.dart';
import 'package:expensio/features/gamification/presentation/screens/gamification_screen.dart';
import 'package:expensio/features/settings/presentation/provider/preferences_providers.dart';

class LabsScreen extends ConsumerWidget {
  const LabsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: const GradientAppBar(title: 'Labs'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 16),
              child: Text(
                'Experimental features under active development. '
                'Stability and completeness may vary.',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
            SettingsCard(
              children: [
                _LabTile(
                  icon: Icons.map_rounded,
                  title: 'Location Map',
                  description: 'Transaction map view with GPS heatmap. '
                      'UI design incomplete, offline maps not configured.',
                  status: _LabStatus.inProgress,
                ),
                _LabTile(
                  icon: Icons.loop_rounded,
                  title: 'Recurring Transactions',
                  description: 'Auto-detect and manage subscriptions. '
                      'Recurring engine partially built, UI integration pending.',
                  status: _LabStatus.inProgress,
                ),
                _LabTile(
                  icon: Icons.sms_rounded,
                  title: 'SMS Auto-Detection',
                  description: 'Parse bank SMS to auto-create expenses. '
                      'Detection accuracy is limited; edge cases not handled.',
                  status: _LabStatus.experimental,
                ),
                _LabTile(
                  icon: Icons.mic_rounded,
                  title: 'Voice Entry',
                  description: 'Natural language expense entry via speech. '
                      'Backend recognition not integrated.',
                  status: _LabStatus.planned,
                ),
                _LabTile(
                  icon: Icons.auto_awesome_rounded,
                  title: 'Smart Categories',
                  description: 'ML-based auto-categorisation of expenses. '
                      'Model training pipeline not started.',
                  status: _LabStatus.planned,
                ),
                _LabTile(
                  icon: Icons.workspace_premium_rounded,
                  title: 'Gamification',
                  description: 'Streaks, achievements, and milestones to '
                      'make expense tracking fun and rewarding.',
                  status: _LabStatus.experimental,
                  onTap: (context) => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const GamificationScreen()),
                  ),
                ),
                _LabTile(
                  icon: Icons.replay_rounded,
                  title: 'Replay Onboarding',
                  description: 'Reset the onboarding flow so it shows again on '
                      'next app launch. Useful for testing changes.',
                  status: _LabStatus.experimental,
                  onTap: (context) async {
                    await ref
                        .read(appPreferencesControllerProvider)
                        .setOnboardingCompleted(false);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Onboarding reset. Restart the app to see it again.',
                          ),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _LabStatus { experimental, inProgress, planned }

class _LabTile extends StatelessWidget {
  const _LabTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.status,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final _LabStatus status;
  final void Function(BuildContext)? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap != null ? () => onTap!(context) : null,
      leading: SettingsTileIcon(icon: icon),
      title: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          _StatusBadge(status: status),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          description,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.4),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final _LabStatus status;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, String label) = switch (status) {
      _LabStatus.experimental => (
        AppColors.warning.withValues(alpha: 0.15),
        AppColors.warning,
        'Experimental',
      ),
      _LabStatus.inProgress => (
        AppColors.primaryBlue.withValues(alpha: 0.12),
        AppColors.primaryBlue,
        'In Progress',
      ),
      _LabStatus.planned => (
        AppColors.textMuted.withValues(alpha: 0.2),
        AppColors.textMuted,
        'Planned',
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: fg,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
