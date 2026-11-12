# Momentum Quest campaign design

All 50 layouts are authored in `data/levels/author_campaign.py` and checked in as editable JSON. Run that script to regenerate the campaign after editing contours. Coordinates are world pixels with positive y downward; the player radius is 18 pixels. Ground contours become two-sided filled polygons. Goals sit 38 pixels above the final floor and checkpoint centers sit 20 pixels above safe ground.

The conservative route for each map joins its ground contours using the listed solution strokes. Stroke endpoints sit 8 pixels above terrain lips, providing perpendicular clearance for six-pixel capsule radii near slopes. A small jump can smooth the transition onto a rounded bridge endpoint, particularly on Ice. Strokes are examples, never placed automatically in normal play. Existing terrain is protected from drawing. Moving ferries provide optional timing routes; every such stage also has a static drawn route above their travel envelope. Roofs leave at least 75 pixels of clearance along the intended floor route.

Physics design basis: gravity 1100 px/s², jump impulse 470 px/s (about 100 px rise), normal horizontal cap 500 px/s. No intended route requires a ballistic jump over its gaps: ink makes continuous ramps with modest slopes. Springs launch outward and therefore require braking and a safe landing, rather than holding full acceleration. Long ramps allow rolling ascent without changing core physics between difficulties.

Normal costs below use 0.06 ink per accepted world pixel and the configured ink multipliers. Some later maps intentionally require drawing in stages with safe waiting for regeneration, pickups, or checkpoints. Engineer budgets are per whole run net expenditure; the finale budget exceeds one reservoir because regeneration is part of its plan. Easy adds safe shelf checkpoints, more capacity and faster regeneration; Expert reduces resources without moving terrain. Zen does not award campaign records.

## Validation limits

`python tests/campaign_validator.py` checks all 50 distinct ground layouts, finite and in-bounds geometry, safe starts/goals/checkpoints, roof clearance along the witness route, supported contour and stroke connectivity, stroke cost, climb gradients, hazard placement, and moving-platform travel bounds. These static checks alone establish only conservative geometric feasibility.

The independent production-physics replay `tests/campaign_physics.gd` has also reached all 50 real finish triggers under Godot 4.7.2 at 60 fixed physics ticks per second. It creates the production LevelWorld and QuestBall, places intended strokes through the production DrawingController (including collision validation and continuous ink charging), and uses only acceleration, braking, and the ordinary jump request after initial spawn. Normal reservoir limits, live regeneration, pickups, hazards, wind and ferries remain active. No teleport or direct velocity overwrite is used along the route. The machine-readable record is `tests/campaign_replay_results.json`. This demonstrates one scripted feasible route per level; it does **not** replace full human touch playthroughs on Android or establish a device frame rate. A level loading successfully is not counted as a solve.

## Green Valley

### 01. Spring to Sky Garden

Draw a horizontal Bounce pad from (500,612) to (610,612). Approach right with speed, spring upward, and land on the garden.

Intended ink: 0.0 units. Engineer budget: 60.0. Standard checkpoints: 0. Wind zones: 0. Ferries: 0.

### 02. Amber Headwind

Draw forward Boost from (350,612) to (1450,612). Its contact force overcomes the wind. Solid and Ice do not add propulsion.

Intended ink: 0.0 units. Engineer budget: 60.0. Standard checkpoints: 0. Wind zones: 1. Ferries: 0.

### 03. The Wandering Orchard

Wait at the bank for the island, board it, jump up to the fixed orchard before passing beneath it, then jump to the final bank.

Intended ink: 0.0 units. Engineer budget: 60.0. Standard checkpoints: 0. Wind zones: 0. Ferries: 1.

### 04. Special Delivery

Push the parcel to x=1030. Hop over it after it settles in the cradle. The roof prevents jumping over the closed door. At the gold plate, draw a short unsupported Solid stroke above it, resume, and let its weight hold the gate open.

Intended ink: 0.0 units. Engineer budget: 60.0. Standard checkpoints: 0. Wind zones: 0. Ferries: 0.

### 05. Borrowed Time

Draw Fragile from (480,572) to (840,572), release, and roll across before the 3.2-second collapse.

Intended ink: 0.0 units. Engineer budget: 60.0. Standard checkpoints: 0. Wind zones: 0. Ferries: 0.

### 06. Slippery Freight

