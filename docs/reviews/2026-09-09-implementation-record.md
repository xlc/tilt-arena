Tilt Arena implementation record — 9 September 2026

**The mechanics foundation and automated tuning pass are implemented. Physical-phone and human balance acceptance remain open.** This record follows the [original review](/Users/xiliangchen/projects/tilt-arena/docs/reviews/2026-09-09-mechanics-balance-review.md) and [detailed improvement plan](/Users/xiliangchen/projects/tilt-arena/docs/reviews/2026-09-09-improvement-plan.md). Changes are local commits on master. Nothing has been pushed or released. Development data may reset; no migration or grandfathering was added.

Each code commit followed inspection, targeted regression checks, a review and correction pass, then validation. Changed visual references were inspected before acceptance. The review found additional problems during implementation: unsupported full-input directions in reclined calibration, misleading retry copy, a shrinking Gravity boundary, clipped codex explanations, and frame-dependent puck bounce travel. These received corrections instead of being accepted because the initial tests passed.

| Commit | Implemented behavior | Main validation |
|---|---|---|
| `6fb33f1` | Sensitivity changes response slope while preserving attainable maximum speed. Calibration uses a three-dimensional neutral basis across supported postures. Legacy calibration decoding was removed. | Physically valid gravity directions, low/high sensitivity, both landscape orientations, diagonal normalization; 552 tests passed. |
| `06f64fb` | Pattern timers remain due while blocked. Oldest due patterns get admission before new chasers, without accumulating spawn bursts. | Original Classic starvation reproduced before the fix; recurrence through 360 seconds and 30/120 Hz resident-population checks. |
| `2a24301` | Separate Classic/Redline records and recent Daily records by captured seed. Lifetime progression is explicit. Daily identity survives midnight and pause. Redline requires a Classic best. | New schema round trips, incompatible development reset, cross-mode and midnight cases, Daily UI snapshots; 559 tests passed. |
| `1f4a2d9` | One pickup activation earns at most one family-clear recognition after its second actual kill. Attribution follows projectiles, waves, shield, frozen enemies, and trail segments. | Frame-grouped hits, delayed hits, overlap, replacement, frozen contact and thaw ownership; 564 tests passed. |
| `3cd196d` | Gravity affects current local entrants and swept core crossings; leaving the field stops the pull. Replacement ends the old field. | Entry/exit, replacement, frozen targets, tangential core crossings at 30/60/120 Hz; full suite plus focused boundary tests. |
| `9c7f726` | Every pickup provides 0.2 seconds of immediate collection grace. Seeker, Lightning, and Lance get a bounded deadline derived from scheduled impacts rather than repeated callback refreshes. | All 11 pickup kinds, non-additive refresh, expired and late callbacks; 572 tests passed. |
| `f07bcf5` | Play Again uses a 0.75-second centered countdown. Classic guarantees Shockwave, Seeker, and Shield in the opening, preserving the weighted cycle. Daily's arsenal is profile-independent. | Duplicate taps, background cancellation, placement failures, 26 opening seeds with fresh/complete profiles, inspected retry snapshot; 579 tests passed. |
| `1c96c7a` | Formations warn about individual lanes and mark the widest opening. Paddles show separate bodies and initial puck direction. Mines mark their stationary body. | Warning/body correspondence including filtered lanes; both-theme warning snapshots; 581-test run plus reference verification. |
| `c760ae6` | All gameplay uses a 718 × 377 world, uniformly fitted to the display. UI stays in screen coordinates. Effects, warnings, player, pickups, death trace and markers share the world transform. | Paired Daily simulation through resize, score/entity agreement, safe-area tests, small/large phone snapshots, complete visual-reference review; 586 tests passed. |
| `bbdc2a2` | General achievements count all modes; the explicitly Classic score achievement remains Classic-only. Multi-kill text matches activation behavior. Gravity keeps its actual field/core boundaries throughout playback. Splitter suppression is visible in the codex. | Achievement mapping, animation-time boundary checks, inspected Gravity/codex snapshots, artwork validation; 589 tests passed followed by 32 copy/screen checks. |
| `1b9b10e` | Paddle pucks preserve the remaining travel after a wall bounce, including multiple bounces in one step. | A failing four-second 30/60/120 Hz reproduction became equal positions at all rates; exact corner and multi-bounce checks; full 592-test pass. |

