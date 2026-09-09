Tilt Arena mechanism and balance review — 9 September 2026

**The core design is coherent: route through danger, time a pickup, turn the pursuing crowd into a clear, and repeat. The next work should make that loop consistent and measurable before expanding the arsenal.** The strongest ingredients are the forgiving hitbox, enemies with different movement roles, automatic weapons that preserve tilt as the main input, and pickups that become stronger when left in danger. The biggest weaknesses are control fairness, unreliable late-game scheduling, uneven weapon safety, and rewards that strongly favor particular clear patterns.

This is the historical pre-change review. See the [implementation record](/Users/xiliangchen/projects/tilt-arena/docs/reviews/2026-09-09-implementation-record.md) for resolved findings and remaining work. Source line references below belong to the reviewed commit, not the changed working tree.

This review covers default tuning at commit `8c564e1`, including input, movement, collisions, all enemy roles, spawn scheduling, all 11 weapons, pickup placement and charging, scoring, progression, modes, replay, and visual feedback. The existing iOS simulator suite passed **550 tests with zero failures**. Temporary Swift probes exercised the current control code and isolated weapon/spawn behavior; existing crowded-gameplay, pickup-charge, and post-run snapshots were also inspected. These checks establish rules and reproducible defects. They do not establish human survival rates, physical tilt comfort, or a definitive weapon tier list.

**Fix these four inconsistencies before changing the overall difficulty.**

| Priority | Finding | Evidence and impact | Suggested change |
|---|---|---|---|
| High | Low sensitivity reduces maximum player speed | Sensitivity 0.6 caps input at 0.6 even at extreme tilt. On a 718 × 377 test arena, actual speed is 157.92 points/s versus 263.2 at sensitivity 1.0. Enemy speed ceilings use the latter. A Classic chaser at its ceiling can therefore be 30% faster than the low-sensitivity player. | Apply sensitivity to the response slope before the final input clamp. Verify every supported sensitivity can reach the same maximum speed at an attainable tilt. |
| High | Shared telegraph capacity can starve late patterns | A full warning budget resets other pattern timers to their full interval, even when they are not due. An isolated 360-second Classic director run with no resident enemies or pickups produced zero paddle traps during seconds 180–360. | Preserve timer progress while capacity is blocked; let due patterns wait without losing their place. Verify sustained recurrence, while retaining the visual warning budget. |
| High | Personal bests mix modes | Classic, Redline, and Daily all update one best score; the UI and Redline unlock call it “CLASSIC BEST,” while Game Center submits only Classic. A Redline record can suppress a later Classic personal best. | Store records per mode and Daily seed. Keep lifetime kill totals shared where intended. |
| Medium | Weapon-family feedback depends on frame grouping | With a prior Seek primer, the same two stationary targets hit by Shockwave produce two one-kill batches and no synergy at 60 FPS, but one two-kill batch and synergy at 30 FPS. Late single hits can also erase cascade history. | Resolve qualifying family clears consistently per activation or explicitly defined clear event. Preserve immediate kill scoring; aggregate family recognition separately. |

Sources: [input response](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Input/TiltSignalProcessor.swift:81), [sensitivity limits](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Input/TiltCalibration.swift:46), [enemy speed integration](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/ArenaScene.swift:981), [timer reset](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Enemies/EnemySpawnDirector+PatternSchedule.swift:60), [shared best score](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Run/RunProfileStore.swift:57), [family state](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Weapons/WeaponComboState.swift:79), [per-frame Shockwave clear](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/ArenaScene.swift:3531).

Restoring missing enemy patterns will itself increase difficulty. Re-measure the default game after these fixes before increasing spawn rates or weakening defensive weapons.

**Movement supports precision, but input settings and burst movement need attention.**

