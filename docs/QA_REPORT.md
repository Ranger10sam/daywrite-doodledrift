# Momentum Quest verification report

**Historical revision 1 results.** See [revision 3](REVISION_3.md) for the current
mechanic-led puzzle work and its verification limits. The browser was updated with falling
ink, wider puzzles, pressure gates and boundaries. See [revision 2](REVISION_2.md)
for current checks; the counts and timings below are not a certification of it.

Verified on **12 November 2026**, using the official **Godot 4.7.2 stable** Windows
GDScript build. The implementation is a native, offline Godot game. This report
separates production-code simulation checks, desktop visual checks, Android build
inspection, and work that still requires physical devices or release credentials.

## Automated results

`tools/run-tests.ps1` completed with exit code **0** after the gameplay and
interface and configurable-physics fixes. Its seven Godot suites and the Python
campaign validator passed, including all 120 session integration checks.
The numeric Godot suites performed **964 assertions**, in addition to **50 actual
campaign route replays**, the UI smoke assertions and **7 Android manifest repair
regression tests**.

| Suite | Observed result | What it establishes |
|---|---:|---|
| `tests/test_runner.gd` | **163 checks passed** | Reservoir boundaries, continuous debit, exhaustion, regeneration, FIFO credit settlement, pickup credit, exact undo/cancel, 100 refund-banking cycles; RDP tolerance/corners, crossing and collinear-overlap rejection; actual drawing-controller fast/stationary/protected input and collider creation |
| `tests/physics_suite.gd` | **42 checks passed** | Actual Godot movement, rolling, gradual brake, jump/air control/fast fall, coyote time, buffering, no air double jump, floor/wall CCD, respawn, surface-normal Bounce, bounded and directional Boost, Ice friction, Fragile collision removal, physics pause/resume, and configured gravity reaching actual fall acceleration |
| `tests/persistence_test.gd` | **24 checks passed** | Atomic save/load, previous-save recovery, malformed/future schemas, independent mastery, best records, Zen exclusion, settings bounds, PBKDF2 known vector, authenticated encrypted backup round trip, wrong password/tamper rejection, overwrite confirmation |
| `tests/integration_suite.gd` | **120 checks passed** | All 50 production sessions load and survive initial fixed steps; integrated draw/pause/regeneration/refund, input release, checkpoint respawn, real First Roll completion, persistence and unlock progression; next-run difficulty preferences do not relabel the current session |
| `tests/stress_suite.gd` | **615 checks passed** | Exact 32-stroke/512-segment limits, limit rejection and fast input; 1,000 full-complexity physics ticks; 100 pause/resume cycles, 100 checkpoint restores, 100 level switches, cancellation of a stale respawn after switching sessions |
| `tests/campaign_physics.gd` | **50 / 50 goals reached** | One physically executed Normal-mode route per level, through actual production finish triggers |
| `tests/ui_smoke.gd` | **UI_SMOKE_PASS** | Real Control construction and independent native indexed movement/jump touches, partial release, pause ownership release, all five ink tools and visible Boost reversal |
| `tests/campaign_validator.py` | **50 unique layouts passed** | Geometry/bounds, safe start/goal/checkpoint placement, conservative route support, slopes, roof/lava clearance, costs, 14 wind zones and 10 ferry travel bounds |
| `tests/test_android_manifest.py` | **7 tests passed** | Repair an actual exported binary manifest, preserve unrelated attributes, require distinct provider authorities, handle repeat repair and reject malformed input |

The 42 physics assertions also passed with render fixed rates of **30 and 120**
while physics remained at **60 Hz**. These runs test fixed-step behavior against
different render scheduling. They do not prove identical floating-point results
across different CPUs or establish an Android refresh-rate guarantee.

Evidence is retained under [`results/`](results/). Logs preserve a host startup
warning about reading the Windows root certificate store. The game does not use
an online gameplay service; the listed offline checks still completed. No other
unexpected engine/script errors were accepted by the final test runner.

## Campaign replay method

