extends SceneTree
## Runs the integrated scene and captures native rendered viewports for QA.

var _game: Node

func _initialize() -> void:
	call_deferred("_run")

func _capture(file_name: String) -> void:
	await create_timer(.3).timeout
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots/" + file_name + ".png")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/screenshots"))
	_game = load("res://scenes/core/main.tscn").instantiate()
	root.add_child(_game)
	await process_frame
	_game.ui.action.emit("play", 3)
	await create_timer(.25).timeout
	if _game.state == "paused":
		_game._resume()
	assert(_game.state == "playing", "Level starts through interface action")
	await _capture("gameplay-03")
	# A second finger can enter Draw Mode while a movement finger is held. The
	# synchronous HUD rebuild must release ownership without recursive actions.
	var left_button: Button
	var draw_button: Button
	for item: Dictionary in _game.ui._touch_buttons:
		if item.action == "move_left":
			left_button = item.button
		elif item.action == "draw":
			draw_button = item.button
	var held_touch := InputEventScreenTouch.new()
	held_touch.index = 4
	held_touch.pressed = true
	held_touch.position = left_button.get_global_rect().get_center()
	_game.ui._input(held_touch)
	assert(_game.touch_left, "Native touch reaches integrated movement")
	var draw_touch := InputEventScreenTouch.new()
	draw_touch.index = 5
	draw_touch.pressed = true
	draw_touch.position = draw_button.get_global_rect().get_center()
	_game.ui._input(draw_touch)
	assert(not _game.touch_left and _game.ui._touch_owners.is_empty(), "Draw transition clears held controls without recursion")
	assert(_game.state == "drawing" and paused, "Draw button pauses real physics")
	var position: Vector2 = _game.player.position
	var time: float = _game.elapsed
	await create_timer(.15).timeout
	assert(_game.player.position.is_equal_approx(position) and _game.elapsed == time, "Drawing preserves simulation state")
	_game.ui.action.emit("ink", "bounce")
	_game._update_hud()
	assert(_game.drawing.selected_ink == "bounce", "Ink selector reaches drawing engine")
	await _capture("drawing-03")
	_game.ui.action.emit("draw", null)
	assert(_game.state == "playing" and not paused, "Done resumes physics")
	_game.ui.action.emit("pause", null)
	assert(_game.state == "paused" and paused, "Pause action pauses")
	_game.ui.action.emit("resume", null)
	assert(_game.state == "playing" and not paused, "Resume action resumes")
	_game.ui.action.emit("play", 35)
	await _capture("gameplay-35")
	_game.ui.action.emit("play", 50)
	await _capture("gameplay-50")
	var manager := root.get_node("SaveManager")
	var original: Dictionary = manager.data.settings.duplicate(true)
	var enlarged := original.duplicate(true)
	enlarged.ui_scale = 1.25
	enlarged.control_size = 1.35
	manager.set_settings(enlarged)
	root.size = Vector2i(1152, 720)
	_game.ui.show_gameplay(_game.campaign[49])
	_game._update_hud()
	await _capture("gameplay-16x10-large-controls")
	_game.ui.action.emit("draw", null)
	await _capture("drawing-16x10-large-ui")
	_game.ui.action.emit("menu", null)
	_game.ui.show_levels(0)
	await _capture("levels-16x10-large-ui")
	root.size = Vector2i(1600, 720)
	manager.set_settings(original)
	_game.ui.action.emit("play", 3)
	await _capture("gameplay-20x9")
	_game.ui.action.emit("draw", null)
	await _capture("drawing-20x9")
	manager.set_settings(original)
	_game.ui.action.emit("menu", null)
	await process_frame
	_game.queue_free()
	await process_frame
	print("GAMEPLAY_UI_PASS: integrated actions, draw pause, resume, rendered HUD, aspect ratios")
	quit(0)
