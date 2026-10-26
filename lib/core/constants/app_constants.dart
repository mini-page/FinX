/// Application-wide constants shared across the app.
abstract final class AppConstants {
  /// The current app version string.  Keep in sync with pubspec.yaml.
  static const String version = '3.0.0';

  /// Display name shown on the about dialog and in the drawer footer.
  static const String appName = 'Expensio';

  /// Supported currency options (symbol → display label).
  static const List<({String symbol, String label})> currencies = [
    (symbol: '₹', label: 'Rupee (₹)'),
    (symbol: r'$', label: 'Dollar (\$)'),
    (symbol: '€', label: 'Euro (€)'),
    (symbol: '£', label: 'Pound (£)'),
    (symbol: '¥', label: 'Yen (¥)'),
    (symbol: 'د.إ', label: 'Dirham (د.إ)'),
    (symbol: '৳', label: 'Taka (৳)'),
    (symbol: 'S\$', label: 'SGD (S\$)'),
  ];

  /// Supported language/locale options (locale → display label).
  static const List<({String locale, String label})> locales = [
    (locale: 'en_IN', label: 'English (India)'),
    (locale: 'en_US', label: 'English (US)'),
    (locale: 'hi_IN', label: 'हिन्दी (Hindi)'),
    (locale: 'ar_AE', label: 'العربية'),
    (locale: 'ja_JP', label: '日本語'),
  ];
}
