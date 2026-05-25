# Game Center App Store Connect Setup and QA

This document covers the release setup and manual validation path for the iOS
Game Center integration tracked by issue #94.

Apple references:

- App Store Connect Game Center overview:
  https://developer.apple.com/help/app-store-connect/configure-game-center/overview-of-game-center/
- Managing leaderboards:
  https://developer.apple.com/help/app-store-connect/configure-game-center/manage-leaderboards/
- Managing achievements:
  https://developer.apple.com/help/app-store-connect/configure-game-center/manage-achievements/
- Testing Game Center:
  https://developer.apple.com/help/app-store-connect/configure-game-center/overview-of-testing-game-center/
- Submitting Game Center components:
  https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-game-center-components/

## App Store Connect Setup

Before testing through TestFlight or App Review, the App Store Connect app record
must match the Xcode bundle ID and the app version must have Game Center
enabled. Apple documents Game Center test builds as using the same Game Center
server environment as released games, so use dedicated prerelease Game Center
accounts and avoid friending personal accounts when test data should stay
private. Treat those dedicated accounts as the sandbox accounts for manual QA;
do not assume prerelease scores or achievements are isolated from production
Game Center visibility.

Create one classic leaderboard:

| Reference name | Leaderboard ID | Type | Sort | In-app source |
| --- | --- | --- | --- | --- |
| Classic Survival High Score | `com.xlc.tiltarena.leaderboard.classic_survival_high_score` | Classic | Higher score is better | `GameCenterScoreSubmission.classicSurvival(from:)` |

Create these achievements with matching IDs:

| Reference name | Achievement ID | Trigger | Suggested points | Hidden | Repeatable |
| --- | --- | --- | --- | --- | --- |
| First Run | `com.xlc.tiltarena.achievement.first_run` | Finish one Classic run | 25 | No | No |
| First Weapon Orb | `com.xlc.tiltarena.achievement.first_weapon_orb` | Collect one weapon orb | 25 | No | No |
| First Enemy Clear | `com.xlc.tiltarena.achievement.first_enemy_clear` | Destroy at least one enemy | 25 | No | No |
| First Chain Reaction | `com.xlc.tiltarena.achievement.first_chain_reaction` | Destroy at least two enemies with a weapon clear | 50 | No | No |
| Combo 10 | `com.xlc.tiltarena.achievement.combo_10` | Reach max combo 10 | 100 | No | No |
| Combo 50 | `com.xlc.tiltarena.achievement.combo_50` | Reach max combo 50 | 100 | No | No |
| Survive 60 | `com.xlc.tiltarena.achievement.survive_60` | Survive 60 seconds in Classic | 100 | No | No |
| Score 100000 | `com.xlc.tiltarena.achievement.score_100000` | Score 100000 in Classic | 100 | No | No |

For each leaderboard and achievement:

1. Add English localization at minimum.
2. Use stable player-facing names and descriptions that match the trigger.
3. Add achievement artwork before release submission; production artwork is
   tracked separately in #114.
4. Add the Game Center component to the app version submission. If these are
   the first Game Center components for the app, submit them with the app
   version.
5. Confirm every component reaches a review-ready or live status before release
   QA signs off.
6. After prerelease leaderboard testing is finished, remove leaderboard test
   data in App Store Connect if the launch board should start clean.

## Manual QA Matrix

Run the authoritative pass on a physical iPhone through a development or
TestFlight build. Use a dedicated Game Center account so leaderboard scores and
achievement progress can be inspected without polluting a personal account.

| Scenario | Steps | Expected result |
| --- | --- | --- |
| Authenticated launch | Sign in to Game Center, install the build, launch the app. | The home menu reaches `GAME CENTER READY`; no prompt appears during active gameplay. |
| Signed out launch | Sign out of Game Center in iOS Settings, launch the app, tap `RANKS` from the home menu. | The app surfaces `SIGN IN TO VIEW RANKS`; any system auth prompt is user-initiated and does not interrupt a run. |
| Leaderboard presentation | Sign in, open `RANKS` from home and from the post-run screen. | The native Game Center leaderboard opens for Classic Survival and closes back to the game. |
| High-score submission | Sign in, finish a Classic run with a nonzero score, then open the leaderboard after Game Center has synced. | The submitted score appears on `com.xlc.tiltarena.leaderboard.classic_survival_high_score`. |
| Offline game over | Sign in, disable network access, finish a Classic run, restart immediately. | The game-over flow is not blocked; restart remains one tap; the pending score is retained for retry. |
| Achievement unlock | Use a fresh test account, collect a weapon orb, clear an enemy, build a combo milestone, and finish a run. | Matching achievements unlock or advance in Game Center with no active-gameplay interruption. |
| Foreground retry | Create a pending score or achievement while offline, background the app, restore network access, foreground the app. | The menu or post-run screen may show `GAME CENTER SYNCING`; queued score and achievement progress retry and the status clears. |
| Unavailable service | Test on a device/account where Game Center is disabled or unavailable. | The menu or post-run screen shows `GAME CENTER UNAVAILABLE`; gameplay remains playable. |

## Simulator Notes

Simulator is useful for build validation, automated tests, and UI routing checks
around home/post-run status text. It is not the sign-off environment for Game
Center service behavior. Use a real device for final authentication,
leaderboard submission, achievement propagation, Settings sign-out behavior,
offline retry, and foreground retry validation.

## Follow-Up Issues

- #113: Add additional Game Center leaderboards.
- #114: Add production Game Center achievement artwork.
- #115: Plan Android leaderboard and achievement parity.
