extends SceneTree
## Same-session layer isolation. Never treats changed diagnostic visibility as
## a production performance result; only the baseline phases render the full game.
var game: Variant
var rows: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")

func percentiles(values: Array[float]) -> Dictionary:
	values.sort()
	return {"median": values[values.size()/2], "p95": values[int(values.size()*.95)], "max": values[-1]}

func run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	var save: Variant = root.get_node("SaveManager")
	save.data.settings["reduced_motion"] = false
	save.data.settings["difficulty"] = "normal"
	game = load("res://scenes/core/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_level(50)
	if game.state == "paused": game._resume()
	var phases := ["baseline", "static_background", "no_background", "no_world", "no_ui", "baseline_repeat"]
	var label := ""
	for argument in OS.get_cmdline_user_args():
		if argument == "--full-only": phases = ["baseline","baseline_repeat"]
		if argument.begins_with("--label="): label = "-"+argument.get_slice("=",1).validate_filename()
	for phase in phases:
		game.background.visible = phase != "no_background"
		game.background.set_reduced_motion(phase == "static_background")
		game.world.visible = phase != "no_world"
		game.ui.visible = phase != "no_ui"
		if game.state == "paused": game._resume()
		for i in range(80): await process_frame
		var frame: Array[float] = []
		var process: Array[float] = []
		var physics: Array[float] = []
		var background_draw: Array[float] = []
		var world_draw: Array[float] = []
		var draw_calls: Array[float] = []
		var primitives: Array[float] = []
		var states: Dictionary = {}
		var focused: int = 0
		for i in range(120):
			var began := Time.get_ticks_usec()
			await process_frame
			frame.append((Time.get_ticks_usec()-began)/1000.0)
			process.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.0)
			physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
			background_draw.append(float(game.background.presentation_draw_usec)/1000.0)
			world_draw.append(float(game.world.presentation_draw_usec)/1000.0)
			draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
			states[game.state] = int(states.get(game.state,0))+1
			if root.has_focus(): focused+=1
		var record := {"phase":phase,"frame_ms":percentiles(frame),"process_ms":percentiles(process),"physics_ms":percentiles(physics),"background_draw_ms":percentiles(background_draw),"world_draw_ms":percentiles(world_draw),"draw_calls":percentiles(draw_calls),"primitives":percentiles(primitives),"states":states,"focused_frames":focused,"samples":120}
		rows.append(record)
		print("RENDER_DIAGNOSTIC ",JSON.stringify(record))
	var result := {"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),"viewport":[1280,720],"limit":"Native Windows Intel host with maxfps60; layer-isolation phases alter rendering only and are diagnostic, not production performance claims.","phases":rows}
	var output := FileAccess.open("res://builds/doodledrift-render-diagnostic"+label+".json",FileAccess.WRITE)
	output.store_string(JSON.stringify(result,"\t"));output.close()
	game._to_menu();game.queue_free();await process_frame
	var audio: Variant = root.get_node("AudioManager")
	await audio.prepare_shutdown()
	quit()
