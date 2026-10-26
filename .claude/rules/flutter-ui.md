# flutter-ui.md — Flutter UI Engineering Standards

## Widget Structure

- Every screen lives in `lib/features/<feature>/presentation/screens/<screen>_screen.dart`.
- When a screen file exceeds **200 lines**, extract private widgets into a sibling subdirectory `screens/<screen>/` and name them `<screen>_widgets.dart` or `<screen>_<concern>.dart`.
- Never nest a `Scaffold` inside another `Scaffold`.
- Prefer `CustomScrollView` + `Sliver*` widgets for complex scrolling layouts.

## Theming

- **Always** use `Theme.of(context).colorScheme.*` tokens — never hardcode `Color(0x...)` or `Colors.*` in widgets.
- Define app-wide color tokens in `lib/core/theme/app_colors.dart`.
- Support both light and dark modes; test both before merging.
- Use `TextTheme` for typography: `Theme.of(context).textTheme.bodyMedium`, etc.

## Responsiveness

- No hardcoded pixel widths/heights. Use `MediaQuery.of(context).size`, `LayoutBuilder`, or `Flexible`/`Expanded`.
- Web breakpoints: ≤ 600 dp = mobile layout; > 600 dp = tablet/desktop layout.
- Minimum tap-target size: **48 × 48 dp** (Material accessibility guideline).

## Performance

- Use `const` constructors everywhere the widget is stateless and its subtree is fixed.
- Use `ListView.builder` / `SliverList.builder` for any list with more than ~20 items.
- Use `RepaintBoundary` around eExpensioive animated children.
- Avoid calling `MediaQuery.of(context)` deep in the widget tree — hoist it to the nearest screen.

## Accessibility

- All interactive elements have `Semantics` labels or `tooltip` text.
- Images have `semanticLabel`.
- Screen-reader order follows visual top-to-bottom flow.
