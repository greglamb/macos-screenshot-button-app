---
name: project-standards
description: Project-wide standards for the macos-screenshot-button repository — Swift/SwiftUI conventions, architecture rules, testing discipline, tooling, and skill priority. Invoke BEFORE writing, editing, reviewing, planning, or refactoring ANY code in this repo, and before answering "how should I..." or "what's the best way to..." questions about this project. If there is even a 1% chance the work touches this repository's code, design, tests, or build config, trigger this skill.
---

# Project Standards — macos-screenshot-button

This file is the source of truth for how work gets done in this repository. Read it before acting. It is short on purpose: it tells you *which* external skills to consult and encodes the small set of rules that are specific to this project and not derivable from those skills.

## What this project is

A macOS utility (Swift 6 / SwiftUI) centered on a screenshot-capture button. The Xcode project is not yet scaffolded — treat any architectural assumption as provisional until the actual project exists. Prefer SwiftUI-first patterns with AppKit bridging only where macOS requires it (status bar, global hotkeys, `ScreenCaptureKit`, etc.).

## Skill priority — read the right skill for the task

When multiple skills could apply, walk this ladder top-to-bottom and stop at the first match. Don't consult all of them for every task — that burns context and produces noise.

1. **This file (`project-standards`)** — project-specific rules, always wins on conflict
2. **`.claude/rules/*.md`** — path-scoped rules (SwiftUI, concurrency, testing). Applied automatically by the harness.
3. **Hudson Pro skills** — narrow, high-signal LLM mistake corrections:
   - `swiftui-pro` — when writing/reviewing SwiftUI views
   - `swift-concurrency-pro` — any `async`, `await`, `actor`, `@MainActor`, `Sendable`
   - `swift-testing-pro` — when writing/reading `@Test` code
   - `swiftdata-pro` — only if/when SwiftData is introduced
4. **Axiom skills** — broad Apple-framework coverage. Reach for the specific one, not all of them:
   - `axiom:axiom-macos` — windows, menus, sandboxing, AppKit bridging
   - `axiom:axiom-swiftui` — general SwiftUI questions, iOS/macOS 26 features
   - `axiom:axiom-swift` — modern Swift idioms
   - `axiom:axiom-concurrency` — Swift 6 strict concurrency, data races
   - `axiom:axiom-testing` — test architecture, flaky tests, framework choice
   - `axiom:axiom-build` — build/Xcode/simulator failures (run **before** debugging code)
   - `axiom:axiom-apple-docs` — authoritative Apple API reference
   - `axiom:axiom-media` — camera/screen capture, AVFoundation, `ScreenCaptureKit`
   - `axiom:axiom-accessibility` — VoiceOver, Dynamic Type, contrast
   - `axiom:axiom-shipping` — App Store submission, notarization, entitlements
   - `axiom:axiom-security` — keychain, code signing, entitlements
   - `axiom:axiom-performance` — profiling, memory, Instruments
   - `axiom:axiom-xcode-mcp` — using Xcode MCP tools
   - `axiom:ask` / `axiom:status` — when unsure which axiom skill fits
5. **swift-dev plugin** (`/swift-dev:tdd`, `/swift-dev:build-fix`, `/swift-dev:verify-ui`, `/swift-dev:health-check`, `/swift-dev:review`) — structured workflow commands. Prefer these over ad-hoc invocations for their matching task.
6. **Web/general knowledge** — last resort.

When two skills conflict, the higher-numbered one loses. Say so in your reasoning so the user sees why.

## Engineering principles

These are the principles the user explicitly called out. Apply them as *defaults*, not dogma — each one names the failure mode it prevents, so when a rule and its reason point in opposite directions, trust the reason.

