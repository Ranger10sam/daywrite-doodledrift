extends SceneTree
## Run with Godot --headless --path . --script res://tests/ui_smoke.gd.
## Exercises real Control construction and two independent native touch owners.

var _events: Array = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var interface := QuestUI.new()
	root.add_child(interface)
	interface.action.connect(func(event: String, value: Variant) -> void: _events.append([event, value]))
	await process_frame
	interface.show_menu()
	await process_frame
	await process_frame
	var continue_button: Button
	for node in interface._root.find_children("*", "Button", true, false):
		if node.text.begins_with("Continue"):
			continue_button = node
	assert(continue_button != null, "Main menu has a Continue button")
	assert(Input.emulate_mouse_from_touch, "Standard menu controls enable native touch emulation")
	# The headless display driver does not translate synthetic touches into mouse
	# GUI events. The same test verifies the full path under a graphical driver.
	if DisplayServer.get_name() != "headless":
		var menu_touch := InputEventScreenTouch.new()
		menu_touch.index = 0
		menu_touch.pressed = true
		menu_touch.position = continue_button.get_global_rect().get_center()
		Input.parse_input_event(menu_touch)
		await process_frame
		var menu_release := InputEventScreenTouch.new()
		menu_release.index = 0
		menu_release.pressed = false
		menu_release.position = menu_touch.position
		Input.parse_input_event(menu_release)
		await process_frame
		assert(_events.has(["continue", null]), "Menu native touch emulates mouse and activates button")
	interface.show_biomes()
	await process_frame
	interface.show_levels(0)
	await process_frame
	interface.show_settings()
	await process_frame
	interface.show_progress()
	await process_frame
	var level: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels/campaign.json"))[0]
	interface.show_gameplay(level)
	interface.update_hud({"ink": 75, "max_ink": 100, "draw_mode": false, "selected_ink": "solid", "elapsed": 5, "deaths": 0})
	await process_frame
	await process_frame
	var left: Dictionary = {}
	var jump: Dictionary = {}
	for entry: Dictionary in interface._touch_buttons:
		if entry.action == "move_left":
			left = entry
		elif entry.action == "jump":
			jump = entry
	assert(not left.is_empty() and not jump.is_empty(), "Movement controls exist")
	for entry: Dictionary in [left, jump]:
		var touch := InputEventScreenTouch.new()
		touch.index = 1 if entry.action == "move_left" else 2
		touch.pressed = true
		touch.position = entry.button.get_global_rect().get_center()
		interface._input(touch)
	assert(interface._touch_owners.size() == 2, "Two independent control touches")
	assert(_events.has(["move_left", true]) and _events.has(["jump", true]), "Both touch actions delivered")
	var release := InputEventScreenTouch.new()
	release.index = 2
	release.pressed = false
	interface._input(release)
	assert(interface._touch_owners.size() == 1, "Releasing jump preserves movement")
	assert(interface._held_counts.get("move_left", 0) == 1, "Movement remains held")
	interface.release_controls()
	assert(interface._touch_owners.is_empty(), "Pause releases touch capture")
	interface.update_hud({"ink": 25, "max_ink": 100, "draw_mode": true, "selected_ink": "bounce", "elapsed": 5, "deaths": 0})
	await process_frame
	assert(interface._ink_buttons.size() == 5, "All physics ink controls exist")
	interface.update_hud({"ink": 20, "max_ink": 100, "draw_mode": true, "selected_ink": "boost", "reverse": true})
	assert(interface._reverse_button.text.contains("←"), "Boost direction is visible")
	interface.show_pause()
	await process_frame
	interface.show_completion({"id": 1, "name": "First Roll", "elapsed": 15.5, "net_ink": 28, "deaths": 0, "explorer": true, "engineer": true, "master": true})
	await process_frame
	interface.show_message("Interface checks complete")
	await process_frame
	interface.queue_free()
	await process_frame
	print("UI_SMOKE_PASS: menus, settings, draw HUD, completion, indexed multitouch, pause release")
	quit(0)
