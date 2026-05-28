import 'package:flutter/material.dart';

/// Maps a category icon key string to its [IconData].
/// Used by [CustomCategoryModel] and [CategoryEditorSheet].
IconData categoryIconFromKey(String key) {
  switch (key) {
    case 'restaurant':
      return Icons.restaurant_outlined;
    case 'transport':
      return Icons.directions_bus_outlined;
    case 'shopping':
      return Icons.shopping_bag_outlined;
    case 'home':
      return Icons.home_outlined;
    case 'health':
      return Icons.health_and_safety_outlined;
    case 'education':
      return Icons.school_outlined;
    case 'entertainment':
      return Icons.movie_outlined;
    case 'gym':
      return Icons.fitness_center_outlined;
    case 'pets':
      return Icons.pets_outlined;
    case 'gift':
      return Icons.card_giftcard_outlined;
    case 'work':
      return Icons.work_outline_rounded;
    case 'star':
      return Icons.star_outline_rounded;
    case 'beauty':
      return Icons.auto_awesome_outlined;
    case 'social':
      return Icons.more_horiz_rounded;
    case 'travel':
      return Icons.flight_takeoff_outlined;
    case 'widgets':
      return Icons.widgets_outlined;
    case 'watch':
      return Icons.watch_outlined;
    case 'award':
      return Icons.emoji_events_outlined;
    case 'coupon':
      return Icons.confirmation_num_outlined;
    case 'lottery':
      return Icons.casino_outlined;
    case 'refund':
      return Icons.replay_circle_filled_outlined;
    case 'sale':
      return Icons.sell_outlined;
    case 'savings':
      return Icons.savings_outlined;
    case 'invest':
      return Icons.trending_up_rounded;
    case 'rent':
      return Icons.house_outlined;
    case 'bill':
      return Icons.receipt_outlined;
    case 'phone':
      return Icons.phone_android_outlined;
    case 'game':
      return Icons.sports_esports_outlined;
    case 'food':
      return Icons.fastfood_outlined;
    case 'coffee':
      return Icons.coffee_outlined;
    case 'music':
      return Icons.music_note_outlined;
    case 'sport':
      return Icons.sports_outlined;
    case 'car':
      return Icons.directions_car_outlined;
    default:
      return Icons.category_outlined;
  }
}

class ExpenseCategory {
  const ExpenseCategory({
    required this.name,
    required this.icon,
    required this.color,
    this.iconKey = 'category',
  });

  final String name;
  final IconData icon;
  final Color color;

  /// Icon key string that maps to this category's icon via [categoryIconFromKey].
  final String iconKey;

  /// 6-char hex colour string without '#', e.g. `'FFB648'`.
  String get colorHex =>
      color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();
}

const List<ExpenseCategory> expenseCategories = <ExpenseCategory>[
  ExpenseCategory(
    name: 'Food & Dining',
    icon: Icons.restaurant_outlined,
    color: Color(0xFFFFB648),
    iconKey: 'restaurant',
  ),
  ExpenseCategory(
    name: 'Transportation',
    icon: Icons.directions_bus_outlined,
    color: Color(0xFF61A7FF),
    iconKey: 'transport',
  ),
  ExpenseCategory(
    name: 'Shopping',
    icon: Icons.shopping_bag_outlined,
    color: Color(0xFFFF8C7A),
    iconKey: 'shopping',
  ),
  ExpenseCategory(
    name: 'Beauty & Care',
    icon: Icons.auto_awesome_outlined,
    color: Color(0xFFFF72B6),
    iconKey: 'beauty',
  ),
  ExpenseCategory(
    name: 'Social',
    icon: Icons.more_horiz_rounded,
    color: Color(0xFF9B8CFF),
    iconKey: 'social',
  ),
  ExpenseCategory(
    name: 'Travel',
    icon: Icons.flight_takeoff_outlined,
    color: Color(0xFF4BB7A6),
    iconKey: 'travel',
  ),
  ExpenseCategory(
    name: 'Other',
    icon: Icons.widgets_outlined,
    color: Color(0xFF7B8BAA),
    iconKey: 'widgets',
  ),
  ExpenseCategory(
    name: 'Accessories',
    icon: Icons.watch_outlined,
    color: Color(0xFF6D8FFF),
    iconKey: 'watch',
  ),
];

const List<ExpenseCategory> incomeCategories = <ExpenseCategory>[
  ExpenseCategory(
    name: 'Salary',
    icon: Icons.work_outline_rounded,
    color: Color(0xFF8FC7FF),
    iconKey: 'work',
  ),
  ExpenseCategory(
    name: 'Award',
    icon: Icons.emoji_events_outlined,
    color: Color(0xFFB4EFB8),
    iconKey: 'award',
  ),
  ExpenseCategory(
    name: 'Coupon',
    icon: Icons.confirmation_num_outlined,
    color: Color(0xFFFFB9C6),
    iconKey: 'coupon',
  ),
  ExpenseCategory(
    name: 'Grant',
    icon: Icons.card_giftcard_outlined,
    color: Color(0xFFD0BEFF),
    iconKey: 'gift',
  ),
  ExpenseCategory(
    name: 'Lottery',
    icon: Icons.casino_outlined,
    color: Color(0xFFFFE38A),
    iconKey: 'lottery',
  ),
  ExpenseCategory(
    name: 'Refund',
    icon: Icons.replay_circle_filled_outlined,
    color: Color(0xFF7FD4C0),
    iconKey: 'refund',
  ),
  ExpenseCategory(
    name: 'Sale',
    icon: Icons.sell_outlined,
    color: Color(0xFFFFCB7A),
    iconKey: 'sale',
  ),
];

ExpenseCategory resolveExpenseCategory(
  String name, [
  List<ExpenseCategory> extra = const [],
]) {
  for (final c in extra) {
    if (c.name == name) return c;
  }
  return expenseCategories.firstWhere(
    (category) => category.name == name,
    orElse: () => expenseCategories.last,
  );
}

ExpenseCategory resolveIncomeCategory(
  String name, [
  List<ExpenseCategory> extra = const [],
]) {
  for (final c in extra) {
    if (c.name == name) return c;
  }
  return incomeCategories.firstWhere(
    (category) => category.name == name,
    orElse: () => incomeCategories.last,
  );
}

ExpenseCategory resolveCategory(
  String name, {
  bool income = false,
  List<ExpenseCategory> extra = const [],
}) {
  return income
      ? resolveIncomeCategory(name, extra)
      : resolveExpenseCategory(name, extra);
}
