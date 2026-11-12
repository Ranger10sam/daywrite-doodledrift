extends SceneTree
## Headless unit/integration regressions. Does not mutate the real save.
## godot --headless --path . --script res://tests/test_runner.gd

class BuildFixture:
	extends Node2D
	var blocked: bool = false
	var definition: Dictionary = {"allowed_inks": ["solid", "bounce", "boost", "ice", "fragile"]}
	# This isolated geometry workbench supports endpoints. Real supported/falling
	# body behavior is exercised by the physics and current-puzzle suites.
	func has_terrain_anchor(_point: Vector2) -> bool:
		return true
	func can_build_segment(a: Vector2, b: Vector2, margin: float) -> bool:
		if a.x < -margin or b.x < -margin or a.x > 2000.0 or b.x > 2000.0:
			return false
		if blocked and maxf(a.x, b.x) >= 240.0 - margin and minf(a.x, b.x) <= 300.0 + margin and minf(a.y, b.y) <= 300.0 + margin and maxf(a.y, b.y) >= 100.0 - margin:
			return false
		return true

var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("FAIL: " + label)

func near(actual: float, expected: float, label: String, tolerance: float = 0.001) -> void:
	check(absf(actual - expected) <= tolerance, "%s (got %.6f, expected %.6f)" % [label, actual, expected])

func run() -> void:
	reservoir_tests()
	geometry_tests()
	await drawing_tests()
	if failures.is_empty():
		print("PASS: %d reservoir, geometry and drawing regression checks" % checks)
		quit(0)
	else:
		print("FAIL: %d of %d checks failed" % [failures.size(), checks])
		for failure in failures:
			print("  " + failure)
		quit(1)

func reservoir_tests() -> void:
	var r := InkReservoir.new()
	r.configure(100.0, 5.0)
	var first: int = r.begin_stroke()
	near(r.spend(first, 30.0), 30.0, "accepted debit")
	near(r.amount, 70.0, "ink decreases immediately")
	near(r.net_used(), 30.0, "net use tracks accepted debit")
	r.tick(2.0)
	near(r.amount, 80.0, "regen uses passed simulation delta")
	near(r.refund(first), 20.0, "refund only unregenerated drawing debit")
	near(r.amount, 100.0, "refund capacity cap")
	near(r.net_used(), 0.0, "removed geometry excluded from net use")
	near(r.refund(first), 0.0, "double refund cannot mint ink")
	near(r.amount, 100.0, "double refund leaves capacity unchanged")
	r.tick(100.0)
	near(r.amount, 100.0, "regen never exceeds capacity")
	r.tick(-8.0)
	near(r.amount, 100.0, "negative simulation delta cannot remove ink")
	r.configure(100.0, 5.0)
	first = r.begin_stroke()
	near(r.spend(first, 1000.0), 100.0, "exhaustion accepts only available resource")
	near(r.amount, 0.0, "exhaustion reaches exactly zero")
	near(r.spend(first, 10.0), 0.0, "empty reservoir accepts zero")
	near(r.spend(first, -10.0), 0.0, "negative cost cannot add resource")
	r.tick(1.0)
	near(r.amount, 5.0, "empty reservoir can recover")
	near(r.refund(first), 95.0, "partial exhaustion refund honors regen ledger")
	near(r.amount, 100.0, "exhaustion refund restores bounded capacity")
	# Banking exploit: old fully regenerated geometry must not refund a new debit.
	r.configure(100.0, 5.0)
	first = r.begin_stroke()
	r.spend(first, 30.0)
	r.tick(6.0)
	var second: int = r.begin_stroke()
	r.spend(second, 40.0)
	near(r.refund(first), 0.0, "old regenerated stroke cannot bank a later refund")
	near(r.amount, 60.0, "old refund does not refill new drawing debit")
	near(r.refund(second), 40.0, "new debit remains independently refundable")
	near(r.amount, 100.0, "independent refund recovers exactly the new debit")
	# Oldest-debit-first credit spans drawings, including those already destroyed.
	r.configure(100.0, 5.0)
	first = r.begin_stroke()
	second = r.begin_stroke()
	r.spend(first, 40.0)
	r.spend(second, 30.0)
	r.tick(10.0)
	near(r.refund(first), 0.0, "regen settles oldest debit first")
	near(r.refund(second), 20.0, "remaining outstanding debit refunds exactly")
	near(r.amount, 100.0, "multiple debit refunds preserve capacity")
	r.configure(150.0, 8.0)
	first = r.begin_stroke()
	r.spend(first, 60.0)
	r.pickup(30.0)
	near(r.amount, 120.0, "pickup adds simulation credit")
	near(r.refund(first), 30.0, "pickup settles old debit and cannot be banked")
	near(r.amount, 150.0, "Easy capacity respected")
	near(r.regeneration, 8.0, "pickup leaves configured regen unchanged")
	for cycle in range(100):
		first = r.begin_stroke()
		r.spend(first, 15.0)
		r.tick(0.4)
		r.refund(first)
		check(r.amount >= 0.0 and r.amount <= r.capacity, "100-cycle debit/regen/undo bounds %d" % cycle)
	near(r.amount, 150.0, "repeated undo cannot inflate reservoir")

