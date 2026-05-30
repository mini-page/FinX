import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../shared/widgets/app_page_header.dart';
import '../../../../../core/utils/context_extensions.dart';
import '../../provider/preferences_providers.dart';
import 'settings_widgets.dart';

const List<({String id, String label, String description})> _kGeminiModels = [
  (
    id: 'gemini-2.0-flash',
    label: 'Gemini 2.0 Flash',
    description: 'Fast & balanced — recommended',
  ),
  (
    id: 'gemini-2.0-flash-lite',
    label: 'Gemini 2.0 Flash Lite',
    description: 'Lightest, lowest latency',
  ),
  (
    id: 'gemini-2.5-flash',
    label: 'Gemini 2.5 Flash',
    description: 'Most capable flash model',
  ),
  (
    id: 'gemini-1.5-flash',
    label: 'Gemini 1.5 Flash',
    description: 'Stable and widely tested',
  ),
  (
    id: 'gemini-1.5-pro',
    label: 'Gemini 1.5 Pro',
    description: 'Highest quality, higher latency',
  ),
];

class AiSettingsScreen extends ConsumerWidget {
  const AiSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(appPreferencesControllerProvider);
    final apiKey = ref.watch(aiApiKeyProvider);
    final aiEnabled = ref.watch(aiEnabledProvider);
    final aiModelId = ref.watch(aiModelIdProvider);
    final aiSmartSearch = ref.watch(aiSmartSearchEnabledProvider);
    final aiVoice = ref.watch(aiVoiceEnabledProvider);
    final aiScanner = ref.watch(aiScannerEnabledProvider);
    final aiSmsAi = ref.watch(aiSmsAiEnabledProvider);

