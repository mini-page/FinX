import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/background_backup.dart';
import 'core/utils/hive_bootstrap.dart';
import 'package:xpens/features/settings/presentation/provider/preferences_providers.dart';
import 'features/expense/presentation/screens/app_shell.dart';
import 'package:xpens/features/settings/presentation/screens/onboarding_screen.dart';
import 'package:xpens/features/settings/presentation/screens/pin_entry_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Workmanager().initialize(
    callbackDispatcher,
  );

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
  );
  await HiveBootstrap.initialize();
  runApp(const ProviderScope(child: XPensApp()));
}

class XPensApp extends ConsumerWidget {
  const XPensApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(appThemeModeProvider);
    final onboardingCompleted = ref.watch(isOnboardingCompletedProvider);
    final preferencesAsync = ref.watch(appPreferencesProvider);
    final isPinEnabled = ref.watch(isPinEnabledProvider);
    final isBiometricEnabled = ref.watch(biometricLockEnabledProvider);
    final localeString = ref.watch(localeProvider);

    // Parse locale (e.g. 'en_IN' → Locale('en', 'IN'))
    final parts = localeString.split('_');
    final appLocale =
        parts.length >= 2 ? Locale(parts[0], parts[1]) : Locale(parts[0]);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppConstants.appName,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      locale: appLocale,
      home: preferencesAsync.when(
        data: (_) {
          if (!onboardingCompleted) return const OnboardingScreen();
          if (isPinEnabled) {
            return PinEntryScreen(
              isSetup: false,
              tryBiometricFirst: isBiometricEnabled,
            );
          }
          return const AppShell();
        },
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const AppShell(),
      ),
    );
  }
}