func geometry_tests() -> void:
	var empty := PackedVector2Array()
	check(StrokeGeometry.simplify(empty).is_empty(), "empty simplification")
	var singleton := PackedVector2Array([Vector2(3, 8)])
	check(StrokeGeometry.simplify(singleton) == singleton, "one-point simplification")
	var straight := PackedVector2Array()
	for i in range(100):
		straight.append(Vector2(i * 4.0, 20.0))
	var simple: PackedVector2Array = StrokeGeometry.simplify(straight, 1.5)
	check(simple.size() == 2, "straight stroke reduces collision complexity to one segment")
	check(simple[0] == straight[0] and simple[-1] == straight[-1], "RDP preserves both endpoints")
	var bend := PackedVector2Array([Vector2(0, 0), Vector2(25, 0), Vector2(50, 0), Vector2(50, 25), Vector2(50, 50)])
	simple = StrokeGeometry.simplify(bend, 1.5)
	check(simple.size() == 3 and simple[1] == Vector2(50, 0), "RDP preserves meaningful right-angle corner")
	var curve := PackedVector2Array()
	for i in range(101):
		curve.append(Vector2(i * 3.0, sin(float(i) * PI / 100.0) * 70.0))
	simple = StrokeGeometry.simplify(curve, 1.5)
	check(simple.size() < curve.size() / 3, "smooth curve simplification reduces segments")
	var maximum_error: float = 0.0
	for point in curve:
		var nearest_distance: float = INF
		for i in range(1, simple.size()):
			nearest_distance = minf(nearest_distance, point.distance_to(Geometry2D.get_closest_point_to_segment(point, simple[i - 1], simple[i])))
		maximum_error = maxf(maximum_error, nearest_distance)
	check(maximum_error <= 1.501, "simplified curve stays within documented 1.5px geometry tolerance")
	near(StrokeGeometry.length_of(PackedVector2Array([Vector2(0, 0), Vector2(3, 4), Vector2(6, 8)])), 10.0, "ink charged by world-space arc length")
	check(StrokeGeometry.crosses_self(PackedVector2Array([Vector2(0, 0), Vector2(100, 100), Vector2(0, 100)]), Vector2(100, 0)), "bow crossing rejected")
	check(not StrokeGeometry.crosses_self(PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(100, 100)]), Vector2(200, 100)), "adjacent noncrossing turn accepted")
	check(StrokeGeometry.crosses_self(PackedVector2Array([Vector2(0, 0), Vector2(40, 0), Vector2(80, 0)]), Vector2(20, 0)), "collinear self-overlap rejected")
	check(StrokeGeometry.circle_near_segment(Vector2(50, 5), 6.0, Vector2.ZERO, Vector2(100, 0)), "player protection uses whole segment")
	check(not StrokeGeometry.circle_near_segment(Vector2(50, 8), 6.0, Vector2.ZERO, Vector2(100, 0)), "clear segment outside protected circle accepted")
	check(StrokeGeometry.circle_near_segment(Vector2(0, 5), 6.0, Vector2.ZERO, Vector2.ZERO), "stationary point handles zero-length segment safely")

