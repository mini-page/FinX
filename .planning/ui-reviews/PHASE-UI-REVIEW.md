# Phase UI — UI Review

**Audited:** 2026-03-28
**Baseline:** Abstract 6-pillar standards plus `docs/plans/2026-03-26-ui-navigation-redesign.md` and `docs/plans/2026-03-26-ui-navigation-search-implementation.md`
**Screenshots:** Not captured (no dev server on `localhost:3000`, `5173`, or `8080`)

---

## Pillar Scores

| Pillar | Score | Key Finding |
|--------|-------|-------------|
| 1. Copywriting | 3/4 | Empty and error states are mostly specific, but primary actions still expose placeholder and generic labels. |
| 2. Visuals | 3/4 | The app has strong focal points and a clear blue-led direction, but several navigation and utility actions are low-discoverability. |
| 3. Color | 2/4 | The palette foundation is coherent, but token discipline is weak with 50 hardcoded color usages across the audited UI. |
| 4. Typography | 2/4 | Hierarchy exists, but the system is over-fragmented with 19 font sizes and 4 weight tiers in the reviewed screens. |
| 5. Spacing | 2/4 | Layouts feel deliberate, yet spacing and radius values drift heavily through one-off numbers instead of a restrained scale. |
| 6. Experience Design | 2/4 | State coverage is decent, but destructive actions lack confirmation or undo and the Power Pill advertises unfinished actions. |

**Overall: 14/24**

---

## Top 3 Priority Fixes

1. **Add confirmation or undo for destructive actions** — users can lose transactions, accounts, and subscriptions with a single tap — add a confirm dialog or `SnackBarAction` undo flow for every delete path.
2. **Centralize visual tokens for color, type, spacing, and radius** — the UI direction is strong but implementation drift makes screens feel assembled rather than systemized — move repeated values into theme/token helpers and replace hardcoded `Color`, `fontSize`, `EdgeInsets`, and `Radius` literals.
3. **Hide, disable, or relabel unfinished utility actions** — the Power Pill and drawer currently surface features that lead to placeholders or vague destinations — gate unfinished actions behind disabled states with explanatory copy, and replace generic labels like `Miscellaneous` with explicit destinations.

---

## Detailed Findings

### Pillar 1: Copywriting (3/4)
- Home, stats, and recurring states use direct, user-facing copy instead of dead-end blanks, which is good for first-run and failure scenarios: `lib/features/Expense/presentation/screens/home_screen.dart:177-193`, `lib/features/Expense/presentation/screens/stats_screen.dart:238-251`, `lib/features/Expense/presentation/widgets/recurring_tool_view.dart:65-75`.
- The Power Pill still exposes unfinished actions as if they are usable. `Voice` and `Split` resolve to placeholder snackbars rather than a disabled or upcoming pattern: `lib/features/Expense/presentation/screens/app_shell.dart:28-35`.
- Drawer IA is underspecified. `Support` and especially `Miscellaneous` are too vague to earn permanent space in the utility section: `lib/features/Expense/presentation/widgets/app_drawer.dart:50-69`.
- `View All` is serviceable but generic against an otherwise stylized UI vocabulary: `lib/features/Expense/presentation/screens/home_screen.dart:152-154`.

### Pillar 2: Visuals (3/4)
- The redesign direction from the plan docs is visible in the implementation: a strong home header, a card-led analytics page, and a focused amount-first composer create clear focal points: `lib/features/Expense/presentation/screens/home_screen.dart:351-395`, `lib/features/Expense/presentation/screens/stats_screen.dart:33-100`, `lib/features/Expense/presentation/screens/add_Expense_screen.dart:159-188`.
- Discoverability is weaker in navigation. Bottom-nav labels disappear for inactive items, so users rely on icon recognition alone for most tabs: `lib/features/Expense/presentation/screens/app_shell.dart:245-279`.
- Several icon-only controls lack tooltip or explicit semantics coverage, unlike the `QuickActionBar`, which does add semantics: `lib/features/Expense/presentation/screens/home_screen.dart:361-386`, `lib/features/Expense/presentation/screens/add_Expense_screen.dart:124-155`, `lib/features/Expense/presentation/widgets/power_pill_menu.dart:95-99`, `lib/features/Expense/presentation/widgets/quick_action_bar.dart:44-47`.
- The floating Power Pill menu is centered on screen instead of feeling anchored to the invoking control, which likely weakens spatial continuity: `lib/features/Expense/presentation/widgets/power_pill_menu.dart:27-60`.

