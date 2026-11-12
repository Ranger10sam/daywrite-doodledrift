"""Static structure and safety checks for current revision-3 campaign maps.

This does not execute Godot or establish that any level has been playtested.
Run: python tests/campaign_validator.py
"""
from __future__ import annotations

import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INK_MULT = {"solid": 1.0, "bounce": 2.5, "boost": 2.0, "ice": 1.5, "fragile": .5}
BASE_INK_COST = json.loads((ROOT / "data/configuration/physics.json").read_text())["base_ink_cost"]


def require(condition, message):
    if not condition:
        raise AssertionError(message)


def distance(a, b):
    return math.hypot(b[0] - a[0], b[1] - a[1])


def finite_pair(v):
    return isinstance(v, (list, tuple)) and len(v) == 2 and all(
        isinstance(n, (int, float)) and not isinstance(n, bool) and math.isfinite(n) for n in v)


def segments_intersect(a, b, c, d):
    def cross(p, q, r):
        return (q[0] - p[0]) * (r[1] - p[1]) - (q[1] - p[1]) * (r[0] - p[0])
    return cross(a, b, c) * cross(a, b, d) < 0 and cross(c, d, a) * cross(c, d, b) < 0


def validate_polygon(points, width, height):
    require(len(points) >= 3, "polygon has fewer than 3 vertices")
    require(all(finite_pair(p) and 0 <= p[0] <= width and 0 <= p[1] <= height for p in points),
            "polygon has invalid or out-of-bounds vertex")
    area = abs(sum(a[0]*b[1] - b[0]*a[1] for a, b in zip(points, points[1:]+points[:1]))) / 2
    require(area > 1, "degenerate polygon")
    edges = list(zip(points, points[1:] + points[:1]))
    for i, (a, b) in enumerate(edges):
        require(distance(a, b) > .1, "duplicate polygon vertex")
        for j, (c, d) in enumerate(edges):
            if j > i + 1 and (i, j) != (0, len(edges) - 1):
                require(not segments_intersect(a, b, c, d), "self-intersecting polygon")


def inside(p, polygon):
    x, y = p
    result = False
    for a, b in zip(polygon, polygon[1:] + polygon[:1]):
        if (a[1] > y) != (b[1] > y):
            ix = (b[0] - a[0]) * (y - a[1]) / (b[1] - a[1]) + a[0]
            if x < ix:
                result = not result
    return result


def circle_hits_polygon(center, radius, polygon):
    if inside(center, polygon):
        return True
    for a, b in zip(polygon, polygon[1:] + polygon[:1]):
        dx, dy = b[0] - a[0], b[1] - a[1]
        t = max(0, min(1, ((center[0] - a[0])*dx + (center[1] - a[1])*dy) / (dx*dx+dy*dy)))
        if distance(center, [a[0]+t*dx, a[1]+t*dy]) < radius:
            return True
    return False


def rect_contains(rect, p, margin=0):
    x, y, w, h = rect
    return x-margin <= p[0] <= x+w+margin and y-margin <= p[1] <= y+h+margin


def floor_edges(level):
    edges = []
    for terrain in level["terrain"]:
        if terrain.get("role", "ground") == "ground":
            top = terrain["points"][:-2]
            edges.extend(zip(top, top[1:]))
    return edges


def support_at(level, p):
    # Within 20px under a ball center and within 3px lateral clearance.
    for a, b in floor_edges(level):
        if a[0] <= p[0] <= b[0]:
            y = a[1] + (b[1] - a[1]) * (p[0] - a[0]) / (b[0] - a[0])
            if 18 <= y - p[1] <= 42:
                return True
    return False


def validate_rect(rect, width, height, label):
    require(isinstance(rect, (list, tuple)) and len(rect) == 4 and
            all(isinstance(v, (int, float)) and not isinstance(v, bool) and math.isfinite(v) for v in rect),
            f"invalid {label} rectangle")
    x, y, w, h = rect
    require(w > 0 and h > 0, f"nonpositive {label} extent")
    require(x >= 0 and y >= 0 and x + w <= width and y + h <= height,
            f"{label} exceeds world bounds")


