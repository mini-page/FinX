/// Analytics / Statistics feature public API.
///
/// Import this barrel to access all statistics-related screens, widgets, and
/// providers.
///
/// The underlying stats computation lives in `expense_providers.dart`
/// (`statsProvider`) because it is tightly coupled to the expense data model.
/// Future work: extract `StatsNotifier` into this feature's own provider.
library;

// Presentation – screens
export 'presentation/screens/stats_screen.dart';
export 'presentation/screens/stats/stats_widgets.dart';

// Presentation – providers (stats live in the expense providers for now)
export 'package:xpens/features/expense/presentation/provider/expense_providers.dart'
    show statsProvider;