**The world conversion removes a measurable device difference.** Before the change, a 667 × 375 phone with no safe-area inset had a 591 × 299 playable rectangle, while a 932 × 430 phone with 59-point horizontal insets had 738 × 354. Full player speed was 236.4 versus 295.2 points/s, and a fully contained base Shockwave covered about 14.4% versus 9.7% of that playfield. Those are geometric calculations, not observed player outcomes.

The shared world now has a 658 × 317 playable rectangle, 263.2 logical points/s maximum ordinary speed, and a 2.5-second horizontal crossing time on both devices. That Shockwave covers about 12.2% on either. Rendering scales uniformly; collision and spawn calculations never use the display dimensions. The 15-second paired Daily fixture exercises input, pickups, effects, entities, score and an in-run resize. It is a deterministic equivalence check, not a survival benchmark.

**Corrected baseline evidence.** The regular suite includes the original four regressions, 360-second recurrence, activation attribution, Gravity boundaries, retry lifecycle, record scope, and layout equivalence. An opt-in 600-second director sweep exercises Classic/Redline, seeds 20260726/91, and enemy residence limits of 6/20/60 seconds. Its CSV reports realized roles, late appearances, first appearances, peak reserved population, and time at population capacity. Pending telegraphs count toward reserved capacity.

The [84-row baseline CSV](/Users/xiliangchen/projects/tilt-arena/docs/reviews/2026-09-09-spawn-baseline.csv) was exported from the passing XCTest attachment against the gameplay code now committed as `1b9b10e`, using the accompanying harness change. **Every role recurred after 180 seconds in all twelve cases, and no population cap assertion failed.** The complete suite, including the extended export, passed 592 tests with zero failures. This adds coverage beyond the original six-second-residence tests without establishing human survivability.

| Mode | Residence limit | Peak reserved population | Seconds at capacity, across seeds | Paddle bodies spawned during 180–600 s, across seeds |
|---|---:|---:|---:|---:|
| Classic | 6 s | 56 | 0 | 315 |
| Classic | 20 s | 109 | 0 | 315 |
| Classic | 60 s | 210 | 30.967–33.017 | 270–297 |
| Redline | 6 s | 92 | 0 | 484–517 |
| Redline | 20 s | 180 | 0 | 462–528 |
| Redline | 60 s | 270 | 142.850–143.750 | 363–462 |

With 60-second residence, Redline spent about 24% of the run at population capacity. Its first paddle arrived at 71.017–72.283 seconds, compared with 60.833 seconds in the shorter-residence cases. This supports keeping nominal rates unchanged for the next playtest: the corrected schedule already delivers substantial additional late pressure. It does not prove that those rates are ideal.

The sweep has a stationary player, one fixed pickup clearance circle, ordinary enemy movement/culling, and synthetic age-based clears. Paddles can expire and linear enemies can leave before the residence limit. It does not apply real weapon effects, measure survival, or test player route choices. A role's spawn count counts bodies; a Paddle Trap therefore contributes multiple bodies. Capacity time is population saturation, not time blocked by the separate warning budget.

Reproduce the extended sweep with the current simulator destination:

```sh
TEST_RUNNER_TILT_BALANCE_SWEEP=1 xcodebuild \
  -project TiltArena.xcodeproj -scheme TiltArena -configuration Debug \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,id=AA706A81-B950-477D-8FAB-B8836EBD57E0,arch=arm64' \
  -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO test
```

Use another installed simulator ID if necessary. The `spawn-baseline.csv` XCTest attachment is emitted by `EnemySpawnDirectorBalanceTests.testExportExtendedSpawnBaseline`. At that baseline, ordinary test runs skipped only this extended export; the current suite also has opt-in weapon, response and full-run exports. The standard cadence regressions still run. Export the attachment using `xcrun xcresulttool export attachments --path <result.xcresult> --output-path <directory>`.

**Current decisions after automated comparisons.** Historical validation below records each slice. The current rules version is 3, with responsive waves, a 0.4-second Power charge, 0.3-second post-weapon recovery and 10-point pickups. See [response decisions](2026-09-09-response-decisions.md) and [full-run decisions](2026-09-09-full-run-decisions.md) for the tested alternatives and limits.

