import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

import 'core/constants/app_constants.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/background_backup.dart';
import 'core/utils/hive_bootstrap.dart';
import 'core/utils/recurring_notification_task.dart';
import 'package:expensio/features/settings/presentation/provider/preferences_providers.dart';
import 'features/expense/presentation/screens/app_shell.dart';
import 'package:expensio/features/settings/presentation/screens/onboarding_screen.dart';
import 'package:expensio/features/settings/presentation/screens/pin_entry_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    Workmanager().initialize(callbackDispatcher);

    // ── Recurring due-date notification check — every 6 hours ───────────────
    Workmanager().registerPeriodicTask(
      kRecurringCheckTask,
      kRecurringCheckTask,
      frequency: const Duration(hours: 6),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(
        networkType: NetworkType.notRequired,
        requiresBatteryNotLow: false,
      ),
    );
  } catch (e) {
    debugPrint('Workmanager init error: $e');
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
  );

  try {
    await HiveBootstrap.initialize();
  } catch (e) {
    debugPrint('HiveBootstrap error: $e');
  }

  try {
    await NotificationService.instance.initialize();
  } catch (e) {
    debugPrint('NotificationService error: $e');
  }

  runApp(const ProviderScope(child: ExpensioApp()));
}

class ExpensioApp extends ConsumerWidget {
  const ExpensioApp({super.key});

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