func drawing_tests() -> void:
	var fixture := BuildFixture.new()
	root.add_child(fixture)
	var ball := RigidBody2D.new()
	ball.freeze = true
	ball.position = Vector2(1500, 650)
	fixture.add_child(ball)
	# Defer loading classes that reference autoloads until SceneTree initialization.
	var drawing: Variant = load("res://scripts/ink/drawing_controller.gd").new()
	fixture.add_child(drawing)
	drawing.level_world = fixture
	drawing.player = ball
	drawing.reservoir.configure(100.0, 5.0)
	var solid_cost_per_pixel: float = PhysicsConfig.number("base_ink_cost", 0.06) * float(InkCatalog.get_ink("solid").cost)
	drawing.start_mode()
	check(drawing.begin_stroke(Vector2(20, 200)), "valid stroke begins")
	for i in range(10):
		drawing.accept_to(Vector2(20, 200))
	near(drawing.reservoir.amount, 100.0, "stationary pointer never drains ink")
	drawing.accept_to(Vector2(520, 200))
	near(drawing.reservoir.amount, 100.0 - 500.0 * solid_cost_per_pixel, "one fast 500px drag charges full distance at the configured ink rate")
	check(drawing.current.size() >= 51, "fast drag resampled before validation")
	drawing.finish_stroke()
	check(drawing.strokes.size() == 1, "release creates one physics body per stroke")
	check(drawing.strokes[0].get_child_count() == 1, "straight drag simplifies to one capsule collider")
	near(drawing.strokes[0].world_points()[-1].x, 520.0, "accepted world geometry endpoint matches pointer")
	drawing.undo()
	near(drawing.reservoir.amount, 100.0, "undo refunds exact accepted stroke debit")
	check(drawing.strokes.is_empty(), "undo removes drawing from active ledger")
	await process_frame
	fixture.blocked = true
	drawing.begin_stroke(Vector2(20, 200))
	drawing.accept_to(Vector2(520, 200))
	check(drawing.current.is_empty(), "protected crossing finishes last valid geometry")
	check(drawing.strokes.size() == 1 and drawing.strokes[0].world_points()[-1].x < 240.0, "fast drag cannot jump over protected obstacle")
	check(drawing.reservoir.amount > 85.0, "rejected protected distance does not consume ink")
	drawing.clear_drawings()
	fixture.blocked = false
	drawing.reservoir.configure(1.0, 5.0)
	drawing.begin_stroke(Vector2(20, 350))
	drawing.accept_to(Vector2(500, 350))
	near(drawing.reservoir.amount, 0.0, "drawing exhaustion clamps at zero")
	check(drawing.current.is_empty() and drawing.strokes.size() == 1, "exhaustion finishes a valid partial stroke")
	near(drawing.strokes[0].world_points()[-1].x, 20.0 + 1.0 / solid_cost_per_pixel, "exhaustion world geometry matches configured charged distance", .01)
	drawing.undo()
	near(drawing.reservoir.amount, 1.0, "partial stroke undo bounded by configured capacity")
	drawing.reservoir.configure(100.0, 5.0)
	check(not drawing.begin_stroke(ball.position), "drawing inside player rejected")
	drawing.begin_stroke(Vector2(20, 400))
	drawing.accept_to(Vector2(80, 400))
	drawing.cancel_stroke()
	near(drawing.reservoir.amount, 100.0, "cancellation refunds only pending accepted geometry")
	check(drawing.strokes.is_empty(), "cancellation creates no collision body")
	fixture.definition.allowed_inks = ["fragile"]
	drawing.selected_ink = "solid"
	check(not drawing.begin_stroke(Vector2(20, 450)), "a puzzle's limited ink supply rejects a forbidden type")
	near(drawing.reservoir.amount, 100.0, "forbidden ink accepts no geometry and consumes no resource")
	fixture.queue_free()
	await process_frame