    final hasKey = apiKey.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: const GradientAppBar(
        title: 'AI Features',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SettingsSectionHeader(title: 'Gemini Connection'),
            SettingsCard(
              children: [
                _buildApiKeyRow(context, ref, hasKey, controller),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (aiEnabled ? AppColors.primaryBlue : AppColors.textMuted)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: aiEnabled ? AppColors.primaryBlue : AppColors.textMuted,
                      size: 18,
                    ),
                  ),
                  title: const Text(
                    'Enable AI Features',
                    style: TextStyle(
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w700,
                        fontSize: 14),
                  ),
                  subtitle: Text(
                    hasKey
                        ? 'Use Gemini to power smart features'
                        : 'Add an API key first',
                    style: TextStyle(
                      color: hasKey ? AppColors.textMuted : AppColors.danger,
                      fontSize: 11,
                    ),
                  ),
                  trailing: Switch(
                    value: aiEnabled,
                    onChanged: hasKey ? (v) => controller.setAiEnabled(v) : (_) {},
                    activeColor: AppColors.primaryBlue,
                  ),
                ),
              ],
            ),
            if (aiEnabled) ...[
              const SizedBox(height: 24),
              const SettingsSectionHeader(title: 'AI Preferences'),
              SettingsCard(
                children: [
                  _buildAiModelSelector(aiModelId, controller),
                  _buildAiFeatureToggle(
                    icon: Icons.search_rounded,
                    title: 'Smart Search',
                    subtitle: 'AI-enhanced transaction search',
                    value: aiSmartSearch,
                    onChanged: controller.setAiSmartSearchEnabled,
                  ),
                  _buildAiFeatureToggle(
                    icon: Icons.mic_rounded,
                    title: 'Smart Voice Entry',
                    subtitle: 'AI parses voice commands',
                    value: aiVoice,
                    onChanged: controller.setAiVoiceEnabled,
                  ),
                  _buildAiFeatureToggle(
                    icon: Icons.qr_code_scanner_rounded,
                    title: 'Smart Scanner',
                    subtitle: 'AI reads receipts & product labels',
                    value: aiScanner,
                    onChanged: controller.setAiScannerEnabled,
                  ),
                  _buildAiFeatureToggle(
                    icon: Icons.sms_outlined,
                    title: 'AI SMS Parsing',
                    subtitle: 'AI extracts amounts from bank SMS',
                    value: aiSmsAi,
                    onChanged: controller.setAiSmsAiEnabled,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildApiKeyRow(
    BuildContext context,
    WidgetRef ref,
    bool hasKey,
    AppPreferencesController controller,
  ) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: (hasKey ? AppColors.success : AppColors.primaryBlue)
              .withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          hasKey ? Icons.check_circle_outline_rounded : Icons.vpn_key_outlined,
          color: hasKey ? AppColors.success : AppColors.primaryBlue,
          size: 22,
        ),
      ),
      title: const Text(
        'Gemini API Key',
        style: TextStyle(
          color: AppColors.textDark,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        hasKey ? 'Connected  •  tap 🗑 to remove' : 'Not configured',
        style: TextStyle(
          color: hasKey ? AppColors.success : AppColors.textMuted,
          fontSize: 11,
        ),
      ),
      trailing: hasKey
          ? IconButton(
              iconSize: 20,
              icon: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.danger),
              tooltip: 'Remove key',
              onPressed: () => _deleteApiKey(context, ref),
            )
          : TextButton(
              onPressed: () => _showAddApiKeyDialog(context, controller),
              child: const Text(
                'Add Key',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
      onTap: hasKey
          ? () => context.showSnackBar(
                'Delete the key first to add a new one.',
                type: AppFeedbackType.warning,
              )
          : () => _showAddApiKeyDialog(context, controller),
    );
  }

  void _showAddApiKeyDialog(
    BuildContext context,
    AppPreferencesController controller,
  ) {
    showDialog<void>(
      context: context,
      builder: (_) => _ApiKeyAddDialog(
        onSave: (key) async {
          await controller.setAiApiKey(key);
          if (context.mounted) {
            context.showSnackBar('AI API key saved.');
          }
        },
      ),
    );
  }

  Future<void> _deleteApiKey(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(appPreferencesControllerProvider);
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Remove AI Key?', style: TextStyle(fontWeight: FontWeight.bold)),
            content: const Text(
              'The Gemini API key will be deleted. AI-powered features '
              'will be unavailable until you add a new key.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Remove'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmed) {
      await controller.setAiApiKey('');
      if (context.mounted) {
        context.showSnackBar('AI API key removed.');
      }
    }
  }

  Widget _buildAiModelSelector(
    String currentId,
    AppPreferencesController controller,
  ) {
    final selected = _kGeminiModels.any((m) => m.id == currentId)
        ? currentId
        : _kGeminiModels.first.id;
    final model = _kGeminiModels.firstWhere((m) => m.id == selected);

    return ListTile(
      leading: const SettingsTileIcon(icon: Icons.settings_suggest_rounded),
      title: const Text(
        'Gemini Model',
        style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        model.description,
        style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
      ),
      trailing: SettingsChoiceMenu(
        value: selected,
        sheetTitle: 'Gemini Model',
        onChanged: (v) {
          if (v != null) controller.setAiModelId(v);
        },
        options: _kGeminiModels
            .map<({String value, String label, IconData? icon, Color? iconColor})>(
              (m) => (
                value: m.id,
                label: m.label,
                icon: Icons.auto_awesome_outlined,
                iconColor: AppColors.primaryBlue,
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  Widget _buildAiFeatureToggle({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: SettingsTileIcon(icon: icon),
      title: Text(
        title,
        style: const TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primaryBlue,
      ),
    );
  }
}

class _ApiKeyAddDialog extends StatefulWidget {
  const _ApiKeyAddDialog({required this.onSave});

  final Future<void> Function(String key) onSave;

  @override
  State<_ApiKeyAddDialog> createState() => _ApiKeyAddDialogState();
}

class _ApiKeyAddDialogState extends State<_ApiKeyAddDialog> {
  late final TextEditingController _ctrl;
  String? _error;
  bool _saving = false;

  static bool _isValidKey(String key) =>
      key.startsWith('AIzaSy') && key.length == 39;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final key = _ctrl.text.trim();
    if (!_isValidKey(key)) {
      setState(() =>
          _error = 'Key must start with "AIzaSy" and be 39 characters long.');
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    await widget.onSave(key);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Add Gemini API Key',
        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your key is stored only on this device.\n'
              'To change it later, delete and re-add.',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            InkWell(
              onTap: () async {
                final uri = Uri.parse('https://aistudio.google.com/api-keys');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.open_in_new_rounded,
                        size: 13, color: AppColors.primaryBlue),
                    SizedBox(width: 4),
                    Text(
                      'Get your key at aistudio.google.com',
                      style: TextStyle(
                        color: AppColors.primaryBlue,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ctrl,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              decoration: InputDecoration(
                hintText: 'AIzaSy…',
                errorText: _error,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