Draw Ice from (558,342) to (1100,590). The parcel is nudged off its shelf, then slides by gravity into the cradle. Walk through the unlocked door. At the gold plate, draw a short unsupported Solid stroke above it, resume, and let its weight hold the gate open.

Intended ink: 0.0 units. Engineer budget: 60.0. Standard checkpoints: 0. Wind zones: 0. Ferries: 0.

### 07. Two Keys, One Door

Draw chutes from (648,330) to (800,590) and (948,330) to (1100,590). Route N and F into their matching elevated cradles, then walk below them through both doors. At the gold plate, draw a short unsupported Solid stroke above it, resume, and let its weight hold the gate open.

Intended ink: 0.0 units. Engineer budget: 60.0. Standard checkpoints: 0. Wind zones: 0. Ferries: 0.

### 08. Elevator Picnic

Jump onto the elevator at x=550, wait for its high point at y=330, then jump right to the high garden. Direct bridging is forbidden over the shaft.

Intended ink: 0.0 units. Engineer budget: 60.0. Standard checkpoints: 0. Wind zones: 0. Ferries: 1.

### 09. Bounce and Brake

Use a Bounce pad at the first bank. Release direction or brake on the high garden. Board the ferry when aligned and jump to the exit.

Intended ink: 0.0 units. Engineer budget: 60.0. Standard checkpoints: 0. Wind zones: 0. Ferries: 1.

### 10. Garden Contraption

Push the parcel into its cradle to clear the bank door. Place Bounce on the bank beyond it, spring to the ferry, and time the last jump. At the gold plate, draw a short unsupported Solid stroke above it, resume, and let its weight hold the gate open.

Intended ink: 0.0 units. Engineer budget: 60.0. Standard checkpoints: 0. Wind zones: 0. Ferries: 1.

## Frozen Peaks

### 11. Snowline · Spring Garden

Coast down the icy descent onto a Solid bridge, then use gradual braking along the long uphill runout. Finish with a supported Bounce pad near the last bank and a controlled landing on the elevated island.

Intended ink: 37.0 units. Engineer budget: 45.0. Standard checkpoints: 0. Wind zones: 0. Ferries: 0.

### 12. Blue Switchback · Wind Machine

Join the first gap with a Solid ramp and the second with Ice. Release the accelerator on the landing, then climb the final slope. Draw forward Boost through the final headwind tunnel.

Intended ink: 88.2 units. Engineer budget: 96.2. Standard checkpoints: 1. Wind zones: 1. Ferries: 0.

### 13. Needle Landing · Parcel Lock

Use two Solid bridges through the 160-pixel central shelf. Slow down on the first crossing before taking the second rise. Push the final parcel into the crate-marked cradle and pass beneath the roof. At the gold plate, draw a short unsupported Solid stroke above it, resume, and let its weight hold the gate open.

Intended ink: 72.7 units. Engineer budget: 80.7. Standard checkpoints: 1. Wind zones: 0. Ferries: 0.

### 14. Glacier Run · Island Hop

Draw a straight Ice bridge across the 310-pixel runout. Let the climb on the far side absorb momentum. Board the moving island, ride toward the exit, then time the jump onto the raised garden.

Intended ink: 55.4 units. Engineer budget: 63.4. Standard checkpoints: 0. Wind zones: 0. Ferries: 1.

### 15. The Quiet Shelf · Sky Ferry

Build a rising Solid bridge, stop on the high shelf, and place a short Fragile bridge for the second crossing. Board the moving island, ride toward the exit, then time the jump onto the raised garden.

Intended ink: 52.4 units. Engineer budget: 60.4. Standard checkpoints: 1. Wind zones: 0. Ferries: 1.

### 16. Frost Arc · Spring Garden

Use a Bounce ramp for the 120-pixel rise, land on the wide ice crest, then make a Solid bridge at the bottom. Finish with a supported Bounce pad near the last bank and a controlled landing on the elevated island.

Intended ink: 127.0 units. Engineer budget: 135.0. Standard checkpoints: 1. Wind zones: 0. Ferries: 0.

### 17. Polished Teeth · Wind Machine

Three short Solid bridges join alternating shelves. Brake on every island rather than carrying full speed into the next gap. Draw forward Boost through the final headwind tunnel.

Intended ink: 107.3 units. Engineer budget: 115.3. Standard checkpoints: 1. Wind zones: 1. Ferries: 0.

### 18. Cyan Express · Parcel Lock

