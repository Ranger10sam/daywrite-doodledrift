extends Node
## Session orchestration only; physics, geometry, level data and presentation are separate.
const PLAYER_SCENE := preload("res://scenes/player/ball.tscn")
const WORLD_SCENE := preload("res://scenes/levels/level_world.tscn")
const DRAWING_SCENE := preload("res://scenes/drawing/drawing_controller.tscn")
const UI_SCENE := preload("res://scenes/ui/quest_ui.tscn")
const CAMERA_SCENE := preload("res://scenes/gameplay/camera.tscn")
var campaign: Array = []
var ui: QuestUI
var background: BiomeBackground
var world: LevelWorld
var player: QuestBall
var camera: QuestCamera
var drawing: DrawingController
var level_id: int = 1
var state: String = "menu"
var elapsed: float = 0.0
var deaths: int = 0
var checkpoint := Vector2.ZERO
var checkpoint_drawings: Array[Dictionary] = []
var checkpoint_ink: float = 100.0
var checkpoint_spent: float = 0.0
var checkpoint_refunded: float = 0.0
var checkpoint_ledger: Array[Dictionary] = []
var checkpoint_next_id: int = 1
var touch_left: bool = false
var touch_right: bool = false
var touch_brake: bool = false
var keyboard_left: bool = false
var keyboard_right: bool = false
var keyboard_brake: bool = false
var difficulty: String = "normal"
var hud_clock: float = 0.0
var quitting: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	PhysicsConfig.load_config()
	PhysicsServer2D.set_active(true)
	campaign = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels/campaign.json"))
	var background_layer := CanvasLayer.new()
	background_layer.layer = -10
	add_child(background_layer)
	background = BiomeBackground.new()
	background_layer.add_child(background)
	ui = UI_SCENE.instantiate() as QuestUI
	add_child(ui)
	ui.action.connect(_on_action)
	SaveManager.save_error.connect(ui.show_message)
	_apply_settings()
	ui.show_menu()
	if not SaveManager.recovery_message.is_empty():
		ui.show_message(SaveManager.recovery_message)
	# Optional command line entry points are developer tooling, never an unlock path in release.
	if OS.is_debug_build():
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--level="):
				call_deferred("start_level", int(argument.get_slice("=", 1)))
	get_tree().auto_accept_quit = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if state in ["playing", "drawing"]:
			pause_game()
		SaveManager.save_game()
		AudioManager.suspend_audio()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		AudioManager.resume_audio()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		AudioManager.resume_audio()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit_game()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if state in ["playing", "drawing"]:
			pause_game()
		elif state == "paused":
			_resume()
		else:
			_to_menu()

func start_level(id: int) -> void:
	if id < 1 or id > campaign.size():
		_to_menu()
		return
	if id > 10 and not Entitlements.has_premium():
		ui.show_message(Entitlements.request_purchase())
		return
	# Sequential campaign progression; debug builds expose level selection for QA.
	if not SaveManager.is_unlocked(id) and not OS.is_debug_build():
		ui.show_message("Complete the previous level first.")
		return
	_dispose_level()
	level_id = id
	difficulty = str(SaveManager.data.settings.get("difficulty", "normal"))
	var data: Dictionary = campaign[id - 1]
	var modifiers := PhysicsConfig.difficulty(difficulty)
	world = WORLD_SCENE.instantiate() as LevelWorld
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	world.configure(data, difficulty)
	add_child(world)
	player = PLAYER_SCENE.instantiate() as QuestBall
	player.position = LevelWorld.vec(data.start)
	player.coyote_duration = float(modifiers.coyote)
	player.buffer_duration = float(modifiers.buffer)
	world.add_child(player)
	world.player = player
	camera = CAMERA_SCENE.instantiate() as QuestCamera
	camera.target = player
	camera.bounds = Vector2(float(data.width), float(data.height))
	world.add_child(camera)
	camera.make_current()
	drawing = DRAWING_SCENE.instantiate() as DrawingController
	drawing.level_world = world
	drawing.player = player
	drawing.selected_ink = str(data.get("allowed_inks",["solid"])[0])
	add_child(drawing)
	drawing.reservoir.configure(float(data.get("ink", 100.0)) * float(modifiers.capacity) / 100.0, float(data.get("regen", 5.0)) * float(modifiers.regen) / 5.0)
	drawing.feedback.connect(ui.show_message)
	world.reached_finish.connect(_complete_level)
	world.player_failed.connect(_fail)
	world.checkpoint_reached.connect(_activate_checkpoint)
	world.pickup_collected.connect(drawing.reservoir.pickup)
	checkpoint = player.position
	checkpoint_drawings.clear()
	elapsed = 0.0
	deaths = 0
	state = "playing"
	get_tree().paused = false
	_clear_inputs()
	SaveManager.data.last_level = id
	SaveManager.save_game()
	background.set_biome(int(data.biome))
	AudioManager.set_biome(int(data.biome))
	_apply_settings()
	ui.show_gameplay(data)
	_capture_checkpoint_state()
	_update_hud()
	SaveManager.data.tutorials[str(id)] = true
	SaveManager.save_game()

