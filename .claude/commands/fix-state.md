# fix-state — Debug & Correct State Management Issues

## Purpose
Resolve Riverpod state bugs: stale UI, missing rebuilds, provider lifecycle errors, and incorrect async state transitions.

## Steps

1. **Describe the symptom**
   - UI not updating after mutation?
   - `AsyncValue` stuck in loading/error state?
   - State reset unexpectedly?

2. **Locate the provider**
   - All providers live in `lib/features/<feature>/presentation/provider/`.
   - Exported via the feature barrel (`lib/features/<name>/<name>.dart`).

3. **Diagnosis checklist**
   - [ ] Is `ref.watch` used in `build()`? (not in callbacks or `initState`)
   - [ ] Does the mutating method call `state = ...` or `state = AsyncData(...)`?
   - [ ] Is `ref.invalidate(provider)` called after external mutations?
   - [ ] Is `AsyncNotifier.build()` re-fetching from Hive correctly?
   - [ ] Are `ProviderScope` overrides set up in widget tests?

4. **Common fixes**

   | Issue | Fix |
   |-------|-----|
   | UI not rebuilding | Confirm `ref.watch` (not `ref.read`) in `build()`. |
   | Stale list after add/delete | Call `ref.invalidate(ExpenseListProvider)` after mutation. |
   | `StateError: Bad state` | Ensure provider is inside `ProviderScope`. |
   | Infinite loading | Check `AsyncNotifier.build()` completes and returns data. |
   | Double build on init | Use `ref.listen` instead of `ref.watch` for side-effects. |

5. **Verify**
   - `flutter analyze` passes.
   - Run affected widget/provider tests: `flutter test test/features/<feature>/`.

## Related Agent
Use `state-manager` for a deeper Riverpod optimization review.
