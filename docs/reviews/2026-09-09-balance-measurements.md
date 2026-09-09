Tilt Arena balance measurements — 9 September 2026

The game now accumulates balance evidence during an active run and emits it once at completion through AppDiagnostics/SwiftLog. No gameplay values changed in this slice. The next step is the matched encounter matrix and candidate comparisons.

Each completed run emits `run.balance`, `run.balance_exposure`, `run.balance_spawns`, and at most eleven `run.balance_weapon` events. `run_id` joins them to `run.started` and `run.finished`; it is a fresh ephemeral UUID. Each event stays below the existing 24-field limit. No position history, input samples, device identifiers, per-frame writes, or growing activation ledger are added. Existing log rotation and failure isolation apply.

| Event | Interpretation |
|---|---|
| `run.balance` | Captured mode/seed/rules, default versus experimental tuning, logical arena dimensions, starting arsenal size, final score and actual kill/pickup/survival awards, kills, maximum combo, duration, end reason and last-pickup association. |
| `run.balance_exposure` | Union of collision immunity; shield duration separately; time with at least one frozen enemy; active Gravity pull time excluding its delay; Time Dilation aura duration. Control presence measures availability, not enemies controlled or space made safe. |
| `run.balance_spawns` | Actual spawned bodies by behavior, including splitter children and separate paddle bars/pucks; peak active and active-plus-pending population; exposure to closed total-population, role-population, and warning gates. Missing role counters mean zero. |
| `run.balance_weapon` | Pickups and attributed kills for each of three tiers; sum of pickup ages; maximum activation kills; activation histogram with buckets 0, 1, 2–4, 5–9, and 10+. An unfinished effect contributes its kills so far when the run ends. |

Score categories count awarded points, including the final partial increment before integer saturation, so their sum equals the run score. Family events currently award no points. Delayed effect kills update the owning pickup's histogram; replacing an effect does not remove its recorded pickup. Old-run activations cannot enter a new run's measurements.

Exposure integrates timer state at the beginning of each active gameplay step and clips to the elapsed step. Pickups and expiry grants introduced during that step contribute starting with the next step. This is a simulation-step convention with up to a step of boundary quantization, not a wall-clock stopwatch or collision-opportunity estimate. Pause and post-run time contribute nothing. Shield clearing is separate from unconditional collision immunity. Freeze presence does not multiply duration by the number of frozen enemies.

Capacity gate time counts a step once when an enabled spawner checks a closed admission gate. The three categories may overlap and are not additive. A multi-body pattern can encounter a closed population gate before the overall population is full. A closed gate can defer a cooldown check; this metric must not be read as missed-spawn count, time at population saturation, or proof that a due pattern was starved. Pending warning and pattern budgets share the warning category. The previous director CSV measures population saturation and is a different metric.

`since_pickup_s` uses active run time and is -1 when no pickup was collected. `death_role` is `none` for a manually ended run. Death-time bands are [0,30), [30,60), [60,120), [120,180), and 180+ seconds. With overlapping effects, last-pickup timing is association only. Compare collision-ended and manually ended runs separately.

Extract summaries from the existing simulator log command:

```sh
scripts/tilt-logs cat | jq -c 'select(.message | startswith("run.balance"))'
```

Comparisons must match mode, seed, profile, arena and tuning. Experimental currently distinguishes overrides from defaults; retain the exact tuning configuration alongside each experiment's results. The deterministic harness must record named candidates and use isolated profiles and a no-op Game Center reporter.

Validation covers actual score saturation, survival overflow, delayed activation histograms, old-run rejection, protection overlap, control duration, independent population/warning gates, metadata sanitization limits, and scene-level pickup kills, pause, completion and restart. Diagnostics failure behavior remains covered by the existing log-store regression suite.

The matched harness is now implemented in `ArenaBalanceEncounterTests`. It drives the production scene and SpriteKit actions with `SKRenderer.update(atTime:)` using a monotonic system-time origin. A zero-based time origin failed the probe and was discarded. It does not draw frames or replace projectile callbacks with synchronous target deletion. Every case gets isolated preferences and a no-op Game Center client.

The first matrix exposed duplicate IDs when fixture enemies and later splitter children overlapped. Fixture seeding now advances the director's ID allocator past the entire injected population; a regression preserves unrelated enemies and both children. Only the corrected export is checked in. The final run executed 604 tests, with the separate long director sweep skipped, zero failures, and no enemy-ID invariant events. SwiftLint and diff whitespace checks passed.

Reproduce the 1,032 cases:

```sh
TEST_RUNNER_TILT_WEAPON_SWEEP=1 xcodebuild \
  -project TiltArena.xcodeproj -scheme TiltArena -configuration Debug \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,id=AA706A81-B950-477D-8FAB-B8836EBD57E0,arch=arm64' \
  -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO \
  -only-testing:TiltArenaTests/ArenaBalanceEncounterTests test
```

Export the `weapon-encounters.json` attachment from `ArenaBalanceEncounterTests/testExportMatchedWeaponComparisons()` with `xcresulttool export attachments --test-id`, then run:

```sh
scripts/summarize-weapon-balance docs/reviews/2026-09-09-weapon-encounters.json
```

The summarizer rejects missing or duplicate cases, nonfinite metrics, mismatched conditions and invalid exposure bounds. [Raw results](2026-09-09-weapon-encounters.json) and [generated comparison tables](2026-09-09-weapon-results.md) include no-pickup controls and explicit methodological limits.

Initial numerical decisions: reject the shorter Freeze proposal for now (five additional collision endings, no removed collision endings, and lower capped observed survival). Retain Flame pending landing-control playtests: the shorter burst changes displacement but barely changes capped survival across these scripts. Investigate Power's 0.4-second charge in an aimed encounter: nine collision endings disappear in the candidate set, but baseline Power records no kills in these two aggressive movement scripts. That warrants a targeted aiming test before accepting a default. Retain the other values pending their role-specific comparisons; these results are not a full-run pickup-strategy or human progression study.