Use a forward Boost bridge into the long climb. Stop at the summit checkpoint and use Solid for the descending final crossing. Push the final parcel into the crate-marked cradle and pass beneath the roof. At the gold plate, draw a short unsupported Solid stroke above it, resume, and let its weight hold the gate open.

Intended ink: 104.6 units. Engineer budget: 112.6. Standard checkpoints: 1. Wind zones: 0. Ferries: 0.

### 19. Snowbridge Study · Island Hop

Use Fragile on the first descent, a Solid ramp on the rise, and Ice for the last straight crossing. Keep moving over the Fragile span. Board the moving island, ride toward the exit, then time the jump onto the raised garden.

Intended ink: 106.8 units. Engineer budget: 114.8. Standard checkpoints: 1. Wind zones: 0. Ferries: 1.

### 20. Crown of Winter · Sky Ferry

A Solid ramp, Bounce ramp, Ice descent and Solid final ramp form a continuous route. Pause on the two checkpoint shelves to plan. Board the moving island, ride toward the exit, then time the jump onto the raised garden.

Intended ink: 214.5 units. Engineer budget: 222.5. Standard checkpoints: 2. Wind zones: 0. Ferries: 1.

## Desert Winds

### 21. A Gentle Headwind · Spring Garden

Draw a Solid bridge, then accelerate continuously through the marked headwind. The wide final climb is safe to wait on. Finish with a supported Bounce pad near the last bank and a controlled landing on the elevated island.

Intended ink: 34.4 units. Engineer budget: 42.4. Standard checkpoints: 0. Wind zones: 1. Ferries: 0.

### 22. Dune Rider · Wind Machine

Use Ice across the descending gap. Let the tailwind carry you, then brake on the long lower landing. Draw forward Boost through the final headwind tunnel.

Intended ink: 53.7 units. Engineer budget: 61.7. Standard checkpoints: 0. Wind zones: 2. Ferries: 0.

### 23. Return Current · Parcel Lock

Bridge both gaps with Solid. Release acceleration in the tailwind, then hold right through the opposing second current. Push the final parcel into the crate-marked cradle and pass beneath the roof. At the gold plate, draw a short unsupported Solid stroke above it, resume, and let its weight hold the gate open.

Intended ink: 71.6 units. Engineer budget: 79.6. Standard checkpoints: 1. Wind zones: 2. Ferries: 0.

### 24. Caravan Crossing · Island Hop

The conservative solution is a 440-pixel Solid bridge above the moving platform's travel path. Alternatively time a jump onto the ferry. Board the moving island, ride toward the exit, then time the jump onto the raised garden.

Intended ink: 34.4 units. Engineer budget: 42.4. Standard checkpoints: 0. Wind zones: 0. Ferries: 2.

### 25. Windward Stair · Sky Ferry

Place two rising bridges, using Boost on the headwind-facing first rise and Solid on the second. The middle shelf allows ink recovery. Board the moving island, ride toward the exit, then time the jump onto the raised garden.

Intended ink: 109.0 units. Engineer budget: 117.0. Standard checkpoints: 1. Wind zones: 1. Ferries: 1.

### 26. Sandglass · Spring Garden

Use a Fragile descent, Solid rise, and Fragile exit. Brake only on the two stone islands. Wind pressure is weakest near the islands. Finish with a supported Bounce pad near the last bank and a controlled landing on the elevated island.

Intended ink: 71.0 units. Engineer budget: 79.0. Standard checkpoints: 1. Wind zones: 2. Ferries: 0.

### 27. The High Ferry · Wind Machine

Draw a 360-pixel Solid rising ramp above the vertical ferry, then a Solid descending bridge from the upper rest shelf. Draw forward Boost through the final headwind tunnel.

Intended ink: 70.5 units. Engineer budget: 78.5. Standard checkpoints: 1. Wind zones: 1. Ferries: 1.

### 28. Amber Jet · Parcel Lock

Bridge the first gap with forward Boost to beat the headwind and climb the dune. Use a short Solid descending bridge after the checkpoint. Push the final parcel into the crate-marked cradle and pass beneath the roof. At the gold plate, draw a short unsupported Solid stroke above it, resume, and let its weight hold the gate open.

Intended ink: 108.5 units. Engineer budget: 116.5. Standard checkpoints: 1. Wind zones: 1. Ferries: 0.

### 29. Two Caravans · Island Hop