The player has a visual radius of 12 and a lethal radius of 4.8. Pickups use the larger visual radius for collection; this is a good distinction for a game about narrow escapes and risky grabs. Ordinary movement crosses the playable horizontal width in 2.5 seconds at full input. Enemy contact uses swept collision, and weapon resolution occurs before the final lethal-collision check. Preserve these safeguards. [Movement](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Player/PlayerMovementController.swift:4), [hitbox](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Run/ClassicRunController.swift:11), [collection](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/ArenaScene.swift:1030), [collision order](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/ArenaScene.swift:871).

The tilt filter has a 3-degree dead zone and a 0.11-second smoothing constant. A step input reaches 90% response in approximately 0.253 seconds; reversing a settled full input takes approximately 0.076 seconds to cross zero. These are calculations from the filter, not measurements of end-to-end device latency. After fixing sensitivity, compare 0.08 versus 0.11 seconds of smoothing on real hardware. Check braking and reversals as well as jitter; changing the dead zone and smoothing together would obscure the cause. [Tilt filtering](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Input/TiltSignalProcessor.swift:4).

Flame Trail changes analog movement into a fixed-speed burst at 5× speed for 0.3 seconds. At a steady nonzero direction this covers 60% of the playable horizontal width before wall clipping, enough to traverse the shorter vertical dimension on some arenas. Even a small nonzero input becomes full burst speed. This may be exciting, but a pickup that unexpectedly changes steering is a significant learning burden. Trial 4× for 0.22 seconds, or retain the existing burst and improve its anticipation cue. Evaluate the landing position and deaths just after protection ends before choosing. [Burst movement](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/ArenaScene.swift:546), [Flame defaults](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Weapons/FlameTrailState.swift:4).

Player speed scales with arena width, while weapon radii, enemy radii, clearances, and much of enemy base speed use fixed points. Screen size can therefore change coverage and relative speed. Compare the smallest supported phone and a large phone using identical seeds. If the difference is material, a common logical arena is a cleaner long-term fix than independently scaling every parameter.

**Enemy roles are well differentiated; pacing needs a reliable schedule and an explicit run-length target.**

| Threat | Counterplay it asks for | Classic earliest gate | Redline earliest gate | Review suggestion |
|---|---|---:|---:|---|
| Chaser | Keep moving, gather a crowd, choose an escape route | Start | Start | Preserve an attainable speed advantage; evaluate how effectively edge circling avoids pressure. |
| Formation | Read the sweep and choose a passage | 30 s | Start | Keep the intended passage clear when another warning overlaps it. |
| Splitter | Decide whether to create more small threats or suppress the split | 50 s | 15 s | Teach which control weapons suppress children; measure the extra score opportunity. |
| Mine | Plan around persistent occupied space and contested pickups | 70 s | 30 s | Track whether mines create interesting detours or deny every useful pickup route. |
| Arrow Rush | Read a fixed path and move perpendicular to it | 95 s | Start | Faster-than-player movement is reasonable with a reliable warning and usable escape space. |
| Hunter | Change direction to defeat prediction | 120 s | 45 s | Preserve its distinction from the ordinary chaser; examine turn frequency and interception deaths. |
| Paddle Trap | Navigate a local obstacle and moving puck | 150 s | 60 s | Fix recurrence before tuning its density; assess the entire trap alongside other threats. |

These are enabling gates, not exact appearance times: telegraphs, capacity, and placement add delay. Classic teaches gradually; Redline introduces movement puzzles immediately. Both use phase anchors at 0, 30, 90, and 180 seconds, with interpolation between them. [Mode gates](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Run/ArenaModeRules.swift:125), [phase and interpolation rules](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Enemies/EnemySpawnConfiguration.swift:4).

Some warning geometry implies a more solid obstacle than collision geometry creates. In a representative 317-point-high playable arena, nine formation lanes leave about 22 points of safe player-center passage between ordinary adjacent dots, even away from the deliberately omitted lane. Paddle bars also consist of separate dots with narrow traversable gaps. Decide whether these should teach a dotted sweep or a wall with a designated opening; align the warning with that choice. Preserve generous collision margins, but make the intended route legible. Mines already try positions near pickups, which directly supports dangerous collection; they are stationary hazards, so their larger warning circle should not imply an explosion. [Formation layout](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Enemies/EnemySpawnDirector.swift:310), [paddle layout](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Enemies/EnemySpawnDirector+PaddleTrap.swift:127), [mine placement](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Enemies/EnemySpawnDirector+MineDot.swift:94).

