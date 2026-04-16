# macos-screenshot-button — Claude Code configuration

macOS screenshot utility written in Swift/SwiftUI. Project is in initial scaffolding — Xcode project not yet created.

## Build & test

Use `xcodebuildmcp` CLI for builds, tests, and simulator interaction. Discover commands with `xcodebuildmcp --help` and `xcodebuildmcp tools`.

- Build & run: `xcodebuildmcp build-and-run`
- Test: `xcodebuildmcp test-sim`
- Screenshot: `xcodebuildmcp screenshot`
- Accessibility tree: `xcodebuildmcp describe-ui`

## Coding standards

- Swift 6 strict concurrency
- MVVM architecture (to be confirmed once the project is scaffolded)
- No persistence framework yet — add SwiftData rules if/when introduced
- Minimum 75% unit test coverage; all tests must pass before committing

## Skill priority

When skills or plugins give conflicting guidance, follow this order:
1. This file and `.claude/rules/` — project-specific, always wins
2. Hudson Pro skills — targeted LLM mistake corrections
3. Axiom skills — broad framework coverage
If still ambiguous, prefer the approach that targets this project's minimum deployment target.

## Workflow

1. Check if Axiom or a Hudson Pro skill covers the task
2. Write code following skill guidance
3. Build — read errors, fix, rebuild
4. Run tests — fix failures
5. Verify UI changes with screenshot and describe-ui

## Git

- Conventional commits: `feat:`, `fix:`, `refactor:`, `test:`, `docs:`, `chore:`

@./docs/ARCHITECTURE.md

<!-- goodvibes-workflow:start -->
# Project Guidelines

## Required Skills and Workflows

- **project-standards** - Contains this project's standards and MUST be invoked before changing ANYTHING!
- **superpowers** — A complete software development workflow with brainstorming, planning, execution, test-driven development, code review, and systematic debugging. Use `/superpowers:brainstorming`, `/superpowers:writing-plans`, `/superpowers:executing-plans`, and other skill commands.
- **episodic-memory** - Semantic search for Claude Code conversations. Remember past discussions, decisions, and patterns. Use `/episodic-memory:remembering-conversations` to search memory.

### Skill Usage Rules

- If there is even a 1% chance a skill applies, invoke it.
- Read the SKILL.md file for each skill before using it.
- Announce each skill by name when activating it: "I'm using the [skill] skill to [purpose]."
- If a skill has a checklist, create a TodoWrite item per checklist entry.
- If a skill fails to activate, stop and report which skill did not trigger rather than continuing without it.

### Development Process

1. **Brainstorm** (`superpowers:brainstorming`) — Always start here, even for "simple" tasks. Explore project context (files, docs, recent commits). Ask clarifying questions one at a time. Propose 2-3 approaches with trade-offs. Before proposing approaches, read and follow the `project-standards` skill to ensure all designs conform to project architecture and coding standards. Present design in sections scaled to complexity, get approval after each section. Save design doc to `docs/plans/YYYY-MM-DD-<topic>-design.md` and commit.

2. **Worktree** (`superpowers:using-git-worktrees`) — After design approval, create an isolated worktree. Run project setup and verify clean test baseline before writing any code. Announce ready status with test count.

3. **Plan** (`superpowers:writing-plans`) — Break work into 2-5 minute tasks with exact file paths, complete code, and verification steps. All planned code must conform to the `project-standards` skill. Reference it when specifying file paths, code structure, and API usage in tasks. Save plan to `docs/plans/YYYY-MM-DD-<feature-name>.md`. Each task must include: files to create/modify, failing test to write, minimal implementation, verification command, and commit step.

4. **Execute** (`superpowers:subagent-driven-development`) — Always use subagent-driven development. Never use batch execution. Never ask which mode to use. Dispatch fresh subagent per task with two-stage review (spec compliance, then code quality).

5. **TDD** (`superpowers:test-driven-development`) — Every task follows strict RED-GREEN-REFACTOR. Write failing test first, run it and watch it fail, write minimal code, run it and watch it pass, commit. Code written before its test must be deleted. No exceptions. No rationalizations.

6. **Code Review** (`superpowers:requesting-code-review`) — Review between tasks. Check against plan. Report issues by severity. Critical issues block progress. Review must verify conformance with `project-standards` skill. Violations of project architecture or coding standards are critical issues that block progress.

7. **Finish** (`superpowers:finishing-a-development-branch`) — Verify all tests pass. Present options: merge, PR, keep branch, or discard. Clean up worktree.

### Debugging (when issues arise during implementation)

- Use `superpowers:systematic-debugging` for any non-trivial bug — 4-phase root cause process. Do not guess-and-check.
- Use `superpowers:verification-before-completion` before declaring any fix complete.

### Additional Rules

