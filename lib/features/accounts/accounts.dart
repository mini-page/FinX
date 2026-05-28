/// Accounts feature public API.
///
/// Import this barrel to access all accounts-related screens, widgets, and
/// providers without coupling consumers to the internal directory layout.
library;

// Presentation – screens
export 'presentation/screens/accounts_screen.dart';
export 'presentation/screens/accounts/accounts_widgets.dart';

// Presentation – widgets
export 'presentation/widgets/account_editor_sheet.dart';
export 'presentation/widgets/account_icons.dart';

// Presentation – providers
export 'presentation/provider/account_providers.dart';

// Data models
export 'data/models/account_model.dart';