func _dispose_level() -> void:
	get_tree().paused = false
	_clear_inputs()
	if is_instance_valid(drawing):
		drawing.cancel_stroke()
		drawing.queue_free()
	if is_instance_valid(world):
		world.hide()
		world.process_mode = Node.PROCESS_MODE_DISABLED
		world.queue_free()
	world = null
	player = null
	camera = null
	drawing = null

func _physics_process(delta: float) -> void:
	if state == "playing" and is_instance_valid(player) and not get_tree().paused:
		elapsed += delta
		drawing.reservoir.tick(delta)
		player.axis = float(keyboard_right or touch_right) - float(keyboard_left or touch_left)
		player.braking = keyboard_brake or touch_brake
		if player.grounded and absf(player.linear_velocity.x)>90:
			AudioManager.play_sfx("rolling",clampf(absf(player.linear_velocity.x)/600.0,0.0,1.0))
		if drawing.reservoir.amount < drawing.reservoir.capacity - 0.5:
			AudioManager.play_sfx("regen",0.3)
		hud_clock += delta
		if hud_clock >= 0.05:
			hud_clock = 0.0
			_update_hud()

func _process(_delta: float) -> void:
	if is_instance_valid(camera):
		background.set_camera(camera.get_screen_center_position())
	if state == "drawing":
		_update_hud()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo:
		var pressed: bool = event.pressed
		match event.physical_keycode:
			KEY_A, KEY_LEFT: keyboard_left = pressed and state == "playing"
			KEY_D, KEY_RIGHT: keyboard_right = pressed and state == "playing"
			KEY_S, KEY_DOWN: keyboard_brake = pressed and state == "playing"
			KEY_SPACE, KEY_W, KEY_UP:
				if pressed and state == "playing" and is_instance_valid(player):
					player.request_jump()
			KEY_E, KEY_TAB:
				if pressed and state in ["playing", "drawing"]:
					toggle_draw()
			KEY_ESCAPE, KEY_P:
				if pressed:
					if state in ["playing", "drawing"]:
						pause_game()
					elif state == "paused":
						_resume()
			KEY_Z:
				if pressed and state == "drawing":
					drawing.undo()
			KEY_R:
				if pressed and state in ["playing", "drawing", "paused"]:
					start_level(level_id)
			KEY_F3:
				if pressed and OS.is_debug_build() and is_instance_valid(world):
					world.debug = not world.debug
					get_tree().debug_collisions_hint = world.debug
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
				if pressed and state == "drawing":
					drawing.finish_stroke()
					drawing.selected_ink = InkCatalog.IDS[event.physical_keycode - KEY_1]
		get_viewport().set_input_as_handled()