| Mode / run time | Nominal chasers per second | Total enemy cap |
|---|---:|---:|
| Classic, 30 s | 1.52 | 82 |
| Classic, 90 s | 2.17 | 140 |
| Classic, 180 s onward | 3.33 | 210 |
| Redline, start | 1.85 | 88 |
| Redline, 30 s | 2.78 | 136 |
| Redline, 90 s | 4.00 | 192 |
| Redline, 180 s onward | 5.56 | 270 |

These are configured rates before blocked placements and caps, and exclude every other enemy role. After 180 seconds, spawn tuning stops rising; the global speed multiplier continues approaching an asymptote, and enemy age acceleration is capped. This creates an eventual pressure ceiling. Whether skilled players can sustain a stable balance between spawns and clears needs playtesting against the intended short sessions. [Classic tuning](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Enemies/EnemySpawnConfiguration.swift:291), [Redline tuning](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Run/ArenaModeRules.swift:182), [speed ramp](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Enemies/EnemySpawnConfiguration.swift:353).

Choose a provisional session target before compressing this curve. For example, if practiced Classic runs should usually last 90–180 seconds, a threat first enabled at 150 seconds will be unfamiliar to many players. An experiment could move the six introductions to 20/40/60/80/100/120 seconds while keeping their first appearances sparse. This is a design trial, not a demonstrated need to make the opening harder. For long expert runs, vary the mix and give brief recovery beats before simply raising the population cap.

The current balance tests use a stationary player and remove enemies after six seconds. They correctly check introductions and frame-rate stability, but they cannot prove survivability, route fairness, or actual late-game pressure. Extend recurrence coverage beyond 180 seconds and examine 6-, 20-, and 60-second enemy residence scenarios. [Existing simulation contract](/Users/xiliangchen/projects/tilt-arena/TiltArenaTests/EnemySpawnDirectorBalanceTests.swift:131).

**Weapon balance should compare space, control, reliability, and protection.** All ordinary enemies die from a successful damaging hit; a single damage-per-second ranking would miss what makes these weapons strong. The following values are current defaults. “Overcharged” is the highest pickup tier; all strength judgments are hypotheses pending matched encounter tests.

| Weapon | Base behavior | Overcharged behavior | Assessment / first experiment |
|---|---|---|---|
| Shockwave | Radius 90; expands over 0.6 s, holds 0.2 s | Radius 118.8 | Clear, useful baseline. Investigate deaths between collection and the expanding wave reaching an incoming enemy. |
| Seeker Swarm | 4 initial targets; radius-30 impact explosions | 8 targets; radius-36 explosions | Reliable reach with strong crowd amplification. Measure kills per impact and protection refreshed by repeated impacts. |
| Razor Shield | Radius-28 contact kills for 4 s; radius-48 expiry burst | Radius 31.36 for 5.6 s; burst 57.6 | Likely a very dependable starter. Check protection uptime and repeat pickups before shortening duration. |
| Freeze Burst | Radius 140; 0.8 s expansion; freezes for 12 s; contact shatters | Radius 184.8; freeze 16.8 s | Strongest candidate for excessive control duration. Trial 8 s base / 11.2 s overcharged after scheduling is fixed. |
| Gravity Well | Radius-160 initial target set; 0.5 s delay, 3 s pull; radius-32 core | Radius 211.2; core 38.4 | Weak or misleading as a persistent trap: later entrants are ignored. First make the active field affect entrants, then assess pull strength. |
| Chain Lightning | Initial range 140, jump range 96, up to 6 hits | Initial range still 140; jumps 126.72; up to 10 hits | Good clustered-crowd identity. Preserve its reach limitation; compare with Seeker rather than simply raising hit count. |
| Flame Trail | 5× burst for 0.3 s; radius-16 trail persists 3 s; 0.5 s protection after burst | Radius 19.2; lifetime 3.72 s; larger segment cap | Strong escape and persistent kill source, with unusually abrupt control. Test burst landing predictability. |
| Time Dilation | Radius-120 moving aura for 6 s; up to 8× slowing; close shove | Radius 144 for 8.4 s; stronger shove distance | Useful route control but no direct kills. Give credit through understandable escape feedback; do not judge it by kill count alone. |
| Power Wave | 0.6 s charge, 60° moving fan, depth 160; travels across arena | 72° fan, depth 211.2 | High skill demand because movement also aims it. Trial 0.4 s charge if post-pickup deaths are high. Direction is taken at release. |
| Ricochet Lance | Width-18 traced beam, one bounce | Width 21.6, three bounces | Strong geometry identity. Validate visible alignment and usefulness near corners before widening it. |
| Nova Bomb | Selects 50% of eligible existing enemies | Selects 100% | Largest charge payoff and strongest density scaling. Measure whether saving Nova dictates the whole route; trial 50/70/90% only if it dominates. |

