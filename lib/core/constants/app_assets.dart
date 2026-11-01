/// Central asset path registry.
abstract final class AppAssets {
  // ── In-app images ─────────────────────────────────────────────────────────

  /// Default in-app brand logo (Dark swoosh on transparent background, optimal for light surfaces).
  static const String logo = 'assets/images/expensio_logo.png';

  /// Dark swoosh logo on transparent background (for white / light surfaces).
  static const String logoDark = 'assets/images/expensio_logo_dark.png';

  /// White swoosh logo on transparent background (for black / dark surfaces).
  static const String logoLight = 'assets/images/expensio_logo_light.png';

  // ── Launcher / splash icons ───────────────────────────────────────────────

  /// Solid brand launcher icon (1024×1024 on #0E1626 dark background).
  static const String appIcon = 'assets/icon/app_icon.png';

  /// Android adaptive icon foreground (transparent background, white swoosh).
  static const String appIconFg = 'assets/icon/app_icon_fg.png';

  /// Native splash screen mark (white swoosh on transparent background).
  static const String splashMark = 'assets/icon/splash_mark.png';

  /// High-res brand mark logo.
  static const String brandLogo = 'assets/icon/brand_logo.png';
}
