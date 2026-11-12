# DoodleDrift visual verification

The visual upgrade uses original procedural Godot drawing and editable SVGs. The
brand is **DoodleDrift**, with the exact subtitle **A little adventure by Daywrite**.
The boot PNG was rendered by Godot using the bundled OFL Fredoka and Nunito fonts;
it does not depend on SVG text support or fonts installed on the player's device.

## Shared palette and visual treatment

| Role | Color |
|---|---|
| Mint | `#A8DFC8` |
| Lavender | `#C5AFF1` |
| Peach / companion body | `#FFCAA6` |
| Sky / Ice ink | `#B7DFFF` |
| Rose / Fragile ink | `#F5B3C5` |
| Cream paper | `#FFF9F0` |
| Slate text and facial details | `#344054` |
| Neutral Solid ink | `#AFC3CB` |

The five existing biomes retain their identities through quiet color shifts:
mint meadow, pale-blue snowy peaks, peach sandstone, lavender crystals, and rosy
volcanoes with muted-plum foregrounds. Backgrounds use a gradient sky, soft cloud
puffs, three restrained paper-cut hill layers and a small deterministic ambient
particle set. Existing play surfaces receive subtle gradients, outlines and
actual-edge highlights; crates and ferries use cream/pastel surfaces and readable
dark details. Root-owned goal and hazard drawing adds a dark goal chevron/outline
and distinct coral lava.

The rolling companion is a warm peach sphere with a gentle highlight, cheek tint,
upright face and rotating freckle. Its visual child supports idle blinking,
jump surprise, spring delight, impact squint and a happy victory expression.
Victory reads the session's presentation metadata. Existing squash/stretch stays
on the visual child. Face-off and reduced-motion preferences remain respected;
reduced motion also freezes decorative cloud drift, particles and parallax.

Inks use rounded cores and restrained gloss. Color is supplemented by parallel
marks for Solid, a spring zigzag for Bounce, directional chevrons for Boost,
crosses for Ice, and diagonal dashes/cracks for Fragile. The rendered core width
still matches the configured capsule width; any surrounding shadow/glow is only
decoration. Anchored stroke pins remain visible.

The app icon and adaptive launcher layers show the peach companion on a colorful
drawn path. Adaptive foreground art stays in the central safe region and the
monochrome layer preserves a readable silhouette. Actual Android launcher masks
and themed-icon appearance still require device inspection.

## Scope preservation

This visual work changes background drawing, the ball's visual child, `_draw` /
`_style` presentation methods for terrain, moving platforms, puzzle crates and ink
strokes, palette/color data, and branded artwork. It does not change terrain
vertices, build regions, allowed inks, collisions, rigid-body settings, forces,
timers, friction, costs, mass, anchoring, progression or any campaign solution.
The authoring script's biome palette definitions were updated to agree with the
checked-in biome JSON; the campaign generator was not run as part of this rebrand.

## Measured native rendering follow-up

The original full-scene sample did not meet the 60 FPS target. A separate native
layer-isolation run confirmed that the game stayed **playing** and the window
stayed **focused** for all 120 samples in every phase. Repeated full-background /
world primitive submission was a measurable cost; hiding the UI alone did not
resolve it. This was investigated before changing presentation code.

Two bounded caches now preserve the same artwork and decoration positions:

- Each cloud's existing eight translucent puffs are rasterized once into a small
  texture, then moved at the same positions/rates as before using one quad.
- Ground flowers retain the existing positions, colors, dimensions and spacing,
  while two MultiMesh sprite batches replace individual stem/petal commands.
  Their textures are generated once per world; terrain and physics remain intact.

No animation rate, particle count, camera behavior, physics setting, terrain
vertex, level rule or gameplay feature was reduced. Native captures were rerun
after the cache change and inspected, including the QuadMesh vertical-UV
correction that keeps flower heads above their stems. Unsupported custom SVG
exports retain the direct-vector fallback.

The before/after comparison used the same Level 50 idle scenario, 1280 × 720,
Compatibility/OpenGL 3.3, active audio, and `--max-fps 60`, with coordinated idle
browser/build/test processes. Each recorded full-scene phase had 80 warmup frames
and 120 measured frames. The repeated full-scene phases are compared below:

| Native Windows measurement | Before | After |
|---|---:|---:|
| Frame interval median | 48.897 ms | **40.894 ms** |
| Frame interval 95th percentile | 57.897 ms | **45.449 ms** |
| Draw calls | 396 | **274** |
| Rendered primitives | approximately 23,909 | **16,517** |
| World `_draw` CPU median | 1.633 ms | **0.441 ms** |

