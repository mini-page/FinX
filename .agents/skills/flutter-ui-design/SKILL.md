# Flutter UI Design — Skill Module

## Domain
Flutter UI/UX design patterns, theming, layout systems, adaptive design, and component architecture for Android and Web.

## Core Concepts

### Layout System
- **Constraints flow down, sizes flow up**: every widget receives constraints from its parent and reports its own size back.
- Use `Flexible` / `Expanded` inside `Row` / `Column` to share available space proportionally.
- Use `ConstrainedBox`, `SizedBox`, or `FractionallySizedBox` for explicit sizing.
- `LayoutBuilder` provides parent constraints at build time — use for breakpoint-aware layouts.

### Adaptive Design (Android + Web)
```dart
class AdaptiveLayout extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width > 600 ? _WideLayout() : _NarrowLayout();
  }
}
```
- Mobile (< 600 dp): single-column, bottom-navigation, full-width cards.
- Tablet/Web (≥ 600 dp): two-column, side-rail navigation, constrained-width content.

### Theming
- All color decisions via `Theme.of(context).colorScheme.*` (Material 3 tokens).
- Typography via `Theme.of(context).textTheme.*`.
- Custom theme extensions for app-specific tokens (e.g., `AppColors`).
- Always define both `theme` and `darkTheme` in `MaterialApp`.

### Component Architecture
- **Atomic**: smallest reusable unit (e.g., `AmountChip`, `CategoryBadge`).
- **Molecule**: combination of atoms (e.g., `TransactionCard`).
- **Organism**: feature-level widget (e.g., `ExpenseList`, `NetWorthHeroCard`).
- **Screen**: full-page widget with scaffold; thin — delegates to organisms.

### Animation
- Use `AnimatedSwitcher`, `AnimatedContainer`, `Hero` for transitions.
- Keep animation durations 150–300 ms for UI feedback, 300–500 ms for page transitions.
- Avoid heavy animations on the main list scroll path.

## Checklist
- [ ] `const` constructors on all leaf widgets.
- [ ] No hardcoded colors or text styles.
- [ ] Tested on 360 dp (small Android) and 1280 dp (Web) viewports.
- [ ] Dark mode verified.
- [ ] Accessibility: `Semantics`, contrast ≥ 4.5:1 for normal text.
