# Interface verification

Verified on 12 November 2026 using Godot **4.7.2.stable.official.ed1daf0bf**, Windows, the Compatibility renderer, OpenGL 3.3 and Intel(R) Graphics. These are desktop viewport and input checks, not Android device certification or performance measurements.

## Automated checks

- `tests/ui_smoke.gd`: constructs the main menu, world selector, level selector, settings, achievements, gameplay, drawing tools, pause and completion screens. Verifies independent indexed movement/jump touches, releasing one touch while the other remains held, clearing touch ownership, all five ink buttons and the reversed boost indicator.
- The same smoke test under the graphical driver sends native `InputEventScreenTouch` events through `Input.parse_input_event` and verifies that the actual **Continue** menu button activates. Standard menus enable Godot's mouse-from-touch translation; gameplay disables it and uses native touch indices. The headless display driver cannot perform this GUI translation, so that one path is checked under the graphical driver instead.
- `tests/gameplay_ui_visual.gd`: loads the integrated main scene and sends UI actions to its real session controller. Verifies level launch, movement touch followed by a second touch on Draw, safe release during synchronous HUD rebuilding, paused player position and simulation time, ink selection, Done, pause and resume.
- `tests/ui_visual.gd`: captures actual rendered menu viewports.
- `tests/integration_suite.gd`: rerun after the proportional snowcap correction; **118 checks, 0 failures**, without the previous polygon triangulation error.

`UI_SMOKE_PASS`, `UI_VISUAL_PASS` and `GAMEPLAY_UI_PASS` were observed. The Windows environment reports a certificate-store warning and loads the bundled CA certificates; the game uses no online gameplay service.

## Visual inspection

Screenshots are native Godot viewport captures, not mockups. The PNG dimensions below were read directly from their headers. Screens were inspected for clipped text, overlapping buttons and offscreen tools after enabling expanding aspect support.

| Capture in `docs/screenshots/` | PNG size | Observed result |
|---|---:|---|
| `main-menu.png` | 1280 × 720 | Hero title, navigation, progress and footer fit |
| `world-select.png` | 1280 × 720 | All five world rows visible and readable |
| `level-select.png` | 1280 × 720 | Ten named cards and mastery explanation fit |
| `settings.png` | 1280 × 720 | Styled controls readable; remaining settings accessible by scrolling |
| `gameplay-03.png` | 1280 × 720 | Level info, ink meter and four movement controls fit |
| `drawing-03.png` | 1280 × 720 | All five ink tools, direction, undo, clear, cancel and Done fit |
| `gameplay-35.png` | 1280 × 720 | Crystal biome and gameplay HUD render together |
| `gameplay-50.png` | 1280 × 720 | Volcanic biome, terrain, checkpoint and HUD render together |
| `gameplay-16x10-large-controls.png` | 1152 × 720 | Controls at 135%, UI text at 125%; controls remain reachable |
| `drawing-16x10-large-ui.png` | 1152 × 720 | UI text at 125%; all drawing tools remain visible |
| `levels-16x10-large-ui.png` | 1152 × 720 | All ten cards readable at 125% UI scale |
| `gameplay-20x9.png` | 1600 × 720 | Controls anchor to expanded edges; playable view expands |
| `drawing-20x9.png` | 1600 × 720 | Toolbar remains centered and all actions visible |

The ink meter animates toward the live reservoir value. Recoloring and button restyling happen when ink selection changes rather than allocating new styles every HUD update. Ink identity uses both names and separately drawn glyphs. Levels 1–8 include short visual tutorial symbols when hints are enabled. Reduced motion suppresses menu fades and ambient background animation.

## Android checks still required

Android safe-area insets are read from `DisplayServer.get_display_safe_area()` and mapped into viewport margins; actual notch, gesture-navigation and system-bar behavior needs physical-device verification. The UI rebuilds when the viewport size changes and releases held controls before callbacks to prevent stuck input.

Physical multi-finger touches, native Android file picking and document-provider URIs, password entry with the soft keyboard, vibration, app interruption, font rendering on devices, and tablet split-screen remain manual Android QA items. No stable 60 FPS or refresh-rate claim is made by these interface checks.

## Reproduction

Use the bundled engine or the pinned Godot version. To keep test user data inside this checkout in the restricted development environment:

```powershell
$env:APPDATA = Join-Path (Get-Location) 'tools/ui-home'
$env:LOCALAPPDATA = $env:APPDATA
$godot = 'tools/godot/Godot_v4.7.2-stable_win64_console.exe'
& $godot --headless --path . --script res://tests/ui_smoke.gd
& $godot --path . --rendering-method gl_compatibility --resolution 1280x720 --script res://tests/ui_smoke.gd
& $godot --path . --rendering-method gl_compatibility --resolution 1280x720 --script res://tests/ui_visual.gd
& $godot --path . --rendering-method gl_compatibility --resolution 1280x720 --script res://tests/gameplay_ui_visual.gd
```

Use a dedicated test user-data directory: the integrated visual script starts several levels and updates the local last-played level while restoring changed settings before exit.
