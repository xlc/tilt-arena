# Tilt Arena Agent Instructions

## Project Context

Tilt Arena is a working title for a mobile arcade survival / dodge-action game.
The intended first platform is iOS, with Android optional later. The game is a
top-down 2D arena where the player controls a small arrow-shaped craft with
device tilt, survives for short sessions, dodges enemy dots, and collects risky
weapon orbs that trigger chain-reaction clears.

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

- Use GitHub Issues as the source of truth for tasks.
- Create a new GitHub issue for every actionable TODO before implementing it.
- Close the corresponding issue as part of the commit/finalization step when
  the work is completed.
- If an issue is too large to implement in one focused change, create
  sub-issues first and implement the smaller sub-issues independently.
- Before starting work on a new GitHub issue, ensure the current branch is
  `master` and up to date.
- Work directly on `master`. Do not create issue branches or pull requests for
  this solo-dev project.
- If the working tree has dirty changes, inspect them before editing. Ask the
  user what to do before switching branches or overwriting unrelated changes.
- When committing completed issue work, include the closing keyword for the
  issue in the commit message, such as `Closes #123`, and verify the issue is
  closed after the commit is pushed to `master`. Close it manually if GitHub
  automation does not.
- For GitHub issue workflow decisions, use the repo-local
  skill at `.agents/skills/github-issue-master-workflow`.

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
  coarse state names, and ephemeral run/session identifiers.
- Never log secrets, tokens, email addresses, player names, vendor identifiers,
  device names, precise device identifiers, or raw high-frequency movement data.
- Throttle recurring diagnostics such as performance samples or spawn activity.
  Per-frame JSONL logging is not acceptable.
- JSONL logs must stay line-delimited, sorted-key, bounded by rotation, excluded
  from backup, protected on device, and friendly to `rg`, `jq`, and
  `scripts/tilt-logs`.
- Logging and export failures must not affect gameplay. If logging persistence
  fails, drop that diagnostic write rather than changing game behavior.

## Visual Assets

- Gameplay sprites and pickup icons must stay readable at their smallest
  in-game size. Prefer simple silhouettes, strong shape language, broad color
  blocks, and limited internal detail over dense ornamentation that collapses
  when scaled down.
