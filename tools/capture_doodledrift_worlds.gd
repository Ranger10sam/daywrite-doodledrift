extends SceneTree
## Native production-scene captures for the visual rebrand; no screenshot mockups.
var game: Variant

func _initialize() -> void:
	call_deferred("capture_worlds")

func capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(image.get_width()==1280 and image.get_height()==720)
	assert(image.save_png("res://docs/screenshots/"+name+".png")==OK)

func capture_worlds() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	var manager: Variant = root.get_node("SaveManager")
	var original: Dictionary = manager.data.settings.duplicate(true)
	manager.data.settings["reduced_motion"] = true
	manager.data.settings["difficulty"] = "normal"
	manager.data.settings["face"] = true
	game = load("res://scenes/core/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var ids := [3,13,24,35,50]
	for index in range(ids.size()):
		game.start_level(ids[index])
		await create_timer(.25).timeout
		if game.state == "paused":
			game._resume()
		await capture("doodledrift-world-%d"%(index+1))
	game.start_level(7)
	await create_timer(.2).timeout
	if game.state == "paused":
		game._resume()
	game.toggle_draw()
	var inks := ["solid","bounce","boost","ice","fragile"]
	for i in range(inks.size()):
		game.drawing.selected_ink = inks[i]
		# This existing two-parcel chute permits all five inks.
		var a := Vector2(665,380+i*45)
		var b := Vector2(785,380+i*45)
		assert(game.drawing.begin_stroke(a))
		game.drawing.accept_to(b)
		game.drawing.finish_stroke()
	game.drawing.selected_ink = "bounce"
	game._update_hud()
	await capture("doodledrift-five-inks")
	manager.data.settings = original
	game._to_menu()
	game.queue_free()
	await process_frame
	print("DOODLEDRIFT_WORLD_VISUAL_PASS: five nativebiomes + physicalinkdrawmode captures1280x720")
	var audio: Variant = root.get_node("AudioManager")
	await audio.prepare_shutdown()
	quit(0)
