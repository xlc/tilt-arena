# Tilt Arena visual review and concepts

Review date: 2026-09-08. The initial working tree was clean.

## Review basis

Inspected the repository's dark and white gameplay snapshots, dark home screen,
visual-role contact sheet, effect contact sheet, weapon sprite sheet, loading art,
and the current theme, player, pickup and enemy renderers. Gameplay snapshots
are 560 × 280 landscape fixtures. This is a static visual review; no fresh
simulator capture, motion evaluation or performance test was performed.

## Findings

1. **Keep the core visual identity.** The notched arrow is easy to find; red
   threats and amber/cyan/violet weapons establish useful visual roles. Preserve
   those silhouettes and families across both themes.
2. **Quiet the arena background.** Grid lines, radar rings and boundary marks
   compete with trails, warning lanes and radial attacks in the saved gameplay
   frames. Use lower contrast, fewer intersecting marks and a calmer center.
   The renderer replaces grid alpha with 0.48 for radar rings, 0.62 for radar
   ticks and 0.7 for white precision lines, so the decorative layers deserve
   separate tuning.
3. **Simplify the pickup hierarchy.** Detailed raster symbols sit inside a
   badge, ring and halo; charging adds rings and ticks. At the contact sheet's
   12-point pickup radius, extra thin contours compete with the identifying
   symbol. Explore one bold glyph and one primary rim, with a distinct,
   economical charge indicator. Preserve the current charge states.
4. **Unify the art finish.** The luminous illustrated weapon sheet, geometric
   actors and technical UI feel like different styles. The loading art is also
   much more dramatic and uses a three-point craft unlike the gameplay arrow.
   Choose a shared shape, edge and material treatment before producing assets.
5. **Reserve the brightest marks for decisions.** The effect contact sheet
   contains large opaque weapon emblems and overlapping radial effects. Explore
   open shock fronts and short trails that leave the player and enemies visible.
   Keep danger lanes visually different from harmless trails.

## Concepts

Each board contains a landscape gameplay proposal and enlarged actor/pickup
specimens. HUD numbers are illustrative. Boards explore appearance, not final
collision sizes, timing or tested interaction.

| Direction | Intent | Main tradeoff |
| --- | --- | --- |
| [A — Dark Radar](a-dark-radar.png) | Restrained luminous geometry, a quieter radar field and bold symbols | Closest to the current game; less spectacle |
| [B — White Precision](b-white-precision.png) | Crisp charcoal/cyan craft, red threats and outlined weapon symbols on off-white | Clear light-theme identity; effects need dark edges rather than white glow |
| [C — Neon Surge](c-neon-surge.png) | More material depth, tightly controlled bloom and stronger motion | Greater energy; effect overlap needs the most care |

Generation uses the built-in `image_gen` tool, one call per direction. Exact
prompts are saved in [prompts.md](prompts.md). The initial concept pass left game
code and shipped resources unchanged. See [implementation.md](implementation.md)
for the approved gameplay pass and its validation.

All three generated boards were visually inspected. A offers the simplest
dark-theme shapes, B makes the light theme feel deliberate, and C has the
quietest arena center and most energetic clear effect. My suggested starting
point is A's shape clarity with C's calmer center and selected motion accents.
Reduce C's enemy bloom before using it in crowded gameplay.

The generator varies enemy counts and relative sizes between boards. Enlarged
specimens are illustrative; none of these boards proves actual-size readability.
The first production pass should retain the game's existing dimensions and
compare all enemy roles and weapon icons at that size. B's specimen shadows are
presentation styling, not a proposal to add floating shadows to gameplay.

## Approved direction — 2026-09-09

- A's clear shapes with C's quieter center and controlled effects.
- Retain both existing dark and white themes.
- Focus on gameplay. Shared arena backgrounds and weapon codex icons inherit
  the new styling; menu layouts and loading art are unchanged.

## Production constraints after selection

- Judge actors and all eleven weapon symbols at actual in-game size on both
  backgrounds, including charged and overcharged pickups.
- Validate crowded frames with simultaneous threats, warning lanes and effects.
- Use generated raster art for selected sprite/effect assets where it improves
  the result; retain code-native geometry for simple shapes and scalable UI.
- Preserve the existing bounded effect fan-out. The current implementation
  samples at most sixteen visual targets per impact plan while resolving all
  logical hits.
- Keep replacements versioned until approved. Update relevant snapshot evidence
  and review motion on the simulator before calling a direction implemented.

## Source pointers

- [Dark gameplay baseline](../../../TiltArenaTests/__Snapshots__/ArenaScreenSnapshotTests/testDarkActiveGameplayScreen.1.png)
- [White gameplay baseline](../../../TiltArenaTests/__Snapshots__/ArenaScreenSnapshotTests/testWhiteActiveGameplayScreen.1.png)
- [Actor and pickup baseline](../../../TiltArenaTests/__Snapshots__/ArenaVisualRoleSnapshotTests/testDarkVisualRolesContactSheet.1.png)
- [Effect baseline](../../../TiltArenaTests/__Snapshots__/ArenaEffectSnapshotTests/testDarkEffectMotionContactSheet.1.png)
- [Theme renderer](../../../TiltArena/Game/Theme/ArenaThemeRenderer.swift)
- [Pickup renderer](../../../TiltArena/Game/Weapons/WeaponPickupNode.swift)
- [Impact budget](../../../TiltArena/Game/Weapons/WeaponImpactPlan.swift)
