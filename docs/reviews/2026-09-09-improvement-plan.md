Tilt Arena improvement plan — 9 September 2026

**Implement the confirmed fixes first, establish the resulting difficulty baseline, and then resolve every balance concern through a defined change or a measured decision.** This plan follows the [full mechanics and balance review](/Users/xiliangchen/projects/tilt-arena/docs/reviews/2026-09-09-mechanics-balance-review.md) at `8c564e1`. Implementation is underway; see the [implementation record and remaining work](/Users/xiliangchen/projects/tilt-arena/docs/reviews/2026-09-09-implementation-record.md) for current status. The game is unreleased: breaking changes are permitted, and no save, score, configuration, or leaderboard migration is required. Every code commit follows a review–fix–validation loop.

The review's 550 passing tests are the starting evidence, not evidence that the planned changes already work. The four reproduced defects are sensitivity limiting speed, starvation of scheduled enemies, mixed-mode personal bests, and frame-dependent family recognition. Weapon dominance, ideal run length, and physical input comfort remain hypotheses. Their completion criteria include retaining the current value when it wins the comparison.

**Use five phases, with small independently validated changes.** Work directly on master, preserve unrelated work, and make each completed slice reviewable. This direct request does not require GitHub issues or pull requests. The user has authorized local commits after a review–fix loop for each slice. Push and release are separate actions.

| Phase | Work packages | Result required before advancing |
|---|---|---|
| 1. Correct mechanics | P01–P05 | Reproductions become regressions; records use the new clean schema; establish the corrected baseline. |
| 2. Make behavior readable and consistent | P06–P09 | Gravity, protection, warnings, and retry have explicit player-facing behavior. |
| 3. Stabilize comparisons | P10–P11 | Progression and screen size no longer silently change the tested conditions. |
| 4. Tune the game | P12–P15 | Weapon, score, pacing, and progression decisions have recorded comparison results. |
| 5. Finish feedback and validate | P16–P17 | Device QA, current-schema persistence, and presentation pass. |

P02, P03, and P04 can be implemented in either order after capturing their existing failure cases. P05 precedes weapon attribution, family rewards, and multi-kill achievement changes. P10 and P11 precede final numerical tuning. Most packages touch ArenaScene, so integrate them sequentially rather than accumulating competing changes there.

**P01 establishes reproducible encounters and bounded balance measurements.**

Keep the existing architecture: ArenaScene coordinates; the director, controllers, and weapon states own their rules. Convert the temporary review probes into focused repository tests using production types. Build a small test support layer around seeded encounters and existing update methods; reuse it across tests without creating a second gameplay simulator. Capture the regressions first and add measurements as their owning systems change; full activation attribution arrives in P05.

Capture the current failing cases before implementing their fixes: maximum input at sensitivity 0.6; Classic paddle recurrence after 180 seconds with no resident enemies; the two-target Shockwave at 30/60/120 Hz; and a Redline record followed by a lower-scoring Classic personal best. Add a midnight-crossing Daily case as part of P04.

For balance comparisons, keep named encounter fixtures: sparse chasers, a dense pursuing pack, a crossing formation, a contested pickup near mines, mixed persistent threats, and late-game pressure. Give each fixture explicit initial positions, seed, charge tier, scripted input, duration, and expected question. Scripted survival is useful comparative evidence, not a substitute for human skill.

Extend the existing diagnostic accumulator, or add one small run-owned accumulator if needed, to record:

- Actual score increments split into kills, pickups, survival, and any later family bonus; totals must reconcile with the run score, including saturation behavior.
- Pickups collected by weapon/tier, age at collection, activation kill totals, and time since the last pickup at death. With overlapping effects, report association rather than claiming the last pickup caused the death.
- Unique time protected from collision, shield-active time, and control-effect time as separate measures. Overlapping protection must not double-count elapsed time.
- Realized spawns per role, seconds blocked by total capacity or warning capacity, population peaks, and deaths by enemy role and run-time band.
- Mode, seed, rules version, coarse arena size, and whether tuning is default or experimental. Do not log raw movement or device identifiers.

Emit a bounded run summary and bounded per-weapon summaries through AppDiagnostics/SwiftLog. Accumulate silently between emissions; reuse the existing heartbeat where appropriate. Extend the [log extraction script](/Users/xiliangchen/projects/tilt-arena/scripts/tilt-logs) to extract comparisons if necessary. Test runs use isolated profiles and mock Game Center clients so comparisons do not modify personal records or submit scores.

