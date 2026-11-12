# Architecture and engineering decisions

## Entry and ownership

`scenes/core/main.tscn` is the entry scene. `scripts/gameplay/main.gd` owns session state (`menu`, `playing`, `drawing`, `paused`, `respawning`, `complete`) and connects modules. Levels never live in the session controller. Runtime composition keeps procedural geometry editable in scripts and authorable JSON without maintaining 50 nearly identical scenes.

| Module | Responsibility |
|---|---|
| `QuestBall` / `ball_visual.gd` | RigidBody simulation, forgiving jump, capped effects; independent visual squash |
| `QuestCamera` | Physics-step follow, look-ahead, bounds and frozen draw coordinates |
| `LevelWorld` | JSON loading, triggers, wind, hazards, pickups, checkpoint flags and world visuals |
| `TerrainBody` / `MovingPlatform` | Polygon terrain, slippery/collapsing surfaces, synchronized animated bodies |
| `DrawingController` | Gesture ownership, sampling, validation, live cost, undo and lifecycle |
| `StrokeGeometry` / `InkStroke` | Bounded simplification and one static compound body per stroke |
| `InkReservoir` | Capacity, simulation regeneration, debit ledger, refunds and net cost |
| `QuestUI` / `InkGlyph` | Responsive styled Controls and indexed touch ownership |
| `BiomeBackground` / `ParticleBurst` | Procedural gradient scenery, parallax and bounded effects |
| `SaveManager` | Version validation, atomic writes, records and authenticated backups |
| `AudioManager` | Cached original synthesis, eight-voice SFX pool, ambience and buses |
| `Entitlements` | Secure boundary for a future verified Google Play Billing implementation |

## Physics model

The ball is a native `RigidBody2D`, circle radius18px and mass1. Gravity1100px/s², jump470px/s and normal movement500px/s were tuned together. `PhysicsConfig` reads centralized JSON; Godot runs 60 fixed ticks per second with interpolation. Input acceleration and braking operate in `_integrate_forces(state.step)`; ordinary movement never teleports the body. Only explicit respawn changes the physics transform. Angular motion is visible in a subtle rotating seam, while the face remains upright.

Ground detection uses a short downward ray and a normal slope threshold. Coyote time and jump buffering are simulation timers. CCD uses shape casting. Ice material friction is0.015; acceleration and braking are reduced to reflect traction. Bounce uses the actual outward collision normal, replaces only insufficient outward speed, and has a cooldown. Boost applies at most once per tick across simultaneous contacts. Global velocity caps bound overlapping effects. Surface-normal regression tests include a vertical wall.

Godot's direct-body-state contact positions and normals are in physics space; applying a second body transform was caught and fixed by the wall-bounce regression. Fixed steps improve reproducibility on the pinned engine, but floating-point physics is not claimed to be bit-identical across architectures.

Collision bits: terrain1, player2, ink4, platforms8, reserved triggers16. The player masks13; terrain/ink/platforms mask2. Logical goal, hazard and checkpoint triggers are distance/rectangle checks each physics tick, avoiding extra physics bodies. The supported maximum speed is included in hazard radius and CCD tests.

## Drawing and geometry

The UI and drawing controller run while the tree is paused. World bodies, camera and stroke timers are pausable. Camera transforms freeze in Draw Mode; screen coordinates use the inverse canvas transform exactly once. Indexed touch controls consume their own events before unhandled drawing input. Menu-only touch-to-mouse emulation enables native Controls without duplicate gameplay input. Input release clears ownership before emitting callbacks, making HUD rebuilds reentrant.

Raw input is resampled at no more than10px per accepted segment with a4px stationary threshold. Every resampled segment is checked against build rectangles, protected polygons, moving platforms, goal and ball. Self-crossings and collinear backtracking are rejected. A rejected segment terminates the current valid stroke. RDP simplification tolerance1.5px is accepted only after checking each simplified segment again. Otherwise raw validated points are retained.

One `StaticBody2D` holds capsule shapes (radius6px) for every simplified segment. Capsule height is segment length+12px and endpoints are drawn with the same radius. All strokes are explicitly two-sided; overhangs and underside contact work as physical structures. Rounded endpoints need perpendicular clearance on slopes, so authored solution endpoints sit8px above terrain lips. Fragile removal disables collision deferred and hides its geometry safely; broken structures remain ledger entries until cleared and receive no refund.

Limits:32 active stroke entries,128 raw points per gesture,512 active collision segments,6000px total active stroke length. These bound physics objects, drawing work and memory. No joints, per-point physics bodies or triangulated self-intersecting collision meshes are used.

## Ink accounting

Accepted distance × type multiplier ×0.06 is charged during the gesture. Exhaustion clamps the last segment to the exact remaining affordable length. Cancel and tiny strokes refund their outstanding debit. A FIFO ledger settles debit as regeneration or pickups restore capacity. Undo credits only the removed stroke's outstanding unregenerated debit, and never exceeds capacity. Net mastery cost subtracts the removed geometry's full accepted cost. Repeated refund/regeneration banking is tested over100 cycles.

Normal capacity100 and regeneration5/s are level-configurable. Difficulty modifiers are data-driven; no regeneration occurs in drawing/pause/respawn/completion. The maximum geometry and current resource balance are separate limits.

## Checkpoints and records

A checkpoint snapshots surviving strokes, original ledger identifiers, reservoir debit state and capacity. On failure, subsequent drawings are removed, snapshot drawings are rebuilt, all fragile timers and moving-platform phases reset, and pickups become available again. The player respawns with zero velocity after a short burst. Geometry is probed around the checkpoint to find a clear circle; the validated start is a final fallback. At least25 units are available after recovery when capacity allows, preventing resource softlocks. Failed-attempt ink use remains in run accounting. Level restart resets all run metrics.

Mastery badges accumulate independently across attempts. Best time, net ink and deaths use independent minima. Zen neither awards mastery nor unlocks competitive progression. Save imports do not contain or grant a paid entitlement. Local saves remain ordinary JSON; see the backup protocol document for cryptographic boundaries.

## Mobile and performance decisions

The1280×720 canvas expands to device aspect ratio. UI uses anchored Controls, adjustable control sizes, opacity and font scale, text/pattern ink labels and optional reduced motion. World rendering uses inexpensive polygons and lines rather than full-screen lighting shaders. Bounded bursts avoid unbounded particles. Audio caches generated streams. HUD numeric updates are throttled to20Hz during active play.

Application background/focus loss pauses the session, releases controls and saves progress. An interrupted draw cancels the active gesture. Native Android file dialogs rely on Storage Access Framework document URIs, with no broad storage or network permission. Optional haptics uses only the normal VIBRATE permission. Android cutouts, input interruption and performance still require device QA.