func _on_action(action: String, value: Variant) -> void:
	match action:
		"play": start_level(int(value))
		"continue": start_level(int(SaveManager.data.get("last_level", 1)))
		"menu": _to_menu()
		"retry": start_level(level_id)
		"next":
			if level_id < campaign.size():
				start_level(level_id + 1)
			else:
				_to_menu()
		"pause": pause_game()
		"resume": _resume()
		"draw": toggle_draw()
		"ink":
			if is_instance_valid(drawing) and str(value) in InkCatalog.IDS:
				drawing.finish_stroke()
				drawing.selected_ink = str(value)
				AudioManager.play_sfx("select")
		"reverse":
			if is_instance_valid(drawing):
				drawing.finish_stroke()
				drawing.reverse = not drawing.reverse
		"undo":
			if state == "drawing": drawing.undo()
		"clear":
			if state == "drawing": drawing.clear_drawings()
		"cancel_stroke":
			if state == "drawing": drawing.cancel_stroke()
		"move_left": touch_left = bool(value) and state == "playing"
		"move_right": touch_right = bool(value) and state == "playing"
		"brake": touch_brake = bool(value) and state == "playing"
		"jump":
			if bool(value) and state == "playing" and is_instance_valid(player): player.request_jump()
		"settings_changed":
			SaveManager.set_settings(value)
			_apply_settings()
		"backup_export":
			var error := SaveManager.export_backup(str(value.path), str(value.password))
			ui.show_message("Encrypted backup exported." if error.is_empty() else error)
		"backup_import":
			var error := SaveManager.import_backup(str(value.path), str(value.password), true)
			if error.is_empty():
				_to_menu()
				_apply_settings()
			ui.show_message("Progress imported." if error.is_empty() else error)
		"restore_save":
			var error := SaveManager.restore_previous()
			if error.is_empty():
				_to_menu()
				_apply_settings()
			ui.show_message("Previous save restored." if error.is_empty() else error)
		"quit", "exit":
			_quit_game()
	_update_hud()

func toggle_draw() -> void:
	if state == "playing":
		state = "drawing"
		_clear_inputs()
		drawing.start_mode()
		camera.zoom = Vector2(0.64,0.64)
		world.drawing = true
		world.queue_redraw()
		get_tree().paused = true
	elif state == "drawing":
		drawing.end_mode()
		camera.zoom = Vector2(0.82,0.82)
		state = "playing"
		world.drawing = false
		world.queue_redraw()
		get_tree().paused = false
	_update_hud()

func pause_game() -> void:
	if state not in ["playing", "drawing"]:
		return
	if state == "drawing":
		drawing.cancel_stroke()
		drawing.draw_mode = false
		world.drawing = false
	state = "paused"
	_clear_inputs()
	get_tree().paused = true
	ui.show_pause()
	SaveManager.save_game()

func _resume() -> void:
	if not is_instance_valid(world):
		_to_menu()
		return
	state = "playing"
	_clear_inputs()
	get_tree().paused = false
	ui.show_gameplay(campaign[level_id - 1])
	_update_hud()

func _to_menu() -> void:
	state = "menu"
	_dispose_level()
	background.set_biome(0)
	background.set_camera(Vector2.ZERO)
	AudioManager.set_biome(0)
	ui.show_menu()

func _clear_inputs() -> void:
	touch_left = false
	touch_right = false
	touch_brake = false
	keyboard_left = false
	keyboard_right = false
	keyboard_brake = false
	if is_instance_valid(player): player.clear_controls()
	if is_instance_valid(ui): ui.release_controls()

func _activate_checkpoint(at: Vector2) -> void:
	checkpoint = at
	_capture_checkpoint_state()
	ui.show_message("Checkpoint saved")

func _capture_checkpoint_state() -> void:
	checkpoint_drawings = drawing.snapshot()
	checkpoint_ink = drawing.reservoir.amount
	checkpoint_spent = drawing.reservoir.total_spent
	checkpoint_refunded = drawing.reservoir.total_refunded
	checkpoint_ledger = drawing.reservoir.debt.duplicate(true)
	checkpoint_next_id = drawing.reservoir.next_id
	# Store each original ledger ID so undo after restoration refunds the same debit.
	var i := 0
	for stroke in drawing.strokes:
		if is_instance_valid(stroke) and not stroke.removed:
			checkpoint_drawings[i]["ledger_id"] = stroke.ledger_id
			i += 1