**Acceptance:** reproduction fixtures demonstrate the original defects; counters are correct across pause, death, restart, and overlapping effects; logging failure cannot change play; no per-frame diagnostic writes. Store the corrected baseline results after P02–P05, then a second baseline after P06–P11.

Primary files: [diagnostic accumulator](/Users/xiliangchen/projects/tilt-arena/TiltArena/Diagnostics/ArenaDiagnosticAccumulator.swift), [scene](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/ArenaScene.swift), [balance tests](/Users/xiliangchen/projects/tilt-arena/TiltArenaTests/EnemySpawnDirectorBalanceTests.swift), [test directory](/Users/xiliangchen/projects/tilt-arena/TiltArenaTests).

**P02 fixes sensitivity without changing the player's maximum-speed contract.**

Apply sensitivity to the active response before its final clamp. Retain the existing 0.6–1.4 settings range, 3-degree dead zone, and 0.11-second smoothing for this fix. Keep full-speed crossing time at 2.5 seconds and preserve diagonal normalization. Enemy ceilings should remain relative to the common full player speed, not compensate for an input bug.

Test all supported sensitivity values for monotonic response, neutral stability, equal attainable top speed, and finite output. Exercise flat, standard, reclined, and custom calibration with physically possible gravity vectors in both landscape orientations. Simply feeding arbitrary large x/y values into a unit test is insufficient: projected gravity has directional limits. If moving the clamp exposes an unreachable full-input direction for a supported posture, correct that calibration/response mapping within this package before declaring the comfort setting fair.

**Acceptance:** sensitivity 0.6 can attain the same full movement speed as 1.0 and 1.4 at a physically attainable tilt in supported postures; low sensitivity still provides finer control over small motion; no directional or diagonal speed advantage. Add focused processor/controller tests and manually validate the calibration preview on a phone.

Primary files: [signal processor](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Input/TiltSignalProcessor.swift), [calibration](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Input/TiltCalibration.swift), [gravity mapping](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Input/TiltGravityMapping.swift), [movement](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Player/PlayerMovementController.swift).

**P03 gives every enabled enemy pattern a fair opportunity to spawn.**

Separate countdown progress from admission to the warning budget. A busy warning slot must not reset another pattern's clock. Keep due patterns pending, service the most overdue viable pattern first, and use a deterministic tie-break. A blocked or geometrically impossible pattern must not prevent other viable patterns from being considered.

Retain the existing warning and population limits. After a successful spawn, schedule the next attempt from that success; do not release a backlog of missed formations in one frame. Keep placement-failure retry behavior bounded and distinct from capacity blocking. Clear pending state correctly when a pattern is disabled or a run resets.

Test admission of multi-body formations and paddles near the population cap. Consider due patterns before filling newly freed slots with chasers. If fragmented capacity still permanently suppresses viable multi-body patterns, reserve only the slots required for the oldest viable due pattern; avoid adding a general encounter-director framework.

**Acceptance:** the isolated 360-second Classic reproduction contains recurring paddles after 180 seconds; every enabled role recurs when its placement and population requirements are satisfiable. Admission happens when capacity returns, without restarting a full countdown or causing a spawn burst. Counts and first/recurring appearances are stable across 30/60/120 Hz within frame-time tolerance. Warning limits and total caps are never exceeded.

Run the primary reproduction at seed 20260726, plus a small fixed seed set with 6-, 20-, and 60-second enemy residence. Add a longer offline 600-second comparison to inspect realized role mix. Do not increase nominal enemy rates in this package: restoring missing threats already increases pressure.

Primary files: [pattern scheduling](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Enemies/EnemySpawnDirector+PatternSchedule.swift), [director](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Enemies/EnemySpawnDirector.swift), [paddle spawning](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Enemies/EnemySpawnDirector+PaddleTrap.swift), [schedule tests](/Users/xiliangchen/projects/tilt-arena/TiltArenaTests/EnemySpawnDirectorPatternScheduleTests.swift).

**P04 separates competitive records and preserves the identity of a Daily run.**

Add explicit score/combo/time records for Classic and Redline, and Daily records keyed by the actual challenge seed. Keep lifetime kills, lifetime runs, earned weapons, and earned awards shared. Maintain explicitly named lifetime best score/combo/time for noncompetitive progression; competitive HUDs must not read those aggregates. Define one record lookup used by the active HUD, home/mode screen, post-run comparison, and new-best audio/haptics; compare against the correct record before persisting the completed run.

Capture the seed, mode, start time, and rules version at actual run start. Pass that context through the session and RunSummary. Resetting a preview must not replace the identity of an active run. Daily participation and best scores use the captured seed, even after midnight, a time-zone change, pause/resume, or a long post-run transition. New attempts select the current local-day seed; an already started attempt keeps its seed. Keep local-day behavior for now and label it consistently.

