extends SceneTree
## Native viewport fixtures for UI layout inspection. Completion data below is a
## presentation fixture and does not claim or award an actual level completion.

func _initialize() -> void:
	call_deferred("_run")

func _capture(name: String) -> void:
	await create_timer(.28).timeout
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png("res://docs/screenshots/doodledrift-" + name + ".png")
	print("CAPTURE: %s %dx%d" % [name, image.get_width(), image.get_height()])

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/screenshots"))
	var manager := root.get_node("SaveManager")
	var original_settings: Dictionary = manager.data.settings.duplicate(true)
	manager.data.settings.ui_scale = 1.0
	manager.data.settings.control_size = 1.0
	root.size = Vector2i(1280, 720)
	var backdrop_layer := CanvasLayer.new()
	backdrop_layer.layer = -10
	root.add_child(backdrop_layer)
	var backdrop := BiomeBackground.new()
	backdrop_layer.add_child(backdrop)
	backdrop.set_reduced_motion(true)
	var ui := QuestUI.new()
	root.add_child(ui)
	await process_frame
	ui.show_menu()
	await _capture("menu-1280")
	ui.show_biomes()
	await _capture("worlds")
	ui.show_levels(0)
	await _capture("levels")
	ui.show_settings()
	await _capture("settings")
	ui.show_progress()
	await _capture("achievements")
	ui.show_pause()
	await _capture("pause")
	ui.show_completion({"id": 1, "name": "Spring to Sky Garden", "elapsed": 14.3, "net_ink": 21.5, "deaths": 0, "explorer": true, "engineer": true, "master": true})
	await _capture("completion-fixture")
	root.size = Vector2i(1152, 720)
	manager.data.settings.ui_scale = 1.25
	manager.data.settings.control_size = 1.35
	await process_frame
	ui.show_menu()
	await _capture("menu-1152-large")
	ui.show_settings()
	await _capture("settings-1152-large")
	ui.show_levels(0)
	await _capture("levels-1152-large")
	root.size = Vector2i(1600, 720)
	manager.data.settings.ui_scale = .85
	manager.data.settings.control_size = .85
	await process_frame
	ui.show_menu()
	await _capture("menu-1600-small")
	manager.data.settings = original_settings
	ui.queue_free()
	backdrop_layer.queue_free()
	await process_frame
	print("DOODLEDRIFT_UI_VISUAL_PASS: native interface fixtures and aspect extremes")
	quit(0)