func _fail() -> void:
	if state != "playing": return
	if difficulty != "zen": deaths += 1
	state = "respawning"
	_clear_inputs()
	world.burst_at(player.position, Color("ff9eaa"), 18)
	AudioManager.play_sfx("fail")
	player.hide()
	player.set_deferred("freeze", true)
	var failed_world := world
	var failed_player := player
	await get_tree().create_timer(0.22, false).timeout
	if state != "respawning" or not is_instance_valid(world) or not is_instance_valid(player): return
	if world != failed_world or player != failed_player: return
	# Whole checkpoint snapshot: drawings, ledger, pickups, platforms, fragile timers.
	# Death never erases previous accepted ink from mastery accounting.
	var spent_on_attempt := drawing.reservoir.net_used()
	drawing.clear_drawings(false)
	drawing.reservoir.amount = maxf(checkpoint_ink, minf(25.0, drawing.reservoir.capacity))
	drawing.reservoir.total_spent = maxf(checkpoint_spent, spent_on_attempt + checkpoint_refunded)
	drawing.reservoir.total_refunded = checkpoint_refunded
	drawing.reservoir.debt = checkpoint_ledger.duplicate(true)
	drawing.reservoir.next_id = checkpoint_next_id
	for saved in checkpoint_drawings:
		var stroke := InkStroke.new()
		stroke.configure(saved.points, saved.ink, bool(saved.reverse))
		stroke.ledger_id = int(saved.get("ledger_id", 0))
		stroke.process_mode = Node.PROCESS_MODE_PAUSABLE
		stroke.shattered.connect(drawing._on_shattered)
		world.add_child(stroke)
		drawing.strokes.append(stroke)
	world.reset_checkpoint()
	player.freeze = false
	player.respawn(_safe_respawn_target(checkpoint))
	player.show()
	camera.snap()
	state = "playing"
	_update_hud()

func _complete_level() -> void:
	if state != "playing": return
	state = "complete"
	player.set_meta("victory",true)
	_clear_inputs()
	var level: Dictionary = campaign[level_id - 1]
	var budget := float(level.budget) * float(PhysicsConfig.difficulty(difficulty).budget)
	var used := drawing.reservoir.net_used()
	var result := {"id": level_id, "name": str(level.name), "elapsed": elapsed, "net_ink": used, "deaths": deaths, "budget": budget, "difficulty": difficulty, "explorer": difficulty != "zen", "engineer": used <= budget and difficulty != "zen", "master": deaths == 0 and difficulty != "zen"}
	SaveManager.complete_level(level_id, result)
	var record: Dictionary = SaveManager.data.levels.get(str(level_id), {})
	result["best_time"] = float(record.get("best_time", elapsed))
	result["best_ink"] = float(record.get("best_ink", used))
	world.burst_at(player.position, Color("ffc378"), 30)
	AudioManager.play_sfx("complete")
	if result.engineer or result.master: AudioManager.play_sfx("achievement")
	get_tree().paused = true
	ui.show_completion(result)

func _apply_settings() -> void:
	var settings: Dictionary = SaveManager.data.get("settings", {})
	AudioManager.apply_settings(settings)
	background.set_reduced_motion(bool(settings.get("reduced_motion", false)))
	if is_instance_valid(player):
		player.facial_expression = bool(settings.get("face", true))
		player.reduced_motion = bool(settings.get("reduced_motion", false))
		world.reduced_motion = player.reduced_motion
		camera.reduced_motion = player.reduced_motion
		world.trajectory_hint = bool(settings.get("trajectory_hint", false)) and difficulty in ["easy", "zen"]

func _safe_respawn_target(preferred: Vector2) -> Vector2:
	var circle := CircleShape2D.new()
	circle.radius = PhysicsConfig.number("radius", 18.0) + 0.5
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.collision_mask = 1 | 4 | 8
	for offset in [Vector2.ZERO, Vector2(0, -8), Vector2(0, -24), Vector2(-30, -24), Vector2(30, -24), Vector2(0, -60), Vector2(0, -100)]:
		query.transform = Transform2D(0, preferred + offset)
		if world.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
			return preferred + offset
	# Validated start is the final safe fallback; reset drawings if their restore blocks it.
	drawing.clear_drawings(false)
	return LevelWorld.vec(world.definition.start)

func _update_hud() -> void:
	if not is_instance_valid(drawing) or not is_instance_valid(ui): return
	ui.update_hud({"ink": drawing.reservoir.amount, "max_ink": drawing.reservoir.capacity, "draw_mode": state == "drawing", "selected_ink": drawing.selected_ink, "reverse": drawing.reverse, "elapsed": elapsed, "deaths": deaths, "net_ink": drawing.reservoir.net_used(), "difficulty": difficulty, "velocity": player.linear_velocity if is_instance_valid(player) else Vector2.ZERO})

func _quit_game() -> void:
	if quitting: return
	quitting=true
	SaveManager.save_game()
	await AudioManager.prepare_shutdown()
	get_tree().quit()
