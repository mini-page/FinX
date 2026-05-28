import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_button.dart';
import 'package:xpens/features/accounts/accounts.dart';
import '../provider/preferences_providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Preferences state
  String _selectedLocale = 'en_IN';
  String _selectedCurrency = '₹';
  String _selectedThemeKey = 'light';
  bool _smartReminders = true;
  String _accountName = 'Main Account';
  double _initialBalance = 0.0;
  String _aiApiKey = '';

  // Step definitions
  static const int _pageCount = 5;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pageCount - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _previousPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                children: List.generate(_pageCount, (index) {
                  final isActive = index <= _currentPage;
                  return Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 4,
                      margin: EdgeInsets.only(
                        right: index < _pageCount - 1 ? 6 : 0,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.primaryBlue
                            : AppColors.surfaceAccent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) => setState(() => _currentPage = page),
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  const _WelcomePage(),
                  _LocalePage(
                    selectedLocale: _selectedLocale,
                    selectedCurrency: _selectedCurrency,
                    onLocaleChanged: (v) => setState(() => _selectedLocale = v),
                    onCurrencyChanged: (v) =>
                        setState(() => _selectedCurrency = v),
                  ),
                  _AccountPage(
                    accountName: _accountName,
                    initialBalance: _initialBalance,
                    onNameChanged: (v) => _accountName = v,
                    onBalanceChanged: (v) =>
                        _initialBalance = double.tryParse(v) ?? 0,
                  ),
                  _PreferencesPage(
                    themeKey: _selectedThemeKey,
                    smartReminders: _smartReminders,
                    onThemeChanged: (v) =>
                        setState(() => _selectedThemeKey = v),
                    onRemindersChanged: (v) =>
                        setState(() => _smartReminders = v),
                  ),
                  _AiApiKeyPage(
                    apiKey: _aiApiKey,
                    onApiKeyChanged: (v) => _aiApiKey = v,
                  ),
                ],
              ),
            ),

            // Navigation buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      if (_currentPage > 0)
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: OutlinedButton(
                            onPressed: _previousPage,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              side: const BorderSide(
                                  color: AppColors.primaryBlue),
                            ),
                            child: const Text(
                              'Back',
                              style: TextStyle(
                                color: AppColors.primaryBlue,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      Expanded(
                        child: AppButton(
                          label: _currentPage == _pageCount - 1
                              ? 'Save & Get Started 🚀'
                              : 'Continue',
                          onPressed: _nextPage,
                        ),
                      ),
                    ],
                  ),
                  if (_currentPage == _pageCount - 1) ...[
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _completeOnboarding,
                      child: const Text(
                        'Skip for now',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _completeOnboarding() async {
    final accountName =
        _accountName.trim().isEmpty ? 'Main Account' : _accountName;

    await ref.read(accountControllerProvider).saveAccount(
          name: accountName,
          iconKey: 'wallet',
          balance: _initialBalance,
        );

    await ref.read(appPreferencesControllerProvider).updateAll(
          themeModeKey: _selectedThemeKey,
          locale: _selectedLocale,
          currencySymbol: _selectedCurrency,
          smartRemindersEnabled: _smartReminders,
          isOnboardingCompleted: true,
        );

    final apiKey = _aiApiKey.trim();
    if (apiKey.isNotEmpty) {
      await ref.read(appPreferencesControllerProvider).setAiApiKey(apiKey);
    }
  }
}

// ---------------------------------------------------------------------------
// Page 1: Welcome
// ---------------------------------------------------------------------------
class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Spacer(),
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset(AppAssets.logo, width: 96, height: 96),
          ),
          const SizedBox(height: 28),
          Text(
            'Welcome to XPens',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.textDark,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'Your smart offline expense tracker.\nLet\'s set you up in a minute.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSubtle,
                  height: 1.5,
                ),
          ),
          const Spacer(flex: 2),
          Text(
            'Version ${AppConstants.version}',
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page 2: Language & Currency
// ---------------------------------------------------------------------------
class _LocalePage extends StatelessWidget {
  const _LocalePage({
    required this.selectedLocale,
    required this.selectedCurrency,
    required this.onLocaleChanged,
    required this.onCurrencyChanged,
  });

  final String selectedLocale;
  final String selectedCurrency;
  final ValueChanged<String> onLocaleChanged;
  final ValueChanged<String> onCurrencyChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          _OnboardingStepHeader(
            icon: Icons.language_rounded,
            title: 'Language & Currency',
            subtitle: 'Choose your region and preferred currency',
          ),
          const SizedBox(height: 28),
          _SectionLabel(label: 'Language'),
          const SizedBox(height: 10),
          _OptionGrid<String>(
            options: AppConstants.locales
                .map((l) => _OptionItem(label: l.label, value: l.locale))
                .toList(),
            selected: selectedLocale,
            onSelected: onLocaleChanged,
          ),
          const SizedBox(height: 24),
          _SectionLabel(label: 'Currency'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: AppConstants.currencies.map((c) {
              final isSelected = selectedCurrency == c.symbol;
              return ChoiceChip(
                label: Text(c.label),
                selected: isSelected,
                onSelected: (_) => onCurrencyChanged(c.symbol),
                selectedColor: AppColors.primaryBlue,
                backgroundColor: Colors.white,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textDark,
                  fontWeight: FontWeight.w700,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page 3: First Account
// ---------------------------------------------------------------------------
class _AccountPage extends StatelessWidget {
  const _AccountPage({
    required this.accountName,
    required this.initialBalance,
    required this.onNameChanged,
    required this.onBalanceChanged,
  });

  final String accountName;
  final double initialBalance;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onBalanceChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          _OnboardingStepHeader(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Your First Account',
            subtitle: 'This is where your transactions will be recorded',
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.cardShadow,
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                TextFormField(
                  initialValue: accountName,
                  onChanged: onNameChanged,
                  decoration: InputDecoration(
                    labelText: 'Account Name',
                    hintText: 'e.g. Cash, HDFC, SBI',
                    prefixIcon: const Icon(Icons.wallet_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: initialBalance > 0
                      ? initialBalance.toStringAsFixed(0)
                      : '',
                  onChanged: onBalanceChanged,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Opening Balance (optional)',
                    hintText: '0',
                    prefixIcon: const Icon(Icons.currency_rupee_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'You can add more accounts later from the Tools page.',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page 4: Theme & Preferences
// ---------------------------------------------------------------------------
class _PreferencesPage extends StatelessWidget {
  const _PreferencesPage({
    required this.themeKey,
    required this.smartReminders,
    required this.onThemeChanged,
    required this.onRemindersChanged,
  });

  final String themeKey;
  final bool smartReminders;
  final ValueChanged<String> onThemeChanged;
  final ValueChanged<bool> onRemindersChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          _OnboardingStepHeader(
            icon: Icons.tune_rounded,
            title: 'Preferences',
            subtitle: 'Customise how XPens looks and behaves',
          ),
          const SizedBox(height: 28),
          _SectionLabel(label: 'Theme'),
          const SizedBox(height: 10),
          Row(
            children: [
              _ThemeOption(
                  label: 'Light',
                  themeKey: 'light',
                  icon: Icons.light_mode_outlined,
                  selected: themeKey,
                  onTap: onThemeChanged),
              const SizedBox(width: 10),
              _ThemeOption(
                  label: 'Dark',
                  themeKey: 'dark',
                  icon: Icons.dark_mode_outlined,
                  selected: themeKey,
                  onTap: onThemeChanged),
              const SizedBox(width: 10),
              _ThemeOption(
                  label: 'System',
                  themeKey: 'system',
                  icon: Icons.brightness_auto_outlined,
                  selected: themeKey,
                  onTap: onThemeChanged),
            ],
          ),
          const SizedBox(height: 28),
          _SectionLabel(label: 'Notifications'),
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SwitchListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Smart Reminders',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              subtitle: const Text(
                'Get notified for pending bills & recurring transactions',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              value: smartReminders,
              activeThumbColor: AppColors.primaryBlue,
              onChanged: onRemindersChanged,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared sub-widgets
// ---------------------------------------------------------------------------

class _OnboardingStepHeader extends StatelessWidget {
  const _OnboardingStepHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: AppColors.primaryBlue, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AppColors.textDark,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        color: AppColors.textMuted,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _OptionItem<T> {
  const _OptionItem({required this.label, required this.value});
  final String label;
  final T value;
}

class _OptionGrid<T> extends StatelessWidget {
  const _OptionGrid({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<_OptionItem<T>> options;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options.map((opt) {
        final isSelected = opt.value == selected;
        return GestureDetector(
          onTap: () => onSelected(opt.value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primaryBlue : Colors.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: isSelected
                    ? AppColors.primaryBlue
                    : AppColors.surfaceAccent,
                width: 1.5,
              ),
            ),
            child: Text(
              opt.label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textDark,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.label,
    required this.themeKey,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String themeKey;
  final IconData icon;
  final String selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == themeKey;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(themeKey),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryBlue.withValues(alpha: 0.1)
                : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color:
                  isSelected ? AppColors.primaryBlue : AppColors.surfaceAccent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 22,
                color:
                    isSelected ? AppColors.primaryBlue : AppColors.textSubtle,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color:
                      isSelected ? AppColors.primaryBlue : AppColors.textSubtle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page 5: AI API Key (optional)
// ---------------------------------------------------------------------------
class _AiApiKeyPage extends StatefulWidget {
  const _AiApiKeyPage({
    required this.apiKey,
    required this.onApiKeyChanged,
  });

  final String apiKey;
  final ValueChanged<String> onApiKeyChanged;

  @override
  State<_AiApiKeyPage> createState() => _AiApiKeyPageState();
}

class _AiApiKeyPageState extends State<_AiApiKeyPage> {
  late final TextEditingController _keyCtrl;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _keyCtrl = TextEditingController(text: widget.apiKey);
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          _OnboardingStepHeader(
            icon: Icons.auto_awesome_rounded,
            title: 'Unlock AI Features',
            subtitle: 'Supercharge XPens with Gemini AI',
          ),
          const SizedBox(height: 20),
          // Feature highlights
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primaryBlue.withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _AiFeatureRow(
                  icon: Icons.search_rounded,
                  label: 'Smart expense search & insights',
                ),
                SizedBox(height: 8),
                _AiFeatureRow(
                  icon: Icons.mic_rounded,
                  label: 'Voice entry — just speak your expense',
                ),
                SizedBox(height: 8),
                _AiFeatureRow(
                  icon: Icons.document_scanner_rounded,
                  label: 'Receipt & bill scanning',
                ),
                SizedBox(height: 8),
                _AiFeatureRow(
                  icon: Icons.sms_rounded,
                  label: 'Automatic SMS transaction detection',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _keyCtrl,
            onChanged: widget.onApiKeyChanged,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'Gemini API Key (optional)',
              hintText: 'AIza...',
              prefixIcon: const Icon(Icons.key_rounded),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              helperText: 'Get your free key at aistudio.google.com',
              helperStyle: const TextStyle(
                color: AppColors.primaryBlue,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.surfaceAccent),
            ),
            child: Row(
              children: const [
                Icon(Icons.info_outline_rounded,
                    color: AppColors.textMuted, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'You can add or change this later in Settings → AI Features',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
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

class _AiFeatureRow extends StatelessWidget {
  const _AiFeatureRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryBlue, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
