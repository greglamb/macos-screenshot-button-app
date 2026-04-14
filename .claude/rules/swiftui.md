---
paths:
  - "**/*View.swift"
  - "**/*Screen.swift"
  - "**/Views/**"
  - "**/UI/**"
  - "**/Components/**"
---

# SwiftUI rules

- Use `foregroundStyle()` not `foregroundColor()` — the latter is deprecated
- Use `containerRelativeFrame` over `GeometryReader` when possible
- NavigationStack with path-based routing, not deprecated NavigationView
- Use `.task {}` for async work, not `.onAppear` with Task {}
- Prefer `@Observable` macro (iOS 17+) over ObservableObject/Published
- Extract reusable views into separate files when they exceed ~50 lines
- Add `.accessibilityLabel()` to all interactive elements and icons
- Use `@Environment(\.dismiss)` not `@Environment(\.presentationMode)`
