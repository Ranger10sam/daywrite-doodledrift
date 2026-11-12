extends SceneTree
## Rebrand-specific checks supplement the existing indexed-touch smoke suite.

var _checks := 0
var _failures: Array[String] = []
var _actions: Array = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(description)
		push_error(description)

func _text_exists(interface: QuestUI, wanted: String) -> bool:
	for node in interface._root.find_children("*", "Label", true, false):
		if node.text == wanted:
			return true
	return false

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var interface := QuestUI.new()
	root.add_child(interface)
	interface.action.connect(func(name: String, value: Variant) -> void: _actions.append([name, value]))
	await process_frame
	var weight_tag := TextServerManager.get_primary_interface().name_to_tag("wght")
	_check(interface._title_font is FontVariation and interface._title_font.base_font.resource_path == "res://assets/fonts/Fredoka-Variable.ttf", "Authentic Fredoka title resource loaded")
	_check(interface._body_font is FontVariation and interface._body_font.base_font.resource_path == "res://assets/fonts/Nunito-Variable.ttf", "Authentic Nunito body resource loaded")
	_check(float(interface._title_font.variation_opentype.get(weight_tag, 0)) == 600, "Fredoka uses actual variable weight 600")
	_check(float(interface._body_font.variation_opentype.get(weight_tag, 0)) == 600, "Nunito uses actual variable weight 600")
	_check(interface._load_font("res://assets/fonts/unavailable.ttf", 500) == ThemeDB.fallback_font, "Missing font has a bundled engine fallback")
	for codepoint: int in [0x2190, 0x2192, 0x25c6, 0x25c7, 0x2713]:
		_check(interface._font_for_text(interface._button_font, String.chr(codepoint)).has_char(codepoint), "Bundled font chain covers UI symbol U+%04X" % codepoint)
	interface.show_menu()
	await process_frame
	_check(_text_exists(interface, "DoodleDrift"), "New brand appears on the menu")
	_check(_text_exists(interface, "A little adventure by Daywrite"), "Exact Daywrite subtitle appears")
	var labels: Array[String] = []
	for button in interface._root.find_children("*", "Button", true, false):
		labels.append(button.text)
	for wanted: String in ["Continue  →", "Play", "Worlds", "Achievements", "Settings"]:
		_check(wanted in labels, "Menu action remains present: " + wanted)
	interface.show_settings()
	await process_frame
	for wanted: String in ["Master volume", "Music", "Ambience", "Sound effects", "Mute all sound", "Reduced motion", "Text / interface scale"]:
		_check(_text_exists(interface, wanted), "Setting remains available: " + wanted)
	var original_music := float(interface._settings_cache.get("music", .3))
	interface._setting("ambience", .15)
	_check(float(interface._settings_cache.ambience) == .15, "Ambience slider has an independent key")
	_check(float(interface._settings_cache.get("music", .3)) == original_music, "Ambience does not alter music volume")
	_check(not _actions.is_empty() and _actions[-1][0] == "settings_changed", "Setting still uses the session action boundary")
	var levels: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels/campaign.json"))
	var level: Dictionary = levels[0]
	interface.show_gameplay(level)
	interface.update_hud({"ink": 42.0, "max_ink": 100.0, "draw_mode": true, "selected_ink": "bounce", "elapsed": 4.2, "deaths": 0})
	await process_frame
	_check(interface._ink_buttons.size() == 5, "All five physics ink identities remain visible")
	for ink: String in interface.INKS:
		_check(interface._ink_buttons[ink].disabled == (not ink in level.get("allowed_inks", interface.INKS)), "Per-level ink restriction preserved: " + ink)
	_check(interface._ink_value.text == "42 / 100", "Numerical reservoir shows the actual resource")
	_check(interface._ink_target == 42.0, "Animated meter follows the actual resource target")
	interface.release_controls()
	interface.queue_free()
	await process_frame
	print("DOODLEDRIFT_UI: %d checks, %d failures" % [_checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)
