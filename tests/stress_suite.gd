extends SceneTree
## Max-complexity production drawing + lifecycle stress. Headless timings are not
## Android/GPU measurements. Run --fixed-fps 60 --script res://tests/stress_suite.gd.
class OpenBuildWorld:
	extends Node2D
	var definition: Dictionary = {"allowed_inks": ["solid", "bounce", "boost", "ice", "fragile"]}
	# A supported workbench isolates collision-complexity limits from puzzle
	# terrain; floating-stroke behavior belongs to the dedicated physics suite.
	func has_terrain_anchor(_point: Vector2) -> bool:
		return true
	func can_build_segment(a: Vector2, b: Vector2, margin: float) -> bool:
		return Rect2(0, 0, 6000, 2000).grow(-margin).has_point(a) and Rect2(0, 0, 6000, 2000).grow(-margin).has_point(b)

var checks: int = 0
var failures: Array[String] = []
var metrics: Dictionary = {}
var fixture: Node2D
var drawing: Variant
var ball: Variant
var live_profile: bool = false

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("FAIL: " + label)

func ticks(count: int) -> void:
	for i in range(count):
		await physics_frame

func run() -> void:
	live_profile = OS.get_cmdline_user_args().has("--profile-live")
	await drawing_stress()
	if not live_profile:
		await lifecycle_stress()
	metrics["checks"] = checks
	metrics["failures"] = failures
	metrics["engine"] = Engine.get_version_info().string
	metrics["physics_hz"] = Engine.physics_ticks_per_second
	metrics["live_profile"] = live_profile
	metrics["measurement_limit"] = "Headless Windows fixed-step simulation only; no Android/GPU frame rate, touch latency, thermal or battery claim. Per-step wall time includes scheduling and scripts. Engine physics monitor is reported separately."
	var file := FileAccess.open("res://tests/stress_live_profile.json" if live_profile else "res://tests/stress_results.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(metrics, "\t") + "\n")
	print("STRESS: %d checks, %d failures; %s" % [checks, failures.size(), JSON.stringify(metrics)])
	quit(0 if failures.is_empty() else 1)

func make_zig(x: float, y: float, segments: int) -> void:
	drawing.begin_stroke(Vector2(x, y - 3.0))
	for i in range(1, segments + 1):
		drawing.accept_to(Vector2(x + i * 6.0, y + (3.0 if i % 2 == 1 else -3.0)))
	drawing.finish_stroke()

func drawing_stress() -> void:
	var construction_started: int = Time.get_ticks_usec()
	fixture = OpenBuildWorld.new()
	root.add_child(fixture)
	ball = load("res://scripts/player/ball.gd").new()
	ball.position = Vector2(150, 520)
	ball.freeze = true
	fixture.add_child(ball)
	drawing = load("res://scripts/ink/drawing_controller.gd").new()
	drawing.level_world = fixture
	drawing.player = ball
	fixture.add_child(drawing)
	drawing.reservoir.configure(9999.0, 100.0)
	var drawing_started: int = Time.get_ticks_usec()
	for i in range(32):
		make_zig(100 + i * 104, 560, 16)
	metrics["batch32_stroke_generation_wall_ms"] = float(Time.get_ticks_usec() - drawing_started) / 1000.0
	metrics["construction_wall_ms"] = float(Time.get_ticks_usec() - construction_started) / 1000.0
	check(drawing.strokes.size() == 32, "maximum 32 physical stroke bodies accepted")
	check(drawing.segment_count() == 512, "maximum 512 active collision segments accepted exactly")
	var shapes: int = 0
	for surface in drawing.strokes:
		shapes += surface.get_child_count()
	check(shapes == 512, "512 visual segments correspond to512 capsule collision shapes")
	metrics["max_complexity_strokes"] = drawing.strokes.size()
	metrics["max_complexity_segments"] = drawing.segment_count()
	metrics["max_complexity_collision_shapes"] = shapes
	var ink_before: float = drawing.reservoir.amount
	check(not drawing.begin_stroke(Vector2(3500, 300)), "33rd stroke rejected at production body limit")
	check(drawing.reservoir.amount == ink_before, "rejected stroke consumes no resource")
	# Isolate segment guard from stroke guard without changing production defaults.
	drawing.maximum_strokes = 64
	check(not drawing.begin_stroke(Vector2(3500, 300)), "513th segment cannot begin at full segment budget")
	drawing.maximum_strokes = 32
	# Broad-phase and repeated rolling contacts at the full supported complexity.
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 1
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(3700, 60)
	collider.shape = shape
	collider.position = Vector2(1800, 650)
	floor_body.add_child(collider)
	fixture.add_child(floor_body)
	ball.freeze = false
	ball.axis = 1.0
	ball.reduced_motion = true
	# The engine monitor updates once per real second. Warm up for two real
	# seconds in the live profile so startup/resource setup is not mistaken
	# for steady-state physics CPU cost. Accelerated monitor data is stale.
	await ticks(120)
	metrics["profile_warmup_ticks"] = 120
	var step_times: Array[float] = []
	var physics_samples: Array[float] = []
	var peak_nodes: int = 0
	var peak_contacts: int = 0
	var speed_maximum: float = 0.0
	var started: int = Time.get_ticks_usec()
	for i in range(1000):
		if ball.position.x > 3250:
			ball.axis = -1.0
		elif ball.position.x < 180:
			ball.axis = 1.0
		if i % 100 == 0 and ball.grounded:
			ball.request_jump()
		var tick_started: int = Time.get_ticks_usec()
		await physics_frame
		step_times.append(float(Time.get_ticks_usec() - tick_started) / 1000.0)
		physics_samples.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		peak_nodes = maxi(peak_nodes, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
		peak_contacts = maxi(peak_contacts, ball.get_colliding_bodies().size())
		speed_maximum = maxf(speed_maximum, ball.linear_velocity.length())
	var elapsed: float = float(Time.get_ticks_usec() - started) / 1000.0
	step_times.sort()
	physics_samples.sort()
	metrics["profile_ticks"] = 1000
	metrics["profile_wall_ms"] = elapsed
	metrics["headless_step_wall_p50_ms"] = step_times[500]
	metrics["headless_step_wall_p95_ms"] = step_times[950]
	metrics["headless_step_wall_max_ms"] = step_times[-1]
	metrics["engine_physics_monitor_p50_ms"] = physics_samples[500]
	metrics["engine_physics_monitor_p95_ms"] = physics_samples[950]
	metrics["engine_physics_monitor_max_ms"] = physics_samples[-1]
	metrics["peak_tree_nodes_at512segments"] = peak_nodes
	metrics["peak_player_simultaneous_contacts"] = peak_contacts
	metrics["maximum_player_speed"] = speed_maximum
	check(ball.position.is_finite() and ball.linear_velocity.is_finite(), "1000 max-complexity ticks retain finite physics")
	check(ball.position.y < 700.0, "full-complexity repeated contacts retain supporting collision")
	check(speed_maximum <= 1101.0, "full-complexity physics respects global speed cap")
	check(drawing.segment_count() <= 512 and drawing.strokes.size() <= 32, "1000 ticks never grow physics geometry")
	# Fast input must terminate at complexity bounds even with almost unlimited ink.
	drawing.clear_drawings()
	await process_frame
	drawing.begin_stroke(Vector2(100, 300))
	drawing.accept_to(Vector2(5500, 300))
	drawing.finish_stroke()
	check(drawing.strokes.size() == 1 and drawing.strokes[0].world_points()[-1].x <= 1380.0, "very fast5400px drag stops at configured raw point bound in world space")
	check(drawing.reservoir.amount >= 0.0, "fast input leaves resource nonnegative")
	check(drawing.strokes[0].get_child_count() <= 127, "fast input never creates excessive colliders")
	drawing.clear_drawings()
	fixture.queue_free()
	await process_frame

func lifecycle_stress() -> void:
	var save: Variant = root.get_node("SaveManager")
	var original: Dictionary = save.data.duplicate(true)
	var original_path: String = save.storage_path
	var original_previous: String = save.previous_path
	save.storage_path = "user://stress-test.json"
	save.previous_path = "user://stress-test.previous.json"
	save.data = save.defaults()
	save.data.settings["reduced_motion"] = true
	var game: Variant = load("res://scripts/gameplay/main.gd").new()
	root.add_child(game)
	await process_frame
	game.start_level(1)
	await ticks(10)
	game.toggle_draw()
	var planned: Dictionary = game.world.definition.solution_strokes[0]
	game.drawing.selected_ink = str(planned.ink)
	game.drawing.begin_stroke(Vector2(planned.points[0][0], planned.points[0][1]))
	game.drawing.accept_to(Vector2(planned.points[1][0], planned.points[1][1]))
	game.drawing.finish_stroke()
	game.toggle_draw()
	game._activate_checkpoint(game.player.position)
	for i in range(100):
		game._on_action("move_right", true)
		game.pause_game()
		var before: Vector2 = game.player.position
		await process_frame
		check(game.state == "paused" and paused and game.player.position.distance_to(before) < .001, "pause cycle%d freezes simulation" % i)
		game._resume()
		check(game.state == "playing" and not paused and not game.touch_right and game.player.axis == 0.0, "pause cycle%d clears held input" % i)
		game._fail()
		await ticks(20)
		check(game.state == "playing" and game.player.visible and not game.player.freeze, "checkpoint reset%d resumes valid player" % i)
		check(game.drawing.strokes.size() == 1 and game.drawing.reservoir.amount >= 0.0 and game.drawing.reservoir.amount <= game.drawing.reservoir.capacity, "checkpoint reset%d restores drawing and bounded resource" % i)
	metrics["pause_resume_cycles"] = 100
	metrics["checkpoint_reset_cycles"] = 100
	var checkpoint_deaths: int = game.deaths
	check(checkpoint_deaths == 100, "100 failures count exactly100 deaths")
	var node_peak: int = 0
	for i in range(100):
		var id: int = i % 50 + 1
		game.start_level(id)
		await ticks(2)
		check(game.state == "playing" and int(game.world.definition.id) == id, "level switch%d loads correct world" % i)
		check(game.player.position.is_finite() and not game.world.death_lock, "level switch%d keeps valid spawn" % i)
		node_peak = maxi(node_peak, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	metrics["level_switches"] = 100
	metrics["level_switch_peak_nodes"] = node_peak
	# A pending old-session respawn must not change a newly started session.
	game.start_level(3)
	await ticks(2)
	game._fail()
	game.start_level(1)
	game._on_action("move_right", true)
	await ticks(35)
	check(game.level_id == 1 and game.deaths == 0 and game.player.position.x > 250.0, "switch during pending respawn cannot reset the next session")
	game._to_menu()
	game.queue_free()
	await process_frame
	save.data = original
	save.storage_path = original_path
	save.previous_path = original_previous
