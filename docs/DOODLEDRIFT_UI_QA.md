# DoodleDrift interface and typography QA

Verified on **12 November 2026**, using **Godot 4.7.2.stable.official.ed1daf0bf**, Windows, the Compatibility renderer, OpenGL 3.3 and Intel(R) Graphics. This report covers source changes, desktop input checks and native viewport inspection. It does not certify Android device performance.

## Implemented

- Rebranded menu: **DoodleDrift** and the exact subtitle **A little adventure by Daywrite**. Continue, Play, Worlds, Achievements and Settings remain functional routes into the existing session controller.
- Original animated peach ball resting on a mint platform and lavender doodle path. This menu illustration creates no physics bodies. Its gentle motion and blinking stop under Reduced motion; the expression setting is also respected.
- Shared cream cards, rounded pastel buttons, subtle shadows, distinct pressed and keyboard-focus states, and dark readable text across world/level selection, settings, achievements, pause, completion, drawing tools and gameplay HUD. Popups and password fields use the same theme.
- Authentic **Fredoka** variable font for the logo, headings, level/world names and buttons. Authentic **Nunito** variable font for settings, descriptions and numbers. Weights are applied with integer OpenType tags from `TextServer.name_to_tag()`. Resources are cached on interface creation. Official OFL **Noto Sans Symbols** and **Noto Sans Symbols 2** provide offline arrows, checkmarks and mastery marks; the bundled engine face is the final fallback.
- Independent **Master**, **Music**, **Ambience** and **Sound effects** sliders, plus master mute. Ambience uses its own `ambience` settings key and does not overwrite the music value.
- The ink meter still follows the actual reservoir target and shows its actual numeric quantity. Five named ink types retain separate glyphs and recognizable pastel tints; per-level unavailable inks remain disabled. Color is not the sole identifier.
- Native indexed multitouch, keyboard controls, safe-area margins, resize handling, adjustable control opacity/size, UI scale, haptics preference, hints and reduced motion are retained.
- User-facing portable-backup labels and suggested download names use DoodleDrift. The legacy authenticated backup format, import validation and stored progress identifiers are retained by the existing persistence layer.

Full font sources, original copyright notices, SIL OFL licenses and downloaded-file SHA-256 hashes are recorded in [ASSET_LICENSES.md](../ASSET_LICENSES.md). All four font files and their complete license notices are present in `assets/fonts/`; no runtime font download is needed.

## Automated checks performed

| Check | Observed result |
|---|---|
| Editor resource import and GDScript parsing | Modified UI scripts and bundled fonts imported and parsed |
| `tests/ui_smoke.gd` | `UI_SMOKE_PASS`: all main UI screens construct; independent movement/jump touch ownership, release handling, five ink controls and boost direction checks pass |
| `tests/doodledrift_ui.gd` | **35 checks, 0 failures**: loaded font resource paths and variable weights, actual symbol coverage, fallback behavior, exact brand/subtitle, five menu actions, independent audio settings, per-level ink restrictions and actual reservoir values |
| `tests/doodledrift_ui_visual.gd` | `DOODLEDRIFT_UI_VISUAL_PASS`: 11 native viewport fixtures including enlarged and reduced UI scales |
| `tests/gameplay_ui_visual.gd` | `GAMEPLAY_UI_PASS`: integrated scene launch, native movement touch followed by Draw, release without recursion, fixed player position/time in Draw Mode, ink selection, Done, pause and resume |

The graphical `ui_smoke` path additionally checks an actual Continue button using synthetic native touch events through Godot's input dispatcher. The headless display driver does not perform mouse-from-touch translation, so only that translation path is skipped headlessly; indexed gameplay touches are still checked.

The environment emits a Windows certificate-store warning and falls back to bundled certificates. No font-loading or UI script error remained in the final checks. An Android SDK path warning from the isolated UI editor profile does not constitute an Android export test.

After the audio lifecycle fix, the graphical `ui_smoke` rerun also exited without ObjectDB or resource-retention warnings. Its actual output is saved in [doodledrift-ui-native-final.log](results/doodledrift-ui-native-final.log). Browser testing then exposed missing symbols that Windows had supplied through system-font fallback. Two licensed Noto symbol faces now cover them locally. The rebrand-specific script remains `tests/doodledrift_ui.gd` and its follow-up run passed **35 checks, 0 failures**, including five added glyph-coverage checks; see [doodledrift-ui-symbol-followup.log](results/doodledrift-ui-symbol-followup.log). The preceding complete runner's 30-check result predates this targeted follow-up.