Each replay instantiates the production `LevelWorld`, `QuestBall` and
`DrawingController`. The bot places the documented world-space strokes through
`begin_stroke`, `accept_to` and `finish_stroke`, so the real build-area validator,
resampling, continuous cost calculation, simplification and collision generation
remain in the path. It uses Normal capacity and regeneration, including real ink
pickups. Structures are staged when resources are available.

Only normal acceleration, braking and jump requests move the ball after its
initial spawn. The bot requests a jump when progress stalls at a rounded bridge
lip. It never teleports along the route, directly sets route positions, grants
unlimited ink, disables hazards, or calls a completion method. Wind, moving
platforms, Fragile countdowns and production goal/failure checks stay active.
All 50 runs reached their goals without a hazard failure. The finale used all five
intended ink types and approximately **102.9 units over the run**, replenished
through ordinary regeneration rather than a larger starting reservoir.

The full record is [`results/campaign_replay_results.json`](results/campaign_replay_results.json).
This verifies a scripted feasible route; it does not replace human touch
playthroughs, evaluate every creative solution, or verify all 50 maps in all four
difficulty modes. Static loading alone is not counted as solvability evidence.

## Measured maximum-complexity simulation

A separate live-clock run used `--headless --max-fps 60`, without accelerated
`--fixed-fps`. After 120 warmup physics ticks, it sampled 1,000 further ticks at the
supported maximum of **32 physical stroke bodies and 512 capsule shapes**. The
ball rolled and jumped across the structures, with up to two simultaneous surface
contacts. The tree contained **564 nodes** in this isolated fixture, including
the autoloads. Other Godot tests/builds were held during this final profile.

| Measurement on this Windows host | Observed value |
|---|---:|
| Godot engine physics monitor, median | **0.757 ms** |
| Godot engine physics monitor, 95th percentile / maximum sampled | **1.149 ms** |
| 1,000 paced ticks, elapsed wall time | **16,682.6 ms** |
| Paced wall tick, 95th percentile | **16.726 ms** |
| Longest wall tick including scheduling/waiting | **33.345 ms** |
| Create and validate all 32 strokes in one synthetic batch | **45.239 ms** |
| Cold fixture construction including initial script loads | **215.124 ms** |
| Maximum observed player speed | **703.28 px/s** |

Godot's physics monitor updates periodically, so the table reports its sampled
values rather than claiming a profiler trace for every physics step. The paced
wall measurements include waiting for the next 60 Hz tick, script work and OS
scheduling; they are not pure CPU physics times. Startup and whole-batch creation
are measured separately. The synthetic creation of all 32 strokes in one call
exceeds a 16.7 ms frame budget on this host; ordinary drawing commits one stroke
at release, and worst-case checkpoint reconstruction still needs device profiling.
No critical drawing limits were silently reduced to obtain these results.

Accelerated stress results are also retained, but their periodic engine-monitor
samples may be stale because 1,000 simulated ticks finish in less than a real
second. They must not be used as a 60 FPS or Android performance claim. The live
profile is [`results/stress_live_profile.json`](results/stress_live_profile.json).

These measurements contain no GPU rendering, physical touch latency, Android
thermal/battery behavior, or representative mid-range-device frame-time data.
**Stable 60 FPS on Android has not been demonstrated.**

## Desktop visual and input verification

The interface agent inspected **13 actual Godot viewport PNGs**, including the
main menu, world/level selection, settings, gameplay and drawing, Crystal Caverns
and the finale. Captures cover 1280 × 720, 1152 × 720 with UI text at 125% and
controls at 135%, and 1600 × 720. The observed layouts kept text and controls
visible without overlap or clipping. These are rendered game images, not mockups.

The graphical driver also verified native touch-to-menu activation through
`Input.parse_input_event`. Integrated UI checks exercised movement held while a
second touch enters Draw, synchronous control release, paused position/time,
ink selection, Done and pause/resume. See [`UI_QA.md`](UI_QA.md) for exact captures,
reproduction commands and platform limits, and [`screenshots/`](screenshots/)
for the PNGs.

## Android build evidence