Use the new records schema directly. Remove legacy record decoding, calibration migrations, compatibility aliases, and grandfathering when touching their owning models. Development saves may reset; do not add historical reconstruction, migration notices, or legacy-record UI. Redline access follows the new Classic gate.

Show “Today's best” and attempt delta for Daily. Maintain a bounded recent Daily record history, such as 90 challenge dates, independent of the five recent-run summaries. Game Center remains Classic-only for score submission, and development submission storage may reset with the schema.

**Acceptance:** higher scores from another mode cannot suppress a new Classic best; midnight tests credit the seed actually played; current-day Daily results never display another day's best. New saves round-trip with correct records and unlocks. Reopening the app cannot duplicate progress or submit a non-Classic score; incompatible development saves can reset.

Primary files: [profile store](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Run/RunProfileStore.swift), [run summary/controller](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Run/ClassicRunController.swift), [session state](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Run/ArenaRunSessionState.swift), [mode rules](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Run/ArenaModeRules.swift), [Game Center service](/Users/xiliangchen/projects/tilt-arena/TiltArena/App/GameCenterService.swift).

**P05 recognizes a weapon clear once, regardless of how many frames its hits take.**

Give each pickup activation a run-local identity. Count successful kills through the shared destruction path, and qualify that activation for family recognition when its second distinct kill occurs. Immediate kill score and ordinary combo updates remain unchanged. An activation that kills only one enemy does not prime, reset, or extend the family chain. Later kills from an already qualified activation do not reset family history or issue duplicate family rewards.

Use the existing six-second family window, refreshed by a newly qualifying activation. A different family produces synergy; three distinct families in the chain produce cascade. A new qualifying activation of the same family can begin a new chain according to the existing same-family rule, but a delayed hit from an old activation cannot do so. Preserve deterministic ordering for simultaneous qualifying events.

Propagate attribution through waves, seeker/lightning callbacks, shield instances, flame segments, Gravity, Nova clears, and frozen enemies that are shattered later. Existing flame segments retain their source activation after another pickup. Reapplying freeze replaces the source only when that application actually refreshes the freeze. For a refreshed single-instance shield or aura, close the old activation for future hits and attribute subsequent hits to the new pickup. Use stable ownership when effects overlap; credit each actual destroyed enemy once.

Keep counters small and lifecycle-owned. Prefer one focused clear tracker or fields in existing runtime state over an event bus. Clear run-local tracking on restart; delayed callbacks from an old run must never affect a new one.

**Acceptance:** the Shockwave reproduction produces the same family event at 30/60/120 Hz; late single hits cannot erase a cascade; overlapping effects cannot double-credit a kill; no-kill and one-kill activations cannot farm a primer. Pause, replacement, expiry, and restart leave no orphan state. Aggregate multi-kill achievements use this same definition.

Primary files: [weapon runtime](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Weapons/ArenaWeaponRuntime.swift), [active weapon state](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Weapons/ArenaActiveWeaponState.swift), [family state](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Weapons/WeaponComboState.swift), [shared destruction and effect integration](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/ArenaScene.swift), [enemy model](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Enemies/ArenaEnemy.swift).

**P06 makes Gravity Well behave like the persistent field shown on screen.**

Replace permanent snapshot membership with spatial membership evaluated against current enemies. The core clears enemies that touch it throughout the visible lifetime, including during the arming delay; the outer pull begins after the existing 0.5-second delay and lasts three seconds. Only enemies currently intersecting the active pull radius receive pull displacement. Enemies that leave stop being pulled and can be affected again if they re-enter. Preserve suppression of splitter children and shared kill/achievement attribution.

Start with the current radii and pull strength. Do not increase radius at the same time as expanding eligibility to entrants. Keep one active well: a new pickup visibly replaces the old well, ends its remaining effect without a free expiry explosion, and creates a new activation identity. Remove old visuals/callbacks together with its state.

**Acceptance:** later entrants are affected, a target crossing the core is cleared, enemies outside the field are not remotely tethered, and replacement cannot leave an invisible hazard or duplicate kill. Test enemies moving both toward and away from the well, frozen targets, splitters, and core crossings at different frame rates. After that, compare the existing 53.3 points/s base pull with stronger pull only if the field still fails to create useful local control.

