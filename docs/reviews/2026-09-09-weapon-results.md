Tilt Arena matched weapon results — 9 September 2026

Validated 1,032 cases: 6 fixed encounters, 2 movement scripts, two seeds, 11 weapons at three tiers and three targeted candidates. The initial matrix includes 24 no-pickup controls. Each case runs at 60 Hz until collision or an 18-second cutoff. These are scripted comparisons, not player survival estimates.

| Weapon / all tiers | Cases | Mean kills | Mean observed seconds (capped at 18) | Collision endings | Mean open-ray fraction |
|---|---:|---:|---:|---:|---:|
| none | 24 | 0.00 | 1.98 | 22 | 0.552 |
| shockwave | 72 | 3.12 | 2.73 | 63 | 0.517 |
| seekerSwarm | 72 | 13.56 | 10.45 | 39 | 0.618 |
| razorShield | 72 | 20.58 | 13.52 | 34 | 0.727 |
| freezeBurst | 72 | 0.71 | 3.89 | 61 | 0.530 |
| gravityWell | 72 | 2.33 | 2.72 | 63 | 0.534 |
| chainLightning | 72 | 5.50 | 7.23 | 53 | 0.622 |
| flameTrail | 72 | 16.28 | 9.89 | 39 | 0.487 |
| warpDash | 72 | 0.00 | 2.83 | 63 | 0.537 |
| powerWave | 72 | 0.00 | 2.00 | 66 | 0.506 |
| ricochetLance | 72 | 4.81 | 8.85 | 48 | 0.602 |
| novaBomb | 72 | 24.28 | 12.77 | 27 | 0.689 |

Candidate differences are paired against the same encounter, route, seed, weapon and tier. Positive observed-time changes mean the script lasted longer within the cutoff.

| Candidate | Pairs | Mean kill change | Mean observed-time change | More / fewer collision endings | Mean early displacement change |
|---|---:|---:|---:|---:|---:|
| shortFreeze | 72 | -0.06 | -0.52 s | 5 / 0 | +0.00 points |
| shortFlame | 72 | +0.82 | +0.01 s | 0 / 0 | -32.69 points |
| quickPower | 72 | +0.69 | +2.49 s | 0 / 9 | +1.02 points |

Tier detail uses baseline tuning. Each tier contains 24 cases.

| Weapon | Mean kills base / charged / overcharged | Mean observed seconds base / charged / overcharged |
|---|---|---|
| shockwave | 1.29 / 3.29 / 4.79 | 2.00 / 2.19 / 4.01 |
| seekerSwarm | 10.50 / 13.50 / 16.67 | 9.32 / 10.41 / 11.61 |
| razorShield | 19.50 / 19.92 / 22.33 | 12.10 / 12.16 / 16.29 |
| freezeBurst | 0.50 / 0.67 / 0.96 | 3.70 / 3.96 / 4.01 |
| gravityWell | 1.88 / 2.38 / 2.75 | 2.07 / 2.07 / 4.01 |
| chainLightning | 4.17 / 5.50 / 6.83 | 7.14 / 7.15 / 7.39 |
| flameTrail | 15.33 / 16.62 / 16.88 | 9.89 / 9.89 / 9.89 |
| warpDash | 0.00 / 0.00 / 0.00 | 2.83 / 2.83 / 2.83 |
| powerWave | 0.00 / 0.00 / 0.00 | 2.00 / 2.00 / 2.00 |
| ricochetLance | 4.42 / 4.92 / 5.08 | 8.82 / 8.86 / 8.88 |
| novaBomb | 16.17 / 24.33 / 32.33 | 9.23 / 11.08 / 18.00 |

Open-ray fraction samples eight 80-point straight paths from the player against currently harmful enemy bodies and arena bounds. It ignores enemy future movement and immunity, and is averaged only over observed frames. It measures local geometric obstruction, not guaranteed safe space. Early displacement is the maximum distance from the starting point in the first half-second.

Initial enemy populations are fixed; ordinary spawning and pickup replenishment are disabled. Production movement, collision, splitting, status effects, culling and SpriteKit callbacks remain active. Mixed and late-pressure fixtures are stress populations, not samples from a natural three-minute run. The scripts cannot adapt to a shorter charge or a different landing point. Surviving cases are censored at 18 seconds; aggregate values are not a weapon ranking or statistical evidence about people. Local tuning decisions need a recorded role-specific rationale; physical-phone acceptance remains outstanding.
