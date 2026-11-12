# DoodleDrift upgrade

**DoodleDrift — A little adventure by Daywrite** updates the existing Godot game.
The current 50-level campaign, ball controls, five physical inks, drawing costs,
regeneration, checkpoints, difficulty modes and progression are retained.

## Implemented

- Cream/pastel menus, cards, controls, reservoir and five biome landscapes.
- An expressive peach ball, independently animated from its collision body.
- Distinct ink glyphs and material patterns, including directional Boost arrows
  and Fragile cracks. Hazards and construction boundaries retain dark outlines.
- Authentic bundled Fredoka and Nunito fonts, OFL symbol fallbacks and notices.
- Five original offline music/ambience pairs, gentle procedural effects,
  bounded crossfades, independent Master/Music/Ambience/SFX controls and mute.
- Focus/background audio suspension, reduced motion, UI scale and touch sizing.
- Original launcher artwork and a font-rendered splash with the exact subtitle.

See [visual QA](DOODLEDRIFT_VISUAL_QA.md), [UI QA](DOODLEDRIFT_UI_QA.md),
[audio implementation](DOODLEDRIFT_AUDIO.md) and [asset licenses](../ASSET_LICENSES.md).

## Compatibility

The Android application ID remains `com.momentumquest.game`. Signing interfaces,
debug signing identity, version-1 save schema, local progress filenames and
authenticated encrypted backup format remain unchanged. The former desktop
user-data directory is pinned explicitly; isolated Windows before/after probes
returned the same `Godot/app_userdata/Momentum Quest` directory. Linux uses the
equivalent lowercase `godot` directory. Web keeps its pack name, `/userfs` and
preview origin.

Older saves acquire only the missing Ambience default. An independently generated
legacy encrypted backup fixture imports successfully with its progress and
settings intact. Tests never use the player's actual progress files.

## Automated and visual verification

The complete current runner passed **14 suites with zero failures and zero
unexpected engine messages**. Counts and machine-readable evidence are in
[current tests](CURRENT_TESTS.md). Checks cover actual ink contact behavior,
consumption/regeneration, selected physical puzzle solutions and negative
substitutions, 50 safe level definitions, legacy saves, crossfades, audio teardown,
UI controls and lifecycle stress. The historical revision-2 bridge bot is excluded.
The later browser glyph correction passed an additional 35-check native UI run,
including explicit coverage for arrows, mastery diamonds and confirmation marks.

Native graphical captures cover all five biomes, the five inks, ball expressions,
splash/icon and menu flows at three viewport/UI-scale combinations. Capture
helpers and native UI smoke exit cleanly. PCM validation checks all ten loops for
hashes, clipping headroom, DC and boundary continuity; a native mixer probe detects
nonzero output. This does not replace subjective listening.

The native 1280×720 Level 50 profile measured a median frame interval of
**48.897 ms before → 40.894 ms after** decorative batching, with draw calls
**396 → 274**. All sampled frames were focused and playing. This improves the
observed result but still falls short of 60 FPS on this Intel Graphics Windows
host. It is not an Android, GPU-timer or worst-case drawing benchmark. Full
records and sampling limits are in the visual QA report.

## Browser and packaged builds

The [real browser QA](DOODLEDRIFT_BROWSER_QA.md) exercised menu navigation,
Levels 7/50, drawing and undo refunds, Boost direction, movement, pause/resume,
independent volume controls and saved settings. It also corrected symbol coverage,
focus-text contrast and drawing-boundary contrast. The local preview is available
at **http://localhost:8080/**. The threaded editor-runtime fallback emits a known
Emscripten main-thread warning; no uncaught game exception was observed. A normal
Web release with matching export templates is still a separate verification.

The signed debug APK is **65,489,675 bytes**, labeled DoodleDrift with the existing
application ID. Signature schemes v2/v3, 16 KB native alignment, API 24/36, the
previous debug certificate and four byte-identical current game JSON files were
verified. Its ten audio loops and all font/project notices are present. An isolated
mount of the Web pack also confirms the notices and 50 level definitions. Both
exports exclude source tooling, tests, documentation and temporary QA/profile data.
See [Android artifact audit](results/doodledrift-android-artifact.json) and
[release instructions](ANDROID_RELEASE.md). Checksums accompany local builds.

The source ZIP was extracted into an isolated project with a fresh resource cache;
editor import, **121 integration checks** and **35 UI checks** passed. The final
archive includes the current source, assets, tests, licenses and QA reports.

## Distribution and remaining checks

The repository is [Ranger10sam/daywrite-doodledrift](https://github.com/Ranger10sam/daywrite-doodledrift).
**`master` is the production branch.** The source archive omits engine/SDK caches,
local progress, signing keys and generated builds.

Before publishing to a store:

- Check the **DoodleDrift trademark and Google Play name availability**.
- Test representative Android devices for frame time, touch, audio interruptions,
  background/resume, launchers and system file-picker backup round trips.
- Complete human playthroughs of all current puzzles and difficulty modes.
- Supply the owner's production signing configuration and finish Billing and
  entitlement restoration. Debug unlocks are for development only.

No production AAB, real-device FPS, subjective audio review or Play acceptance is
claimed by desktop regression tests.
