# DoodleDrift browser QA

Tested **12 November 2026** at `http://localhost:8080/` using the Playwright CLI, **Headless Chromium 151.0.0.0**, a dedicated profile under `output/playwright/profile`, and a **1280 × 720** viewport. The user's Chrome profile was not used.

The preview runs the actual Godot game through the official cached **Godot 4.7.2** Web editor runtime and exported project pack. Its console identifies **WebGL 2.0 / Compatibility**, **Emscripten 4.0.20**, and a multithreaded build. The localhost server supplies COOP/COEP headers; `crossOriginIsolated` was observed as `true`. This is a development preview using the available runtime fallback, not a verified browser release export.

## Exercised in the real browser

| Check | Observed result |
|---|---|
| Initial loader | Exact DoodleDrift name and **A little adventure by Daywrite** subtitle; Fredoka and Nunito loaded from bundled local files |
| Start playing | The observed DOM button starts the Godot canvas successfully |
| Menus | Continue, Worlds, all five world entries, Green Valley and Volcanic Core level grids rendered; long level names fit |
| Glyphs | Continue/Explore arrows, left boost-direction arrow, mastery diamonds and Done checkmark render correctly with the shipped Noto symbol fallbacks |
| Real gameplay | Levels **7** and **50** loaded through their level cards; warm ball, terrain, hazards and cached flowers render, with flowers above the ground |
| Keyboard and pause | Right-arrow movement changed the ball/camera position; E entered/exited drawing; P opened pause; Back from settings resumed the session |
| Drawing | Real pointer events created a Solid stroke in an allowed region. The displayed reservoir changed **100 → 96**; Z removed the stroke and restored **100** |
| Simulation pause | The elapsed gameplay display stayed at **3.7 s** throughout drawing, selection and undo checks |
| Ink UI | All five ink identities visible; Boost selection changed the reservoir tint; reversing Boost visibly switched the direction arrow left |
| Audio controls | Master, Music, Ambience and SFX sliders changed independently. A full reload restored observed values **70% / 50% / 15% / 60%**, along with the last-played level |
| Accessibility | Reduced motion toggled On; scrollable settings remained usable |
| Build boundaries | The final dark-mint dashed allowed regions are clearly visible in Draw Mode; the five-tool toolbar and status text remain readable |
| Confirmation | Return-to-menu confirmation opened and Enter returned to the menu |
| Focus contrast | Final focused Confirm text is dark and readable inside the visible purple focus border |

These checks exercised actual pointer and keyboard events rather than changing game state through injected JavaScript. They do not demonstrate completion of either level or human playthrough of all fifty levels. Audio controls and their persistence were tested; subjective listening quality and Android audio interruptions are separate QA work.

## Issues found and corrected

- The loader's favicon request initially returned 404. The final shell references the bundled SVG favicon.
- Windows had concealed missing arrow/check/diamond glyphs through system fonts. The project now bundles authentic OFL **Noto Sans Symbols** and **Noto Sans Symbols 2**, with full notices and hashes in [ASSET_LICENSES.md](../ASSET_LICENSES.md).
- A global symbol fallback enlarged ordinary text metrics. Fallbacks are now cached per string only when its symbols require them; the final menu footer, level grids and drawing controls fit correctly.
- The default focused-button font color was white on cream. The shared theme now explicitly supplies dark focus text.
- QA profile files were identified in an intermediate export. The final export presets exclude `output/*`, `.playwright-cli/*` and `.test-home/*`; `output/.gdignore` also prevents their import.

The symbol follow-up suite passed **35 checks, 0 failures**, including coverage of both arrows, both mastery diamonds and the checkmark. Its output is in [doodledrift-ui-symbol-followup.log](results/doodledrift-ui-symbol-followup.log).

## Console and limitations

The threaded Web editor runtime logs an error-severity Emscripten message when entering a level: **“Blocking on the main thread is very dangerous”** (`godot.editor.js:344`). Gameplay, drawing, navigation and settings continued to respond. No GDScript parse error or uncaught game exception was observed. This engine-runtime message remains a known preview limitation; the browser console is therefore not described as error-free.

Browser frame rate was not profiled. No stable 60 FPS claim follows from these checks. Browser upload/download backup dialogs, other browsers, touch devices and private-mode persistence were not verified in this session. Native persistence and backup tests are reported separately.

## Evidence

Actual Playwright screenshots and snapshots are under the local `output/playwright/` directory, including `loader.png`, `menu-final.png`, `worlds.png`, `levels.png`, `volcanic-levels.png`, `ink-stroke.png`, `ink-undo.png`, `boost-reverse.png`, `settings-changed.png`, `settings-persisted.png`, `reduced-motion-on.png`, `drawing-final-bounds.png`, and `volcanic-gameplay.png`. The isolated browser profile and its diagnostic artifacts are excluded from game exports.

The final filtered pack was rebuilt after the artifact exclusions and focus fix, reloaded and visually checked. Its proof is also retained in `output/playwright/build-proof.json`:

```text
SHA-256: 117938E6B94D2F14B819043DC137A89621097FFA82F746BDA67F14240BCDA77C
Size: 6,811,332 bytes
Built: 2026-11-12T15:56:19.9910310Z
```

Selected non-profile evidence is included with the source: [final browser menu](screenshots/doodledrift-browser-menu.png), [visible build boundaries](screenshots/doodledrift-browser-build-bounds.png), [readable focused confirmation](screenshots/doodledrift-browser-focus.png), and [final console output](results/doodledrift-browser-console.log). Reproduction uses `tools/build-web.ps1`, the localhost `tools/serve-web.py` server and the Playwright CLI session named `doodledrift` with its task-local configuration.