Primary files: [Gravity state](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Weapons/GravityWellState.swift), [initial selection](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Weapons/StartingWeaponResolver.swift), [scene integration](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/ArenaScene.swift), [Gravity tests](/Users/xiliangchen/projects/tilt-arena/TiltArenaTests/GravityWellStateTests.swift).

**P07 defines pickup protection explicitly and budgets it per activation.**

Use a 0.2-second immediate collection grace as the first candidate for every weapon, expressed through the existing protection state and tuning catalog. Multiple pickups refresh to the later deadline rather than adding durations. Persistent defensive effects keep their explicit contracts: Flame protects during its burst and aftermath; Razor clears contact threats; Time Dilation pushes/slows but is not equivalent to invulnerability.

Measure the current projectile safety first, then replace repeated per-impact generic refresh with one bounded protection budget per activation. Derive its deadline from scheduled travel/completion plus the chosen recovery duration, with a documented upper bound, rather than letting every hit restart another full window. Preserve enough travel coverage that the change does not reintroduce deaths before a promised immediate rescue resolves. Keep that deadline stable if an effect's target dies early or an animation callback arrives late.

Introduce collection grace and normalize impact refresh in separate comparisons. A 0.2-second grace does not promise immunity throughout a 0.6-second Power charge or a 3.5-second Gravity lifetime; the remaining danger is intentional and must be visible.

**Acceptance:** pickup priority is consistent at lethal contact; pause freezes safety; duration follows the declared activation budget rather than the number or grouping of impact callbacks; shield/Flame/slow states remain distinct. Measure post-pickup deaths in 0.25/0.5/1-second windows and the fraction of a run protected. Accept the candidate when avoidable collection-frame deaths decline without routine pickup cycling sustaining near-continuous generic immunity. Record the observed distributions instead of adopting an arbitrary global protection target.

Primary files: [protection state](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Weapons/ArenaActiveWeaponState.swift), [feedback tuning](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Tuning/GameTuningConfiguration.swift), [scene protection calls](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/ArenaScene.swift), [lifecycle tests](/Users/xiliangchen/projects/tilt-arena/TiltArenaTests/ArenaSceneEnemyLifecycleTests.swift).

**P08 aligns enemy warnings with actual collision and counterplay.**

Keep formations as dotted sweeps with several legal passages, highlighting the widest opening. Replace warning visuals that imply an unbroken wall with lane/trajectory marks consistent with the dots. Keep paddle bars visibly segmented and make the puck's travel area readable. Preserve current collision generosity while tuning visuals; do not enlarge hitboxes merely to make a warning accurate.

Distinguish mine spawn warnings from the stationary lethal body; a large warning circle must not imply a later area explosion. Ensure freeze, thaw grace, spawn grace, and lethal states have consistent shape/motion cues in both themes. Teach splitter suppression in concise weapon descriptions: Freeze, Gravity, and Nova remove the parent cleanly; other damage can produce children and additional scoring risk.

Inspect overlapping warnings as complete encounters. If a warning combination removes every reachable exit under normal input, constrain that specific combination or delay the second admission; use deterministic fixtures to prove the failure before adding broad pathfinding or generalized safety heuristics. Keep hunters' prediction strength unchanged initially. Trial a small commitment window or clearer facing only if phone tests show their reversals are unreadable.

**Acceptance:** players can identify a safe passage and distinguish warning from live hazard in representative small-device footage; chosen passages agree with actual collisions; the first appearance of each role can be understood without opening the codex. Add visual snapshots for changed warnings and collision fixtures only where geometry changes.

Primary files: [telegraph node](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Enemies/EnemyTelegraphNode.swift), [enemy node](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Enemies/EnemyNode.swift), [visual geometry](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Enemies/EnemyVisualGeometry.swift), [menu models](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/UI/ArenaMenuModels.swift).

**P09 restores a fast retry loop without removing the deliberate first start.**

Keep the three-second first-start/calibration hold. “Play Again” uses a separate short retry path: start with a 0.75-second visible countdown from a safe centered position. Do not require another three-second dwell. Reset stale input smoothing, weapons, score, and warning state before the countdown completes. Backgrounding pauses or cancels the pending start safely; a changed device posture remains recoverable through the existing calibration control.

Use P04's selected-mode record in every post-run comparison. Show score, survival, kills, combo, actual unlocks, and Daily attempt delta where applicable, with the retry control prominent. Avoid adding multiple new buttons or diagnostic copy.

**Acceptance:** one tap after death reliably begins a fresh attempt after the short countdown; repeated taps cannot create duplicate runs; accidental app backgrounding cannot launch unseen gameplay; no enemy or pickup activity occurs during the countdown. Verify the actual tap-to-control time on a phone and update affected UI snapshots.

