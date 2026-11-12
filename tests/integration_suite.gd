extends SceneTree
## End-to-end production scene wiring, no simulated completions or save unlocks.
var checks: int = 0
var failures: Array[String] = []
var game: Variant

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
	var save: Variant = root.get_node("SaveManager")
	var original_data: Dictionary = save.data.duplicate(true)
	var original_path: String = save.storage_path
	var original_previous: String = save.previous_path
	save.storage_path = "user://integration-test.json"
	save.previous_path = "user://integration-test.previous.json"
	save.data = save.defaults()
	var script: Script = load("res://scripts/gameplay/main.gd")
	game = script.new()
	root.add_child(game)
	await process_frame
	check(game.state == "menu", "production scene opens menu")
	for id in range(1, 51):
		game.start_level(id)
		await ticks(12)
		check(is_instance_valid(game.world) and int(game.world.definition.id) == id, "level %d loads correct definition" % id)
		check(game.deaths == 0 and game.player.position.y < float(game.world.definition.height), "level %d spawn survives fixed steps" % id)
	# The current first puzzle provides a Bounce plan; the ferry puzzle (3)
	# intentionally has no bridge plan and cannot be used as a drawing fixture.
	game.start_level(1)
	await ticks(20)
	game._on_action("move_right", true)
	game.ui._held_counts["move_right"] = 1
	game.toggle_draw()
	check(game.state == "drawing" and paused, "draw action pauses whole simulation while movement held")
	check(not game.touch_right and not game.keyboard_right and game.player.axis == 0.0, "enter draw clears movement")
	var at: Vector2 = game.player.position
	var before: float = game.drawing.reservoir.amount
	for i in range(20): await process_frame
	check(game.player.position.is_equal_approx(at), "ball remains still in draw mode")
	check(game.drawing.reservoir.amount == before, "no regeneration in draw mode")
	var solution: Dictionary = game.world.definition.solution_strokes[0]
	var points: Array = solution.points
	game.drawing.selected_ink = solution.ink
	check(game.drawing.begin_stroke(Vector2(points[0][0], points[0][1])), "intended launch pad begins through drawing validator")
	for i in range(1, points.size()): game.drawing.accept_to(Vector2(points[i][0], points[i][1]))
	game.drawing.finish_stroke()
	check(game.drawing.strokes.size() == 1, "intended launch pad creates physical stroke")
	check(game.drawing.reservoir.amount < before, "drawing charges live reservoir")
	var used: float = game.drawing.reservoir.net_used()
	game.drawing.undo()
	check(game.drawing.strokes.is_empty() and used > 0.0 and game.drawing.reservoir.net_used() < 0.001, "undo removes physics and restores exact net cost")
	game.toggle_draw()
	check(game.state == "playing" and not paused, "done resumes simulation")
	game.drawing.reservoir.spend(game.drawing.reservoir.begin_stroke(), 10.0)
	before = game.drawing.reservoir.amount
	await ticks(61)
	check(game.drawing.reservoir.amount > before + 4.0, "active gameplay regenerates about five units per second")
	game.pause_game()
	before = game.drawing.reservoir.amount
	for i in range(10): await process_frame
	check(game.drawing.reservoir.amount == before and game.state == "paused", "pause menu stops regeneration")
	game._resume()
	game._fail()
	await ticks(30)
	check(game.state == "playing" and game.deaths == 1, "failure returns to checkpoint with one counted fall")
	check(game.player.linear_velocity.length() < 250.0, "respawn clears unsafe velocity")
	game.start_level(1)
	await ticks(10)
	# Changing the next-run preference must not relabel or reclassify this Normal run.
	save.data.settings.difficulty = "zen"
	game._update_hud()
	check(game.difficulty == "normal" and not game.ui._time_label.text.contains("Zen"), "current run HUD keeps session difficulty after preference changes")
	game.toggle_draw()
	var launch_plan: Dictionary = game.world.definition.solution_strokes[0]
	game.drawing.selected_ink = str(launch_plan.ink)
	check(game.drawing.begin_stroke(Vector2(launch_plan.points[0][0], launch_plan.points[0][1])), "current spring puzzle accepts its authored Bounce pad")
	for index: int in range(1, launch_plan.points.size()):
		game.drawing.accept_to(Vector2(launch_plan.points[index][0], launch_plan.points[index][1]))
	game.drawing.finish_stroke()
	game.toggle_draw()
	game._on_action("move_right", true)
	for frame in range(900):
		await physics_frame
		if game.state == "complete": break
	check(game.state == "complete", "current spring puzzle completes through drawing, actual movement, and elevated goal contact")
	var misleading_zen := false
	for label in game.ui._root.find_children("*", "Label", true, false):
		if label.is_visible_in_tree() and label.text.contains("Zen practice"):
			misleading_zen = true
	check(not misleading_zen, "completion uses finished run difficulty rather than next-run preference")
	check(bool(save.data.levels.get("1", {}).get("explorer", false)), "real completion persists Explorer")
	check(save.is_unlocked(2), "real completion unlocks next level")
	game._to_menu()
	check(game.state == "menu" and not is_instance_valid(game.player), "return menu disposes session")
	game.queue_free()
	await process_frame
	save.data = original_data
	save.storage_path = original_path
	save.previous_path = original_previous
	print("INTEGRATION: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
