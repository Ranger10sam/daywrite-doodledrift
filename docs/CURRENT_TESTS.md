# Current regression scope

Run `tools/run-tests.ps1` with Godot 4.7.2 and Python 3. The runner imports the
project, executes the current suites, audits engine logs for script/errors and
resource leaks, and writes `builds/current-test-results.json`. Its AppData changes
are temporary and restored when the script ends; progress tests use isolated files.

The current campaign is revision 3. It contains launch pads, strong wind, moving
islands, crate keys, low roofs and limited ink supplies. Its structural validator
checks 50 unique maps, safe start/finish/checkpoint geometry, valid polygons,
allowed inks/build zones, bounded resources/wind/platforms and gate-to-crate keys.
It does not assume a continuous ground/bridge route or that every level regenerates
ink. Fixed-ink puzzles can be restarted.

Negative validator regressions reject a spawn in terrain, a hazard on a safe spawn,
a forbidden example ink, a no-build-zone example, an unmatched crate key,
nonfinite wind and self-crossing terrain. Unit/drawing checks still reject protected
crossings, drawing into the ball, empty ink, invalid geometry and forbidden inks;
they verify costs against the current central ink configuration and world-space
endpoints of the current rigid stroke bodies.

The integrated session test now uses the first puzzle's authored Bounce launch pad
and completes its elevated goal through drawing and actual movement. It still
checks all 50 safe spawns, paused controls/drawing/resource behavior, regeneration,
undo, checkpoint respawn, session difficulty, persistence and unlock progression.
The puzzle suite tests selected current solutions and negative substitutions;
the revision suite checks physical loose/anchored strokes, plate interactions and
the simple repeated-jump bypass. These are specific regressions, not a solver for
every creative route in every difficulty.

The stress suite uses an explicitly supported isolated workbench to load 32 rigid
stroke bodies/512 capsule colliders. It checks finite physics, input limits,
100 pause/respawn cycles and 100 level switches. A current Bounce plan replaces
its former level-3 bridge fixture. Accelerated headless timing/engine-monitor data
is not a real-time performance profile and proves no Android/GPU frame rate.

`tests/campaign_physics.gd` is retained as a historical revision-2 static-support
bridge bot and is excluded from the default runner. It refuses revision-3 data
instead of reporting current solves. Its old result files and any old 50-solve
claims describe that historical campaign snapshot. Do not use them as evidence for
the current 50 timing/puzzle levels.

Audio tests exercise real player state through the dummy mixer, independent buses,
bounded crossfades, rapid changes, suspend/resume and shutdown. PCM tests inspect
all ten original loops. Persistence tests import an independent legacy encrypted
fixture while preserving its progress and settings. Listening, browser/device
interruption behavior, Android performance and complete human campaign playthroughs
remain separate manual QA work.

## Verified current run

The complete default runner exited successfully on 12 November 2026: **14 suites,
zero failures and zero unexpected engine messages**. The host's root-certificate
store warning remains the sole whitelisted environmental diagnostic.

| Current checks | Result |
|---|---:|
| Reservoir, geometry, drawing and forbidden-ink regressions | 165 passed |
| Fixed-step player and ink physics | 42 passed |
| Persistence and legacy compatibility | 32 passed |
| Audio routing, loops, fades, suspension and shutdown | 55 passed |
| DoodleDrift rebrand UI | 30 passed |
| Integrated production sessions | 121 passed |
| Selected actual puzzle solutions and negative substitutions | 20 passed |
| Loose/anchored physics, switches and simple bypass rejection | 8 passed |
| Geometry limits and lifecycle stress | 615 passed |
| Python manifest, signal and negative structure tests | 19 tests passed |
| Current campaign structure | 50 definitions passed |
| Control/indexed-touch smoke and immediate audio-quit probe | Passed |

Full machine-readable results and the sanitized runner output are preserved in
`docs/results/current-test-results.json` and
`docs/results/current-test-runner.log`. The active-playback immediate-quit probe
also passed without leaked resources after adding its explicit playback assertion.
The counts do not represent 50 current campaign completions; see the scope above.
