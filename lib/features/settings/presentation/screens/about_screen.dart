import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/update_service.dart';
import '../../../../core/utils/context_extensions.dart';
import '../../../../shared/widgets/app_page_header.dart';
import 'settings/settings_widgets.dart';
import 'support_screen.dart';

/// About & Developer screen shown from the Settings → About section.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  // ── Developer links ──────────────────────────────────────────────────────

  static const String _githubUrl = 'https://github.com/mini-page/';
  static const String _linkedinUrl = 'https://www.linkedin.com/in/ug5711';
  static const String _xUrl = 'https://x.com/ug_5711';
  static const String _instagramUrl = 'https://www.instagram.com/ug_5711';
  static const String _repoUrl = 'https://github.com/mini-page/XPens';
  static const String _issuesUrl = 'https://github.com/mini-page/XPens/issues';
  static const String _email = 'xpens-support@gmail.com';
  static const int _kMaxReleaseNotesLength = 280;

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updateState = ref.watch(updateCheckerProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: const GradientAppBar(
        title: 'About',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── App identity card ───────────────────────────────────────────
            _AppIdentityCard(),
            const SizedBox(height: 28),

            // ── Update Checker ──────────────────────────────────────────────
            const SettingsSectionHeader(title: 'Updates'),
            SettingsCard(
              children: [
                _buildUpdateTile(context, ref, updateState),
              ],
            ),
            const SizedBox(height: 28),

            // ── Developer section ───────────────────────────────────────────
            const SettingsSectionHeader(title: 'Developer'),
            _DeveloperCard(onLaunchUrl: _launchUrl, email: _email),
            const SizedBox(height: 28),

            // ── Support the Project section ─────────────────────────────────
            const SettingsSectionHeader(title: 'Support the Project'),
            SettingsCard(
              children: [
                ListTile(
                  leading: const SettingsTileIcon(
                      icon: Icons.volunteer_activism_outlined),
                  title: const Text(
                    'Support XPens',
                    style: TextStyle(
                        color: AppColors.textDark, fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Donate or buy me a coffee',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded,
                      color: AppColors.textMuted),
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                        builder: (_) => const SupportScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // ── Other ways to help ──────────────────────────────────────────
            const SettingsSectionHeader(title: 'Other Ways to Help'),
            SettingsCard(
              children: [
                _ActionTile(
                  icon: Icons.star_outline_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  title: 'Star the Repository',
                  subtitle: 'Boosts visibility and helps others find it',
                  onTap: () => _launchUrl(_repoUrl),
                ),
                _ActionTile(
                  icon: Icons.bug_report_outlined,
                  iconColor: AppColors.primaryBlue,
                  title: 'Report a Bug',
                  subtitle: 'Help us fix issues and improve XPens',
                  onTap: () => _launchUrl(_issuesUrl),
                ),
                _ActionTile(
                  icon: Icons.share_outlined,
                  iconColor: AppColors.primaryBlue,
                  title: 'Share with Friends',
                  subtitle: 'Word of mouth is the best marketing',
                  onTap: () => Share.share(
                    'Check out XPens – a free, offline-first expense tracker! '
                    '$_repoUrl',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Footer ──────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.lightBlueBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.favorite_rounded,
                      color: Colors.red, size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Every contribution — financial or not — makes a real difference. Thank you!',
                      style: TextStyle(
                        color: AppColors.primaryBlue,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpdateTile(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<UpdateInfo?> state,
  ) {
    if (state.isLoading) {
      return ListTile(
        leading: const SettingsTileIcon(icon: Icons.system_update_outlined),
        title: const Text(
          'Checking for Updates\u2026',
          style:
              TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w700),
        ),
        subtitle: const Text(
          'Please wait a moment',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        trailing: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (state.hasValue && state.value != null) {
      final info = state.value!;
      return ListTile(
        leading: const SettingsTileIcon(icon: Icons.system_update_outlined),
        title: const Text(
          'Update Available',
          style: TextStyle(
              color: AppColors.primaryBlue, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          'v${info.latestVersion} is ready to download',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        trailing: _UpdateBadge(label: 'Download'),
        onTap: () => _showUpdateDialog(context, ref, info),
      );
    }

    if (state.hasError) {
      return ListTile(
        leading: const SettingsTileIcon(icon: Icons.system_update_outlined),
        title: const Text(
          'Check for Updates',
          style:
              TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w700),
        ),
        subtitle: const Text(
          'Could not connect. Tap to retry',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        trailing: const Icon(Icons.refresh_rounded, color: AppColors.textMuted),
        onTap: () => ref.read(updateCheckerProvider.notifier).check(),
      );
    }

    return ListTile(
      leading: const SettingsTileIcon(icon: Icons.system_update_outlined),
      title: const Text(
        'Check for Updates',
        style:
            TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        'Current version: v${AppConstants.version}',
        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
      ),
      trailing:
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
      onTap: () => ref.read(updateCheckerProvider.notifier).check(),
    );
  }

  Future<void> _showUpdateDialog(
    BuildContext context,
    WidgetRef ref,
    UpdateInfo info,
  ) async {
    final notes = info.releaseNotes;
    final hasNotes = notes != null && notes.trim().isNotEmpty;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.system_update_outlined, color: AppColors.primaryBlue),
            SizedBox(width: 10),
            Text('Update Available'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A new version of XPens is available.\n\n'
              'v${AppConstants.version}  \u2192  v${info.latestVersion}',
              style: const TextStyle(fontSize: 14),
            ),
            if (hasNotes) ...[
              const SizedBox(height: 12),
              const Text(
                "What's new:",
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                notes.length > _kMaxReleaseNotesLength
                    ? '${notes.substring(0, _kMaxReleaseNotesLength).trimRight()}\u2026'
                    : notes,
                style:
                    const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Later'),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final uri = Uri.parse(info.releaseUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } else if (context.mounted) {
                context.showSnackBar(
                  'Could not open the download link. '
                  'Visit github.com/mini-page/XPens/releases manually.',
                );
              }
            },
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Download'),
          ),
        ],
      ),
    );
  }
}

// ── Private widgets ──────────────────────────────────────────────────────────

class _AppIdentityCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Logo
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(AppAssets.logo, width: 72, height: 72),
          ),
          const SizedBox(height: 14),
          // App name
          const Text(
            AppConstants.appName,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: AppColors.primaryBlue,
            ),
          ),
          const SizedBox(height: 6),
          // Version badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.lightBlueBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Version ${AppConstants.version}',
              style: const TextStyle(
                color: AppColors.primaryBlue,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'A simple and smart expense tracker to\nhelp you manage money better.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text(
                'Made with ',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
              Icon(Icons.favorite_rounded, color: Colors.red, size: 14),
              Text(
                ' in India',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeveloperCard extends StatelessWidget {
  const _DeveloperCard({
    required this.onLaunchUrl,
    required this.email,
  });

  final Future<void> Function(String) onLaunchUrl;
  final String email;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.lightBlueBg,
                child: const Icon(Icons.person_rounded,
                    size: 30, color: AppColors.primaryBlue),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Umang Gupta',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Independent Developer · aka mini-page',
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            "I'm a passionate developer building useful apps in my free time. "
            "Every bit of support helps me keep building and improving XPens.",
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SocialChip(
                icon: Icons.code_rounded,
                label: 'GitHub',
                onTap: () => onLaunchUrl(AboutScreen._githubUrl),
              ),
              _SocialChip(
                icon: Icons.work_outline_rounded,
                label: 'LinkedIn',
                onTap: () => onLaunchUrl(AboutScreen._linkedinUrl),
              ),
              _SocialChip(
                icon: Icons.alternate_email_rounded,
                label: 'X',
                onTap: () => onLaunchUrl(AboutScreen._xUrl),
              ),
              _SocialChip(
                icon: Icons.photo_camera_outlined,
                label: 'Instagram',
                onTap: () => onLaunchUrl(AboutScreen._instagramUrl),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => onLaunchUrl('mailto:$email'),
            child: Row(
              children: [
                const Icon(Icons.email_outlined,
                    size: 16, color: AppColors.primaryBlue),
                const SizedBox(width: 6),
                Text(
                  email,
                  style: const TextStyle(
                    color: AppColors.primaryBlue,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialChip extends StatelessWidget {
  const _SocialChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.lightBlueBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.primaryBlue),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.primaryBlue,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(
            color: AppColors.textDark, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
      ),
      trailing:
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
      onTap: onTap,
    );
  }
}

class _UpdateBadge extends StatelessWidget {
  const _UpdateBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
