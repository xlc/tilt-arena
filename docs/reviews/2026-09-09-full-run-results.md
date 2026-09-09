Tilt Arena full-run balance results — 9 September 2026

Validated 261 cases with real spawning, replenishing pickups, movement, collision, effects, SpriteKit callbacks and scoring. Runs use a fixed 718 × 377 world at 60 Hz, ending on collision or at 180 seconds. Each table row contains only three seeds. The deterministic controller knows enemy positions, uses simple repulsion and wall avoidance, and does not model human skill, timing, aim or learning. Paired scripts are correlated, not independent participants.

Reference tuning uses responsive exponent-3 waves and a 0.4-second Power charge, but retains 0.5-second post-weapon recovery. Candidates change one parameter group. Shorter safety is 0.3 seconds; immediate collection grace stays 0.2 seconds. The earlier-Classic candidate enables roles at 20/40/60/80/100/120 seconds, including warmup formations at a 10-second interval and pressure arrows at a 10-second interval, speed 150 and count 2. Minimum-time gates alone cannot activate a role absent from its phase. Clearing-score tuning combines shorter safety with 10 pickup points instead of 50; it keeps kill scoring unchanged.

**Reference pickup policies.** Immunity is the mean per-run protected fraction, excluding shield-only protection. Time is capped observed time, not an uncensored survival estimate.

| Mode / profile / policy | Mean seconds | Mean score | Immunity | Mean pickups | Mean pickup age |
|---|---:|---:|---:|---:|---:|
| classic / fresh / cycle | 130.76 | 20186 | 75.3% | 267.7 | 1.02 s |
| classic / fresh / bankNova | 130.76 | 20186 | 75.3% | 267.7 | 1.02 s |
| classic / fresh / parkTwo | 88.06 | 5677 | 44.7% | 76.3 | 1.62 s |
| classic / partial / cycle | 132.30 | 25316 | 78.5% | 309.0 | 0.84 s |
| classic / partial / bankNova | 132.30 | 25316 | 78.5% | 309.0 | 0.84 s |
| classic / partial / parkTwo | 88.25 | 6017 | 44.6% | 68.3 | 2.13 s |
| classic / complete / cycle | 116.43 | 18475 | 83.4% | 285.0 | 0.78 s |
| classic / complete / bankNova | 105.49 | 13540 | 73.1% | 204.7 | 1.09 s |
| classic / complete / parkTwo | 97.95 | 6939 | 45.8% | 76.7 | 2.51 s |
| redline / complete / cycle | 27.19 | 1803 | 45.2% | 22.7 | 1.16 s |
| redline / complete / bankNova | 27.19 | 1803 | 45.2% | 22.7 | 1.16 s |
| daily / fresh / cycle | 116.43 | 18475 | 83.4% | 285.0 | 0.78 s |
| daily / fresh / bankNova | 105.49 | 13540 | 73.1% | 204.7 | 1.09 s |
| daily / fresh / parkTwo | 97.95 | 6939 | 45.8% | 76.7 | 2.51 s |
| daily / complete / cycle | 116.43 | 18475 | 83.4% | 285.0 | 0.78 s |
| daily / complete / bankNova | 105.49 | 13540 | 73.1% | 204.7 | 1.09 s |
| daily / complete / parkTwo | 97.95 | 6939 | 45.8% | 76.7 | 2.51 s |

**Accepted safety and pickup score.** Immunity is the mean per-run protected fraction, excluding shield-only protection. Time is capped observed time, not an uncensored survival estimate.

