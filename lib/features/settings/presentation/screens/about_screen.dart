import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import 'settings/settings_widgets.dart';
import 'support_screen.dart';

/// About & Developer screen shown from the Settings → About section.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  // ── Developer links ──────────────────────────────────────────────────────

  static const String _githubUrl = 'https://github.com/mini-page/';
  static const String _linkedinUrl = 'https://www.linkedin.com/in/ug5711';
  static const String _xUrl = 'https://x.com/ug_5711';
  static const String _instagramUrl = 'https://www.instagram.com/ug_5711';
  static const String _repoUrl = 'https://github.com/mini-page/XPens';
  static const String _issuesUrl = 'https://github.com/mini-page/XPens/issues';
  static const String _email = 'xpens-support@gmail.com';

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'About',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.textDark,
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── App identity card ───────────────────────────────────────────
            _AppIdentityCard(),
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
          // Avatar + name row
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
          // Bio
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
          // Social links wrap
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
          // Email
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