- **SOLID** — single responsibility is the one that matters most at this project's scale. A type whose name needs "and" or "manager" is almost certainly doing too much. Dependency inversion matters at module seams (protocols for services, not for every type).
- **YAGNI** — don't build abstractions for hypothetical future requirements. Three similar call sites is fine; a premature protocol hierarchy is not. Delete dead paths aggressively.
- **KISS** — the simplest code that meets today's requirements. A `struct` with `let` beats a class-with-properties-and-willSet. `if` beats a strategy pattern until there are three strategies.
- **DRY** — deduplicate *knowledge*, not incidental similarity. Two functions that look the same but change for different reasons should stay separate. Extract when a change to one forces a change to the other.
- **TDD (strict)** — RED → GREEN → REFACTOR per `superpowers:test-driven-development`. Failing test first, watch it fail, minimal passing implementation, commit, then refactor. Implementation code written before its test must be deleted. This is non-negotiable because this repo's CLAUDE.md commits to it in the goodvibes-workflow block.

## Architecture

- **Swift 6 strict concurrency** enabled. All new types must justify their `Sendable` story. `@unchecked Sendable` requires a comment explaining the invariant.
- **SwiftUI-first**, with `@Observable` view models (not `ObservableObject`) for state that outlives a view's body.
- **MVVM, lightly** — View → ViewModel → Service. Keep ViewModels `@MainActor`. Keep Services `actor` or plain value types. Do not invent repositories/use-cases/coordinators until the complexity demands it.
- **No persistence yet.** If persistence is added later, add `.claude/rules/swiftdata.md` and prefer SwiftData over Core Data. Revisit this file when that happens.
- **AppKit bridging is fine** for macOS primitives that SwiftUI doesn't cover yet (status-bar items, global hotkeys, `NSScreen` geometry, `ScreenCaptureKit` setup). Wrap it in a narrow Swift interface and keep it out of view code.

## Testing

- **Swift Testing** (`@Test`, `#expect`) for all new tests. Do not add XCTest unless a dependency forces it.
- Tests mirror source layout: `Foo/Bar.swift` → `Tests/Foo/BarTests.swift`.
- Use `@Test(arguments:)` for table-driven cases rather than copy-pasted tests.
- Mock at protocol boundaries, injected via `init`. Don't mock Apple framework types directly — wrap them.
- Target **≥75% unit coverage**. All tests must pass before a commit lands.

## Build & run

- Use **`xcodebuildmcp`** CLI, not raw `xcodebuild`. It gives structured output that's faster to diagnose.
  - `xcodebuildmcp build-and-run` — build + launch
  - `xcodebuildmcp test-sim` — run tests (on sim, swap for `test-mac` when a macOS scheme exists)
  - `xcodebuildmcp screenshot` / `describe-ui` — UI verification, required for any visual change
- When a build fails, consult `axiom:axiom-build` *before* editing code — environment issues masquerade as code bugs more often than the reverse.

## Git & commits

- **Conventional Commits** format, enforced by the `commit-message-validator.sh` pre-tool hook:
  `type(scope): description` — types: `feat, fix, docs, style, refactor, test, chore, build, ci, perf, revert`. First line ≤72 chars.
- **Commit per passing task**, not per session. Matches the TDD/goodvibes cadence.
- **Never `git add -A` / `git add .`** — the staging-guard hook will block it, and for good reason: this repo has a history of noisy untracked files. Stage named paths.
- **Worktrees live in `.worktrees/`.** Any other path is blocked by `worktree-safety-gate.sh`. Commit or ask before creating one — don't stash to work around the gate.

## Documentation cadence

- `CHANGELOG.md` — every user-facing change. Tooling-only changes are exempt, but state that explicitly in the commit. **Before tagging a release**, promote everything under `## [Unreleased]` into a dated `## [vX.Y.Z] - YYYY-MM-DD` section matching the tag, leaving `## [Unreleased]` empty. The promotion must be in the commit the tag points at — never push the tag without the promotion. If you delete and retag, undo the promotion too.
- `TODO.md` — any deferred work, scope cut, or discovered tech debt. Never silently defer.
- `docs/ARCHITECTURE.md` — updated when module layout, data flow, or major dependencies change.
- `docs/plans/YYYY-MM-DD-<topic>.md` — design docs and plans, per the goodvibes workflow.

## When the rules and reality disagree

This project is new. These standards are best-guess defaults. If a rule here actively makes a task worse — not just inconvenient, genuinely worse — say so, propose the change, and update this file as part of the same PR. A standards doc that no one pushes back on is a standards doc no one is reading.
