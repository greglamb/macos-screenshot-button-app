---
paths:
  - "**/*Tests.swift"
  - "**/*Test.swift"
  - "**/Tests/**"
---

# Testing rules

- Use Swift Testing framework (`@Test`, `#expect`) not XCTest for new tests
- Parameterized tests with `@Test(arguments:)` for multiple input scenarios
- Use traits: `@Test(.tags(.ui))`, `@Test(.timeLimit(.minutes(1)))`
- `#expect(throws:)` for error testing, not do/catch blocks
- Name tests descriptively: `@Test("User login fails with invalid credentials")`
- Test file mirrors source: `Models/User.swift` → `Tests/UserTests.swift`
- Mock protocols, not concrete types — inject dependencies via init
