extends SceneTree
## Native presentation sample, not Android performance certification.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var audio: Variant=root.get_node("AudioManager")
	root.size=Vector2i(1280,720)
	var game: Variant=load("res://scenes/core/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_level(50)
	var frame_ms: Array[float]=[]
	var process_ms: Array[float]=[]
	var physics_ms: Array[float]=[]
	var peak_db := -100.0
	var sampled_states: Dictionary={}
	var focused_frames := 0
	for i in range(720):
		var began := Time.get_ticks_usec()
		await process_frame
		if i % 120 == 0: audio.play_sfx("jump")
		if i>=120:
			sampled_states[game.state]=int(sampled_states.get(game.state,0))+1
			if root.has_focus(): focused_frames+=1
			frame_ms.append((Time.get_ticks_usec()-began)/1000.0)
			process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.0)
			physics_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
			peak_db=maxf(peak_db,AudioServer.get_bus_peak_volume_left_db(0,0))
	frame_ms.sort(); process_ms.sort(); physics_ms.sort()
	var result := {"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_video_adapter_name(),"display":DisplayServer.get_name(),"viewport":[1280,720],"scenario":"Level50 idle, pastel scene/HUD, audio active;120warmup+600renderframes; OS scheduling and vsync included", "frames":600,"frame_median_ms":frame_ms[300],"frame_p95_ms":frame_ms[570],"frame_max_ms":frame_ms[-1],"process_median_ms":process_ms[300],"process_p95_ms":process_ms[570],"physics_p95_ms":physics_ms[570],"master_peak_db":peak_db,"limits":"Single Windows host, not Android/GPU profiling, maximum drawing complexity or subjective audio listening."}
	result["states"]=sampled_states
	result["focused_frames"]=focused_frames
	var output := FileAccess.open("res://builds/doodledrift-presentation-profile.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(result,"\t")); output.close()
	print("PRESENTATION_PROFILE ",result)
	game._to_menu(); game.queue_free(); await process_frame
	await audio.prepare_shutdown()
	quit()