This is about a **16% reduction in median frame interval**, **21% at the 95th
percentile**, and **31% fewer draw calls** in the recorded workload. It is a
bounded improvement, **not stable 60 FPS**: the measured full scene remains near
24 FPS on this host. Frame intervals include OS scheduling and presentation;
the short periodic engine-monitor samples are not a GPU timing trace. The result
does not establish Android performance, moving-camera or maximum-drawing budgets.

The concise paired evidence is
[`results/doodledrift-render-before-after.json`](results/doodledrift-render-before-after.json).
The full layer-isolation / optimized records and logs are also retained under
`docs/results/`. Reproduce using `tests/render_diagnostic.gd`; add
`-- --full-only --label=optimized` for the two full-scene comparison phases.

## Observed native rendering

Verified with **Godot 4.7.2 stable**, Windows, Intel Graphics and the OpenGL 3.3
Compatibility renderer on 12 November 2026. The following are actual native Godot
viewport/asset renders, not externally composited mockups:

| Capture under `docs/screenshots/` | Dimensions | Inspection |
|---|---:|---|
| `doodledrift-splash.png` | 960 × 540 | Correct Fredoka 600 title, Nunito 600 exact subtitle, peach character and five-color path |
| `doodledrift-icon.png` | 512 × 512 | Actual SVG rasterization, face/path readable and centered |
| `doodledrift-companion-expressions.png` | 1280 × 440 | Five production visual-child poses: idle, jump, Bounce, impact and victory; a labeled asset study rather than a gameplay screenshot |
| `doodledrift-world-1.png` | 1280 × 720 | Mint meadow, peach ball, actual moving-island stage, dark goal and coral hazard |
| `doodledrift-world-2.png` | 1280 × 720 | Soft snowy mountains, blue foreground and clear surface boundary |
| `doodledrift-world-3.png` | 1280 × 720 | Sandstone palette, actual ferry, readable controls and gap |
| `doodledrift-world-4.png` | 1280 × 720 | Lavender crystal scenery and distinct foreground |
| `doodledrift-world-5.png` | 1280 × 720 | Rosy volcano scenery, muted-plum ground and contrasting coral lava |
| `doodledrift-five-inks.png` | 1280 × 720 | All five real production strokes and patterns in the existing legal two-parcel chute, while Draw Mode is paused |

These images were inspected for clipping, foreground/background separation, the
small companion's readability, ink differentiation and distracting contrast.
The five-ink capture uses the existing level 7 build region and allowed ink
supplies; no game rule was relaxed for the capture. The interface agent separately
verifies menus, typography, interaction and alternate aspect ratios.

The successful render markers are `DOODLEDRIFT_SPLASH_PASS`,
`DOODLEDRIFT_COMPANION_PASS` and `DOODLEDRIFT_WORLD_VISUAL_PASS`. All three final
graphical runs exited with code 0 and no resource-shutdown or script/drawing
errors. The Windows certificate-store startup warning is retained in the logs.
Earlier active-audio shutdown warnings were traced to looping WAV playback,
resolved through the audio manager's shutdown API, and retested in these same
native helpers. Final evidence is retained under `docs/results/` as
`doodledrift-splash-render.log`, `doodledrift-companion-visual.log` and
`doodledrift-world-visual.log`.

## Reproduction and limits

After importing the project, run the bundled engine with a dedicated test user
directory. The helpers write the production boot PNG / native captures:

```powershell
$env:APPDATA = Join-Path (Get-Location) 'tools/visual-home'
$env:LOCALAPPDATA = $env:APPDATA
$godot = 'tools/godot/Godot_v4.7.2-stable_win64_console.exe'
& $godot --path . --rendering-method gl_compatibility --resolution 960x540 --script res://tools/render_branding.gd
& $godot --path . --rendering-method gl_compatibility --resolution 1280x720 --script res://tools/capture_doodledrift_worlds.gd
& $godot --path . --rendering-method gl_compatibility --resolution 1280x440 --script res://tools/render_companion_expressions.gd
```

Fredoka/Nunito variable-font weights use integer OpenType tags from
`name_to_tag("wght")`; string tags left the observed rendering at the fonts'
default light weight in this environment. Native mobile text rendering, launcher
mask/themed-icon output, screen brightness, physical touch, GPU frame times,
thermal behavior and stable Android 60 FPS remain device QA. These desktop visual
checks make no Android performance or certification claim.
