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
- Achievement field and image requirements:
  https://developer.apple.com/help/app-store-connect/reference/game-center/achievements/
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

Create these achievements with matching IDs and upload the matching artwork from
`Assets/GameCenterAchievements/final/`. The generated artwork and structured
metadata also live in `Assets/GameCenterAchievements/manifest.json`.

| Reference name | Achievement ID | Display name | Pre-earned description | Earned description | Points | Hidden | Repeatable | Asset |
| --- | --- | --- | --- | --- | ---: | --- | --- | --- |
| First Run | `com.xlc.tiltarena.achievement.first_run` | First Vector | Finish one Classic run. | You finished your first Classic run. | 25 | No | No | `first-run.jpg` |
| First Weapon Orb | `com.xlc.tiltarena.achievement.first_weapon_orb` | Orb Contact | Collect one weapon orb. | You collected your first weapon orb. | 25 | No | No | `first-weapon-orb.jpg` |
| First Enemy Clear | `com.xlc.tiltarena.achievement.first_enemy_clear` | First Clear | Destroy one enemy. | You destroyed your first enemy. | 25 | No | No | `first-enemy-clear.jpg` |
| First Chain Reaction | `com.xlc.tiltarena.achievement.first_chain_reaction` | Chain Ignition | Destroy two enemies with one weapon clear. | You triggered your first chain reaction. | 50 | No | No | `first-chain-reaction.jpg` |
| Combo 10 | `com.xlc.tiltarena.achievement.combo_10` | Combo 10 | Reach a 10 combo. | You reached a 10 combo. | 100 | No | No | `combo-10.jpg` |
| Combo 50 | `com.xlc.tiltarena.achievement.combo_50` | Combo 50 | Reach a 50 combo. | You reached a 50 combo. | 100 | No | No | `combo-50.jpg` |
| Survive 60 | `com.xlc.tiltarena.achievement.survive_60` | One-Minute Line | Survive 60 seconds in Classic. | You survived 60 seconds in Classic. | 100 | No | No | `survive-60.jpg` |
| Score 100000 | `com.xlc.tiltarena.achievement.score_100000` | Six-Figure Signal | Score 100,000 in Classic. | You scored 100,000 in Classic. | 100 | No | No | `score-100000.jpg` |

For each leaderboard and achievement:

1. Add English localization at minimum.
2. Use the player-facing names, descriptions, points, hidden flags, repeatable
   flags, and artwork listed above unless a later product review intentionally
   changes the launch set.
3. Add the Game Center component to the app version submission. If these are
   the first Game Center components for the app, submit them with the app
   version.
4. Confirm every component reaches a review-ready or live status before release
   QA signs off.
5. After prerelease leaderboard testing is finished, remove leaderboard test
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
