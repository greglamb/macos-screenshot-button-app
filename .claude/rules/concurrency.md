---
paths:
  - "**/*.swift"
---

# Swift concurrency rules

- Never assume state is unchanged after an `await` — actor reentrancy invalidates assumptions
- Use `@MainActor` on view models and UI-touching code, not manual DispatchQueue.main
- Prefer structured concurrency (async let, TaskGroup) over unstructured Task {}
- All Sendable conformances must be verified — don't just slap `@unchecked Sendable` on things
- Use `actor` for mutable shared state, not classes with locks
- Cancel tasks explicitly when views disappear — use `.task {}` modifier which auto-cancels
- When bridging completion handlers, use `withCheckedContinuation` (not unsafe variant) unless performance-critical
