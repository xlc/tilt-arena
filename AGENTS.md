# Tilt Arena Agent Instructions

Build a complete, polished player experience with the simplest clear, correct,
maintainable implementation that satisfies the actual requirements. Compiling
and passing tests alone do not establish product quality.

## Project Context

Tilt Arena is currently an iPhone-only, landscape arcade survival game built
with Swift 6, UIKit, and SpriteKit; Android is a possible later platform. The
player tilts a small arrow-shaped craft around a top-down arena, dodges enemies,
and collects risky weapon orbs that trigger chain-reaction clears.

Design pillars:

- One-input mastery: tilt control should be understandable in seconds and deep
  enough to reward precision over time.
- Danger creates opportunity: meaningful pickups belong in risky locations.
- Readable chaos: player, enemies, pickups, danger, effects, and score feedback
  must remain visually distinct even under pressure.
- High-score replayability: runs are short, failure is instant, and restart is
  one tap.
- Combo satisfaction: chained kills, close calls, and multi-kill clears should
  drive repeat play.

Core loop:

1. Tilt to move around the arena.
2. Dodge enemies as they spawn, chase, and form patterns.
3. Collect weapon orbs in dangerous locations.
4. Trigger attacks, shields, traps, or movement effects.
5. Destroy enemies, increase score and combo, and survive escalating pressure.
6. On collision, show score, combo, survival time, rewards, and unlock progress.
7. Restart immediately or change mode/loadout.

## Workflow Rules

- Use GitHub Issues as the source of truth when work starts from an existing
  issue, when the user explicitly asks to create or track an issue, or when a
  task is already issue-backed.
- Do not create new GitHub issues, sub-issues, or TODO-tracking issues unless
  the user explicitly asks for them.
- If the user explicitly asks to split a large issue, create sub-issues first
  and implement the smaller sub-issues independently.
- Before starting issue-backed work, ensure the current branch is `master` and
  up to date.
- Work directly on `master`. Do not create issue branches or pull requests for
  this solo-dev project. Direct user requests do not require a GitHub issue.
- If the working tree has dirty changes, inspect them before editing. Ask the
  user what to do before switching branches or overwriting unrelated changes.
- When committing completed issue work, include the closing keyword for the
  issue in the commit message, such as `Closes #123`, and verify the issue is
  closed after the commit is pushed to `master`. Close it manually if GitHub
  automation does not.
- For GitHub issue workflow decisions, use the repo-local
  skill at `.agents/skills/github-issue-master-workflow`.
- Scale discovery, planning, and review to the change. Small changes need no
  design document, test matrix, multiple proposals, reviewer agents, or new
  process files. Ask when an answer materially affects the outcome; otherwise
  use repository conventions and reasonable assumptions and proceed.

## Player Experience and Visual Quality

- Understand the affected journey, including entry, interaction, feedback, and
  exit. Complete necessary supporting behavior without expanding into optional
  features. Keep Play, pause/resume, results, and one-tap Play Again coherent
  when the change touches those flows.
- Follow `ArenaTheme`, the shared controls in `ArenaUIRenderer`, and
  `ArenaLandscapeUILayout`. Preserve the dark and white themes and the geometric,
  restrained direction in `docs/visual-direction/2026-09-08/README.md` unless a
  redesign is requested. Current `TiltArenaTests/__Snapshots__/` images are the
  implemented baseline; concept boards are references.
- Make hierarchy, primary actions, spacing, alignment, typography, density,
  color, and interaction feedback intentional. Polish means clarity and
  consistency, not extra effects, decoration, controls, or features. Resolve
  ordinary rough edges within the task rather than deferring a polish pass.
- Use clear labels, predictable controls, sensible defaults, and visible
  feedback. Preserve relevant mode, settings, and navigation context. Avoid
  needless confirmations, repeated steps, and player-facing implementation
  details. Handle reachable loading, empty, error, and success states with an
  understandable next action; do not invent hypothetical recovery flows.
- Check affected layouts with realistic scores, progression, long labels, and
  crowded gameplay. Account for small and large landscape iPhones, safe areas,
  clipping, overflow, and scrolling where present. Check readable contrast,
  touch targets, accessibility labels/roles, and supported keyboard/focus
  behavior for affected controls.
- Gameplay sprites and pickup icons must remain readable at their smallest
  in-game size: simple silhouettes, broad color blocks, and limited internal
  detail. Keep the player, threats, pickups, and protection feedback distinct
  during overlapping effects; decoration must not obscure gameplay.

## Implementation and Defensive Behavior

- Keep control and data flow direct, with cohesive responsibilities and one
  authoritative owner of each state value. `ArenaScene` coordinates SpriteKit
  lifecycle; existing run, enemy, weapon, input, and UI collaborators own their
  respective responsibilities. Reuse project components and platform features.
- Add a helper, module, or abstraction when it clarifies a real responsibility
  or reduces demonstrated complexity, even if used once. Avoid speculative
  frameworks, service layers, wrapper chains, configuration, feature flags, and
  compatibility machinery. Optimize for readability and ease of change, not
  minimum line count; simplicity must not drop requirements or useful feedback.