## Native visual inspection

The screenshots below were produced by Godot's viewport renderer. They are not image mockups. Completion is a clearly named presentation fixture; it does not award progress or prove that a level was completed.

| Screenshot in `docs/screenshots/` | Actual PNG dimensions | Inspection |
|---|---:|---|
| `doodledrift-menu-1280.png` | 1280 × 720 | Title, exact subtitle, menu hero and all navigation fit |
| `doodledrift-worlds.png` | 1280 × 720 | All five named world cards readable |
| `doodledrift-levels.png` | 1280 × 720 | Ten level cards, names and mastery marks readable |
| `doodledrift-settings.png` | 1280 × 720 | Independent audio controls visible; further settings scroll normally |
| `doodledrift-achievements.png` | 1280 × 720 | Three mastery cards and initial progress state fit |
| `doodledrift-pause.png` | 1280 × 720 | Four pause actions and keyboard hint fit |
| `doodledrift-completion-fixture.png` | 1280 × 720 | Results, three objectives, retry/menu and next action fit |
| `doodledrift-menu-1152-large.png` | 1152 × 720 | Menu fits at **125% UI scale** |
| `doodledrift-settings-1152-large.png` | 1152 × 720 | Enlarged controls and labels fit within the scroll area |
| `doodledrift-levels-1152-large.png` | 1152 × 720 | Card height reserves room for wrapped names and mastery marks |
| `doodledrift-menu-1600-small.png` | 1600 × 720 | Wide layout remains balanced at **85% UI scale** |

Integrated gameplay and drawing captures also cover 1280 × 720, 1152 × 720 with **125% UI / 135% control size**, and 1600 × 720. The enlarged long-hint case initially revealed an overlap with the Draw Mode status. The HUD now measures the multiline hint before placing the status or tutorial glyph, and enlarged cards reserve additional title height. Keyboard captions have cream backplates to remain readable over lava and darker ground.

Contrast calculations for the principal fixed color pairs:

| Foreground / background | Calculated contrast |
|---|---:|
| Dark text `#344054` / cream `#FFF9F0` | **9.99:1** |
| Muted body text `#647286` / cream `#FFF9F0` | **4.67:1** |
| Dark text `#344054` / mint `#A8DFC8` | **7.00:1** |
| Deep mint text `#3F7564` / card `#FFFEFA` | **5.28:1** |

These calculations cover those fixed pairs, not every composited pixel, transparency or world background. Ink labels use darker complementary shades rather than pastel text on cream.

## Remaining platform checks

Real Android multitouch, notch and gesture-bar safe areas, password entry with the system keyboard, native document providers, vibration, accessibility services, audio interruption, GPU behavior and device frame rate still require hardware QA. Browser-specific upload/download behavior requires the Web build's browser test. No stable 60 FPS or full Android compatibility claim follows from these UI checks.

The **DoodleDrift** name also requires trademark and Google Play availability checks before publication.

## Reproduction

```powershell
$env:APPDATA = Join-Path (Get-Location) 'tools/ui-home'
$env:LOCALAPPDATA = $env:APPDATA
$godot = 'tools/godot/Godot_v4.7.2-stable_win64_console.exe'
& $godot --headless --path . --editor --quit
& $godot --headless --path . --script res://tests/ui_smoke.gd
& $godot --headless --path . --script res://tests/doodledrift_ui.gd
& $godot --path . --rendering-method gl_compatibility --resolution 1280x720 --script res://tests/ui_smoke.gd
& $godot --path . --rendering-method gl_compatibility --resolution 1280x720 --script res://tests/doodledrift_ui_visual.gd
& $godot --path . --rendering-method gl_compatibility --resolution 1280x720 --script res://tests/gameplay_ui_visual.gd
```

Run graphical capture scripts sequentially: opening a second Godot window can correctly trigger the first game's focus-loss pause. Use a dedicated test data directory for integrated session tests; they start levels and can update the local last-played level.
