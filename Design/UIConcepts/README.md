# Tilt Arena UI concept set

These references were generated with OpenAI's built-in image generation in
generate-with-reference mode. The input references were the current dark and
light snapshot-test baselines, grouped into menu and run-state contact sheets.
The generated images informed the implementation; they are not shipped as
full-screen raster UI.

## Shared prompt direction

> Create a production-ready 2:1 landscape mobile-game UI concept for Tilt
> Arena. Preserve every existing control and its gameplay meaning from the
> supplied snapshot. Use shippable SpriteKit-style construction: simple
> geometric glyphs, crisp vector-like panels, strong spacing, and readable
> hierarchy at 560 x 280. Establish a tactical neon visual system with a
> near-black navy field, cool cyan player/action accents, white primary text,
> red danger, and amber objectives. Make the primary action unmistakable,
> isolate destructive actions, and keep gameplay readable under pressure. Do
> not add monetization, logos, watermarks, decorative copy, or controls absent
> from the reference.

The home concept established the visual language. Each following generation
used `home.png` as its style reference together with the matching current
screen snapshot as the functional reference.

## Screen briefs

- `home.png`: stronger title/stat hierarchy and a dominant PLAY action.
- `mode-select.png`: scannable mode rows, availability state, and mission brief.
- `awards.png`: completed-versus-active objective status and readable progress.
- `weapon-codex.png`: distinct weapon silhouettes and role colors.
- `options.png`: grouped controls, feedback, display/data, and isolated reset.
- `calibration.png`: live tilt radar, neutral target, presets, and clear bounds.
- `developer-tuning.png`: compact expert controls with stronger grouping.
- `pre-run.png`: clear hold-to-launch instruction without obscuring the craft.
- `gameplay.png`: the compact-HUD direction; the shipped gameplay treatment
  keeps unboxed score, survival time, and best at identical top-margin anchors
  from pre-run through active play, while using player-centered arcs for combo
  timing.
- `pause.png`: dominant resume path with secondary utilities and isolated exit.
- `post-run.png`: score-first result hierarchy and immediate replay.
