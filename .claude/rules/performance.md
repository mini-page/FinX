# performance.md — Flutter Performance Standards

## Frame Rendering

- Target **60 fps** on mid-range Android devices; **no jank** on the home, records, and stats screens.
- Use Flutter DevTools → Performance overlay to identify jank frames during development.
- Keep `build()` methods cheap: no heavy computation, no synchronous I/O.

## Rebuild Minimization

- Use `const` constructors for widgets whose subtree never changes.
- Narrow `ref.watch` with `.select(...)` to avoid rebuilding when unrelated state changes.
- Split large widgets into smaller ones so only the affected subtree rebuilds.
- Use `RepaintBoundary` around widgets that animate independently.

## List Performance

- Use `ListView.builder` / `SliverList.builder` — **never** `Column(children: items.map(...).toList())` for lists that may have more than ~20 items.
- Use `itemExtent` or `SliverFixedExtentList` when all items are the same height (avoids layout passes).

## Image Performance

- Decode images at their display size using `cacheWidth` / `cacheHeight` on `Image` widgets.
- Use `ResizeImage` from `flutter/painting.dart` for asset images.
- Prefer WebP format for photo-realistic assets.

## Lazy Loading

- Load heavy data (stats, large Expense lists) inside `AsyncNotifierProvider.build()` — not in `initState`.
- Paginate long lists if the dataset can grow unbounded.

## Data Computation

- Run eExpensioive computations (`ExpenseStats.fromExpenses`) outside `build()`, inside a provider.
- Pre-compute date boundaries (week start, month start) **once before** iterating a list, not inside the `where` predicate.

## Measurement

- Profile release builds (`flutter run --release --profile`) for accurate timings.
- Benchmark hot paths in `benchmark/` before and after optimization.
