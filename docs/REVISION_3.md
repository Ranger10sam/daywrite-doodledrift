# Mechanic-led puzzles and manual level authoring

Revision 3 replaces the ten opening stages with authored puzzle layouts rather
than a sequence of long bridges. The remaining forty authored routes gain a
mechanic-dependent final station: elevated spring gardens, headwind tunnels,
crate-locked doors or travelling islands across no-build channels.

The first ten are Spring to Sky Garden, Amber Headwind, The Wandering Orchard,
Special Delivery, Borrowed Time, Slippery Freight, Two Keys One Door, Elevator
Picnic, Bounce and Brake, and Garden Contraption. Hints and ink inventories now
match their mechanics. Unavailable ink buttons are visibly disabled.

New reusable objects include falling/pushable labelled parcels, crate-specific
switches, matching doors, gravity-fed cargo dispensers, horizontally travelling
islands and vertical elevators. Frozen-island motion uses the existing fixed-step
AnimatableBody implementation. Draw Mode pauses both platforms and physics.
No-build regions prevent bypassing those timing puzzles with a single bridge.
Crates reset explicitly on checkpoint restoration. Labels distinguish parcels
without relying solely on color.

## Actual verification

`tests/puzzle_suite.gd` exercises actual production physics. Actual finish triggers were reached
using Bounce for the high garden, Boost against the headwind and Fragile through
the low-roof crossing. Actual controls also push the parcel into its switch,
hop over it, and reach the Special Delivery goal. Matching Solid attempts failed the spring/wind puzzles.
The moving island moves and its channel rejects a generic bridge. A ball cannot
unlock the crate-specific switch; the matching real rigid-body crate can. Cargo
slides down an Ice chute to activate its switch, while the corresponding grippy
Solid chute stalls the cargo. Ink outside the Fragile tutorial supply is rejected.

This is not a new 50-level solved-route claim: the previous campaign solver only
knows how to place Solid bridges and weights and is not a solver for timed island
transfers, labelled parcel delivery or the new stations. Human playthroughs and
more scripted timing routes remain necessary, especially for stages 7–10 and
the later campaign. Previous revision reports do not certify these layouts.

## Create your own

See [LEVEL_DESIGN_TEMPLATE.md](LEVEL_DESIGN_TEMPLATE.md). Send plain text, a
labelled sketch, or JSON. Describe the intended chain of interactions, the
shortcut that must fail, and which alternative solutions should remain valid.

Source of truth: `data/levels/puzzle_workshop.py`, applied by
`python data/levels/author_campaign.py`. Definitions are compiled into the browser
pack by `tools/build-web.ps1`. No solution drawings are placed automatically.