- Commit after each passing task, not at the end.
- YAGNI — ruthlessly remove unnecessary features from designs.
- Stop immediately on blockers. Ask for clarification rather than guessing.
- When receiving code review feedback, use `superpowers:receiving-code-review`.
- Do not skip worktree setup. Do not skip TDD. Do not skip code review.

### Worktree Preferences

Worktree directory: .worktrees/

## Hook-Enforced Rules

The following rules are enforced mechanically by hooks and cannot be bypassed:

### Worktree Safety Gate (`PreToolUse` → `worktree-safety-gate.sh`)

Blocks worktree creation if:
1. Working tree has uncommitted changes (prevents silent orphaning of files)
2. Worktree path is not inside `.worktrees/` directory

If the hook blocks you:
- **Commit changes first** — do NOT stash, do NOT bypass
- If changes are WIP and shouldn't be committed, STOP and ask the user what to do
- After worktree merge/cleanup, verify the source branch still has all expected files

### Commit Message Validator (`PreToolUse` → `commit-message-validator.sh`)

Blocks `git commit` if the message does not follow Conventional Commits format:
- Required format: `type(scope): description`
- Allowed types: feat, fix, docs, style, refactor, test, chore, build, ci, perf, revert
- First line must be 72 characters or fewer

### Staging Guard (`PreToolUse` → `staging-guard.sh`)

Blocks `git add -A` / `git add .` if untracked files match sensitive patterns (`.env`, `.pem`, `.key`, credentials, SSH keys). Stage files individually instead.

### CHANGELOG/TODO Reminder (`PostToolUse` → `changelog-todo-reminder.sh`)

After each successful `git commit`, checks whether CHANGELOG.md and TODO.md were included. Provides a non-blocking reminder if they were not.

### CLAUDE.md Drift Detection (`SessionStart` → `claudemd-drift-detection.sh`)

On session start, checks if CLAUDE.md exists but is missing goodvibes-workflow markers. Suggests running the goodvibes-workflow skill in validate mode.

### Plugin Dependency Check (`SessionStart` → `check-plugin-dependencies.sh`)

On session start, verifies that required plugins (superpowers, episodic-memory, project-standards) are installed. Warns with install commands if missing.

### episodic-memory Sync (`PreToolUse` → `vibeplan-pre-sync.sh`)

Automatically runs `episodic-memory sync` before the vibeplan command executes.

## Documentation Requirements
- **CHANGELOG.md**: ALL user-facing changes MUST be documented in CHANGELOG.md (root)
- **TODO.md**: ALL deferred work, known limitations, and planned features MUST be tracked in TODO.md (root)
- Update both files as part of every PR/commit that changes behavior (enforced by `changelog-todo-reminder` hook)
- **Deferred work rule**: Any task identified during implementation that is explicitly out of scope or deferred MUST be added to TODO.md before the work is considered complete. This includes: scope reductions, "fix later" decisions, discovered tech debt, and follow-up improvements. Never defer work silently.
- **CHANGELOG release promotion (Keep a Changelog)**: Before pushing any `v*` tag, promote everything currently under `## [Unreleased]` to a new dated section `## [vX.Y.Z] - YYYY-MM-DD` matching the tag, and leave `## [Unreleased]` empty (with empty `### Added/Changed/Fixed/Removed` subsections as needed). Commit that change in the same commit the tag points at — do NOT push the tag first and the changelog update later. If a release is later deleted/retagged, also undo the promotion so we don't end up with a section for a tag that no longer exists.
<!-- goodvibes-workflow:end -->

<!-- swift-dev:managed:suggest-skills -->

## Suggest these manual skills when relevant

The user won't remember these exist. Proactively suggest (don't auto-run) when the context fits:

- `/swift-dev:build-fix` — when a build fails and the user wants an autonomous compile→fix→rebuild loop
- `/swift-dev:verify-ui` — after any UI change, before declaring it done (builds, screenshots, reads a11y tree)
- `/swift-dev:health-check` — before a release, PR, or when the user asks "is this ready to ship?"
- `swift-reviewer` subagent — when the user is about to commit or wants review; invoke via `superpowers:requesting-code-review` or directly with the Agent tool

<!-- /swift-dev:managed:suggest-skills -->

<!-- swift-dev:managed:consult-skills -->

## Swift skills to consult during brainstorming, planning, and implementation

Axiom is forced by its own session-start hook. These are not — check them explicitly when the domain matches:

- **Hudson Pro skills** — SwiftUI, SwiftData, Concurrency, Testing patterns and anti-patterns
- **Swift Architecture skill** — module layout, dependency direction, testability
- **Writing for Interfaces skill** — UX copy review, microcopy, button labels, error messages

During `superpowers:brainstorming`: when the user's idea touches any of these domains, surface relevant skills before continuing the Socratic loop.
During `superpowers:writing-plans`: consult these skills when specifying tasks in the affected domain.
During implementation: reference the relevant skill before writing code in that domain.

<!-- /swift-dev:managed:consult-skills -->