| Mode / profile / policy | Mean seconds | Mean score | Immunity | Mean pickups | Mean pickup age |
|---|---:|---:|---:|---:|---:|
| classic / fresh / cycle | 130.76 | 9480 | 67.0% | 267.7 | 1.02 s |
| classic / fresh / bankNova | 130.76 | 9480 | 67.0% | 267.7 | 1.02 s |
| classic / fresh / parkTwo | 88.06 | 2624 | 40.0% | 76.3 | 1.62 s |
| classic / partial / cycle | 132.19 | 12956 | 71.3% | 309.0 | 0.84 s |
| classic / partial / bankNova | 132.19 | 12956 | 71.3% | 309.0 | 0.84 s |
| classic / partial / parkTwo | 88.24 | 3283 | 37.3% | 68.3 | 2.13 s |
| classic / complete / cycle | 116.43 | 7075 | 75.7% | 285.0 | 0.78 s |
| classic / complete / bankNova | 99.54 | 4973 | 65.9% | 196.0 | 1.07 s |
| classic / complete / parkTwo | 97.95 | 3873 | 38.6% | 76.7 | 2.51 s |
| redline / complete / cycle | 27.19 | 897 | 37.6% | 22.7 | 1.16 s |
| redline / complete / bankNova | 27.19 | 897 | 37.6% | 22.7 | 1.16 s |
| daily / fresh / cycle | 116.43 | 7075 | 75.7% | 285.0 | 0.78 s |
| daily / fresh / bankNova | 99.54 | 4973 | 65.9% | 196.0 | 1.07 s |
| daily / fresh / parkTwo | 97.95 | 3873 | 38.6% | 76.7 | 2.51 s |
| daily / complete / cycle | 116.43 | 7075 | 75.7% | 285.0 | 0.78 s |
| daily / complete / bankNova | 99.54 | 4973 | 65.9% | 196.0 | 1.07 s |
| daily / complete / parkTwo | 97.95 | 3873 | 38.6% | 76.7 | 2.51 s |

**Paired candidates.** Faster/slower/unchanged counts use a 0.001-second tolerance. Ranges expose regressions hidden by averages. Clearing-score tuning is paired against shorter safety; the other variants are paired against the reference.

| Mode / candidate | Pairs | Mean time change (range) | Faster / slower / unchanged deaths | Mean score change | Immunity change |
|---|---:|---:|---:|---:|---:|
| classic / shorterFreeze | 27 | -1.28 s (-62.70 to +46.38) | 5 / 3 / 19 | -1230 | -0.3 pp |
| classic / shorterFlame | 27 | -3.52 s (-78.70 to +56.25) | 9 / 9 / 9 | -697 | -1.2 pp |
| classic / widerCombo | 27 | +0.00 s (+0.00 to +0.00) | 0 / 0 / 27 | +3237 | +0.0 pp |
| classic / earlierClassic | 27 | -18.32 s (-78.18 to +49.67) | 20 / 6 / 1 | -3211 | +0.7 pp |
| classic / shorterSafety | 27 | -0.69 s (-17.83 to +0.00) | 6 / 0 / 21 | -81 | -7.3 pp |
| classic / clearingScore | 27 | +0.00 s (+0.00 to +0.00) | 0 / 0 / 27 | -8247 | +0.0 pp |
| redline / shorterSafety | 6 | +0.00 s (+0.00 to +0.00) | 0 / 0 / 6 | +0 | -7.6 pp |
| redline / clearingScore | 6 | +0.00 s (+0.00 to +0.00) | 0 / 0 / 6 | -907 | +0.0 pp |
| daily / shorterSafety | 18 | -1.98 s (-17.83 to +0.00) | 2 / 0 / 16 | -242 | -7.4 pp |
| daily / clearingScore | 18 | +0.00 s (+0.00 to +0.00) | 0 / 0 / 18 | -7436 | +0.0 pp |

**Policy adherence and score composition under accepted tuning.** Banking can collect a Nova accidentally before it matures, and avoidance can cross a parked pickup. These counts prevent interpreting the scripts as perfect execution. +25 per synergy and +75 per cascade are shadow calculations only; no family points were awarded and no strategy adapted to them.