### Pillar 3: Color (2/4)
- `AppColors` provides a solid base token set and the major surfaces follow the intended blue-led direction: `lib/core/theme/app_colors.dart:1-24`, `lib/main.dart:38-43`.
- The audited files contain **50 hardcoded color usages**, which is too much drift for a small app and makes future visual tuning eExpensioive.
- Hardcoded examples appear in the home date strip and supporting cards: `lib/features/Expense/presentation/screens/home_screen.dart:632-642`.
- The composer introduces several bespoke neutrals and accents outside `AppColors`: `lib/features/Expense/presentation/screens/add_Expense_screen.dart:132-153`, `lib/features/Expense/presentation/screens/add_Expense_screen.dart:371-495`.
- Category, split-bill, and drawer views continue the same pattern with ad hoc blues and greys: `lib/features/Expense/presentation/screens/categories_screen.dart:386-416`, `lib/features/Expense/presentation/screens/categories_screen.dart:460-461`, `lib/features/Expense/presentation/widgets/split_bill_tool_view.dart:119-177`, `lib/features/Expense/presentation/widgets/app_drawer.dart:99-99`.

### Pillar 4: Typography (2/4)
- The typography does create emphasis in the right places, especially on money values and section anchors: `lib/features/Expense/presentation/screens/home_screen.dart:142-149`, `lib/features/Expense/presentation/screens/add_Expense_screen.dart:167-176`, `lib/features/Expense/presentation/screens/stats_screen.dart:96-100`, `lib/features/Expense/presentation/screens/stats_screen.dart:226-227`.
- The reviewed UI uses **19 distinct font sizes** (`10, 11, 12, 13, 14, 15, 16, 17, 18, 20, 22, 24, 25, 28, 30, 32, 34, 38, 52`) and **4 font weights** (`w600, w700, w800, w900`). That is more variety than the screen count justifies.
- Some components compress too many small typographic decisions into one card, which makes the system feel hand-tuned instead of designed from a shared scale: `lib/features/Expense/presentation/screens/categories_screen.dart:381-416`.

### Pillar 5: Spacing (2/4)
- Common values such as `8`, `12`, and `16` do recur, which helps basic consistency.
- The overall scale is still too loose. The audited files use many one-off paddings and radii, including `Radius.circular(8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 32, 34, 44, 99)` plus mixed custom `EdgeInsets.fromLTRB(...)` values.
- Examples of spacing drift: `lib/features/Expense/presentation/screens/home_screen.dart:352-355`, `lib/features/Expense/presentation/screens/stats_screen.dart:281-285`, `lib/features/Expense/presentation/screens/stats_screen.dart:337-345`, `lib/features/Expense/presentation/screens/add_Expense_screen.dart:130-133`, `lib/features/Expense/presentation/screens/add_Expense_screen.dart:188-210`, `lib/features/Expense/presentation/screens/app_shell.dart:251-256`.
- The result is visually acceptable but fragile; future feature additions will likely increase inconsistency unless spacing tokens are formalized.

### Pillar 6: Experience Design (2/4)
- Loading, error, and empty states are present on core surfaces, which is a strong baseline: `lib/features/Expense/presentation/screens/home_screen.dart:177-199`, `lib/features/Expense/presentation/widgets/recurring_tool_view.dart:65-75`, `lib/features/Expense/presentation/screens/stats_screen.dart:238-251`.
- Delete actions are immediate across multiple objects. There is no confirmation and no undo path for transactions, accounts, or recurring subscriptions: `lib/features/Expense/presentation/screens/home_screen.dart:201-209`, `lib/features/Expense/presentation/widgets/transaction_card.dart:135-155`, `lib/features/Expense/presentation/screens/accounts_screen.dart:257-265`, `lib/features/Expense/presentation/screens/accounts_screen.dart:473-485`, `lib/features/Expense/presentation/widgets/recurring_tool_view.dart:85-87`, `lib/features/Expense/presentation/widgets/recurring_tool_view.dart:191-204`.
- The Power Pill advertises `Voice` and `Split` as active tools, but those routes are not available yet: `lib/features/Expense/presentation/screens/app_shell.dart:28-35`.
- Positive note: amount validation does block empty saves in the composer: `lib/features/Expense/presentation/screens/add_Expense_screen.dart:558-565`.

---

## Files Audited
- `docs/plans/2026-03-26-ui-navigation-redesign.md`
- `docs/plans/2026-03-26-ui-navigation-search-implementation.md`
- `lib/main.dart`
- `lib/core/theme/app_colors.dart`
- `lib/features/Expense/presentation/screens/app_shell.dart`
- `lib/features/Expense/presentation/screens/home_screen.dart`
- `lib/features/Expense/presentation/screens/stats_screen.dart`
- `lib/features/Expense/presentation/screens/accounts_screen.dart`
- `lib/features/Expense/presentation/screens/categories_screen.dart`
- `lib/features/Expense/presentation/screens/add_Expense_screen.dart`
- `lib/features/Expense/presentation/widgets/app_drawer.dart`
- `lib/features/Expense/presentation/widgets/quick_action_bar.dart`
- `lib/features/Expense/presentation/widgets/power_pill_menu.dart`
- `lib/features/Expense/presentation/widgets/transaction_card.dart`
- `lib/features/Expense/presentation/widgets/split_bill_tool_view.dart`
- `lib/features/Expense/presentation/widgets/recurring_tool_view.dart`