An actual **debug APK was exported successfully** with the pinned official
Android template. Android tooling verified APK v2/v3 signatures and inspected the
packaged manifest: `com.momentumquest.game`, version **1.0.0 / code 1**, minimum
API **24**, target API **36**, landscape, **arm64-v8a + x86_64**, and only the
optional **VIBRATE** permission. ZIP inspection found all 50 campaign definitions
and the configuration JSON, and excluded development tools, tests, docs and build
outputs. This establishes build/export success, not successful installation or
gameplay on an Android device.

The prebuilt exporter assigned the same authority to FileProvider and AndroidX
InitializationProvider. The reproducible build script repairs only AndroidX's
authority, verifies that unrelated manifest attributes are unchanged, restores a
stale themed-icon XML alias, aligns the APK at 16 KB and re-signs it. The final
package is inspected again with Android's native tools. Release AAB builds use
Gradle's source-manifest merge and need a separate production inspection.

The APK is `builds/momentum-quest-debug.apk`. The build/signature/manifest logs and
SHA-256 digest are under `builds/`, with sanitized copies in `docs/results`.
[`ANDROID_RELEASE.md`](ANDROID_RELEASE.md) records the toolchain, final package
inspection, icon caveats if any, and exact commands. A signed production AAB has
not been generated with an owner's release key or uploaded to Google Play.

## Source archive verification

The source archive was extracted into a separate directory with no Godot import
cache or SDK. Godot 4.7.2 imported its six visual assets and registered all script
classes successfully. The extracted project's production integration suite then
passed all **120 checks**, including an actual First Roll completion and save.
The engine was supplied externally to this check, as documented for archive users.

## Remaining release work and manual checklist

The production premium adapter is deliberately unavailable until actual Google
Play Billing is connected and verified. Editor/debug builds expose all 50 levels
for development. Release builds provide the free Green Valley and never infer
premium entitlement from an imported save. No payment is simulated as successful.
Billing, release signing/AAB publication, and physical Android verification remain
release blockers.

- [ ] Install and launch the final debug APK on representative mid-range phones
  and tablets. Repeat offline cold starts and upgrade-over-existing-save tests.
- [ ] Record CPU/GPU frame times, slow frames, memory, heat and battery during
  ordinary play, high-speed launches, maximum drawings and full checkpoint
  reconstruction. Optimize measured device bottlenecks before a performance claim.
- [ ] Human-play all 50 intended routes; evaluate alternate solutions, hints and
  difficulty balance in Easy, Normal, Expert and Zen. Verify extra checkpoints,
  reduced hazard pressure and mastery objectives at each modifier.
- [ ] Exercise real multi-finger movement/jump/brake/draw transitions, cancelled
  touches, gesture navigation, notches, tablets, resizing and large UI/control
  settings. Confirm optional vibration, reduced motion, glyphs and readability.
- [ ] Background/resume, audio interruption, screen lock, task switching, low
  memory and process termination during play, drawing, respawn and saving.
- [ ] Export/import/overwrite/restore through Android's real system document
  picker, including `content://` providers, denied/revoked grants, incomplete
  backups, wrong passwords, tampering and soft-keyboard password entry. Measure
  the password-derivation delay on release hardware. Device-local JSON is not
  encrypted; portable backups use password-derived encrypt-then-authenticate.
- [ ] Inspect adaptive/themed icons and launch screen on supported Android
  versions. Verify the final manifest, permissions and signatures after the final
  build, and repeat using a production release export.
- [ ] Integrate and test Google Play Billing purchase, acknowledgement, restore,
  pending/cancel/refund/offline/account-change states; complete signing, AAB,
  internal testing track, store listing, data-safety and current Play-policy review.

## Reproduce the checks

Use the bundled official engine or install the exact pinned version, then run:

```powershell
.\tools\run-tests.ps1
```

For the live-clock maximum-complexity profile, use a dedicated test user-data
directory and keep other heavy processes idle:

```powershell
$env:APPDATA = Join-Path (Get-Location) '.test-home'
& '.\tools\godot\Godot_v4.7.2-stable_win64_console.exe' --headless --max-fps 60 --path . --script res://tests/stress_suite.gd --log-file tests/stress_live_profile.log -- --profile-live
```

The automated suites use dedicated test progress paths and restore session data;
they do not intentionally replace a player's real progress. Graphical captures
should likewise use a dedicated test user-data directory as documented in UI QA.
