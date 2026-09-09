# Weapon glyph production prompt

Built-in `image_gen` generation; selected direction: A's shape clarity with C's
quiet center and controlled lighting. The atlas is tinted for both game themes.

```text
Use case: stylized-concept
Asset type: production transparent PNG weapon glyph atlas for the approved Tilt Arena A-plus-C game visual direction.
Primary request: ONE square raster sprite atlas, exactly four equal columns and four equal rows on a truly transparent alpha background. No visible grid. Each cell is one quarter of canvas width and height. Exactly eleven isolated weapon symbols occupying the first eleven cells in row-major order; the twelfth cell and the entire fourth row are empty transparent. Center each symbol exactly in its cell and keep ALL artwork inside the central 64% of the cell. Uniform optical weight and size.
Style: clean white luminous arcade glyphs with bold filled silhouettes, extremely subtle cool-white bevels, broad simple shapes, crisp edges. These will be color-tinted at runtime and displayed only about 18 pixels wide, so prioritize immediate shape recognition, not ornament. Pure white foreground with alpha edges; no black or gray backdrop, no checkerboard, no outer orb rims or circular badge containers, no cast shadows, no bloom outside the glyph.
Exact row-major symbol layout:
Row 1 column 1: shockwave — two bold concentric circular rings around a small solid central dot.
Row 1 column 2: seeker swarm — three solid arrowhead darts flying toward upper right, one leading and two trailing.
Row 1 column 3: razor shield — a single strong shield outline with a small solid diamond center.
Row 1 column 4: freeze burst — one bold six-arm snowflake with only one fork per arm.
Row 2 column 1: gravity well — one thick curling spiral with a clearly open center.
Row 2 column 2: chain lightning — a single bold zigzag lightning bolt with one short branch.
Row 2 column 3: flame trail — a solid teardrop flame with a small transparent inner flame cutout.
Row 2 column 4: time dilation — a bold hourglass, two triangular chambers and short horizontal caps.
Row 3 column 1: power wave — three separated broad curved crescent wavefronts facing right.
Row 3 column 2: ricochet lance — one long sharp faceted lance pointing upper right, a simple single diamond spearhead and short tail.
Row 3 column 3: nova bomb — solid bright central disc with eight short broad pointed rays.
Row 3 column 4 and row 4 all columns: blank, fully transparent.
Constraints: no text, numbers, labels, frame, title, UI, colored background, outer pickup badge or extra symbols. All eleven glyphs are white. Genuine alpha transparency. Same isolated glyph scale in all occupied cells. Flat front-facing view.
```

## Iterations

The white exports had background artifacts. The selected final asset uses black alpha silhouettes, tinted by SpriteKit. The original PNG is copied without pixel edits; texture crops use measured centers because the generated layout is not a precise grid.

### Cleanup (rejected export)

```text
Use case: precise-object-edit
Input image 1 is the edit target: the generated white weapon glyph atlas.
Clean this production sprite atlas. Keep exactly the same eleven glyph subjects, order and strong shapes. Remove EVERY speckle, dusty halo, texture, tiny stray fragment and shadow outside the eleven symbols, and remove all internal bevel lines. Each glyph must be SOLID clean white with intentional transparent cutouts and clean antialiased edges. Background must be truly transparent alpha everywhere else, including between symbols. No black background and no checkerboard.
Correct alignment to a precise invisible 4-by-4 equal cell grid on a square canvas: row-major eleven symbols in the first eleven cells, last five cells empty transparent. Glyph centers at 12.5%, 37.5%, 62.5%, 87.5% of width; row centers 12.5%, 37.5%, 62.5% of height. All glyphs fit inside the central 60% of each cell. Do not introduce enclosing badge circles or change the eleven symbols. No text. Smooth broad silhouettes, no noise.
```

### Alpha extraction (rejected export)

```text
Use case: background-extraction. Remove the checkerboard background completely from this weapon sprite sheet. Return the same eleven clean white glyphs on a genuinely transparent PNG alpha background. All gray checkerboard squares and all gray pixels between and inside glyph cutouts must become fully transparent. Preserve only the white glyph silhouettes with clean antialiased edges. Keep glyph positions, dimensions, and shapes exactly unchanged. Do not draw a checkerboard or any background color.
```

### Final silhouette atlas

```text
Use case: style-transfer.
Input image is a reference for the ELEVEN SYMBOL SHAPES AND THEIR ORDER.
Create a production game sprite atlas of those exact eleven glyphs, but make ALL GLYPHS PURE SOLID BLACK instead of white. Completely flat ink silhouettes with sharp smooth edges and transparent interior cutouts, NO white pixels, no gray shading, no glow, no shadow, no texture and no particles.
Background MUST be genuinely transparent alpha; do not paint a checkerboard. No framing or text.
Square image; invisible precise four-column four-row grid. Center each icon at the exact center of its cell, each icon fitting within the central 60% of the square cell. First row: shockwave rings, three seeker darts, shield, snowflake. Second row: gravity spiral, lightning, flame, hourglass. Third row: triple crescent waves, diagonal lance, nova sun, empty. Fourth row entirely empty. Preserve all these shapes as bold black silhouettes with intentional transparent holes. These are alpha masks for color-tinting in a game, not white stickers.
```