def validate(level):
    """Current puzzle structure/safety only; not a support-route or solver proof."""
    w, h = level["width"], level["height"]
    require(isinstance(w, (int, float)) and isinstance(h, (int, float)) and
            math.isfinite(w) and math.isfinite(h) and w >= 1000 and h >= 800,
            "invalid world bounds")
    require(level.get("puzzle_revision") == 3, "expected current puzzle revision 3")
    require(level["biome"] == (level["id"] - 1) // 10, "wrong biome")
    require(bool(level["solution"].strip()) and bool(level["hint"].strip()), "missing solution/hint")
    require(isinstance(level["ink"], (int, float)) and math.isfinite(level["ink"]) and level["ink"] > 0,
            "invalid initial ink")
    # Fixed-ink puzzles intentionally use zero regeneration and offer restart.
    require(isinstance(level["regen"], (int, float)) and math.isfinite(level["regen"]) and level["regen"] >= 0,
            "invalid regeneration rate")
    require(isinstance(level["budget"], (int, float)) and math.isfinite(level["budget"]) and level["budget"] >= 0,
            "invalid mastery budget")
    # Production defaults a missing constraint to all five inks.
    allowed = level.get("allowed_inks", list(INK_MULT))
    require(bool(allowed) and len(allowed) == len(set(allowed)) and set(allowed) <= set(INK_MULT),
            "invalid allowed-ink supply")
    require(bool(level["terrain"]), "level has no terrain")
    for terrain in level["terrain"]:
        validate_polygon(terrain["points"], w, h)
        require(terrain["surface"] in {"solid", "ice", "fragile"}, "unknown terrain surface")
    for label, point in [("start", level["start"]), ("finish", level["finish"])]:
        require(finite_pair(point) and 0 < point[0] < w and 0 < point[1] < h, f"invalid {label}")
        require(support_at(level, point), f"{label} has no stable ground below it")
        require(not any(circle_hits_polygon(point, 17.5, terrain["points"]) for terrain in level["terrain"]),
                f"{label} overlaps terrain")
    checkpoints = level["checkpoints"] + level.get("easy_checkpoints", [])
    for point in checkpoints:
        require(finite_pair(point) and support_at(level, point), "checkpoint not supported by ground")
        require(not any(circle_hits_polygon(point, 17.5, terrain["points"]) for terrain in level["terrain"]),
                "checkpoint overlaps terrain")
    for hazard in level["hazards"]:
        rect = hazard["rect"]
        validate_rect(rect, w, h, "hazard")
        require(hazard["type"] in {"lava", "spikes", "water"}, "unknown hazard type")
        for point in [level["start"], level["finish"], *checkpoints]:
            require(not rect_contains(rect, point, 20), "hazard overlaps safe spawn/goal/checkpoint")
    require(bool(level["build_regions"]), "missing editable build regions")
    for rect in level["build_regions"]:
        validate_rect(rect, w, h, "build")
    for rect in level.get("no_build_regions", []):
        validate_rect(rect, w, h, "no-build")
    estimated_example_cost = 0.0
    for stroke in level["solution_strokes"]:
        require(stroke["ink"] in allowed, "example stroke uses forbidden ink")
        points = stroke["points"]
        require(2 <= len(points) <= 128, "invalid example stroke complexity")
        for point in points:
            require(finite_pair(point) and any(rect_contains(rect, point) for rect in level["build_regions"]),
                    "example stroke outside build region")
            require(not any(rect_contains(rect, point) for rect in level.get("no_build_regions", [])),
                    "example stroke enters a no-build region")
        for a, b in zip(points, points[1:]):
            require(distance(a, b) > 1, "tiny example stroke")
            estimated_example_cost += distance(a, b) * BASE_INK_COST * INK_MULT[stroke["ink"]]
    # V3 includes launch pads, vertical chutes, intentional wind, crates and
    # moving islands. Its partial example strokes do not form a static support
    # chain and need not fit a single reservoir fill. The old V1/V2
    # solution_ink_cost/support-witness fields are not a current solver oracle.
    crate_ids = []
    for crate in level.get("crates", []):
        require(isinstance(crate.get("id"), str) and bool(crate["id"]), "crate is missing its identifier")
        require(crate["id"] not in crate_ids, "duplicate crate identifier")
        crate_ids.append(crate["id"])
        require(finite_pair(crate["position"]) and 0 < crate["position"][0] < w and 0 < crate["position"][1] < h,
                "invalid crate position")
        require(finite_pair(crate["size"]) and all(value > 0 for value in crate["size"]), "invalid crate size")
        require(math.isfinite(crate.get("mass", 2)) and crate.get("mass", 2) > 0, "invalid crate mass")
    for gate in level.get("gates", []):
        for key in ("plate", "gate"):
            point = gate[key]
            require(finite_pair(point) and 0 <= point[0] <= w and 0 <= point[1] <= h,
                    f"invalid {key} position")
        if gate.get("crate_only", False):
            require(gate.get("object_id") in crate_ids, "gate references a missing crate key")
    for moving in level["platforms"]:
        require(math.isfinite(moving["period"]) and moving["period"] >= 2 and
                finite_pair(moving["size"]) and all(value > 0 for value in moving["size"]),
                "unsafe platform timing/size")
        for point in [moving["from"], moving["to"]]:
            require(finite_pair(point) and 0 <= point[0] <= w and 0 <= point[1] <= h,
                    "platform travel outside bounds")
    for wind in level["winds"]:
        validate_rect(wind["rect"], w, h, "wind")
        require(finite_pair(wind["force"]), "invalid wind force")
        require(max(abs(value) for value in wind["force"]) <= 10000, "wind exceeds bounded authored-force envelope")
    return estimated_example_cost


def main():
    levels = json.loads((ROOT / "data/levels/campaign.json").read_text(encoding="utf-8"))
    require(len(levels) == 50, "campaign must contain exactly 50 levels")
    require([l["id"] for l in levels] == list(range(1, 51)), "nonsequential campaign IDs")
    require(len({l["name"] for l in levels}) == 50, "duplicate level names")
    fingerprints = {json.dumps([t["points"] for t in l["terrain"]], sort_keys=True) for l in levels}
    require(len(fingerprints) == 50, "duplicate terrain layouts")
    for l in levels:
        try:
            validate(l)
        except AssertionError as exc:
            raise AssertionError(f"Level {l['id']:02d} {l['name']}: {exc}") from exc
    print("PASS: 50 unique revision-3 campaign definitions; bounds, safe spawns/goals/checkpoints,")
    print("      polygons, allowed ink/build regions, bounded resources/wind/platforms,")
    print("      crate identifiers and matching gate keys.")
    print("LIMIT: structural safety only. No continuous support witness, all-level solution,")
    print("       Engineer-budget proof, manual playthrough, or Android result is claimed.")
    print(f"Campaign: {sum(len(l['terrain']) for l in levels)} terrain polygons, "
          f"{sum(len(l['solution_strokes']) for l in levels)} example strokes, "
          f"{sum(len(l['winds']) for l in levels)} wind zones, "
          f"{sum(len(l['platforms']) for l in levels)} moving platforms.")


if __name__ == "__main__":
    main()
