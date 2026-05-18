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
- Always close the issue when the work is completed.
- If an issue is too large to implement in one pull request, create sub-issues
  first and implement the smaller sub-issues independently.
- Before starting work on an issue, switch to a new branch from `master`.
- Do not implement work directly on `master`.
- Link pull requests to the issue they complete, preferably with a closing
  keyword such as `Closes #123` in the PR body.
- After work is completed and the pull request is merged, delete the local
  branch, switch back to `master`, and run `git pull`.
- For GitHub issue and pull request workflow decisions, use the repo-local
  skill at `.agents/skills/github-issue-pr-workflow`.

