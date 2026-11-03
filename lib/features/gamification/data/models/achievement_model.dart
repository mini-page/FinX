import 'package:flutter/material.dart';

enum AchievementId {
  firstExpense,
  streak3,
  streak7,
  streak30,
  budgetMaster,
  categoryExplorer,
  saver,
  splitter,
  receiptScanner,
  subscriptionTracker,
  nightOwl,
  earlyBird,
}

class AchievementDef {
  const AchievementDef({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
  });

  final AchievementId id;
  final String title;
  final String description;
  final IconData icon;

  static const List<AchievementDef> all = [
    AchievementDef(
      id: AchievementId.firstExpense,
      title: 'First Step',
      description: 'Log your first expense',
      icon: Icons.edit_note_rounded,
    ),
    AchievementDef(
      id: AchievementId.streak3,
      title: 'Getting Started',
      description: 'Log expenses for 3 consecutive days',
      icon: Icons.local_fire_department_rounded,
    ),
    AchievementDef(
      id: AchievementId.streak7,
      title: 'Week Warrior',
      description: 'Log expenses for 7 consecutive days',
      icon: Icons.local_fire_department_rounded,
    ),
    AchievementDef(
      id: AchievementId.streak30,
      title: 'Month Master',
      description: 'Log expenses for 30 consecutive days',
      icon: Icons.whatshot_rounded,
    ),
    AchievementDef(
      id: AchievementId.budgetMaster,
      title: 'Budget Master',
      description: 'Stay within budget for a full month',
      icon: Icons.account_balance_wallet_rounded,
    ),
    AchievementDef(
      id: AchievementId.categoryExplorer,
      title: 'Explorer',
      description: 'Use 5+ different expense categories',
      icon: Icons.explore_rounded,
    ),
    AchievementDef(
      id: AchievementId.saver,
      title: 'Super Saver',
      description: 'Save more than you spend in a month',
      icon: Icons.savings_rounded,
    ),
    AchievementDef(
      id: AchievementId.splitter,
      title: 'Fair Share',
      description: 'Create a split expense',
      icon: Icons.call_split_rounded,
    ),
    AchievementDef(
      id: AchievementId.receiptScanner,
      title: 'Scanner',
      description: 'Scan a receipt with OCR',
      icon: Icons.document_scanner_rounded,
    ),
    AchievementDef(
      id: AchievementId.subscriptionTracker,
      title: 'Subscription Guru',
      description: 'Track 3+ subscriptions',
      icon: Icons.repeat_rounded,
    ),
    AchievementDef(
      id: AchievementId.nightOwl,
      title: 'Night Owl',
      description: 'Log an expense after 10 PM',
      icon: Icons.nightlight_round,
    ),
    AchievementDef(
      id: AchievementId.earlyBird,
      title: 'Early Bird',
      description: 'Log an expense before 7 AM',
      icon: Icons.wb_sunny_rounded,
    ),
  ];
}

class GamificationState {
  const GamificationState({
    this.streak = 0,
    this.longestStreak = 0,
    this.totalExpenses = 0,
    this.categoriesUsed = 0,
    this.hasSplitExpense = false,
    this.hasScannedReceipt = false,
    this.subscriptionCount = 0,
    this.unlockedAchievements = const {},
    this.hasNightOwl = false,
    this.hasEarlyBird = false,
    this.monthSaved = false,
    this.monthWithinBudget = false,
  });

  final int streak;
  final int longestStreak;
  final int totalExpenses;
  final int categoriesUsed;
  final bool hasSplitExpense;
  final bool hasScannedReceipt;
  final int subscriptionCount;
  final Set<AchievementId> unlockedAchievements;
  final bool hasNightOwl;
  final bool hasEarlyBird;
  final bool monthSaved;
  final bool monthWithinBudget;

  bool isUnlocked(AchievementId id) => unlockedAchievements.contains(id);

  GamificationState copyWith({
    int? streak,
    int? longestStreak,
    int? totalExpenses,
    int? categoriesUsed,
    bool? hasSplitExpense,
    bool? hasScannedReceipt,
    int? subscriptionCount,
    Set<AchievementId>? unlockedAchievements,
    bool? hasNightOwl,
    bool? hasEarlyBird,
    bool? monthSaved,
    bool? monthWithinBudget,
  }) =>
      GamificationState(
        streak: streak ?? this.streak,
        longestStreak: longestStreak ?? this.longestStreak,
        totalExpenses: totalExpenses ?? this.totalExpenses,
        categoriesUsed: categoriesUsed ?? this.categoriesUsed,
        hasSplitExpense: hasSplitExpense ?? this.hasSplitExpense,
        hasScannedReceipt: hasScannedReceipt ?? this.hasScannedReceipt,
        subscriptionCount: subscriptionCount ?? this.subscriptionCount,
        unlockedAchievements:
            unlockedAchievements ?? this.unlockedAchievements,
        hasNightOwl: hasNightOwl ?? this.hasNightOwl,
        hasEarlyBird: hasEarlyBird ?? this.hasEarlyBird,
        monthSaved: monthSaved ?? this.monthSaved,
        monthWithinBudget: monthWithinBudget ?? this.monthWithinBudget,
      );
}
