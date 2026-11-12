extends SceneTree
## The test launcher inspects the engine's shutdown log, including leak warnings.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var manager: Variant = load("res://scripts/managers/audio_manager.gd").new()
	manager.playback_enabled = true
	root.add_child(manager)
	await process_frame
	await process_frame
	if not manager.music_player.playing:
		push_error("Immediate-shutdown probe requires active PCM playback.")
		quit(1)
		return
	print("Audio immediate-shutdown probe reached active loop playback.")
	quit(0)