| Balance question | Current decision | Remaining evidence |
|---|---|---|
| Freeze hold and Flame burst | Retain Freeze 12/14.4/16.8 seconds and Flame 5× for 0.3 seconds after mixed candidate outcomes. | Deliberate shatters, burst landing and physical braking. |
| Power response | Accept 0.4-second charge; aimed-clear tests still pass at 30/60/120 Hz. | Human aim correction and readability in crowded scenes. |
| Generic protection | Accept 0.3-second recovery, retaining 0.2-second collection grace and projectile travel budgets. | Cycling still has substantial immunity; inspect understandable expiry and post-pickup deaths on phones. |
| Score composition | Accept 10-point pickups; kills become the largest category in every tested policy group. Retain ordinary combo 1.2 seconds and score-neutral family celebrations. | Intentional connections and human routes on the new score scale. |
| Nova banking and parking | Retain Nova 50/75/100% and weighted supply; neither policy beats cycling in this controller. | Other optimized policies and score-aware human choices; Redline scripts did not reach Nova. |
| Earlier Classic roles | Reject the corrected 20/40/60/80/100/120 trial for now; shorter runs did not increase hunter/paddle exposure. | Human first-exposure comprehension and session distributions. |
| Progression and Daily | Retain current gates; fresh scripted cycling still reaches score thresholds, and Daily remains profile-independent. | Human runs-to-unlock and Daily participation delay. |
| Tilt smoothing | Retain 0.11 seconds. | Compare 0.08 on physical phones; no available iPhone was reported locally. |

**Remaining acceptance work, in order:**

1. Finish the restrained generic-protection cue and inspect its expiry, theme changes, pause, death and restart lifecycle.
2. Perform the [physical-phone and human acceptance pass](2026-09-09-device-acceptance.md): input, aiming, landing control, threat readability, score choices, unlock pacing and sustained performance. Automated results do not establish human run lengths or comfort.
3. Add graze, extra aim or charge-progress feedback only if those checks demonstrate a comprehension problem. No graze mechanic or score was added.
4. Apply achievement metadata in App Store Connect during release preparation and validate real Game Center submission. No account settings, uploads, leaderboard data or production state were changed here.

The complete plan remains the source for dependencies and acceptance criteria. The four originally reproduced defects and the additional confirmed behavior inconsistencies are fixed locally; the game has not yet passed the full human balance and release matrix.

Final local validation: 592 XCTest cases passed with the extended sweep enabled; SwiftLint and `git diff --check` passed; the Release simulator build succeeded for arm64 and x86_64; all eight achievement artwork files passed the repository validator. Changed warnings, Gravity fields, codex, retry, HUD and world-layout snapshots were visually inspected. Physical-device input, sustained device performance, App Store Connect configuration and release verification remain outstanding.

Follow-up measurement validation: 599 tests executed, one opt-in extended sweep skipped, zero failures. SwiftLint and diff whitespace checks passed. The review corrected a survival-overflow test that initially exercised the quotient guard and verified all summary fields survive diagnostic sanitization. This slice changes measurement plumbing, not tuning defaults.

Matched encounter follow-up: 604 tests executed with the weapon sweep enabled, one separate director sweep skipped, zero failures. Review found and fixed injected-enemy ID collisions with production splitter children before exporting the checked-in results. No numeric defaults changed in this slice.

Response tuning is now implemented: shared exponent-3 Shockwave/Freeze fronts preserve their old radius and lifetime; Power charges in 0.4 seconds. Two 864-case experiments rejected shorter-lived waves and accepted responsive fronts. See [decisions and evidence](2026-09-09-response-decisions.md). Rules version 2 resets incompatible development profiles. The reviewed full suite executed 612 tests with three opt-in sweeps skipped and zero failures; both-theme front captures were inspected. Full-run balance and physical acceptance remain open.

Full-run follow-up: the reviewed 261-case natural-spawn matrix passed, including the combined safety and scoring candidate. Default recovery is now 0.3 seconds and pickups award 10 points; incompatible rules-version-2 profiles reset under version 3. The complete regression suite ran 618 tests with four opt-in exports skipped; its sole failure was a layout-equivalence fixture's obsolete 100-point pickup assumption. That fixture now checks the credited pickup category against the configured award, and the affected lifecycle suite passed on recheck. SwiftLint, diff checks and eight malformed-data validator probes passed. The comparison and retained-rule rationale are in [full-run decisions](2026-09-09-full-run-decisions.md).
