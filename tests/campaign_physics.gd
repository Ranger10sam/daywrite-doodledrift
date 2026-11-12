extends SceneTree
## HISTORICAL revision-2 support-route bot; excluded from current run-tests.ps1.
## Revision 3 introduces moving islands, crate keys, constrained inks and timing
## puzzles. This old bridge bot is not a solver for that campaign and must not be
## reported as 50 current level completions. Use puzzle_suite.gd for validated
## current scenarios, plus manual playthroughs for unautomated solutions.
var world_script: Script
var ball_script: Script
var drawing_script: Script
var results: Array[Dictionary] = []
var world: Variant
var ball: Variant
var drawing: Variant

func _initialize() -> void:
	call_deferred("run")

func vec(data: Array) -> Vector2:
	return Vector2(float(data[0]), float(data[1]))

func run() -> void:
	world_script = load("res://scripts/level/level_world.gd")
	ball_script = load("res://scripts/player/ball.gd")
	drawing_script = load("res://scripts/ink/drawing_controller.gd")
	var campaign: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels/campaign.json"))
	for definition: Dictionary in campaign:
		if int(definition.get("puzzle_revision", 2)) != 2:
			print("HISTORICAL BOT NOT RUN: requires revision-2 campaign data; current revision is 3. No solve result claimed.")
			quit(2)
			return
	var only: int = 0
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--only="):
			only = int(argument.get_slice("=", 1))
	for definition: Dictionary in campaign:
		if only > 0 and int(definition.id) != only:
			continue
		var record: Dictionary = await replay(definition)
		results.append(record)
		print("%s L%02d %s | frames=%d final=(%.1f,%.1f) ink=%.1f placed=%d/%d" % ["PASS" if record.solved else "FAIL", int(definition.id), str(definition.name), record.frames, record.final[0], record.final[1], record.ink_used, record.placed, definition.solution_strokes.size()])
	var passed: int = 0
	for record in results:
		if bool(record.solved):
			passed += 1
	var file := FileAccess.open("res://tests/campaign_replay_results.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"engine": Engine.get_version_info().string, "physics_hz": Engine.physics_ticks_per_second, "passed": passed, "total": results.size(), "method": "Revision 2: conservative anchored Solid spans plus unsupported falling weights for pressure gates, placed through production drawing validation. Actual axis/brake/jump physics with normal resources, wind, hazards and platforms. Other ink routes are not established by this replay.", "levels": results}, "\t") + "\n")
	if is_instance_valid(world):
		world.queue_free()
	if is_instance_valid(drawing):
		drawing.queue_free()
	await process_frame
	print("Campaign physics replay: %d/%d reached production finish triggers" % [passed, results.size()])
	quit(0 if passed == results.size() else 1)

func replay(definition: Dictionary) -> Dictionary:
	if is_instance_valid(drawing):
		drawing.queue_free()
	if is_instance_valid(world):
		world.queue_free()
	await process_frame
	await physics_frame
	world = world_script.new()
	world.configure(definition, "normal")
	world.reduced_motion = true
	root.add_child(world)
	ball = ball_script.new()
	ball.position = vec(definition.start)
	ball.reduced_motion = true
	world.add_child(ball)
	world.player = ball
	drawing = drawing_script.new()
	drawing.level_world = world
	drawing.player = ball
	root.add_child(drawing)
	drawing.reservoir.configure(float(definition.ink), float(definition.regen))
	world.pickup_collected.connect(drawing.reservoir.pickup)
	var planned: Array = definition.solution_strokes
	var next_stroke: int = 0
	var frames: int = 0
	var maximum_speed: float = 0.0
	var place_failure: String = ""
	var last_position: Vector2 = ball.position
	var stuck_frames: int = 0
	var progress_frames: int = 0
	var best_x: float = ball.position.x
	var jumps: int = 0
	var weights_placed := false
	while frames < 5400 and not world.complete and not world.death_lock:
		if not weights_placed and next_stroke == planned.size() and not definition.get("gates", []).is_empty():
			var plate := vec(definition.gates[0].plate)
			if ball.position.x > plate.x-500 and ball.position.x < plate.x-90:
				drawing.selected_ink="solid"
				if drawing.begin_stroke(plate+Vector2(-25,-90)):
					drawing.accept_to(plate+Vector2(25,-90)); drawing.finish_stroke(); weights_placed=true
		# Keep enough runway to stop before an unbuilt bridge. Regeneration only
		# advances inside this active gameplay loop, never during stroke creation.
		if next_stroke < planned.size():
			var item: Dictionary = planned[next_stroke].duplicate(true)
			# A conservative alternative: anchored Solid spans. Other ink routes
			# remain player options and require their own landing/timing strategy.
			item.ink = "solid"
			var points := PackedVector2Array()
			for point: Array in item.points:
				points.append(vec(point))
			var cost: float = StrokeGeometry.length_of(points) * PhysicsConfig.number("base_ink_cost",.04) * float(InkCatalog.get_ink(str(item.ink)).cost)
			if drawing.reservoir.amount >= cost + .001 and points[0].x - ball.position.x > 80.0:
				drawing.selected_ink = str(item.ink)
				drawing.reverse = bool(item.get("reverse", false))
				var previous_count: int = drawing.strokes.size()
				if drawing.begin_stroke(points[0]):
					for i in range(1, points.size()):
						drawing.accept_to(points[i])
					drawing.finish_stroke()
				if drawing.strokes.size() != previous_count + 1 or drawing.strokes[-1].world_points()[-1].distance_to(points[-1]) > 2.0:
					place_failure = "Intended stroke rejected or clipped: " + str(drawing.last_warning)
					break
				next_stroke += 1
		# A player can jump onto a rounded bridge lip instead of indefinitely
		# pushing into it. This bot uses exactly the production jump request.
		if progress_frames > 45 and ball.grounded:
			ball.request_jump()
			jumps += 1
			progress_frames = 0
		var finish: Vector2 = vec(definition.finish)
		var dx: float = finish.x - ball.position.x
		var direction: float = signf(dx)
		var desired: float = direction * minf(460.0, sqrt(maxf(0.0, absf(dx) - 8.0) * 1000.0))
		var error: float = desired - ball.linear_velocity.x
		ball.braking = false
		ball.axis = signf(error) if absf(error) > 24.0 else 0.0
		if ball.grounded and absf(ball.linear_velocity.x) > absf(desired) + 20.0:
			ball.axis = 0.0
			ball.braking = true
		if absf(dx) < 35.0 and not ball.grounded:
			ball.braking = true
		if next_stroke < planned.size():
			var lip: Vector2 = vec(planned[next_stroke].points[0])
			if lip.x - ball.position.x < 160.0:
				ball.axis = 0.0
				ball.braking = true
		await physics_frame
		frames += 1
		drawing.reservoir.tick(1.0 / float(Engine.physics_ticks_per_second))
		maximum_speed = maxf(maximum_speed, ball.linear_velocity.length())
		if ball.position.x > best_x + 2.0:
			best_x = ball.position.x
			progress_frames = 0
		else:
			progress_frames += 1
		if ball.position.distance_to(last_position) < .15:
			stuck_frames += 1
		else:
			stuck_frames = 0
		last_position = ball.position
		if stuck_frames > 240:
			break
	return {"id": int(definition.id), "name": str(definition.name), "solved": bool(world.complete), "failed_hazard": bool(world.death_lock), "frames": frames, "simulation_seconds": float(frames) / 60.0, "final": [ball.position.x, ball.position.y], "maximum_speed": maximum_speed, "ink_used": drawing.reservoir.net_used(), "placed": next_stroke, "jump_requests": jumps, "placement_error": place_failure}