- Before adding a nontrivial guard, retry, fallback, or recovery path,
  identify the concrete failure or supported requirement, why existing
  layers do not handle it, and why the response is proportionate. Check whether
  it could block valid play, hide a defect, or create inconsistent state. Omit
  unjustified mechanisms; this judgment needs no separate process document.
- Do not add security or privacy safeguards, permission gates, or trust-boundary
  layers to this local game. Use established internal data contracts instead of
  repeatedly validating the same values.
- Preserve profile/progression integrity and Game Center submission semantics.
  Custom-tuned runs must not update records, unlocks, achievements, or Game Center.
  For changed gameplay validation or limits, verify both the intended
  rejection and a legitimate end-to-end success. Share authoritative rules while
  keeping save correctness in the code that owns persistence.
- Retry only credible transient failures when repetition is safe and useful.
  Bound attempts and account for existing client/service retry behavior; do not
  retry invalid input, permanent failures, programming bugs, or operations that
  would duplicate side effects. An isolated need does not justify a generic
  retry framework.
- A fallback must provide a deliberately acceptable, correct degraded experience.
  Offline Game Center play with retained pending submissions is supported; fake
  submission success or lost progress is not. Do not turn errors into empty data,
  guessed values, or silent no-ops. Remove obsolete compatibility or fallback
  paths only when their requirement is demonstrably gone and removal is in scope.
- Catch errors where there is recovery, cleanup, useful diagnostic context, or
  a player-facing response to provide. Avoid blanket catches and repeated handling
  at every layer. Keep expected user errors understandable and programming defects
  visible to developers, using the logging rules below.

## Verification and Completion

- Use existing checks in proportion to the change. `README.md` documents the
  simulator build; `.github/workflows/ci.yml` defines generation, lint, build,
  and test commands. Use `xcodegen generate` for project generation and
  `swiftlint lint --no-cache` for Swift linting. Select an available iPhone test
  destination using `xcrun simctl list devices available`, as CI does.
- Add focused XCTest or snapshot regression coverage for meaningful behavior
  changes and bugs in `TiltArenaTests`. Prioritize the primary workflow, real
  failure cases, and affected save behavior. Repeat affected checks
  after fixes; do not add frameworks or exhaustive hypothetical matrices for
  small changes. Documentation-only edits need a diff review, not app tests.
- For substantial implementation changes, review both the running/rendered
  product and the code diff. Exercise the affected journey in Simulator or on
  an iPhone. For UI changes, inspect screen/effect output in both themes at
  relevant phone sizes against the brief and visual baseline. Fix concrete
  interaction, layout, and feedback defects; inspect changed snapshots before
  accepting new baselines. Preserve successful design choices.
- In the code review, remove unnecessary layers, dependencies, duplicated state,
  repeated validation, unsupported branches, and retries/fallbacks hiding defects.
  Make the normal successful path easy to trace. Address existing complexity
  only where directly relevant to the task.
- For relevant balance comparisons, use the existing encounter/full-run XCTest
  fixtures and their `scripts/summarize-weapon-balance` and
  `scripts/summarize-full-run-balance` summaries. Use the capture instructions in
  `docs/visual-direction/2026-09-09-effects/README.md` for motion/overlap inspection.
  Deterministic simulations and screenshots do not establish tilt comfort,
  human playability, or device performance. Use physical iPhone checks for those
  claims and `docs/game-center-release-qa.md` for live Game Center verification
  when relevant.
- Completion requires the requested experience to work end to end, appropriate
  product inspection, no known unnecessary complexity introduced by the task,
  and relevant checks. Keep the handoff brief: what changed, what was actually
  verified, and remaining limitations. Distinguish implementation, automated
  checks, visual inspection, device testing, and publication; name unavailable
  tools or environments rather than claiming unperformed verification.

## Logging and Diagnostics

- Use `AppDiagnostics.logger(_:)` and SwiftLog for app logging. Do not add
  `print`, `debugPrint`, `NSLog`, ad hoc files, or another logging dependency.
- Bootstrap logging once from app startup. Keep persistence behind SwiftLog
  handlers so gameplay code only emits structured events.
- Use stable dot-separated event names such as `run.started` or
  `weapon.resolved`, not sentence text.
- Choose levels deliberately: `debug` for high-volume local investigation,
  `info` for routine state changes, `notice` for user-visible milestones,
  `warning` for recoverable abnormal states, and `error` for failed operations.
- Pass Swift errors through the SwiftLog `error:` parameter. Do not stringify
  errors into a generic metadata key at call sites.
- Keep metadata small, scalar, and bounded. Prefer modes, counts, durations,
  state names, and run/session identifiers.
- Throttle recurring diagnostics such as performance samples or spawn activity.
  Per-frame JSONL logging is not acceptable.
- JSONL logs must stay line-delimited, sorted-key, bounded by rotation, and
  friendly to `rg`, `jq`, and `scripts/tilt-logs`.
- Logging and export failures must not affect gameplay. Dropping a failed
  diagnostic write is an intentional best-effort exception to the error-handling
  guidance above; it does not justify silently discarding player progress.