Sources: [weapon defaults](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Weapons/StartingWeaponResolver.swift:4), [charge scaling](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Weapons/StartingWeaponResolver.swift:166), [Flame scaling](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Weapons/FlameTrailState.swift:40), [Power Wave travel](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Weapons/PowerWaveState.swift:58), [Nova selection](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Weapons/NovaBombTargetSelector.swift:1).

Gravity Well deserves a behavior fix before a numerical buff. Its pull only affects the IDs captured at activation, and its core also ignores later entrants. Base pull displacement is 160/3 = 53.3 points/s, applied after ordinary movement; a fleeing target can overcome it. A second well replaces the first. A visible active well should have a clear contract: either it captures entrants throughout its lifetime, or it visibly tethers only its initial victims. The former better supports a trap role. [Stored targets](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Weapons/GravityWellState.swift:4), [pull and replacement](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/ArenaScene.swift:3650).

Protection timing is uneven. Several projectile/beam effects protect during travel; Shockwave and Freeze grant generic safety on wave completion, Power Wave on completion, and Gravity Well on completion. Razor clears close enemies continuously, while Flame has explicit invulnerability. Therefore “collect an orb to escape” is dependable for some pickups and less dependable for others. First measure deaths within 0.25/0.5/1 second after collecting each weapon. If slow weapons show a large immediate-death spike, trial a short 0.15–0.25-second collection grace or an immediate local effect, and review total protection uptime so rapid pickups do not create permanent safety. [Wave safety](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/ArenaScene.swift:3531), [Power and Gravity safety](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/ArenaScene.swift:3644), [protection state](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Weapons/ArenaActiveWeaponState.swift:119).

Freeze, Gravity, and Nova suppress splitter children. Other damage produces additional small targets, which also score. This creates a legitimate choice between clean removal and extra scoring risk, but the distinction needs to be taught and evaluated when comparing weapon scores. [Splitter suppression](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/ArenaScene.swift:1396).

**Pickup charging is a strong risk/reward mechanism, but availability and progression can obscure the choice.**

Classic maintains up to three pickups, refills vacancies after 0.5 seconds, and charges them at 3 and 6 seconds. Redline uses two pickups, 0.75-second refills, and 3.8/7.2-second charge gates. Pickups persist until collected. Positions are selected from deterministic candidates with a safe-placement fallback; they avoid immediate enemy overlap and the player, but do not explicitly score the danger of the route to them. [Pickup defaults and placement](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Weapons/PickupSpawnPlanner.swift:34), [Redline pickups](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Run/ArenaModeRules.swift:283).