| Mode / profile / policy | Nova base / charged / overcharged | Parked orbs collected | Kill / pickup / survival score | Shadow family addition |
|---|---:|---:|---:|---:|
| classic / fresh / cycle | 0 / 0 / 0 | 0 | 69.9% / 28.2% / 1.8% | +11.0% |
| classic / fresh / bankNova | 0 / 0 / 0 | 0 | 69.9% / 28.2% / 1.8% | +11.0% |
| classic / fresh / parkTwo | 0 / 0 / 0 | 14 | 68.6% / 29.1% / 2.3% | +25.4% |
| classic / partial / cycle | 0 / 0 / 0 | 0 | 74.8% / 23.8% / 1.4% | +16.9% |
| classic / partial / bankNova | 0 / 0 / 0 | 0 | 74.8% / 23.8% / 1.4% | +16.9% |
| classic / partial / parkTwo | 0 / 0 / 0 | 13 | 77.4% / 20.8% / 1.8% | +32.2% |
| classic / complete / cycle | 33 / 0 / 0 | 0 | 57.9% / 40.3% / 1.9% | +22.3% |
| classic / complete / bankNova | 2 / 2 / 17 | 0 | 58.8% / 39.4% / 1.8% | +24.1% |
| classic / complete / parkTwo | 6 / 0 / 1 | 21 | 77.4% / 19.8% / 2.8% | +30.6% |
| redline / complete / cycle | 0 / 0 / 0 | 0 | 74.7% / 25.3% / 0.0% | +35.3% |
| redline / complete / bankNova | 0 / 0 / 0 | 0 | 74.7% / 25.3% / 0.0% | +35.3% |
| daily / fresh / cycle | 33 / 0 / 0 | 0 | 57.9% / 40.3% / 1.9% | +22.3% |
| daily / fresh / bankNova | 2 / 2 / 17 | 0 | 58.8% / 39.4% / 1.8% | +24.1% |
| daily / fresh / parkTwo | 6 / 0 / 1 | 21 | 77.4% / 19.8% / 2.8% | +30.6% |
| daily / complete / cycle | 33 / 0 / 0 | 0 | 57.9% / 40.3% / 1.9% | +22.3% |
| daily / complete / bankNova | 2 / 2 / 17 | 0 | 58.8% / 39.4% / 1.8% | +24.1% |
| daily / complete / parkTwo | 6 / 0 / 1 | 21 | 77.4% / 19.8% / 2.8% | +30.6% |

**Threat exposure with accepted tuning.** Counts are spawned bodies, so one paddle trap contributes several bodies. Gate times measure checked admission gates being closed; they are not missed-spawn counts.

| Mode / profile | Collision endings / cases | Death roles | Hunter / paddle bodies | Mean population / warning gate seconds |
|---|---:|---|---:|---:|
| classic / fresh | 9 / 9 | chaser: 6, formation: 1, hunter: 2 | 10 / 18 | 0.00 / 2.14 |
| classic / partial | 9 / 9 | chaser: 8, formation: 1 | 12 / 36 | 0.00 / 2.29 |
| classic / complete | 9 / 9 | chaser: 8, formation: 1 | 5 / 0 | 0.00 / 1.54 |
| redline / complete | 6 / 6 | chaser: 2, formation: 4 | 0 / 0 | 0.00 / 0.00 |
| daily / fresh | 9 / 9 | chaser: 8, formation: 1 | 5 / 0 | 0.00 / 1.54 |
| daily / complete | 9 / 9 | chaser: 8, formation: 1 | 5 / 0 | 0.00 / 1.54 |

**Score-gate check.** These are completed fresh-profile Classic runs, not human unlock times. They confirm the unchanged thresholds are attainable by this controller on the new scale. Progress is normally applied after a run, so the harness holds its supplied arsenal fixed until that run ends.

| Policy | Cases reaching 1,500 / 3,000 / 5,000 points | Score range |
|---|---:|---:|
| cycle | 3 / 3 / 3 of 3 | 5336–15053 |
| bankNova | 3 / 3 / 3 of 3 | 5336–15053 |
| parkTwo | 2 / 1 / 0 of 3 | 1360–3768 |

Daily fresh and complete profiles matched on every measured outcome. Widening the combo window changed score/combo only, and lowering pickup points changed score/pickup points only; all other measured outcomes matched their paired configuration. No result here establishes runs-to-unlock for a person, physical tilt comfort, visual readability, or fairness for every strategy. See the accompanying decision record for accepted defaults and retained rules.