Primary files: [ready controller](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/UI/ReadyStartHoldController.swift), [navigation state](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/UI/ArenaNavigationState.swift), [scene transitions](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/ArenaScene.swift), [screen rendering](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/UI/ArenaUIRenderer+Screens.swift).

**P10 makes pickup supply predictable enough to learn and fair across unlock progress.**

Guarantee one Shockwave, one Seeker, and one Razor Shield in Classic's initial offered set, in seeded order. Reorder the first filtered weighted cycle to do this while preserving its counts, rather than injecting unlimited extra starter pickups. Continue the ordinary weighted cycle afterward. Failed placements must leave the pending kind available for a later successful placement.

For a newly unlocked weapon, consider a one-run introduction within the first six successful spawns by moving an existing occurrence forward. Preserve the weighted cycle's multiset and do not apply profile-dependent introductions to Daily. Daily's opening and complete cycle are determined solely by challenge rules and seed.

Keep Redline's distinct two-pickup structure during the first comparison. Measure availability of escape tools for fresh, intermediate, and complete Classic profiles and for Redline separately. If progression still makes reliable choices too scarce, adjust the cycle's role proportions; add no loadout system to solve an unmeasured distribution problem.

Test immediate collection, Nova banking, and leaving two unwanted orbs parked while cycling one slot. Track reward, survival, and repetitive route behavior. Keep persistent charging unless a specific strategy wins consistently with little meaningful risk. If safe repetitive farming appears, first improve pickup placement among existing valid candidates: offer a readable contested option while retaining an obtainable alternative. Do not spawn an orb directly inside unavoidable damage.

**Acceptance:** the guaranteed opening survives placement retries; seeds remain deterministic; full-cycle frequencies remain explicit; unlock introductions do not alter Daily fairness. No unlock silently removes already earned content. Each suspected pickup strategy receives a documented retain/change decision based on matched comparisons.

Primary files: [pickup planner](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Weapons/PickupSpawnPlanner.swift), [progression rules](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Run/ArenaProgressionRules.swift), [pickup registry](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Weapons/ArenaPickupRegistry.swift), [planner tests](/Users/xiliangchen/projects/tilt-arena/TiltArenaTests/PickupSpawnPlannerTests.swift).

**P11 establishes one logical arena for consistent physics across phones.**

First capture the actual scene/playable rectangles on the smallest supported phone and a large phone, and compare speed, weapon coverage, formation gaps, and spawn clearances. The recommended resolution is a common gameplay coordinate system, initially matching the review benchmark's 718 × 377 gameplay bounds and 658 × 317 playable region. Confirm those dimensions are readable on the small phone before locking them in.

Fit that world into the available landscape display with one uniform scale. Keep UI layout in screen/safe-area coordinates, separate from gameplay coordinates. Apply the world transform consistently to players, enemies, pickups, effects, warnings, background, and death markers. Audit every conversion used by movement bounds, projectile origins, culling, snapshot setup, and touch handling. Keep logical radii/speeds unchanged during this conversion and avoid adding a second border inset.

**Acceptance:** the same seed and scripted input produce the same logical positions, hits, spawn choices, and score across device layouts within numerical tolerance. Physical sprites and charge markers remain readable on the smallest display; notch areas do not overlap the active world. If the proposed dimensions fail readability, choose one revised canonical rectangle and rerun the baseline rather than applying unrelated scaling rules per device.

Primary files: [arena geometry](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/ArenaGeometry.swift), [landscape layout](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/UI/ArenaLandscapeUILayout.swift), [scene coordinate integration](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/ArenaScene.swift), [view controller](/Users/xiliangchen/projects/tilt-arena/TiltArena/App/GameViewController.swift).

**P12 evaluates every weapon against its intended job before accepting buffs or nerfs.**

Run all 11 weapons at all three charge tiers through the named encounters from P01. Use sparse and dense populations and moving targets. Report direct kills, survival effect, controlled space, duration, pickup-to-death distribution, and combo continuity. Distinguish static snapshot targets from persistent effects. A control weapon is not weak merely because it records fewer kills.