Keep the decision to collect now or wait. Measure three possible dominant strategies: rapid pickup cycling for points/protection, banking an overcharged Nova for a dense clear, and leaving unwanted pickups parked while cycling one remaining slot. Do not add pickup expiry or more randomization without seeing which behavior is actually harmful. If route risk is too low, prefer placing one offered pickup near a readable threatened route while keeping another obtainable escape option.

Unlocks alter the weighted cycle. Each starter occupies 4 of 12 slots for a fresh profile, but only 4 of 26 when fully unlocked: its frequency falls from 33.3% to 15.4%. The full pool can begin with Power Wave, Ricochet Lance, and Nova because its starting position is seeded. This does not prove progression makes the game harder, but it means a stronger profile is not simply the same game with more options. Guarantee a straightforward useful opening, then compare fresh, partially unlocked, and complete profiles. Consider making a newly unlocked weapon appear early in the next run so the reward is immediately understandable. [Pool and rotation](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Weapons/PickupSpawnPlanner.swift:5), [unlock filtering](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Run/ArenaProgressionRules.swift:144).

**The score currently measures sustained clearing far more than survival or weapon variety.**

Each kill awards `10 × (1 + floor(currentCombo / 10))`; the new kill is included in `currentCombo`. The multiplier has no gameplay cap, and a 1.2-second gap resets the chain. Every pickup awards 50 points. Survival starts paying at 61 seconds at `1 + sqrt(totalKills) / 10` points per second, with fractional carry. [Scoring](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Run/ClassicRunController.swift:190).

| Same number of kills | One uninterrupted chain | Every kill separated by a combo break |
|---:|---:|---:|
| 30 | 630 | 300 |
| 50 | 1,550 | 500 |
| 100 | 5,600 | 1,000 |
| 300 | 46,800 | 3,000 |

These totals exclude pickup and survival points. At 100 kills, a pickup's 50 points equal 25 seconds of survival bonus. Large clears, persistent damage that bridges pickups, and banking crowds can consequently outweigh a long sequence of careful dodges. This fits a combo arcade game if intentional. Make that goal clear, and capture the score shares before reweighting them.

My first scoring experiment would be a 1.6-second combo window against the current 1.2 seconds, measuring how often players can deliberately connect two pickups. If extreme long chains still dominate outcomes, test a gentler multiplier curve or a cap separately. If survival should be a meaningful independent route, try a small fixed survival award from run start. Do not combine these experiments initially, and revise score-based unlocks and achievements whenever the scoring scale changes.

Family synergy and cascade currently add effects, audio, and haptics only. They do not add score, alter weapon power, or extend the kill combo. Resolve the frame-dependent recognition bug first, then either present them as celebrations or test a modest fixed bonus, such as +25 for synergy and +75 for cascade, once per qualifying activation. Avoid adding automatic extra clears at this stage. [Family feedback](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/ArenaScene.swift:3757).

The design pillars mention close calls, but the reviewed runtime has no separate graze reward. This is an optional addition, below the existing-system fixes. A restrained cue, or a small once-per-enemy reward after a completed dangerous pass, could recognize precise dodging. Continuous points for remaining close to an enemy would invite farming and should not be the initial design.

**Progression has useful variety goals, but modes need distinct records and a better replay payoff.**

| Unlock | Current requirement |
|---|---|
| Freeze Burst | 50 lifetime kills |
| Gravity Well | 100 lifetime kills |
| Flame Trail | Best score 1,500 |
| Chain Lightning | 175 lifetime kills |
| Time Dilation | Combo 20 |
| Power Wave | Best score 3,000 |
| Nova Bomb | 300 lifetime kills |
| Ricochet Lance | Combo 30 |
| Redline | Best score 5,000, labeled Classic best |
| Daily | All 11 weapons unlocked |

The mixture of cumulative and skill milestones is good, and unlocks do not add permanent numerical stats. Keep that structure. The main tuning concern is that the score and combo gates depend on the same crowd-clearing behavior, while some players may finish the cumulative milestones without reaching them. Evaluate actual runs-to-unlock before lowering thresholds. [Progression rules](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Run/ArenaProgressionRules.swift:88).