Three Solid spans connect the banks above two ferry tracks. The final rising bridge reaches the sheltered gate. Board the moving island, ride toward the exit, then time the jump onto the raised garden.

Intended ink: 107.2 units. Engineer budget: 115.2. Standard checkpoints: 1. Wind zones: 1. Ferries: 3.

### 30. Eye of the Sirocco · Sky Ferry

Use Solid, Fragile, Boost and Solid across the four crossings. The boost ramp counters the strongest headwind; each shelter supports a checkpoint. Board the moving island, ride toward the exit, then time the jump onto the raised garden.

Intended ink: 161.4 units. Engineer budget: 169.4. Standard checkpoints: 2. Wind zones: 2. Ferries: 2.

## Crystal Caverns

### 31. First Facet · Spring Garden

Two Solid ramps rise 120 and 110 pixels. Rest on the broad central crystal shelf before the second climb. Finish with a supported Bounce pad near the last bank and a controlled landing on the elevated island.

Intended ink: 73.2 units. Engineer budget: 81.2. Standard checkpoints: 1. Wind zones: 0. Ferries: 0.

### 32. Prism Tunnel · Wind Machine

Draw low Solid ramps through both roofed gaps. Stay grounded beneath the crystal ceiling rather than using Bounce. Draw forward Boost through the final headwind tunnel.

Intended ink: 71.5 units. Engineer budget: 79.5. Standard checkpoints: 1. Wind zones: 1. Ferries: 0.

### 33. Amethyst Springs · Parcel Lock

Use Bounce on the first two rising gaps and Solid on the third. Draw one spring at a time, using the broad shelves to recover ink. Push the final parcel into the crate-marked cradle and pass beneath the roof. At the gold plate, draw a short unsupported Solid stroke above it, resume, and let its weight hold the gate open.

Intended ink: 214.0 units. Engineer budget: 96.0. Standard checkpoints: 2. Wind zones: 0. Ferries: 0.

### 34. Needle Eye · Island Hop

Use three Solid ramps and brake on each narrow shelf. All ramps fit under the staggered roofs; avoid springing into the crystal undersides. Board the moving island, ride toward the exit, then time the jump onto the raised garden.

Intended ink: 107.2 units. Engineer budget: 115.2. Standard checkpoints: 1. Wind zones: 0. Ferries: 1.

### 35. Lantern Gallery · Sky Ferry

Solid reaches the first lantern, Fragile crosses the dip, and Bounce climbs the final 120-pixel rise. Checkpoint only on stable stone. Board the moving island, ride toward the exit, then time the jump onto the raised garden.

Intended ink: 144.5 units. Engineer budget: 152.5. Standard checkpoints: 2. Wind zones: 0. Ferries: 1.

### 36. Crystal Elevator · Spring Garden

Build three Solid rising bridges, bypassing the lift's shaft. The modest slopes allow controlled rolling through the tall chamber. Finish with a supported Bounce pad near the last bank and a controlled landing on the elevated island.

Intended ink: 108.0 units. Engineer budget: 116.0. Standard checkpoints: 2. Wind zones: 0. Ferries: 1.

### 37. Violet Channel · Wind Machine

Use Solid through the low first passage, Ice over the second rise, and Solid for the final descent. Brake before the last tunnel. Draw forward Boost through the final headwind tunnel.

Intended ink: 125.8 units. Engineer budget: 133.8. Standard checkpoints: 1. Wind zones: 1. Ferries: 0.

### 38. The Split Prism · Parcel Lock

Build Solid, Fragile, Solid and Solid ramps. Enter the Fragile segment already moving and rest on the larger third shelf. Push the final parcel into the crate-marked cradle and pass beneath the roof. At the gold plate, draw a short unsupported Solid stroke above it, resume, and let its weight hold the gate open.

Intended ink: 127.3 units. Engineer budget: 135.3. Standard checkpoints: 2. Wind zones: 0. Ferries: 0.

### 39. Resonant Vault · Island Hop

Use Bounce for the first rise, Solid for the second, and Boost for the third. Align gold chevrons uphill and brake on every landing. Board the moving island, ride toward the exit, then time the jump onto the raised garden.

Intended ink: 197.4 units. Engineer budget: 205.4. Standard checkpoints: 2. Wind zones: 0. Ferries: 1.

### 40. Heart of the Geode · Sky Ferry

