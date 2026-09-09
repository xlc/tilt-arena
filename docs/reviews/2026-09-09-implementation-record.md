Tilt Arena implementation record — 9 September 2026

**The mechanics foundation is implemented. Numerical balance experiments and physical-phone acceptance remain open.** This record follows the [original review](/Users/xiliangchen/projects/tilt-arena/docs/reviews/2026-09-09-mechanics-balance-review.md) and [detailed improvement plan](/Users/xiliangchen/projects/tilt-arena/docs/reviews/2026-09-09-improvement-plan.md). Changes are local commits on master. Nothing has been pushed or released. Development data may reset; no migration or grandfathering was added.

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

Use another installed simulator ID if necessary. The `spawn-baseline.csv` XCTest attachment is emitted by `EnemySpawnDirectorBalanceTests.testExportExtendedSpawnBaseline`. Ordinary test runs skip only this extended export. The standard cadence regressions still run. Export the attachment using `xcrun xcresulttool export attachments --path <result.xcresult> --output-path <directory>`.

**Retained values are provisional, not completed numerical experiments.** Restoring missing threats, allowing Gravity entrants, removing the speed penalty, and changing openings already alter difficulty. No additional blanket spawn-rate increase or weapon nerf was applied on top of those fixes.

| Balance question | Current decision | Evidence still needed |
|---|---|---|
| Freeze lasts 12/14.4/16.8 seconds | Retain while comparing the proposed 8/9.6/11.2. | Whether shorter freezes leave enough time for intentional contact shatters and escape routes. |
| Flame travels too far | Retain 5× for 0.3 seconds for the baseline; compare 4× for 0.22. | Current straight burst is 394.8 logical points, or 60% of width; candidate is 231.6, or 35.2%. Measure landing control and deaths after protection. |
| Power Wave charge feels unsafe | Retain 0.6 seconds for the baseline; compare 0.4. | Pickup-to-death windows and deliberate aiming after collection grace. The wave still travels across the arena. |
| Overcharged Nova dominates banking | Retain 50/75/100% until banking beats alternatives in matched encounters. | Immediate cycling, banking, and leaving unwanted pickups parked, with real survival and score composition. |
| Family feedback should pay score | Retain cosmetic synergy/cascade and the 1.2-second ordinary combo window pending comparison. | Trial 1.6 seconds separately from +25/+75 family awards; quantify score composition and passive-chain effects. |
| Classic introductions are too late | Retain 30/50/70/95/120/150-second gates after scheduler repair. | First-exposure deaths, run-length distribution, and repeated-route success; compare 20/40/60/80/100/120 only after baseline. |
| Unlocks or Daily access delay variety | Retain current milestones and Daily's complete-arsenal gate. | Runs to unlock for new/intermediate players and participation delay. Common Daily rules are already independent of personal unlocks. |
| Tilt smoothing feels sluggish | Retain 0.11 seconds; compare 0.08 on hardware. | Jitter, reversals, braking, comfort and attainable input on physical phones. |

**Remaining implementation and acceptance work, in order:**

1. P01 measurement accumulation is now implemented: reconciled score categories, pickup age/tier, activation kill distribution, protection/control exposure, spawn gates and pickup-to-death association. See [measurement definitions](2026-09-09-balance-measurements.md). The matched encounter work below remains open.
2. P12 now has a corrected 1,032-case matched matrix covering all 11 weapons and three tiers, two scripts, two seeds and three candidates. See [results](2026-09-09-weapon-results.md). P10 full-run pickup strategies, deliberate aiming follow-ups, and human role comparisons remain open; the matrix is not a weapon tier ranking.
3. Run counterbalanced baseline/candidate sessions for P12–P15. Accept or reject each numerical change using the plan's criteria and update the retained-value table with results. Do not treat this table as completion of those experiments.
4. Finish P16's aimed-charge/safety feedback evaluation and decide whether score-neutral graze feedback improves play. No graze mechanic or reward was added.
5. Perform P17 physical-phone QA in both landscape orientations, both themes, supported postures and small/large layouts. Inspect overlapping warning exits, real tap-to-control retry time, and sustained crowded-frame performance. Simulator snapshots do not prove physical tilt comfort or human readability under motion.
6. Apply the final achievement metadata in App Store Connect during release preparation. No account settings, uploads, leaderboard data or production state were changed here.

The complete plan remains the source for dependencies and acceptance criteria. The four originally reproduced defects and the additional confirmed behavior inconsistencies are fixed locally; the game has not yet passed the full human balance and release matrix.

Final local validation: 592 XCTest cases passed with the extended sweep enabled; SwiftLint and `git diff --check` passed; the Release simulator build succeeded for arm64 and x86_64; all eight achievement artwork files passed the repository validator. Changed warnings, Gravity fields, codex, retry, HUD and world-layout snapshots were visually inspected. Physical-device input, sustained device performance, App Store Connect configuration and release verification remain outstanding.

Follow-up measurement validation: 599 tests executed, one opt-in extended sweep skipped, zero failures. SwiftLint and diff whitespace checks passed. The review corrected a survival-overflow test that initially exercised the quotient guard and verified all summary fields survive diagnostic sanitization. This slice changes measurement plumbing, not tuning defaults.

Matched encounter follow-up: 604 tests executed with the weapon sweep enabled, one separate director sweep skipped, zero failures. Review found and fixed injected-enemy ID collisions with production splitter children before exporting the checked-in results. No numeric defaults changed in this slice.
