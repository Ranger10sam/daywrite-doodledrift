extends SceneTree
## Automated viewport capture; requires a graphical rendering driver.

func _initialize() -> void:
	call_deferred("_run")

func _capture(file_name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png("res://docs/screenshots/" + file_name + ".png")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/screenshots"))
	var layer := CanvasLayer.new()
	layer.layer = -10
	root.add_child(layer)
	var backdrop := BiomeBackground.new()
	layer.add_child(backdrop)
	backdrop.set_reduced_motion(true)
	var interface := QuestUI.new()
	root.add_child(interface)
	await process_frame
	interface.show_menu()
	await create_timer(.3).timeout
	await _capture("main-menu")
	interface.show_biomes()
	await create_timer(.3).timeout
	await _capture("world-select")
	interface.show_levels(0)
	await create_timer(.3).timeout
	await _capture("level-select")
	interface.show_settings()
	await create_timer(.3).timeout
	await _capture("settings")
	interface.queue_free()
	layer.queue_free()
	await process_frame
	print("UI_VISUAL_PASS: four viewport captures")
	quit(0)