| Weapon | Intended job | First candidate / decision rule |
|---|---|---|
| Shockwave | Immediate local breathing room | Retain 90/104.4/118.8 radii; evaluate P07 collection grace before expansion speed changes. |
| Seeker | Reliable distributed kills with crowd splash | Retain 4/6/8 targets and 30/33/36 splash; normalize protection and compare sparse versus dense outcomes. |
| Razor Shield | Temporary safe contact clearing | Retain 4/4.8/5.6 seconds initially; shorten only if repeat pickups produce excessive safe uptime after P10. |
| Freeze | Buy time and turn threats into collectible shatters | Compare 12/14.4/16.8 seconds with 8/9.6/11.2; retain radius and thaw grace. Keep the shorter set only if it restores decisions without making contact shattering impractical. |
| Gravity | Persistent local capture/control | Evaluate P06 first; vary pull strength separately from radius or lifetime. |
| Lightning | Clear a connected dense pack | Retain 6/8/10 targets and initial range 140; compare its capped chain reach with Seeker splash after protection normalization. |
| Flame | Escape while leaving a useful trail | Compare 5× for 0.3 seconds with 4× for 0.22 seconds; keep trail dimensions fixed initially. Measure landing control and post-burst deaths. |
| Time Dilation | Create a route through pursuing enemies | Retain 6/7.2/8.4 seconds and max slowdown 8× initially; measure route access and post-aura safety rather than adding damage. |
| Power Wave | Deliberate directional clear | Compare charge 0.6 with 0.4 seconds, preserving full-arena travel and direction at release. Keep an accurate moving aim cue. |
| Ricochet Lance | Reward use of walls and alignment | Retain 1/2/3 bounces and current width; validate path readability and usefulness near corners before buffing. |
| Nova | Rare high-density reset worth delaying | Compare 50/75/100% with 50/70/90% only after a banking strategy demonstrably dominates. Preserve population-dependent value and splitter suppression. |

Alter one parameter family at a time through the existing tuning configuration/catalog. A retained baseline is a completed balance decision, provided the comparison and reason are recorded. Validate effect duration/area shown by visuals against actual collision behavior after each accepted change.

**Acceptance:** every weapon has at least one clear useful encounter role; charge tiers never reduce effective utility through a mechanics defect; no candidate is accepted solely because its raw kills exceed a defensive tool's. Each numerical change has a baseline, result, decision, and relevant regression/visual check.

Primary files: [weapon configuration](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Weapons/StartingWeaponResolver.swift), [Flame configuration](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Weapons/FlameTrailState.swift), [tuning catalog](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Tuning/GameTuningParameterCatalog.swift), [weapon tests](/Users/xiliangchen/projects/tilt-arena/TiltArenaTests/ArenaWeaponRuntimeTests.swift).

**P13 makes the score reward deliberate connections and explains family rewards.**

Keep clearing mastery as the main scoring identity. Compare a 1.6-second ordinary combo window with the current 1.2 seconds. Evaluate whether players can intentionally connect different pickups and whether passive persistent effects gain disproportionate benefit. Do not change the multiplier curve in the same trial.

Once P05 is stable, test a fixed +25 synergy / +75 cascade award, paid once per qualifying activation. A cascade receives its cascade award rather than both awards. Show the actual bonus briefly; preserve the ordinary kill-combo timer. Do not add automatic damage or invulnerability as a family reward. If the extra score distracts from the core loop without changing useful choices, retain family events as clearly celebratory feedback and remove any implication of a hidden power bonus.

If long uninterrupted chains still make the score excessively sensitive to one lucky crowd, separately compare a gentler high-end multiplier slope with the current uncapped curve. Only trial survival points from the beginning if score-composition data shows careful survival is insufficiently recognized. Keep anti-idling and pickup-farming consequences in the comparison.

**Acceptance:** frame grouping cannot change family payouts; score categories reconcile; ordinary and family combos are visually distinguishable; missed connections have understandable consequences. Recalculate score gates and achievements against the chosen formula. Use final score rules consistently before the first release; development records can reset when the scoring scale changes.

Primary files: [scoring controller](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Run/ClassicRunController.swift), [family state](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Weapons/WeaponComboState.swift), [HUD feedback](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Player/PlayerCraftNode.swift), [scoring tests](/Users/xiliangchen/projects/tilt-arena/TiltArenaTests/ClassicRunControllerTests.swift).

**P14 tunes enemy pacing to an explicit session goal while preserving counterplay.**

Use provisional goals of roughly 45–90 seconds for a new player's settled early attempts and 90–180 seconds for practiced Classic play. These are product targets to test, not measured current results. Keep an expert tail beyond three minutes without allowing a single trivial route to neutralize the whole encounter mix. Redline should require earlier pattern reading and tighter decisions.

After the scheduler and weapon changes settle, compare the current Classic introductions at 30/50/70/95/120/150 seconds with 20/40/60/80/100/120 seconds. Introduce each role sparsely before raising its recurring density. Retain warnings, child grace, and the attainable pursuit-speed advantage. Evaluate Redline separately rather than copying Classic rate changes into it.

