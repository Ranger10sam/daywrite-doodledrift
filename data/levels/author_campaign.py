"""Editable campaign source. Run with Python 3 to regenerate the checked-in JSON.

Every top contour is authored here, rather than reskinning one procedural map.
Coordinates are world pixels, y down. A contour becomes a filled terrain polygon.
"""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LEVELS: list[dict] = []


def add(name, contours, hint, solution, inks=(), *, width=None, ceiling=(), winds=(),
        platforms=(), checkpoints=(), extras=(), budget=None, pickup=True):
    ident = len(LEVELS) + 1
    biome = (ident - 1) // 10
    # Deliberate build puzzles: even a full-speed ordinary jump cannot clear
    # these channels. Preserve each authored contour, roof, wind and checkpoint.
    if ident == 1:
        name, contours = "Meadow Bridge", [[[0, 560], [480, 560]], [[700, 560], [1800, 560]]]
        hint = "Draw a bridge with BOTH ends on the banks. Floating lines fall when you press Done!"
        solution = "Join the two bank edges with Solid ink. Bolts show that both ends are supported, then roll across."
    elif ident == 2:
        name, contours = "Ramp Garden", [[[0, 620], [480, 620]], [[730, 500], [1900, 500]]]
        hint = "Build an anchored uphill ramp. Jumping alone cannot reach the next garden."
        solution = "Place a Solid ramp from the lower bank to the upper bank. Roll up the ramp and brake at the garden."
    gaps = [(a[-1][0], b[0][0], 860 + ((ident + j) % 3) * 32) for j, (a, b) in enumerate(zip(contours, contours[1:]))]
    def map_x(x):
        shift = 0
        for a, b, new_width in gaps:
            if x <= a: return x + shift
            if x < b: return a + shift + (x-a) * new_width / (b-a)
            shift += new_width - (b-a)
        return x + shift
    old_width = width or contours[-1][-1][0]
    ceiling = [[[map_x(x), y] for x,y in poly] for poly in ceiling]
    winds = [dict(rect=[map_x(z['rect'][0]), z['rect'][1], map_x(z['rect'][0]+z['rect'][2])-map_x(z['rect'][0]), z['rect'][3]], force=z['force']) for z in winds]
    platforms = [{**p, 'from':[map_x(p['from'][0]),p['from'][1]], 'to':[map_x(p['to'][0]),p['to'][1]]} for p in platforms]
    extras = [{**e, 'points':[[map_x(x),y] for x,y in e['points']]} for e in extras]
    checkpoints = [map_x(x) for x in checkpoints]
    contours = [[[map_x(x), y] for x,y in p] for p in contours]
    width = map_x(old_width)
    width = width or contours[-1][-1][0]
    surface = "ice" if biome == 1 else "solid"
    terrain = [dict(points=[*p, [p[-1][0], 900], [p[0][0], 900]], surface=surface,
                    role="ground") for p in contours]
    terrain += [dict(points=p, surface="solid", role="ceiling") for p in ceiling]
    terrain += list(extras)
    strokes, hazards = [], []
    for n, (left, right) in enumerate(zip(contours, contours[1:])):
        a, b = left[-1], right[0]
        kind = inks[n] if n < len(inks) else "solid"
        # Eight pixels gives a six-pixel capsule perpendicular clearance at
        # sloped terrain lips, rather than only clearance in the vertical axis.
        strokes.append(dict(ink=kind, points=[[a[0], a[1] - 8], [b[0], b[1] - 8]], reverse=False))
        hy = max(a[1], b[1]) + (62 if biome == 4 else 120)
        hazards.append(dict(rect=[a[0] + 4, hy, max(8, b[0] - a[0] - 8), 900 - hy],
                            type="lava" if biome == 4 else "spikes"))
    # Start/finish and checkpoint are ball/gate centers, not floor positions.
    def top_y(contour, x):
        for a, b in zip(contour, contour[1:]):
            if a[0] <= x <= b[0]:
                t = (x - a[0]) / (b[0] - a[0])
                return round(a[1] + (b[1] - a[1]) * t, 3)
        raise ValueError((name, x))
    start_x = 140
    finish_x = width - 130
    start = [start_x, top_y(contours[0], start_x) - 20]
    finish = [finish_x, top_y(contours[-1], finish_x) - 38]
    cps = []
    for x in checkpoints:
        for p in contours:
            if p[0][0] + 35 < x < p[-1][0] - 35:
                cps.append([x, top_y(p, x) - 20])
                break
        else:
            raise ValueError((name, "checkpoint outside terrain", x))
    # Easy mode gets these safe intermediate floor anchors in addition to standard ones.
    easy_cps = []
    for p in contours[1:-1]:
        if p[-1][0] - p[0][0] >= 130:
            x = round((p[0][0] + p[-1][0]) / 2)
            easy_cps.append([x, top_y(p, x) - 20])
    mult = dict(solid=1, bounce=2.5, boost=2, ice=1.5, fragile=.5)
    cost = sum(((s['points'][-1][0] - s['points'][0][0]) ** 2 +
               (s['points'][-1][1] - s['points'][0][1]) ** 2) ** .5 * .04 * mult[s['ink']]
               for s in strokes)
    route = []
    for contour in contours:
        route.extend([[x, y - 20] for x, y in contour])
    pickups = []
    if pickup and len(contours) >= 3:
        p = contours[len(contours)//2]
        x = round((p[0][0] + p[-1][0]) / 2)
        pickups.append([x, top_y(p, x) - 52])
    LEVELS.append(dict(
        id=ident, name=name, biome=biome, width=width, height=900,
        start=start, finish=finish, terrain=terrain, hazards=hazards,
        checkpoints=cps, easy_checkpoints=easy_cps, pickups=pickups,
        winds=list(winds), platforms=list(platforms),
        build_regions=[[30, 100, width - 60, 690]], ink=100, regen=5,
        budget=budget if budget is not None else round(max(18, cost + 8), 1),
        hint=hint, solution=solution, solution_strokes=strokes,
        solution_route=route, solution_ink_cost=round(cost, 3),
        gates=([dict(plate=[finish_x-400, top_y(contours[-1], finish_x-400)], gate=[finish_x-190, top_y(contours[-1], finish_x-190)])] if ident % 5 == 0 or ident == 2 else []),
        mastery_note="Explorer: finish. Engineer: net spent ink within budget. Master: no deaths.",
    ))


def wind(x, y, w, h, fx, fy=0):
    return dict(rect=[x, y, w, h], force=[fx, fy])


def platform(a, b, size=(140, 20), period=4.0):
    return dict(**{"from": a, "to": b}, size=list(size), period=period)


# GREEN VALLEY — one idea per introductory stage.
add("First Roll", [[[0, 560], [520, 560], [760, 530], [1110, 530], [1450, 560], [1800, 560]]],
    "Hold a direction. Keep rolling toward the ring.",
    "Roll right across the shallow dip and crest. No drawing or jump is required.", pickup=False)
add("Uphill Battle", [[[0, 590], [380, 590], [720, 450], [950, 450], [1320, 590], [1900, 590]]],
    "Build speed before the hill. Brake gently on the way down.",
    "Accelerate on the opening flat, carry momentum up the long hill, then brake before the finish.", pickup=False)
add("Missing Path", [[[0, 560], [540, 560]], [[720, 560], [1800, 560]]],
    "DRAW pauses the world. Connect the two grassy edges with Solid ink.",
    "Draw one 180-pixel Solid bridge above the lips, exit Draw, and roll across.", ["solid"], pickup=False)
add("Build a Launch", [[[0, 620], [470, 620]], [[730, 520], [1140, 520], [1430, 570], [1920, 570]]],
    "A rising line becomes a ramp. Start at the lower edge.",
    "Draw a rising Solid ramp across the 260-pixel gap. Accelerate up it to reach the high bank.", ["solid"], pickup=False)
add("Spring Forward", [[[0, 620], [540, 620]], [[750, 530], [1030, 530], [1340, 580], [1920, 580]]],
    "Purple Bounce ink pushes away from its surface. Try a gentle rising spring.",
    "Place a Bounce ramp across the gap. Approach slowly; the outward normal lifts the ball onto the higher meadow.", ["bounce"], pickup=False)
add("Speed Trail", [[[0, 550], [640, 550]], [[920, 550], [1210, 550], [1490, 480], [2040, 480]]],
    "Gold chevrons show Boost direction. Draw left to right for forward speed.",
    "Bridge with forward Boost ink and ride its tangential acceleration toward the long hill; brake at the summit.", ["boost"], pickup=False)
add("Slippery Slope", [[[0, 460], [410, 460], [710, 610]], [[940, 610], [1260, 550], [1980, 550]]],
    "Ice keeps your momentum. Give yourself room to brake.",
    "Draw a 230-pixel Ice bridge at the bottom of the descent. Coast across, then brake on the grassy landing.", ["ice"], pickup=False)
add("Breaking Point", [[[0, 570], [590, 570]], [[770, 560], [1130, 560], [1480, 590], [1920, 590]]],
    "Fragile ink starts cracking on contact. Keep moving.",
    "Create a cheap Fragile bridge. Enter at speed and cross its 180 pixels before the 1.5-second crack timer expires.", ["fragile"], pickup=False)
add("Double Solution", [[[0, 600], [500, 600]], [[700, 550], [1050, 550]], [[1260, 600], [2150, 600]]],
    "A bridge, a spring, or a boost can all solve a gap.",
    "One conservative route uses a Solid rising bridge, then a Fragile descending bridge. Bounce or Boost alternatives also work.", ["solid", "fragile"], checkpoints=[900])
add("Valley Finale", [[[0, 610], [480, 610]], [[650, 550], [1040, 550]], [[1260, 600], [1660, 600]], [[1900, 520], [2600, 520]]],
    "Three crossings, three ideas. Reach the lantern to save a checkpoint.",
    "Use Solid for the first rise, Bounce for the middle dip, then forward Boost for the final rise. Checkpoint between stages.",
    ["solid", "bounce", "boost"], checkpoints=[850, 1480])

# FROZEN PEAKS — ice ground, long slopes, landing precision, and recovery space.
add("Snowline", [[[0, 500], [350, 500], [690, 640]], [[880, 640], [1160, 560], [2030, 560]]],
    "Snow is slippery. Brake before the crest, not after it.",
    "Coast down the icy descent onto a Solid bridge, then use gradual braking along the long uphill runout.", ["solid"])
add("Blue Switchback", [[[0, 630], [420, 630]], [[660, 540], [920, 540]], [[1130, 600], [1470, 480], [2180, 480]]],
    "Use each uphill section to shed speed naturally.",
    "Join the first gap with a Solid ramp and the second with Ice. Release the accelerator on the landing, then climb the final slope.", ["solid", "ice"], checkpoints=[790])
add("Needle Landing", [[[0, 540], [540, 540]], [[800, 570], [960, 570]], [[1220, 520], [2080, 520]]],
    "The central shelf is small. Touch Brake before entering it.",
    "Use two Solid bridges through the 160-pixel central shelf. Slow down on the first crossing before taking the second rise.", ["solid", "solid"], checkpoints=[880])
add("Glacier Run", [[[0, 430], [360, 430], [790, 660]], [[1100, 660], [1470, 530], [2370, 530]]],
    "A long descent stores plenty of speed. Keep the bridge shallow.",
    "Draw a straight Ice bridge across the 310-pixel runout. Let the climb on the far side absorb momentum.", ["ice"])
add("The Quiet Shelf", [[[0, 590], [460, 590]], [[650, 510], [1060, 510]], [[1220, 510], [1550, 570], [2210, 570]]],
    "A wide shelf is a good place to stop and draw again.",
    "Build a rising Solid bridge, stop on the high shelf, and place a short Fragile bridge for the second crossing.", ["solid", "fragile"], checkpoints=[850])
add("Frost Arc", [[[0, 620], [460, 620]], [[710, 500], [1030, 500], [1280, 620]], [[1510, 620], [2270, 620]]],
    "A spring can lift you; a long landing keeps the next move calm.",
    "Use a Bounce ramp for the 120-pixel rise, land on the wide ice crest, then make a Solid bridge at the bottom.", ["bounce", "solid"], checkpoints=[890])
add("Polished Teeth", [[[0, 550], [420, 550]], [[570, 600], [740, 600]], [[940, 530], [1130, 530]], [[1290, 580], [2250, 580]]],
    "Short bridges are cheap. Place the next one while physics is paused.",
    "Three short Solid bridges join alternating shelves. Brake on every island rather than carrying full speed into the next gap.", ["solid", "solid", "solid"], checkpoints=[1040])
add("Cyan Express", [[[0, 610], [550, 610]], [[870, 600], [1220, 450], [1530, 450]], [[1730, 510], [2450, 510]]],
    "Boost supplies the climb; the summit supplies a safe rest.",
    "Use a forward Boost bridge into the long climb. Stop at the summit checkpoint and use Solid for the descending final crossing.", ["boost", "solid"], checkpoints=[1370])
add("Snowbridge Study", [[[0, 510], [460, 510]], [[660, 590], [900, 590]], [[1140, 500], [1430, 500]], [[1640, 560], [2460, 560]]],
    "Different inks change how you arrive, even when the route is the same.",
    "Use Fragile on the first descent, a Solid ramp on the rise, and Ice for the last straight crossing. Keep moving over the Fragile span.", ["fragile", "solid", "ice"], checkpoints=[1280])
add("Crown of Winter", [[[0, 650], [450, 650]], [[660, 550], [950, 550]], [[1160, 460], [1460, 460]], [[1710, 550], [2080, 550]], [[2280, 480], [2960, 480]]],
    "Climb in stages. You can wait safely on each broad shelf for ink.",
    "A Solid ramp, Bounce ramp, Ice descent and Solid final ramp form a continuous route. Pause on the two checkpoint shelves to plan.", ["solid", "bounce", "ice", "solid"], checkpoints=[810, 1870])

# DESERT WINDS — marked wind volumes and moving platforms with drawable alternatives.
add("A Gentle Headwind", [[[0, 570], [550, 570]], [[770, 570], [1150, 500], [2110, 500]]],
    "Sand streaks point with the wind. Hold right to lean into it.",
    "Draw a Solid bridge, then accelerate continuously through the marked headwind. The wide final climb is safe to wait on.", ["solid"], winds=[wind(490, 310, 760, 380, -125)])
add("Dune Rider", [[[0, 610], [340, 610], [690, 470]], [[970, 550], [1320, 630], [2220, 630]]],
    "A tailwind carries momentum over the dune.",
    "Use Ice across the descending gap. Let the tailwind carry you, then brake on the long lower landing.", ["ice"], winds=[wind(350, 290, 1000, 390, 110)])
add("Return Current", [[[0, 560], [480, 560]], [[720, 510], [1030, 510]], [[1270, 590], [2200, 590]]],
    "One current helps; the next pushes back. Watch the sand.",
    "Bridge both gaps with Solid. Release acceleration in the tailwind, then hold right through the opposing second current.", ["solid", "solid"], winds=[wind(390, 300, 620, 380, 140), wind(1080, 300, 680, 380, -140)], checkpoints=[880])
add("Caravan Crossing", [[[0, 590], [540, 590]], [[980, 590], [1380, 520], [2350, 520]]],
    "The sandstone platform moves. Ride it or draw your own bridge.",
    "The conservative solution is a 440-pixel Solid bridge above the moving platform's travel path. Alternatively time a jump onto the ferry.", ["solid"], platforms=[platform([600, 650], [900, 650], (150, 22), 5.2)])
add("Windward Stair", [[[0, 660], [470, 660]], [[700, 560], [980, 560]], [[1220, 450], [2180, 450]]],
    "Boost direction follows your line, including on a ramp.",
    "Place two rising bridges, using Boost on the headwind-facing first rise and Solid on the second. The middle shelf allows ink recovery.", ["boost", "solid"], winds=[wind(450, 300, 680, 430, -150)], checkpoints=[840])
add("Sandglass", [[[0, 540], [490, 540]], [[650, 610], [810, 610]], [[1010, 530], [1230, 530]], [[1420, 590], [2340, 590]]],
    "Stay moving over pink lines; rest on stone.",
    "Use a Fragile descent, Solid rise, and Fragile exit. Brake only on the two stone islands. Wind pressure is weakest near the islands.", ["fragile", "solid", "fragile"], winds=[wind(550, 360, 210, 270, 95), wind(1250, 360, 270, 290, -95)], checkpoints=[1120])
add("The High Ferry", [[[0, 620], [520, 620]], [[880, 500], [1200, 500]], [[1480, 570], [2420, 570]]],
    "You may bypass a moving platform with a planned ramp.",
    "Draw a 360-pixel Solid rising ramp above the vertical ferry, then a Solid descending bridge from the upper rest shelf.", ["solid", "solid"], platforms=[platform([660, 690], [660, 510], (150, 20), 4.4)], checkpoints=[1040])
add("Amber Jet", [[[0, 610], [590, 610]], [[940, 560], [1270, 440], [1580, 440]], [[1820, 510], [2570, 510]]],
    "The long approach rewards momentum. Brake on the high plateau.",
    "Bridge the first gap with forward Boost to beat the headwind and climb the dune. Use a short Solid descending bridge after the checkpoint.", ["boost", "solid"], winds=[wind(530, 260, 830, 440, -180)], checkpoints=[1420])
add("Two Caravans", [[[0, 570], [470, 570]], [[800, 570], [1100, 500]], [[1460, 550], [1810, 550]], [[2030, 490], [2750, 490]]],
    "Ferries are optional. Your ink can make a stable route above them.",
    "Three Solid spans connect the banks above two ferry tracks. The final rising bridge reaches the sheltered gate.", ["solid", "solid", "solid"],
    platforms=[platform([520, 650], [730, 650], (130, 20), 3.8), platform([1190, 630], [1360, 630], (130, 20), 5.0)],
    winds=[wind(1130, 300, 420, 340, 135)], checkpoints=[1650])
add("Eye of the Sirocco", [[[0, 650], [470, 650]], [[680, 560], [1000, 560]], [[1240, 630], [1540, 630]], [[1780, 520], [2110, 520]], [[2330, 480], [3050, 480]]],
    "Work from shelter to shelter. Wind never consumes your ink while drawing.",
    "Use Solid, Fragile, Boost and Solid across the four crossings. The boost ramp counters the strongest headwind; each shelter supports a checkpoint.",
    ["solid", "fragile", "boost", "solid"], winds=[wind(450, 300, 520, 400, 125), wind(1610, 250, 710, 440, -165)],
    platforms=[platform([1110, 710], [1450, 710], (120, 18), 4.7)], checkpoints=[840, 1930])

# CRYSTAL CAVERNS — rising routes, roofed chambers, narrow ledges, and staged springs.
add("First Facet", [[[0, 680], [450, 680]], [[690, 560], [1010, 560]], [[1240, 450], [2110, 450]]],
    "Build upward in two stages. The camera follows your climb.",
    "Two Solid ramps rise 120 and 110 pixels. Rest on the broad central crystal shelf before the second climb.", ["solid", "solid"], checkpoints=[850])
add("Prism Tunnel", [[[0, 600], [460, 600]], [[650, 560], [1020, 560]], [[1210, 510], [2240, 510]]],
    "The tunnel has room for a ball and a low bridge. Keep lines close to the floor.",
    "Draw low Solid ramps through both roofed gaps. Stay grounded beneath the crystal ceiling rather than using Bounce.", ["solid", "solid"],
    ceiling=[[[390, 360], [1080, 360], [1080, 460], [390, 460]], [[1110, 290], [1780, 290], [1780, 405], [1110, 405]]], checkpoints=[840])
add("Amethyst Springs", [[[0, 680], [450, 680]], [[660, 560], [960, 560]], [[1180, 440], [1460, 440]], [[1680, 340], [2390, 340]]],
    "Three spring ramps rise toward the light. Land before drawing again.",
    "Use Bounce on the first two rising gaps and Solid on the third. Draw one spring at a time, using the broad shelves to recover ink.", ["bounce", "bounce", "solid"], checkpoints=[810, 1320], budget=96)
add("Needle Eye", [[[0, 580], [500, 580]], [[690, 520], [850, 520]], [[1060, 460], [1260, 460]], [[1450, 430], [2260, 430]]],
    "Short rising ramps keep the route inside the low ceiling.",
    "Use three Solid ramps and brake on each narrow shelf. All ramps fit under the staggered roofs; avoid springing into the crystal undersides.", ["solid", "solid", "solid"],
    ceiling=[[[570, 260], [930, 260], [930, 410], [570, 410]], [[980, 210], [1350, 210], [1350, 350], [980, 350]]], checkpoints=[1160])
add("Lantern Gallery", [[[0, 650], [480, 650]], [[740, 540], [1090, 540]], [[1340, 590], [1690, 590]], [[1930, 470], [2660, 470]]],
    "A long gallery rewards a calm multi-stage plan.",
    "Solid reaches the first lantern, Fragile crosses the dip, and Bounce climbs the final 120-pixel rise. Checkpoint only on stable stone.", ["solid", "fragile", "bounce"], checkpoints=[910, 1510])
add("Crystal Elevator", [[[0, 690], [460, 690]], [[780, 550], [1100, 550]], [[1390, 420], [1720, 420]], [[1960, 330], [2700, 330]]],
    "The lift offers another route. A chain of ramps stays predictable.",
    "Build three Solid rising bridges, bypassing the lift's shaft. The modest slopes allow controlled rolling through the tall chamber.", ["solid", "solid", "solid"],
    platforms=[platform([620, 740], [620, 490], (140, 20), 5.6)], checkpoints=[940, 1550])
add("Violet Channel", [[[0, 610], [450, 610]], [[640, 560], [920, 560]], [[1150, 490], [1430, 490]], [[1650, 540], [2430, 540]]],
    "A fast ink is not always a safe ink under a roof.",
    "Use Solid through the low first passage, Ice over the second rise, and Solid for the final descent. Brake before the last tunnel.", ["solid", "ice", "solid"],
    ceiling=[[[370, 340], [960, 340], [960, 450], [370, 450]], [[1550, 290], [2180, 290], [2180, 420], [1550, 420]]], checkpoints=[1280])
add("The Split Prism", [[[0, 660], [420, 660]], [[600, 590], [790, 590]], [[1000, 510], [1290, 510]], [[1480, 410], [1710, 410]], [[1930, 350], [2680, 350]]],
    "Small ledges divide the climb into decisions.",
    "Build Solid, Fragile, Solid and Solid ramps. Enter the Fragile segment already moving and rest on the larger third shelf.", ["solid", "fragile", "solid", "solid"], checkpoints=[1140, 1600])
add("Resonant Vault", [[[0, 690], [500, 690]], [[750, 570], [1070, 570]], [[1330, 450], [1640, 450]], [[1900, 330], [2710, 330]]],
    "A spring followed by a stable ramp makes a controlled ascent.",
    "Use Bounce for the first rise, Solid for the second, and Boost for the third. Align gold chevrons uphill and brake on every landing.", ["bounce", "solid", "boost"], checkpoints=[900, 1480])
add("Heart of the Geode", [[[0, 700], [460, 700]], [[660, 610], [920, 610]], [[1150, 500], [1440, 500]], [[1680, 380], [1970, 380]], [[2200, 280], [3000, 280]]],
    "Climb four facets. Think one safe landing ahead.",
    "Use Solid for the opening, Bounce for the second rise, Solid through the roofed third chamber, and Boost into the final high gallery.", ["solid", "bounce", "solid", "boost"],
    ceiling=[[[1580, 140], [2060, 140], [2060, 260], [1580, 260]]], checkpoints=[800, 1820], budget=106)

# VOLCANIC CORE — lava under every gap; collapsing side shelves and timing alternatives.
add("Warm Welcome", [[[0, 580], [520, 580]], [[740, 540], [1070, 540]], [[1290, 590], [2180, 590]]],
    "Lava resets you immediately. Bridges keep the route calm.",
    "Two Solid bridges cross separate lava pools. Activate the stone checkpoint before entering the second pool.", ["solid", "solid"], checkpoints=[900])
add("Ashfall Steps", [[[0, 650], [450, 650]], [[650, 560], [880, 560]], [[1080, 470], [1340, 470]], [[1540, 530], [2340, 530]]],
    "Keep moving across pink spans. The stone shelves are safe.",
    "Use a Solid rise, short Fragile rise and Solid descent. The temporary bridge lasts long enough at ordinary rolling speed.", ["solid", "fragile", "solid"], checkpoints=[1210])
add("Furnace Ferry", [[[0, 610], [540, 610]], [[940, 550], [1290, 550]], [[1570, 490], [2470, 490]]],
    "The ferry crosses lava. A drawn path can pass above it.",
    "Place a long Solid ramp above the horizontal ferry route, then another Solid ramp to the gate plateau. The checkpoint separates both stages.", ["solid", "solid"],
    platforms=[platform([620, 700], [850, 700], (150, 20), 3.6)], checkpoints=[1110])
add("Cooling Channel", [[[0, 490], [430, 490], [710, 640]], [[960, 640], [1240, 550], [1550, 550]], [[1800, 510], [2570, 510]]],
    "Ice saves the momentum you need after the descent.",
    "Use an Ice bridge at the foot of the long descent. Brake on the high stone shelf, then use Solid to cross the final lava channel.", ["ice", "solid"], checkpoints=[1390])
add("Cinder Rhythm", [[[0, 600], [450, 600]], [[620, 570], [800, 570]], [[990, 620], [1190, 620]], [[1380, 530], [1640, 530]], [[1840, 590], [2690, 590]]],
    "Rest on stone, cross pink quickly. Find a steady rhythm.",
    "Four short bridges alternate Fragile, Solid, Fragile and Solid. Keep enough approach speed for each temporary crossing, and brake on the stone landings.", ["fragile", "solid", "fragile", "solid"], checkpoints=[1510])
add("Pressure Rise", [[[0, 680], [480, 680]], [[720, 570], [1010, 570]], [[1260, 450], [1550, 450]], [[1790, 370], [2630, 370]]],
    "Spring away from the heat; use Boost to finish the climb.",
    "A Bounce ramp starts the climb, a Solid middle span provides stability, and a forward Boost ramp reaches the final shelf.", ["bounce", "solid", "boost"],
    winds=[wind(1100, 280, 650, 350, -105)], checkpoints=[870, 1400])
add("Basalt Passage", [[[0, 590], [460, 590]], [[650, 540], [940, 540]], [[1150, 500], [1450, 500]], [[1690, 560], [2520, 560]]],
    "Basalt ceilings make low bridges safer than high jumps.",
    "Use three Solid spans below the staggered basalt roof. Keep speed controlled while moving above the lava channels.", ["solid", "solid", "solid"],
    ceiling=[[[380, 300], [1000, 300], [1000, 430], [380, 430]], [[1060, 230], [1500, 230], [1500, 390], [1060, 390]], [[1580, 300], [2120, 300], [2120, 440], [1580, 440]]], checkpoints=[1290])
add("Ember Causeway", [[[0, 640], [440, 640]], [[640, 550], [850, 550]], [[1060, 590], [1280, 590]], [[1510, 480], [1760, 480]], [[1970, 530], [2780, 530]]],
    "Plan a stable landing after every spring.",
    "Use Solid, Fragile, Bounce and Ice across four lava channels. Checkpoint on basalt after the Fragile crossing, then spring onto the next ledge.", ["solid", "fragile", "bounce", "ice"],
    platforms=[platform([910, 720], [1190, 720], (110, 18), 3.2)], checkpoints=[1170, 1640])
add("The Last Ascent", [[[0, 700], [450, 700]], [[650, 610], [920, 610]], [[1160, 500], [1460, 500]], [[1700, 390], [1990, 390]], [[2220, 310], [3040, 310]]],
    "Draw between safe shelves. The final wind rewards an uphill boost.",
    "Build Solid, Bounce, Solid and forward Boost ramps through the four-step climb. Wait at the stone lanterns if you need regenerated ink.", ["solid", "bounce", "solid", "boost"],
    winds=[wind(2040, 170, 650, 390, -150)], checkpoints=[790, 1840], budget=106)
add("Find Your Momentum", [[[0, 680], [470, 680]], [[650, 600], [910, 600]], [[1120, 650], [1380, 650]], [[1600, 540], [1890, 540]], [[2110, 470], [2410, 470]], [[2620, 390], [3440, 390]]],
    "Five inks. Five crossings. Your path is yours.",
    "The intended finale route uses Solid up to the first shelf, Fragile over the dip, Bounce up the third channel, Ice over the fourth, and forward Boost into the gate climb. Activate both basalt checkpoints and use the generous rest shelves to regenerate ink between stages.",
    ["solid", "fragile", "bounce", "ice", "boost"],
    platforms=[platform([990, 750], [1300, 750], (120, 18), 4.8), platform([2270, 700], [2270, 560], (120, 18), 4.2)],
    winds=[wind(2520, 200, 640, 400, -110)], checkpoints=[1250, 2260], budget=110)


def main():
    from puzzle_workshop import revise
    revise(LEVELS)
    target = ROOT / "data/levels/campaign.json"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(LEVELS, indent=2) + "\n", encoding="utf-8")
    biomes = [
        dict(id=0, name="Green Valley", accent="#A8DFC8", sky_top="#E8F5EE", sky_bottom="#FFF9F0", terrain="#AECDBB", mechanic="Rolling and five inks"),
        dict(id=1, name="Frozen Peaks", accent="#B7DFFF", sky_top="#E1EFF9", sky_bottom="#FFF9F0", terrain="#9FBFD0", mechanic="Ice, slopes, and controlled braking"),
        dict(id=2, name="Desert Winds", accent="#FFCAA6", sky_top="#F8E9DA", sky_bottom="#FFF9F0", terrain="#D5B8A0", mechanic="Wind and moving sandstone ferries"),
        dict(id=3, name="Crystal Caverns", accent="#C5AFF1", sky_top="#EEE6F8", sky_bottom="#FAF2F3", terrain="#B29EC7", mechanic="Vertical routes and low crystal roofs"),
        dict(id=4, name="Volcanic Core", accent="#F5B3C5", sky_top="#F5E0E6", sky_bottom="#FFEEDF", terrain="#9F91A9", mechanic="Lava, timing, and multi-ink mastery"),
    ]
    for level in LEVELS:
        if level['gates']:
            level['hint'] += ' Drop a loose ink weight onto the gold plate to open the tall gate.'
            level['solution'] += ' At the gold plate, draw a short unsupported Solid stroke above it, resume, and let its weight hold the gate open.'
    (ROOT / "data/biomes").mkdir(parents=True, exist_ok=True)
    (ROOT / "data/biomes/biomes.json").write_text(json.dumps(biomes, indent=2) + "\n", encoding="utf-8")
    lines = ["# Momentum Quest campaign design", "",
             "All 50 layouts are authored in `data/levels/author_campaign.py` and checked in as editable JSON. Run that script to regenerate the campaign after editing contours. Coordinates are world pixels with positive y downward; the player radius is 18 pixels. Ground contours become two-sided filled polygons. Goals sit 38 pixels above the final floor and checkpoint centers sit 20 pixels above safe ground.", "",
             "The conservative route for each map joins its ground contours using the listed solution strokes. Stroke endpoints sit 8 pixels above terrain lips, providing perpendicular clearance for six-pixel capsule radii near slopes. A small jump can smooth the transition onto a rounded bridge endpoint, particularly on Ice. Strokes are examples, never placed automatically in normal play. Existing terrain is protected from drawing. Moving ferries provide optional timing routes; every such stage also has a static drawn route above their travel envelope. Roofs leave at least 75 pixels of clearance along the intended floor route.", "",
             "Physics design basis: gravity 1100 px/s², jump impulse 470 px/s (about 100 px rise), normal horizontal cap 500 px/s. No intended route requires a ballistic jump over its gaps: ink makes continuous ramps with modest slopes. Springs launch outward and therefore require braking and a safe landing, rather than holding full acceleration. Long ramps allow rolling ascent without changing core physics between difficulties.", "",
             "Normal costs below use 0.06 ink per accepted world pixel and the configured ink multipliers. Some later maps intentionally require drawing in stages with safe waiting for regeneration, pickups, or checkpoints. Engineer budgets are per whole run net expenditure; the finale budget exceeds one reservoir because regeneration is part of its plan. Easy adds safe shelf checkpoints, more capacity and faster regeneration; Expert reduces resources without moving terrain. Zen does not award campaign records.", "",
             "## Validation limits", "",
             "`python tests/campaign_validator.py` checks all 50 distinct ground layouts, finite and in-bounds geometry, safe starts/goals/checkpoints, roof clearance along the witness route, supported contour and stroke connectivity, stroke cost, climb gradients, hazard placement, and moving-platform travel bounds. These static checks alone establish only conservative geometric feasibility.", "",
             "The independent production-physics replay `tests/campaign_physics.gd` has also reached all 50 real finish triggers under Godot 4.7.2 at 60 fixed physics ticks per second. It creates the production LevelWorld and QuestBall, places intended strokes through the production DrawingController (including collision validation and continuous ink charging), and uses only acceleration, braking, and the ordinary jump request after initial spawn. Normal reservoir limits, live regeneration, pickups, hazards, wind and ferries remain active. No teleport or direct velocity overwrite is used along the route. The machine-readable record is `tests/campaign_replay_results.json`. This demonstrates one scripted feasible route per level; it does **not** replace full human touch playthroughs on Android or establish a device frame rate. A level loading successfully is not counted as a solve.", ""]
    for biome in biomes:
        lines += [f"## {biome['name']}", ""]
        for l in LEVELS:
            if l["biome"] != biome["id"]:
                continue
            lines += [f"### {l['id']:02d}. {l['name']}", "", l["solution"], "",
                      f"Intended ink: {l['solution_ink_cost']:.1f} units. Engineer budget: {l['budget']:.1f}. Standard checkpoints: {len(l['checkpoints'])}. Wind zones: {len(l['winds'])}. Ferries: {len(l['platforms'])}.", ""]
    (ROOT / "docs").mkdir(exist_ok=True)
    (ROOT / "docs/LEVEL_DESIGN.md").write_text("\n".join(lines), encoding="utf-8")
    print(f"Authored {len(LEVELS)} campaign levels -> {target}")


if __name__ == "__main__":
    main()