Daily uses Classic tuning and a local calendar seed. Requiring every weapon ensures a common pool, but delays access to the recurring mode. A later experiment could provide a standard Daily arsenal independently of personal unlocks. First persist the actual run-start seed, show today's best and the delta from the previous attempt, and retain records per seed. Currently participation is assigned from the finish timestamp, so a run crossing midnight can be attributed to a different day from its encounter seed. [Daily seed](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Run/ArenaModeRules.swift:105), [participation persistence](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Run/RunProfileStore.swift:72).

“Play Again” returns through the same mandatory three-second hold as the first start. For short repeated failures, that is meaningful friction. Keep the deliberate first start and trial a 0.75–1-second retry countdown. Also make general achievement scope consistent: some clear-triggered achievements accept every mode, while run-finished progress is restricted to Classic. [Retry action](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/ArenaScene.swift:2610), [hold duration](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/UI/ReadyStartHoldController.swift:4), [achievement processing](/Users/xiliangchen/projects/tilt-arena/TiltArena/App/GameCenterScoreSubmissionStore.swift:208).

**Readability has a good foundation, with several states competing for a small visual area.** The inspected snapshots clearly separate the cyan craft, red threats, and colored pickup glyphs. Charge levels use external arcs while the glyph remains stable, which is appropriate for small icons. The post-run screen has a prominent restart and a collision explanation. Preserve those choices.

Validate charge-tier recognition at actual device size, particularly charged versus overcharged, without relying only on color. Make harmful, frozen, newly spawned, and protected states distinguishable in motion. The player also carries a kill-combo arc and a family-primer arc, so any added safety cue should be simple. Test crowded multi-effect footage on both themes; the existing visual snapshots are composed scenes, not proof that every combination remains legible. Preserve bounds on visual fan-out while allowing all gameplay hits to resolve. [Pickup visual states](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Weapons/WeaponPickupNode.swift:47), [player feedback arcs](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Player/PlayerCraftNode.swift:78), [bounded clear effects](/Users/xiliangchen/projects/tilt-arena/TiltArena/Game/Weapons/WeaponImpactPlan.swift:1).

**Recommended implementation and validation order:**

1. Fix sensitivity, telegraph recurrence, per-mode records, and activation-level family recognition. Add focused regression coverage for their actual failure cases.
2. Re-run encounter comparisons with the corrected schedule. Improve Gravity Well's field contract and reduce retry friction. Keep other numerical tuning stable for this pass.
3. Compare every weapon at three charge tiers against sparse pursuit, dense pursuit, crossing formations, mixed persistent hazards, and late-game pressure. Record kills, safe space created, protection duration, combo continuity, and immediate post-pickup deaths. Use matched seeds and positions.
4. Playtest fresh, partially unlocked, and complete profiles on small and large phones. Record median and upper-percentile run duration, deaths by role/time, pickup age when collected, pickup-to-death time, score sources, and time spent protected. These can be aggregated per run; raw movement traces are unnecessary.
5. Trial one change at a time: shorter retry, Gravity behavior, Freeze duration, Flame burst, Power charge, combo window, or Nova charge curve. Compare against the corrected baseline before accepting a number.

The proposed numerical values are starting points for experiments, not validated balance targets. My highest-value design direction is to strengthen readable route choices and weapon timing, preserve the one-input control model, and let score explain the play the game wants to reward.

Validation evidence: [full simulator test log](/tmp/tilt-arena-balance-review-tests.log), [control probe](/tmp/tilt-arena-balance-review/main.swift), [spawn probe](/tmp/tilt-enemy-review/main.swift), [wave/family probe](/tmp/tilt-weapons-review/main.swift). The spawn probe uses the current director/enemy code with extracted mode defaults and lightweight geometry support; the wave probe uses current wave/family code with minimal data/configuration stubs. The temporary probes isolate behavior and do not simulate player skill. Temporary files are supporting session artifacts and may be removed by the system.