Inspect realized role mix beyond 180 seconds. If skilled play reaches a stable, repetitive equilibrium, add a small bounded cycle of pressure and recovery using the existing tuning structure: vary which patterns are emphasized and create short breathing windows. Establish its exact timing from baseline recordings. Keep population caps and pursuit-speed ratios fixed in the first trial; do not use endless speed growth as the default solution.

**Acceptance:** most of the intended audience encounters each core role before repeatedly exhausting the mode; deaths are explainable; pressure does not degrade into only chasers because of admission order; multiple viable routes remain. Record survival percentiles, first-exposure deaths, realized spawns, and cap occupancy. Demonstrate that any pacing change improves the target behavior in paired sessions rather than merely lowering average survival.

Primary files: [mode rules](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Run/ArenaModeRules.swift), [enemy tuning](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Enemies/EnemySpawnConfiguration.swift), [balance tests](/Users/xiliangchen/projects/tilt-arena/TiltArenaTests/EnemySpawnDirectorBalanceTests.swift).

**P15 aligns unlocks, achievements, and Daily access with the revised game.**

Retain the mixture of lifetime-kill and skill milestones. Weapon score/combo unlocks use shared lifetime bests across standard modes; only the Redline entry gate requires a Classic best. Use the new progression schema directly. Review runs-to-unlock after P12–P14, particularly the score 1,500/3,000 and combo 20/30 gates. Adjust only milestones shown to block progression unfairly or become trivial under the accepted scoring rules. Redline access uses the new Classic record.

Make general Game Center achievements consistent across all standard modes: first run, pickups, kills, combo milestones, and survival progress use the same scope for live completion and run-finished partial progress. Keep leaderboard submission Classic-only. Review the score achievement's description and threshold with the final score rules; if it is intended to be Classic-specific, explicitly label and enforce that single exception. No development achievement migration is required. Keep identifiers consistent with the final artwork manifest and release setup.

Use P05's two-kill activation definition for the existing first multi-kill achievement. Prefer renaming its displayed description to match that behavior over silently changing it to require the three-family cascade. Update local text, asset metadata, and release QA documentation together; external App Store Connect changes remain a release task.

Keep Daily's all-weapons prerequisite for the first corrected release. Then evaluate earlier access with a supplied common arsenal if the prerequisite materially delays participation. The candidate Daily rules must ignore personal unlock introductions and use the same complete arsenal for every player. Today's best, attempt delta, and actual seed persistence from P04 are required regardless of access timing.

**Acceptance:** current-rule progress persists correctly; unlock text reports the right metric; live and final achievement progress agree for the same mode; Daily rules are profile-independent. Every reviewed progression concern has either a validated change or an explicit retained-rule rationale.

Primary files: [progression rules](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Run/ArenaProgressionRules.swift), [achievement mapping](/Users/xiliangchen/projects/tilt-arena/TiltArena/App/GameCenterScoreSubmissionStore.swift), [achievement identifiers](/Users/xiliangchen/projects/tilt-arena/TiltArena/App/GameCenterIdentifiers.swift), [release QA](/Users/xiliangchen/projects/tilt-arena/docs/game-center-release-qa.md).

**P16 finishes control feel and feedback with minimal extra screen clutter.**

Compare smoothing at 0.08 versus 0.11 seconds after P02 and P11, holding the dead zone fixed. Use stop/reverse drills, diagonal approaches, and narrow-passage recovery on a physical phone. Keep the value that improves intentional control without visible jitter; do not infer comfort from simulator keyboard input.

Keep stable pickup glyphs and collection boundaries. Add a subtle indication of progress toward the next charge tier if users cannot predict the wait; charged and overcharged states must remain identifiable without color alone. Reuse existing aim feedback for Power and add a restrained alignment cue for Lance only if actual missed shots show the need. Give generic protection a simple cue distinct from shield, freeze, and slow effects. Prefer reusing an existing visual channel over adding another concentric HUD ring.

Close-call scoring is an optional addition. Address the missing feedback first with a restrained cue for a completed dangerous pass. If implemented, emit at most once per enemy after entering and then leaving a narrow near-miss band; exclude frozen, spawn-grace, and protected contact, and clear tracking with enemy lifecycle. Keep it score-neutral initially. If it fails readability or distracts from pickups, defer scoring and record that decision explicitly.

**Acceptance:** players can identify harmful versus harmless states, charge tier, aim, and the reason for death at actual device size in both themes. Effects remain bounded under mass clears. Pausing/resuming cannot leave a misleading visual state. Close-call feedback cannot repeat while orbiting or sitting beside one harmless target.

