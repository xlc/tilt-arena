# Effect motion pass — 2026-09-09

Builds on the approved geometric visual direction, using SpriteKit paths and
the existing generated glyphs.

- Shockwaves have a narrow contrasting crest. Short radial accents now travel
  with the expanding front instead of appearing at the final radius immediately.
- Freeze bursts have six faceted ice fragments and retain a visible front until
  expansion completes, followed by a short fade.
- Lightning uses a sharper zigzag, a thin contrasting core and the same weapon
  color as its pickup. Repeated lightning glyphs at every impact were removed.
- Impact sparks move outward with a quick start and slower finish; broken arcs
  replace an extra full circle. The combined paths retain the existing impact
  budget.
- Charged activations use compact symbols and batched rays below the player,
  keeping the craft visible during overlapping effects.

Attack ranges, hit timing, damage, target selection and scoring are unchanged.

| Effect | Previous nodes | Current nodes |
| --- | ---: | ---: |
| Shockwave | 11 | 5 |
| Freeze burst | 9 | 4 |
| Overcharged activation | 15 | 5 |

Counts include effect children and exclude the shared effect container. The
sixteen-target cap for impact visuals remains unchanged.

## Playback previews

These GIFs capture actual SpriteKit action playback on the iPhone 16 Pro
simulator. Capture intervals are recorded in the GIF timing. The fixture stages
several effects together for comparison; it is not a live gameplay run or a
frame-rate benchmark.

![Dark effect playback](dark-playback.gif)

![White effect playback](white-playback.gif)

## Validation coverage

- The playback test exercises both themes and checks that transient effect nodes
  are removed after playback. Its scenes use isolated preferences and tuning,
  with audio and haptics disabled.
- GIF capture is optional: set `TILT_RECORD_EFFECT_PREVIEWS=1` in the test
  process environment to attach both previews to the test result bundle.
  Ordinary runs exercise the same actions without image readback or encoding.
- The charged-activation test enforces the five-node budget.
- Eight reviewed snapshot baselines cover both themes' effect sheets, crowded
  scenes, active gameplay and run-over screens.

Final validation: simulator build succeeded; **536 tests passed with zero
failures**, snapshot recording disabled. SwiftLint and `git diff --check` passed.
Result bundle: `/tmp/tilt-effects-review-20260909.xcresult`.
The optional GIF recording run also passed:
`/tmp/tilt-effects-review-preview-20260909.xcresult`.
