# Send me a level design

You can send **plain text, a labelled sketch/screenshot, or JSON**. A sketch plus
an intended solution is enough; exact coordinates are optional. Tell me what
each object does and what must prevent the obvious shortcut. I will translate
the design into game data, check its physics, and rebuild the browser preview.

Copy and fill this:

```text
Level name:
World/theme:
Main puzzle idea (one sentence):
Player start:
Goal:

Islands/terrain:
- A: position, approximate width/height; fixed or moving
- B: position; if moving, from -> to, horizontal/vertical, travel time

Objects:
- Crate/parcel: where it starts, where it must end
- Switch: what activates it (ball, any weight, or a specific parcel)
- Door: which switch opens it; stays open or closes when released
- Wind/hazard: position, direction/strength or timing

Ink supply:
Buildable zones:
No-build zones:
Checkpoints:

Intended solution, step by step:
Why simply jumping / drawing one Solid bridge should fail:
Other clever solutions that should be allowed:
Difficulty (easy/medium/hard):
```

Example: “Start on the left grassy bank. A small island travels horizontally
between the bank and a high fixed island. You must first push a labelled crate
onto a switch to open a door on the bank. Build only on the bank, then jump onto
the moving island, ride it, and use Bounce near the far end to reach the goal.
A full bridge must be impossible because the channel is a no-build zone.”

## Coordinates if you want precision

- Units are **Godot world pixels**, not browser screenshot pixels. X increases
  rightward; Y increases downward. `(0,0)` is the level's top left.
- The ball is 36 pixels across. Its initial center should be approximately
  20 pixels above a supporting surface.
- A normal jump rises approximately 100 pixels; allow margins. Start with
  60–80-pixel steps, 120–220-pixel gaps and 150–220-pixel landing widths.
- A flat Bounce launch is substantially higher, but run-up, launch position and
  landing width matter. Don't use its theoretical peak as guaranteed clearance.
- Terrain polygons use absolute world coordinates. A floating island is a thin
  polygon, rather than one extending to the bottom of the map.
- Moving-island `from`/`to` values are **body centers**. `period` is a full
  out-and-back cycle in seconds. Its movement pauses in Draw Mode.
- Build/no-build rectangles are `[left, top, width, height]`.

## JSON vocabulary

The game loads `data/levels/campaign.json`. The first ten puzzles and the later
mechanic stations are authored in `data/levels/puzzle_workshop.py`, called by
`author_campaign.py`. Editing generated JSON alone is temporary if that generator
is run again; tell me whether your design should replace a slot or become a new
campaign stage.

```json
{
  "id": 3,
  "name": "My Moving Garden",
  "biome": 0,
  "width": 1600,
  "height": 900,
  "start": [140, 560],
  "finish": [1440, 462],
  "terrain": [
    {"points": [[0,580],[400,580],[400,900],[0,900]], "surface":"solid", "role":"ground"},
    {"points": [[1030,500],[1600,500],[1600,535],[1030,535]], "surface":"solid", "role":"ground"}
  ],
  "platforms": [{"from":[510,560],"to":[900,520],"size":[180,22],"period":6,"island":true}],
  "crates": [{"id":"parcel","position":[320,560],"size":[36,36],"mass":2}],
  "gates": [],
  "winds": [],
  "hazards": [],
  "build_regions": [[40,540,310,38]],
  "no_build_regions": [[401,0,628,900]],
  "allowed_inks": ["solid","bounce"],
  "ink": 40,
  "regen": 5,
  "budget": 30,
  "checkpoints": [],
  "pickups": [],
  "hint": "Time boarding the travelling garden.",
  "solution": "Wait for the island, jump onto it, ride right, then jump to the goal."
}
```

Other supported objects:

```json
{
  "gates": [{"plate":[800,600],"gate":[1050,600],"crate_only":true,"object_id":"parcel","latch":true}],
  "winds": [{"rect":[400,0,900,900],"force":[-2600,0]}],
  "crates": [{"id":"cargo","position":[590,280],"release_on_ink_below":true}]
}
```

`plate` is the floor contact point; `gate` is its bottom center. A gate is 190
pixels tall. Parcel IDs must match `object_id`; otherwise that parcel will not
activate the marked switch. A cargo dispenser waits until a physical ink stroke
exists below it, then releases the crate to gravity.

## What makes a useful puzzle brief

Describe a **causal chain**: build chute → release parcel → parcel slides → switch
opens door → board island → time landing. Specify failure cases, reset rules and
where the player can experiment safely. Restrictions should be visible and
explained, and alternative solutions should remain welcome when they actually
solve the same physical problem.