Use Solid for the opening, Bounce for the second rise, Solid through the roofed third chamber, and Boost into the final high gallery. Board the moving island, ride toward the exit, then time the jump onto the raised garden.

Intended ink: 235.5 units. Engineer budget: 106.0. Standard checkpoints: 2. Wind zones: 0. Ferries: 1.

## Volcanic Core

### 41. Warm Welcome · Spring Garden

Two Solid bridges cross separate lava pools. Activate the stone checkpoint before entering the second pool. Finish with a supported Bounce pad near the last bank and a controlled landing on the elevated island.

Intended ink: 71.5 units. Engineer budget: 79.5. Standard checkpoints: 1. Wind zones: 0. Ferries: 0.

### 42. Ashfall Steps · Wind Machine

Use a Solid rise, short Fragile rise and Solid descent. The temporary bridge lasts long enough at ordinary rolling speed. Draw forward Boost through the final headwind tunnel.

Intended ink: 89.6 units. Engineer budget: 97.6. Standard checkpoints: 1. Wind zones: 1. Ferries: 0.

### 43. Furnace Ferry · Parcel Lock

Place a long Solid ramp above the horizontal ferry route, then another Solid ramp to the gate plateau. The checkpoint separates both stages. Push the final parcel into the crate-marked cradle and pass beneath the roof. At the gold plate, draw a short unsupported Solid stroke above it, resume, and let its weight hold the gate open.

Intended ink: 72.8 units. Engineer budget: 80.8. Standard checkpoints: 1. Wind zones: 0. Ferries: 1.

### 44. Cooling Channel · Island Hop

Use an Ice bridge at the foot of the long descent. Brake on the high stone shelf, then use Solid to cross the final lava channel. Board the moving island, ride toward the exit, then time the jump onto the raised garden.

Intended ink: 89.9 units. Engineer budget: 97.9. Standard checkpoints: 1. Wind zones: 0. Ferries: 1.

### 45. Cinder Rhythm · Sky Ferry

Four short bridges alternate Fragile, Solid, Fragile and Solid. Keep enough approach speed for each temporary crossing, and brake on the stone landings. Board the moving island, ride toward the exit, then time the jump onto the raised garden.

Intended ink: 106.0 units. Engineer budget: 114.0. Standard checkpoints: 1. Wind zones: 0. Ferries: 1.

### 46. Pressure Rise · Spring Garden

A Bounce ramp starts the climb, a Solid middle span provides stability, and a forward Boost ramp reaches the final shelf. Finish with a supported Bounce pad near the last bank and a controlled landing on the elevated island.

Intended ink: 196.2 units. Engineer budget: 204.2. Standard checkpoints: 2. Wind zones: 1. Ferries: 0.

### 47. Basalt Passage · Wind Machine

Use three Solid spans below the staggered basalt roof. Keep speed controlled while moving above the lava channels. Draw forward Boost through the final headwind tunnel.

Intended ink: 107.2 units. Engineer budget: 115.2. Standard checkpoints: 1. Wind zones: 1. Ferries: 0.

### 48. Ember Causeway · Parcel Lock

Use Solid, Fragile, Bounce and Ice across four lava channels. Checkpoint on basalt after the Fragile crossing, then spring onto the next ledge. Push the final parcel into the crate-marked cradle and pass beneath the roof. At the gold plate, draw a short unsupported Solid stroke above it, resume, and let its weight hold the gate open.

Intended ink: 197.2 units. Engineer budget: 205.2. Standard checkpoints: 2. Wind zones: 0. Ferries: 1.

### 49. The Last Ascent · Island Hop

Build Solid, Bounce, Solid and forward Boost ramps through the four-step climb. Wait at the stone lanterns if you need regenerated ink. Board the moving island, ride toward the exit, then time the jump onto the raised garden.

Intended ink: 235.2 units. Engineer budget: 106.0. Standard checkpoints: 2. Wind zones: 1. Ferries: 1.

### 50. Find Your Momentum · Sky Ferry

The intended finale route uses Solid up to the first shelf, Fragile over the dip, Bounce up the third channel, Ice over the fourth, and forward Boost into the gate climb. Activate both basalt checkpoints and use the generous rest shelves to regenerate ink between stages. Board the moving island, ride toward the exit, then time the jump onto the raised garden.

Intended ink: 268.9 units. Engineer budget: 110.0. Standard checkpoints: 2. Wind zones: 1. Ferries: 3.
