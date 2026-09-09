Tilt Arena matched weapon results — 9 September 2026

Validated 864 cases: 8 fixed encounters, 3 movement scripts, two seeds, 3 weapons at three tiers and three targeted candidates. Each case runs at 60 Hz until collision or an 18-second cutoff. These are scripted comparisons, not player survival estimates.

| Weapon / all tiers | Cases | Mean kills | Mean observed seconds (capped at 18) | Collision endings | Mean open-ray fraction |
|---|---:|---:|---:|---:|---:|
| shockwave | 144 | 8.54 | 4.15 | 116 | 0.615 |
| freezeBurst | 144 | 1.90 | 8.48 | 85 | 0.617 |
| powerWave | 144 | 0.82 | 3.22 | 123 | 0.571 |

Candidate differences are paired against the same encounter, route, seed, weapon and tier. Positive observed-time changes mean the script lasted longer within the cutoff.

| Candidate | Pairs | Mean kill change | Mean observed-time change | More / fewer collision endings | Mean early displacement change |
|---|---:|---:|---:|---:|---:|
| responsiveShockwave | 144 | +8.70 | +2.95 s | 0 / 22 | +19.94 points |
| responsiveFreeze | 144 | +2.58 | +7.80 s | 0 / 44 | +21.99 points |
| quickPower | 144 | +1.79 | +1.26 s | 0 / 9 | +0.51 points |

Tier detail uses baseline tuning. Each tier contains 48 cases.

| Weapon | Mean kills base / charged / overcharged | Mean observed seconds base / charged / overcharged |
|---|---|---|
| shockwave | 6.69 / 8.79 / 10.15 | 3.30 / 3.77 / 5.39 |
| freezeBurst | 1.67 / 1.98 / 2.04 | 6.88 / 9.19 / 9.35 |
| powerWave | 0.77 / 0.79 / 0.90 | 3.21 / 3.22 / 3.22 |

Open-ray fraction samples eight 80-point straight paths from the player against currently harmful enemy bodies and arena bounds. It ignores enemy future movement and immunity, and is averaged only over observed frames. It measures local geometric obstruction, not guaranteed safe space. Early displacement is the maximum distance from the starting point in the first half-second.

Initial enemy populations are fixed; ordinary spawning and pickup replenishment are disabled. Production movement, collision, splitting, status effects, culling and SpriteKit callbacks remain active. Mixed and late-pressure fixtures are stress populations, not samples from a natural three-minute run. The scripts cannot adapt to a shorter charge or a different landing point. Surviving cases are censored at 18 seconds; aggregate values are not a weapon ranking or statistical evidence about people. Local tuning decisions need a recorded role-specific rationale; physical-phone acceptance remains outstanding.