Primary files: [pickup visuals](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Weapons/WeaponPickupNode.swift), [player visuals](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Player/PlayerCraftNode.swift), [effect bounds](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Weapons/WeaponImpactPlan.swift), [input filtering](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Input/TiltSignalProcessor.swift), [visual tests](/Users/xiliangchen/projects/tilt-arena/TiltArenaTests/ArenaVisualRoleSnapshotTests.swift).

**P17 closes the work with regression, device, and persistence evidence.**

For each mechanics slice, run the focused tests that cover its changed contract, then the complete suite at phase boundaries. Run SwiftLint and a simulator build as required by the repository's normal checks. Update snapshots only after inspecting intended visual changes. Keep every accepted tuning set in source defaults/catalog and document the tested values; do not leave the release dependent on one developer's persisted overrides.

Use this final matrix:

| Dimension | Required checks |
|---|---|
| Modes | Classic, Redline, Daily; correct records, seeds, rules, and achievement scope. |
| Profiles | New, partially unlocked, fully unlocked, new-schema round trips and corrupt-data recovery. |
| Timing | 30/60/120 Hz, dropped-frame fixtures, pause/resume, backgrounding, midnight rollover, rapid retry. |
| Weapons | 11 weapons × 3 tiers; overlap, refresh/replacement, moving targets, splitter suppression, delayed callbacks after death. |
| Encounters | Early teaching, 180–360-second recurrence, 600-second role mix, population and warning saturation. |
| Devices | Small and large phones; physical tilt in both landscape orientations; actual-size readability in both themes. |
| Persistence | Records and unlocks survive relaunch; mode/seed assignment uses actual run context. |
| Performance | Crowded effects do not create sustained frame deterioration; gameplay hit resolution remains uncapped by visual limits. |

For human balance checks, begin with counterbalanced matched-seed sessions on the same device and profile, then expand to several new and practiced players. Use an initial pilot of 6–10 testers with at least two baseline and two candidate attempts per person for the most consequential changes. Treat that sample as directional evidence; collect more when results conflict or a change targets rare late-game behavior. Report distributions and qualitative failure explanations, not a claim that a small sample proves universal balance.

Freeze the resulting tuning before the first public release. Align Game Center identifiers, achievement descriptions, and queue formats with those rules; no compatibility with development records is required.

**Completion means:** every confirmed defect has regression coverage; every balance concern has a recorded tested decision; current-schema persistence and device checks pass; approved defaults are committed in a coherent set of slices; the final report distinguishes local tests, device playtesting, and any later release. Implementation can be complete locally without claiming a deployment or public leaderboard migration occurred.

**Every finding in the review is covered by a work package.**

| Review concern | Resolution owner |
|---|---|
| Sensitivity speed penalty and supported posture limits | P02 |
| Input smoothing, reversals, and physical comfort | P16 |
| Scheduler starvation, multi-body admission, and recurring threat mix | P03, P14 |
| Mixed records and new-best feedback | P04 |
| Daily midnight identity, per-day records, replay incentive | P04, P15 |
| Frame-dependent family recognition and late-hit history resets | P05 |
| Gravity entrants, weak pull, and replacement semantics | P06, P12 |
| Uneven pickup safety and repeated-impact protection | P07 |
| Formation/paddle gaps, mine warnings, hunter readability | P08 |
| Splitter suppression and its score/risk tradeoff | P08, P12 |
| Mandatory retry hold and post-run usability | P09 |
| Starter dilution, poor openings, teaching new unlocks | P10 |
| Pickup farming, Nova banking, parked undesirable pickups, route danger | P10, P12 |
| Device-size differences in coverage, movement, and gaps | P11 |
| All 11 weapon roles and charge-tier balance | P12 |
| Freeze duration, Flame displacement, Power charge, Nova full clear | P12 |
| Score concentration, combo window, family payoff, survival contribution | P13 |
| Late introductions, short-session goals, post-180-second ceiling | P14 |
| Unlock thresholds, Daily accessibility, achievement consistency | P15 |
| Charge/safety/aim readability and missing close-call feedback | P16 |
| Missing balance evidence, diagnostic limits, performance and release compatibility | P01, P17 |

The four original defects now have regression coverage, and the new records schema is validated. Implementation also covers the confirmed Gravity, pickup, retry, warning, device-geometry, and achievement inconsistencies. The implementation record tracks remaining measurement work and numerical experiments explicitly; these packages are not complete merely because their prerequisite mechanics are fixed.
