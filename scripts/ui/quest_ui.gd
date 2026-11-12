class_name QuestUI
extends CanvasLayer
## The interface keeps running while the world is paused. Each touch owns its
## control until release, so two fingers can move and jump independently.

signal action(name: String, value: Variant)

const BG := Color("FFF9F0")
const PANEL := Color("FFFEFA")
const TEXT := Color("344054")
const MUTED := Color("647286")
const MINT := Color("A8DFC8")
const LAVENDER := Color("C5AFF1")
const PEACH := Color("FFCAA6")
const SKY := Color("B7DFFF")
const ROSE := Color("F5B3C5")
const ACCENT := Color("3F7564")
const CORAL := Color("f5b48e")
const INKS := ["solid", "bounce", "boost", "ice", "fragile"]
const INK_COLORS := {"solid": Color("BDC8CF"), "bounce": LAVENDER, "boost": Color("FFC18B"), "ice": Color("A9DFED"), "fragile": ROSE}
const INK_TEXT := {"solid": Color("526276"), "bounce": Color("71539A"), "boost": Color("8A5935"), "ice": Color("396E82"), "fragile": Color("91516A")}
const INK_COSTS := {"solid": "1x", "bounce": "2.5x", "boost": "2x", "ice": "1.5x", "fragile": "0.5x"}
const WORLDS := ["Green Valley", "Frozen Peaks", "Desert Winds", "Crystal Caverns", "Volcanic Core"]
const WORLD_DESCS := ["Find your feet. Then find your momentum.", "Carry your speed across the quiet snow.", "Ride the wind. Make every launch count.", "Think upwards. Follow the crystal glow.", "One final journey through fire and stone."]
const WORLD_COLORS := [MINT, SKY, PEACH, LAVENDER, ROSE]
const WORLD_TEXT := [ACCENT, Color("426582"), Color("885D3E"), Color("71548E"), Color("925446")]
const WebBackup := preload("res://scripts/ui/web_backup_bridge.gd")
const MenuBall := preload("res://scripts/ui/menu_companion.gd")

var _root: Control
var _toast: Label
var _toast_tween: Tween
var _screen := "menu"
var _in_level := false
var _draw_mode := false
var _level: Dictionary = {}
var _stats: Dictionary = {}
var _campaign: Array = []
var _settings_cache: Dictionary = {}
var _touch_buttons: Array[Dictionary] = []
var _touch_owners: Dictionary = {}
var _held_counts: Dictionary = {}
var _blocking: Array[Control] = []
var _ink_meter: ProgressBar
var _ink_value: Label
var _time_label: Label
var _selected_label: Label
var _draw_label: Label
var _ink_buttons: Dictionary = {}
var _reverse_button: Button
var _ink_display := 100.0
var _ink_target := 100.0
var _last_hud_ink := ""
var _dialog_open := false
var _chosen_biome := 0
var _last_completion: Dictionary = {}
var _resize_pending := false
var _web_backups: WebBackup
var _title_font: Font
var _button_font: Font
var _body_font: Font
var _symbol_fonts: Array[Font] = []
var _text_font_cache: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels/campaign.json"))
	if parsed is Array:
		_campaign = parsed
	elif parsed is Dictionary:
		_campaign = parsed.get("levels", [])
	_root = Control.new()
	_root.name = "Interface"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	for path: String in ["res://assets/fonts/NotoSansSymbols-Variable.ttf", "res://assets/fonts/NotoSansSymbols2-Regular.ttf"]:
		if ResourceLoader.exists(path):
			_symbol_fonts.append(load(path))
	_symbol_fonts.append(ThemeDB.fallback_font)
	_title_font = _load_font("res://assets/fonts/Fredoka-Variable.ttf", 600.0)
	_button_font = _load_font("res://assets/fonts/Fredoka-Variable.ttf", 500.0)
	_body_font = _load_font("res://assets/fonts/Nunito-Variable.ttf", 600.0)
	var theme := Theme.new()
	theme.default_font_size = 20
	theme.default_font = _body_font
	_configure_theme(theme)
	_root.theme = theme
	set_process_input(true)
	get_viewport().size_changed.connect(_on_viewport_resize)
	if OS.has_feature("web"):
		_web_backups = WebBackup.new()
		add_child(_web_backups)
		_web_backups.feedback.connect(show_message)
		_web_backups.download_ready.connect(func(bytes: PackedByteArray) -> void:
			_confirm("Your backup is ready", "Click Download to save your encrypted progress file.", func() -> void: _web_backups.download(bytes), "Download")
		)
		_web_backups.backup_selected.connect(func(path: String, password: String) -> void:
			var payload := {"path": path, "password": password}
			_confirm("Replace progress with this backup?", "Your current progress will be backed up first. The password and backup must pass validation.", func() -> void:
				_emit("backup_import", payload)
				_web_backups.cleanup_import()
			)
		)

func _load_font(path: String, weight: float) -> Font:
	if ResourceLoader.exists(path):
		var base: Font = load(path)
		if base != null:
			base.fallbacks = []
			var font := FontVariation.new()
			font.base_font = base
			font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
			return font
	return ThemeDB.fallback_font

func _font_for_text(base: Font, text: String) -> Font:
	var needed: Array[int] = []
	var mask := 0
	var symbols := [0x2190, 0x2192, 0x25c6, 0x25c7, 0x2713]
	for index in range(symbols.size()):
		if text.contains(String.chr(symbols[index])):
			needed.append(symbols[index])
			mask |= 1 << index
	if needed.is_empty():
		return base
	var key := "%d:%d" % [base.get_instance_id(), mask]
	if _text_font_cache.has(key):
		return _text_font_cache[key]
	# Noto symbol faces have taller vertical metrics. Limit their fallback chain
	# to strings that actually need symbols, preserving ordinary text layout.
	var composed := FontVariation.new()
	if base is FontVariation:
		composed.base_font = base.base_font
		composed.variation_opentype = base.variation_opentype.duplicate()
	else:
		composed.base_font = base
	var fallbacks: Array[Font] = []
	for candidate: Font in _symbol_fonts:
		for codepoint: int in needed:
			if candidate.has_char(codepoint):
				fallbacks.append(candidate)
				break
	composed.fallbacks = fallbacks
	_text_font_cache[key] = composed
	return composed

func _configure_theme(theme: Theme) -> void:
	# Native-looking Godot defaults would break the paper-and-pastel language on
	# popups and password fields, so style those shared controls as well.
	for type_name: String in ["Button", "OptionButton", "MenuButton"]:
		theme.set_font("font", type_name, _button_font)
		theme.set_color("font_color", type_name, TEXT)
		theme.set_color("font_hover_color", type_name, TEXT)
		theme.set_color("font_pressed_color", type_name, TEXT)
		theme.set_color("font_focus_color", type_name, TEXT)
		theme.set_stylebox("normal", type_name, _style(PANEL, Color("DEDCD6")))
		theme.set_stylebox("hover", type_name, _style(LAVENDER.lightened(.67), Color("B59EDC")))
		theme.set_stylebox("pressed", type_name, _style(MINT, ACCENT))
		theme.set_stylebox("focus", type_name, _focus_style())
		theme.set_font_size("font_size", type_name, 20)
	theme.set_stylebox("panel", "AcceptDialog", _style(PANEL, Color("D9D2E3"), 26))
	theme.set_stylebox("panel", "PopupMenu", _style(PANEL, Color("D9D2E3"), 16))
	theme.set_stylebox("hover", "PopupMenu", _style(LAVENDER.lightened(.62), Color.TRANSPARENT, 10))
	theme.set_color("font_color", "PopupMenu", TEXT)
	theme.set_color("font_hover_color", "PopupMenu", TEXT)
	theme.set_color("font_disabled_color", "PopupMenu", MUTED)
	theme.set_font("font", "PopupMenu", _body_font)
	theme.set_font_size("font_size", "PopupMenu", 20)
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_color", "LineEdit", TEXT)
	theme.set_color("font_placeholder_color", "LineEdit", MUTED)
	theme.set_color("caret_color", "LineEdit", TEXT)
	theme.set_color("selection_color", "LineEdit", LAVENDER)
	theme.set_stylebox("normal", "LineEdit", _style(Color.WHITE, Color("D7D6CF"), 14))
	theme.set_stylebox("focus", "LineEdit", _focus_style())
	theme.set_font("font", "LineEdit", _body_font)
	theme.set_font_size("font_size", "LineEdit", 20)

func _focus_style() -> StyleBoxFlat:
	var focus := _style(Color.TRANSPARENT, Color("8B70B6"), 20)
	focus.set_border_width_all(2)
	focus.shadow_size = 0
	return focus

func _process(delta: float) -> void:
	if _screen == "gameplay" and is_instance_valid(_ink_meter):
		_ink_display = move_toward(_ink_display, _ink_target, maxf(18.0, absf(_ink_display - _ink_target) * 14.0) * delta)
		_ink_meter.value = _ink_display

func _save() -> Dictionary:
	var manager := get_node_or_null("/root/SaveManager")
	if manager != null:
		return manager.data
	return {}

func _settings() -> Dictionary:
	return _save().get("settings", {})

func _scale() -> float:
	return clampf(float(_settings().get("ui_scale", 1.0)), .85, 1.25)

func _safe_insets() -> Vector4:
	if OS.get_name() != "Android":
		return Vector4.ZERO
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var display_size: Vector2i = DisplayServer.screen_get_size()
	if display_size.x <= 0 or display_size.y <= 0 or safe.size.x <= 0:
		return Vector4.ZERO
	var ratio := get_viewport().get_visible_rect().size / Vector2(display_size)
	return Vector4(maxf(0, safe.position.x * ratio.x), maxf(0, safe.position.y * ratio.y), maxf(0, (display_size.x - safe.end.x) * ratio.x), maxf(0, (display_size.y - safe.end.y) * ratio.y))

func _on_viewport_resize() -> void:
	if not _resize_pending:
		_resize_pending = true
		call_deferred("_refresh_layout")

func _refresh_layout() -> void:
	_resize_pending = false
	if _dialog_open or not is_instance_valid(_root):
		return
	match _screen:
		"menu": show_menu()
		"biomes": show_biomes()
		"levels": show_levels(_chosen_biome)
		"settings": show_settings()
		"progress": show_progress()
		"gameplay": _build_hud()
		"pause": show_pause()
		"complete": show_completion(_last_completion)

func _emit(name: String, value: Variant = null) -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null and not name in ["move_left", "move_right", "brake", "jump"]:
		audio.play_sfx("click")
	action.emit(name, value)

func _reset(screen_name: String) -> void:
	release_controls()
	_stop_toast()
	_screen = screen_name
	# Standard Godot controls use emulated mouse input in menus. During gameplay,
	# native indexed touch capture below owns the buttons and drawing gestures.
	Input.emulate_mouse_from_touch = screen_name != "gameplay"
	for child in _root.get_children():
		if child is Control:
			child.hide()
		child.queue_free()
	_touch_buttons.clear()
	_blocking.clear()
	_ink_buttons.clear()
	_ink_meter = null
	_ink_value = null
	_time_label = null
	_selected_label = null
	_draw_label = null
	_reverse_button = null
	_toast = null
	_last_hud_ink = ""
	_dialog_open = false

func _style(color: Color, border: Color = Color.TRANSPARENT, radius: int = 18) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(1 if border.a > 0 else 0)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 22
	box.content_margin_right = 22
	box.content_margin_top = 14
	box.content_margin_bottom = 14
	box.shadow_color = Color(.26, .32, .38, .075)
	box.shadow_size = 5 if color.a > .1 else 0
	box.shadow_offset = Vector2(0, 4)
	return box

func _meter_style(color: Color) -> StyleBoxFlat:
	var box := _style(color, Color.TRANSPARENT, 5)
	box.content_margin_left = 0
	box.content_margin_right = 0
	box.content_margin_top = 0
	box.content_margin_bottom = 0
	box.shadow_size = 0
	return box

func _label(text: String, font_size: int = 20, color: Color = TEXT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", int(font_size * _scale()))
	label.add_theme_font_override("font", _font_for_text(_body_font, text))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _heading(text: String, font_size: int = 24, color: Color = TEXT) -> Label:
	var heading := _label(text, font_size, color)
	heading.add_theme_font_override("font", _font_for_text(_title_font, text))
	return heading

func _button(text: String, callback: Callable, primary: bool = false, compact: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 52 if compact else 64)
	button.add_theme_font_size_override("font_size", int((18 if compact else 21) * _scale()))
	button.add_theme_font_override("font", _font_for_text(_button_font, text))
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", TEXT)
	button.add_theme_color_override("font_pressed_color", TEXT)
	button.add_theme_color_override("font_disabled_color", Color("8C94A0"))
	button.add_theme_stylebox_override("normal", _style(MINT if primary else PANEL, Color("DDDCD5") if not primary else Color("92CBB3"), 22))
	button.add_theme_stylebox_override("hover", _style(Color("C5ECD9") if primary else LAVENDER.lightened(.69), Color("A0BDB0"), 22))
	var pressed_style := _style(Color("B6DCCB"), Color("7BAA96"), 22)
	pressed_style.shadow_size = 1
	pressed_style.shadow_offset = Vector2(0, 1)
	button.add_theme_stylebox_override("pressed", pressed_style)
	button.add_theme_stylebox_override("disabled", _style(Color("F1EEE8"), Color("E6E2DD")))
	button.add_theme_stylebox_override("focus", _focus_style())
	button.pressed.connect(callback)
	button.button_down.connect(func() -> void:
		if not bool(_settings().get("reduced_motion", false)):
			button.modulate = Color(.95, .98, .96)
	)
	button.button_up.connect(func() -> void: button.modulate = Color.WHITE)
	return button

func _panel(parent: Node, color: Color = PANEL) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(color, Color("E4E3DB"), 24))
	parent.add_child(panel)
	return panel

func _vbox(parent: Node, gap: int = 14) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", gap)
	parent.add_child(box)
	return box

func _hbox(parent: Node, gap: int = 14) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", gap)
	parent.add_child(box)
	return box

func _spacer(parent: Node, height: float = 12) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	parent.add_child(spacer)
	return spacer

func _page(title: String, subtitle: String, back: Callable) -> VBoxContainer:
	var safe := _safe_insets()
	var shade := ColorRect.new()
	shade.color = Color(.999, .976, .941, .96)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 48 + int(safe.x))
	margin.add_theme_constant_override("margin_right", 48 + int(safe.z))
	margin.add_theme_constant_override("margin_top", 30 + int(safe.y))
	margin.add_theme_constant_override("margin_bottom", 24 + int(safe.w))
	_root.add_child(margin)
	var page := _vbox(margin, 12)
	var header := _hbox(page, 20)
	header.add_child(_button("Back", back, false, true))
	var headings := _vbox(header, 2)
	headings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	headings.add_child(_heading(title, 32))
	headings.add_child(_label(subtitle, 16, MUTED))
	_spacer(page, 6)
	return page

func _scroll(parent: Node) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var content := _vbox(scroll, 16)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return content

func show_menu() -> void:
	_in_level = false
	_reset("menu")
	var safe := _safe_insets()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 58 + int(safe.x))
	margin.add_theme_constant_override("margin_right", 58 + int(safe.z))
	margin.add_theme_constant_override("margin_top", 42 + int(safe.y))
	margin.add_theme_constant_override("margin_bottom", 28 + int(safe.w))
	_root.add_child(margin)
	var columns := _hbox(margin, 46)
	var left := _vbox(columns, 8)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.3
	left.add_child(_label("DAYWRITE  /  A WORLD OF SMALL JOYS", 13, ACCENT))
	_spacer(left, 5)
	left.add_child(_heading("DoodleDrift", 82, TEXT))
	left.add_child(_label("A little adventure by Daywrite", 23, TEXT))
	_spacer(left, 6)
	left.add_child(_label("A tiny ball. A world of possibilities.
Draw your way forward.", 20, MUTED))
	var companion := MenuBall.new()
	companion.reduced_motion = bool(_settings().get("reduced_motion", false))
	companion.show_face = bool(_settings().get("face", true))
	companion.custom_minimum_size = Vector2(460, 165)
	companion.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(companion)
	left.add_child(_label("50 little journeys  ·  5 lovely worlds", 17, TEXT))
	left.add_child(_label("Roll a little. Doodle a little. Discover something new.", 14, MUTED))
	var stage := _panel(columns, Color(.999, .996, .985, .97))
	stage.custom_minimum_size.x = 356
	stage.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var right := _vbox(stage, 12)
	var last_id := int(_save().get("last_level", 1))
	right.add_child(_label("YOUR NEXT LITTLE ADVENTURE", 12, ACCENT))
	right.add_child(_heading(_level_name(last_id), 23))
	right.add_child(_label("%d / 50 journeys discovered" % _completed_count(), 16, MUTED))
	_spacer(right, 3)
	right.add_child(_button("Continue  →", func() -> void: _emit("continue"), true))
	var play := _button("Play", func() -> void: show_levels(clampi((last_id - 1) / 10, 0, 4)))
	play.add_theme_stylebox_override("normal", _style(PEACH.lightened(.12), Color("E7B995"), 22))
	right.add_child(play)
	var worlds := _button("Worlds", show_biomes)
	worlds.add_theme_stylebox_override("normal", _style(SKY.lightened(.28), Color("A8C7DD"), 22))
	right.add_child(worlds)
	var extras := _hbox(right, 10)
	var achievements := _button("Achievements", show_progress, false, true)
	achievements.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	extras.add_child(achievements)
	var settings := _button("Settings", show_settings, false, true)
	settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	extras.add_child(settings)
	if OS.is_debug_build():
		right.add_child(_label("All worlds open for this development build", 11, MUTED))
	if OS.get_name() != "Android" and not OS.has_feature("web"):
		var exit_button := _button("Exit", func() -> void: _emit("exit"), false, true)
		exit_button.add_theme_stylebox_override("normal", _style(Color.TRANSPARENT, Color.TRANSPARENT, 16))
		right.add_child(exit_button)
	_transition()

func _completed_count() -> int:
	var count := 0
	for record: Variant in _save().get("levels", {}).values():
		if record is Dictionary and bool(record.get("completed", record.get("explorer", false))):
			count += 1
	return count

func _level_name(id: int) -> String:
	for level: Dictionary in _campaign:
		if int(level.get("id", 0)) == id:
			return "%02d  %s" % [id, level.get("name", "First Roll")]
	return "01  First Roll"

func show_biomes() -> void:
	_in_level = false
	_reset("biomes")
	var page := _page("A world of possibilities", "Choose a landscape. Bring your imagination.", show_menu)
	var content := _scroll(page)
	for index in range(5):
		var row := _panel(content, Color(.999, .992, .972, .98))
		var layout := _hbox(row, 24)
		var world_number := _label("0%d" % (index + 1), 38, WORLD_TEXT[index])
		world_number.custom_minimum_size.x = 72
		layout.add_child(world_number)
		var description := _vbox(layout, 4)
		description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		description.add_child(_heading(WORLDS[index], 25))
		description.add_child(_label(WORLD_DESCS[index], 16, MUTED))
		var count := 0
		for id in range(index * 10 + 1, index * 10 + 11):
			var record: Dictionary = _save().get("levels", {}).get(str(id), {})
			if bool(record.get("completed", record.get("explorer", false))):
				count += 1
		layout.add_child(_label("%d / 10" % count, 19, WORLD_TEXT[index]))
		var world_index: int = index
		var unlocked := index == 0 or _premium()
		layout.add_child(_button("Explore  →" if unlocked else "Lifetime unlock", func() -> void:
			if unlocked:
				show_levels(world_index)
			else:
				_show_purchase_info()
		, false, true))
	_transition()

func _premium() -> bool:
	var entitlements := get_node_or_null("/root/Entitlements")
	return entitlements.has_premium() if entitlements != null else OS.is_debug_build()

func _show_purchase_info() -> void:
	var entitlements := get_node_or_null("/root/Entitlements")
	var message := "The lifetime unlock is not connected to Google Play in this build. Green Valley and all five inks are available."
	if entitlements != null:
		message = entitlements.request_purchase()
	show_message(message)

func show_levels(biome: int) -> void:
	_in_level = false
	_chosen_biome = biome
	_reset("levels")
	var page := _page(WORLDS[biome], "10 little journeys. Many ways to get there.", show_biomes)
	var content := _scroll(page)
	var grid := GridContainer.new()
	grid.columns = clampi(floori((get_viewport().get_visible_rect().size.x - 80.0) / 221.0), 2, 5)
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	content.add_child(grid)
	for id in range(biome * 10 + 1, biome * 10 + 11):
		var level_data: Dictionary = {}
		for candidate: Dictionary in _campaign:
			if int(candidate.get("id", 0)) == id:
				level_data = candidate
		var record: Dictionary = _save().get("levels", {}).get(str(id), {})
		var manager := get_node_or_null("/root/SaveManager")
		var unlocked: bool = OS.is_debug_build() or (manager != null and bool(manager.is_unlocked(id)))
		var chosen: int = id
		var button := _button("", func() -> void: _emit("play", chosen))
		button.custom_minimum_size = Vector2(205, 190 * _scale())
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.disabled = not unlocked
		grid.add_child(button)
		var margin := MarginContainer.new()
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.add_theme_constant_override("margin_left", 18)
		margin.add_theme_constant_override("margin_top", 16)
		margin.add_theme_constant_override("margin_right", 18)
		margin.add_theme_constant_override("margin_bottom", 16)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(margin)
		var card := _vbox(margin, 8)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(_label("%02d" % id, 36, WORLD_TEXT[biome] if unlocked else MUTED))
		var name_label := _heading(level_data.get("name", "Journey %d" % id), 18)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(name_label)
		var filler := _spacer(card, 4)
		filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var mastery := ""
		for objective in ["explorer", "engineer", "master"]:
			mastery += "◆ " if bool(record.get(objective, record.get("completed", false) if objective == "explorer" else false)) else "◇ "
		card.add_child(_label(mastery if unlocked else "Complete the previous journey", 18 if unlocked else 12, ACCENT if unlocked else MUTED))
	content.add_child(_label("Mastery: Explorer · reach the goal     Engineer · save ink     Master · no falls", 16, MUTED))
	_transition()

func show_pause() -> void:
	_in_level = true
	_reset("pause")
	var content := _modal("Take a breath.", "Your journey will wait right here.")
	content.add_child(_button("Keep rolling", func() -> void: _emit("resume"), true))
	content.add_child(_button("Try again", func() -> void: _confirm("Restart this journey?", "Drawings and your current run will reset.", func() -> void: _emit("retry"))))
	content.add_child(_button("Settings", show_settings))
	content.add_child(_button("Return to menu", func() -> void: _confirm("Return to the menu?", "Your completed journeys are saved. This run will end.", func() -> void: _emit("menu"))))
	content.add_child(_label("Esc / P to resume", 14, MUTED))
	_transition()

func _modal(title: String, subtitle: String) -> VBoxContainer:
	var shade := ColorRect.new()
	shade.color = Color(.999, .976, .941, .86)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var panel := _panel(center)
	panel.custom_minimum_size.x = 440
	var content := _vbox(panel, 14)
	content.add_child(_heading(title, 34))
	var subtitle_label := _label(subtitle, 17, MUTED)
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.custom_minimum_size.x = 400
	content.add_child(subtitle_label)
	_spacer(content, 6)
	return content

func _confirm(title: String, description: String, yes: Callable, accept_text: String = "Confirm") -> void:
	release_controls()
	_dialog_open = true
	Input.emulate_mouse_from_touch = true
	var dialog := ConfirmationDialog.new()
	dialog.theme = _root.theme
	dialog.title = title
	dialog.dialog_text = description
	dialog.ok_button_text = accept_text
	dialog.cancel_button_text = "Keep playing" if _in_level else "Cancel"
	dialog.exclusive = true
	dialog.confirmed.connect(func() -> void:
		_dialog_open = false
		Input.emulate_mouse_from_touch = _screen != "gameplay"
		yes.call()
		dialog.queue_free()
	)
	dialog.canceled.connect(func() -> void:
		_dialog_open = false
		Input.emulate_mouse_from_touch = _screen != "gameplay"
		dialog.queue_free()
	)
	_root.add_child(dialog)
	dialog.popup_centered(Vector2i(480, 180))

func show_completion(result: Dictionary) -> void:
	_in_level = true
	_last_completion = result.duplicate(true)
	_reset("complete")
	var zen := bool(result.get("zen", result.get("difficulty", _settings().get("difficulty", "normal")) == "zen"))
	var name_text: String = str(result.get("name", _level.get("name", "Journey complete")))
	var content := _modal("A path of your own.", name_text)
	content.add_child(_label("%.1fs    /    %.1f ink    /    %d falls" % [float(result.get("elapsed", result.get("time", 0.0))), float(result.get("net_ink", result.get("ink", 0.0))), int(result.get("deaths", 0))], 22, ACCENT))
	if zen:
		content.add_child(_label("Zen practice · no mastery records awarded", 16, MUTED))
	else:
		for objective in ["explorer", "engineer", "master"]:
			var achieved := bool(result.get(objective, true if objective == "explorer" else false))
			var objective_name: String = str(objective).capitalize()
			var detail: String = {"explorer": "A journey completed", "engineer": "Within the ink budget", "master": "Without a single fall"}[objective]
			content.add_child(_label(("◆  " if achieved else "◇  ") + objective_name + "  ·  " + detail, 17, ACCENT if achieved else MUTED))
		if result.has("best_time"):
			content.add_child(_label("Best %.1fs · least ink %.1f" % [float(result.get("best_time", 0.0)), float(result.get("best_ink", 0.0))], 16, MUTED))
	_spacer(content, 6)
	var next_id := int(result.get("id", _level.get("id", 1))) + 1
	if next_id <= 50 and (next_id <= 10 or _premium()):
		content.add_child(_button("Next journey  →", func() -> void: _emit("next"), true))
	elif next_id == 11:
		content.add_child(_button("Explore more worlds", _show_purchase_info, true))
	else:
		content.add_child(_label("Every world explored. Your creativity made the way.", 17, ACCENT))
	var row := _hbox(content, 12)
	var retry := _button("Play again", func() -> void: _emit("retry"), false, true)
	retry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(retry)
	var menu := _button("Main menu", func() -> void: _emit("menu"), false, true)
	menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(menu)
	_transition()

func show_progress() -> void:
	_reset("progress")
	var page := _page("Little steps. Lovely discoveries.", "Your collection of clever solutions.", show_menu)
	var content := _scroll(page)
	var totals := {"explorer": 0, "engineer": 0, "master": 0}
	for record: Variant in _save().get("levels", {}).values():
		if record is Dictionary:
			for objective in totals:
				if bool(record.get(objective, record.get("completed", false) if objective == "explorer" else false)):
					totals[objective] += 1
	var row := _hbox(content, 18)
	for objective: String in totals:
		var card := _panel(row)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var card_content := _vbox(card, 8)
		card_content.add_child(_label("%d / 50" % int(totals[objective]), 38, ACCENT))
		card_content.add_child(_heading(objective.capitalize(), 24))
		card_content.add_child(_label({"explorer": "Find the finish", "engineer": "Stay within the ink budget", "master": "Complete a run without falling"}[objective], 16, MUTED))
	for id in range(1, 51):
		var record: Dictionary = _save().get("levels", {}).get(str(id), {})
		if not bool(record.get("completed", record.get("explorer", false))):
			continue
		var card := _panel(content)
		var layout := _hbox(card, 20)
		var name_label := _heading(_level_name(id), 19)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		layout.add_child(name_label)
		layout.add_child(_label("Best %.1fs   ·   %.1f ink" % [float(record.get("best_time", 0.0)), float(record.get("best_ink", 0.0))], 17, MUTED))
	if _completed_count() == 0:
		content.add_child(_label("Your first discovery is waiting in Green Valley.", 24, MUTED))
	_transition()

func show_settings() -> void:
	_reset("settings")
	_settings_cache = _settings().duplicate(true)
	var page := _page("Make yourself comfortable", "Changes are saved automatically on this device.", func() -> void:
		if _in_level:
			_emit("resume")
		else:
			show_menu()
	)
	var content := _scroll(page)
	var difficulty_card := _panel(content)
	var difficulty_layout := _hbox(difficulty_card, 18)
	var labels := _vbox(difficulty_layout, 2)
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	labels.add_child(_label("Your pace", 23))
	labels.add_child(_label("Easy: more ink · Expert: tighter resources · Zen: free practice", 15, MUTED))
	var difficulty := OptionButton.new()
	difficulty.custom_minimum_size = Vector2(220, 54)
	var choices := ["easy", "normal", "expert", "zen"]
	for choice: String in choices:
		difficulty.add_item(choice.capitalize())
	difficulty.select(maxi(0, choices.find(_settings_cache.get("difficulty", "normal"))))
	difficulty.add_theme_stylebox_override("normal", _style(Color("F0EDF7"), Color("D9CFEB")))
	difficulty.add_theme_font_size_override("font_size", 20)
	difficulty.add_theme_font_override("font", _button_font)
	difficulty.item_selected.connect(func(index: int) -> void: _setting("difficulty", choices[index]))
	difficulty_layout.add_child(difficulty)
	var note := _label("Difficulty applies when you start or retry a journey. Core physics stay consistent.", 15, MUTED)
	content.add_child(note)
	_add_slider(content, "Master volume", "master", 0.0, 1.0, .05, 1.0)
	_add_slider(content, "Music", "music", 0.0, 1.0, .05, .3)
	_add_slider(content, "Ambience", "ambience", 0.0, 1.0, .05, .35)
	_add_slider(content, "Sound effects", "sfx", 0.0, 1.0, .05, .8)
	_add_toggle(content, "Mute all sound", "mute", false)
	_add_slider(content, "Control opacity", "control_opacity", .25, 1.0, .05, .85)
	_add_slider(content, "Control size", "control_size", .85, 1.35, .05, 1.0)
	_add_slider(content, "Text / interface scale", "ui_scale", .85, 1.25, .05, 1.0)
	_add_toggle(content, "Reduced motion", "reduced_motion", false)
	_add_toggle(content, "Show short tutorial hints", "hints", true)
	_add_toggle(content, "Show ink numbers", "numeric_ink", true)
	_add_toggle(content, "Trajectory hint in Easy / Zen", "trajectory_hint", false)
	_add_toggle(content, "Character expression", "face", true)
	_add_toggle(content, "Touch vibration", "haptics", false)
	var backup := _panel(content)
	var backup_content := _vbox(backup, 10)
	backup_content.add_child(_label("Keep your discoveries", 23))
	var info := _label("Portable backups use your password. Remember it: lost passwords cannot be recovered. Local saves stay on this device.", 15, MUTED)
	if OS.has_feature("web"):
		info.text = "Browser progress belongs to this site address. Clearing site data or using private browsing can erase it. Download an encrypted backup to keep a portable copy."
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	backup_content.add_child(info)
	var backup_row := _hbox(backup_content, 12)
	for mode in ["export", "import"]:
		var selected_mode: String = mode
		backup_row.add_child(_button("Export progress" if mode == "export" else "Import progress", func() -> void: _backup_password(selected_mode), false, true))
	backup_row.add_child(_button("Restore previous save", func() -> void: _confirm("Restore previous save?", "Current progress will be replaced by the last valid saved copy.", func() -> void: _emit("restore_save")), false, true))
	_transition()

func _setting(key: String, value: Variant) -> void:
	_settings_cache[key] = value
	_emit("settings_changed", _settings_cache.duplicate(true))

func _add_slider(parent: Node, title: String, key: String, minimum: float, maximum: float, step: float, default_value: float) -> void:
	var panel := _panel(parent)
	var row := _hbox(panel, 18)
	var label := _label(title, 19)
	label.custom_minimum_size.x = 290
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = float(_settings_cache.get(key, default_value))
	slider.custom_minimum_size = Vector2(200, 42)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var track := _style(Color("E3E9E6"), Color.TRANSPARENT, 4)
	track.shadow_size = 0
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = MINT
	var highlight := track.duplicate() as StyleBoxFlat
	highlight.bg_color = CORAL
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", highlight)
	row.add_child(slider)
	var value_label := _label("%d%%" % roundi(slider.value * 100), 18, ACCENT)
	value_label.custom_minimum_size.x = 66
	row.add_child(value_label)
	slider.value_changed.connect(func(value: float) -> void:
		value_label.text = "%d%%" % roundi(value * 100)
		_setting(key, value)
	)

func _add_toggle(parent: Node, title: String, key: String, default_value: bool) -> void:
	var panel := _panel(parent)
	var row := _hbox(panel, 18)
	var label := _label(title, 19)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var toggle := _button("On" if bool(_settings_cache.get(key, default_value)) else "Off", func() -> void: pass, false, true)
	toggle.custom_minimum_size.x = 100
	toggle.toggle_mode = true
	toggle.button_pressed = bool(_settings_cache.get(key, default_value))
	toggle.toggled.connect(func(pressed: bool) -> void:
		toggle.text = "On" if pressed else "Off"
		_setting(key, pressed)
	)
	row.add_child(toggle)

func _backup_password(mode: String) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.theme = _root.theme
	dialog.title = "Export progress" if mode == "export" else "Import progress"
	dialog.ok_button_text = "Prepare download" if OS.has_feature("web") and mode == "export" else "Choose a file"
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	var prompt := _label("Use at least 10 characters." if mode == "export" else "Enter the password used for this backup.", 17)
	content.add_child(prompt)
	var password := LineEdit.new()
	password.secret = true
	password.placeholder_text = "Backup password"
	password.custom_minimum_size = Vector2(440, 52)
	content.add_child(password)
	dialog.add_child(content)
	dialog.register_text_enter(password)
	_root.add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		var secret := password.text
		if mode == "export" and secret.length() < 10:
			show_message("Please use a password with at least 10 characters.")
		else:
			_backup_picker(mode, secret)
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(490, 190))
	password.grab_focus()

func _backup_picker(mode: String, password: String) -> void:
	if OS.has_feature("web"):
		if _web_backups == null:
			show_message("Browser file access is unavailable in this build.")
		elif mode == "export":
			_web_backups.request_export(password)
		else:
			_web_backups.request_import(password)
		return
	var picker := FileDialog.new()
	picker.title = "Save encrypted progress" if mode == "export" else "Open encrypted progress"
	picker.access = FileDialog.ACCESS_FILESYSTEM
	picker.file_mode = FileDialog.FILE_MODE_SAVE_FILE if mode == "export" else FileDialog.FILE_MODE_OPEN_FILE
	picker.use_native_dialog = true
	picker.filters = PackedStringArray(["*.mqbackup;DoodleDrift encrypted backup;application/octet-stream"])
	if mode == "export":
		picker.current_file = "doodledrift.mqbackup"
	_root.add_child(picker)
	picker.file_selected.connect(func(path: String) -> void:
		var payload := {"path": path, "password": password}
		if mode == "import":
			_confirm("Replace progress with this backup?", "Your current progress will be backed up before importing. Only a valid backup with the correct password can be imported.", func() -> void: _emit("backup_import", payload))
		else:
			_emit("backup_export", payload)
		picker.queue_free()
	)
	picker.canceled.connect(picker.queue_free)
	picker.popup_centered_ratio(.8)

func show_gameplay(level: Dictionary) -> void:
	_in_level = true
	_level = level
	_draw_mode = bool(_stats.get("draw_mode", false))
	_build_hud()

func _build_hud() -> void:
	_reset("gameplay")
	var safe := _safe_insets()
	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 26 + safe.x
	top.offset_right = -26 - safe.z
	top.offset_top = 20 + safe.y
	top.offset_bottom = 104 + safe.y
	top.add_theme_constant_override("separation", 14)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(top)
	var info := _panel(top, Color(.999, .992, .972, .97))
	info.custom_minimum_size.x = 260
	_blocking.append(info)
	var info_content := _vbox(info, 2)
	info_content.add_child(_heading("%02d  /  %s" % [int(_level.get("id", 1)), str(_level.get("name", "First Roll"))], 17))
	_time_label = _label("Find your momentum.", 13, MUTED)
	info_content.add_child(_time_label)
	var ink_panel := _panel(top, Color(.999, .992, .972, .97))
	ink_panel.custom_minimum_size.x = 260
	_blocking.append(ink_panel)
	var ink_content := _vbox(ink_panel, 5)
	var ink_header := _hbox(ink_content, 12)
	_selected_label = _label("SOLID INK", 13, INK_TEXT.solid)
	_selected_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ink_header.add_child(_selected_label)
	_ink_value = _label("100 / 100", 13, MUTED)
	ink_header.add_child(_ink_value)
	_ink_meter = ProgressBar.new()
	_ink_meter.custom_minimum_size = Vector2(220, 10)
	_ink_meter.show_percentage = false
	_ink_meter.max_value = 100
	_ink_meter.value = _ink_display
	_ink_meter.add_theme_stylebox_override("background", _meter_style(Color("E2E9E2")))
	_ink_meter.add_theme_stylebox_override("fill", _meter_style(INK_COLORS.get(_stats.get("selected_ink", "solid"), MINT)))
	ink_content.add_child(_ink_meter)
	var stretch := Control.new()
	stretch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stretch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(stretch)
	var draw_button := _button("Done  ✓" if _draw_mode else "Draw a path", func() -> void: _emit("draw"), true)
	draw_button.custom_minimum_size = Vector2(172, 64)
	top.add_child(draw_button)
	_register_touch(draw_button, "draw", false)
	var pause := _button("Pause", func() -> void: _emit("pause"), false)
	pause.custom_minimum_size.x = 96
	top.add_child(pause)
	_register_touch(pause, "pause", false)
	if _draw_mode:
		_build_drawing_toolbar()
	else:
		_build_movement_controls()
	var status_y := 117.0 + safe.y
	if bool(_settings().get("hints", true)):
		var hint := _label(str(_level.get("hint", "Roll, draw, discover.")), 17, Color("214959"))
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		var hint_width := minf(940, get_viewport().get_visible_rect().size.x - 100 - safe.x - safe.z)
		hint.offset_left = -hint_width * .5
		hint.offset_right = hint_width * .5
		hint.offset_top = 117 + safe.y
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.add_theme_color_override("font_shadow_color", Color(1, .995, .98, .9))
		hint.add_theme_constant_override("shadow_offset_x", 1)
		hint.add_theme_constant_override("shadow_offset_y", 2)
		var text_size := hint.get_theme_font("font").get_multiline_string_size(hint.text, HORIZONTAL_ALIGNMENT_CENTER, hint_width, hint.get_theme_font_size("font_size"))
		hint.offset_bottom = hint.offset_top + text_size.y
		status_y = hint.offset_bottom + 10
		_root.add_child(hint)
		if not _draw_mode and int(_level.get("id", 1)) <= 8:
			_build_tutorial_glyph(status_y)
	if _draw_mode:
		_draw_label = _label("PHYSICS PAUSED  /  Draw inside the dotted build area", 15, ACCENT)
		_draw_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		_draw_label.offset_left = -360
		_draw_label.offset_right = 360
		_draw_label.offset_top = status_y
		_draw_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_root.add_child(_draw_label)

func _build_tutorial_glyph(top: float) -> void:
	var id := int(_level.get("id", 1))
	var guides := {1: ["bounce", "SPRING TO THE GARDEN"], 2: ["boost", "OVERCOME THE WIND"], 3: ["jump", "TIME THE ISLAND"], 4: ["right", "DELIVER THE PARCEL"], 5: ["fragile", "CROSS BEFORE IT BREAKS"], 6: ["ice", "BUILD A CARGO CHUTE"], 7: ["right", "MATCH BOTH PARCELS"], 8: ["jump", "RIDE THE ELEVATOR"]}
	var guide: Array = guides.get(id, ["right", "ROLL"])
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	row.offset_left = -150
	row.offset_right = 150
	row.offset_top = top
	row.offset_bottom = top + 34
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	_root.add_child(row)
	var icon := InkGlyph.new()
	icon.kind = str(guide[0])
	icon.tint = INK_TEXT.get(guide[0], ACCENT)
	icon.custom_minimum_size = Vector2(32, 32)
	row.add_child(icon)
	var caption := _label(str(guide[1]), 13, ACCENT)
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(caption)

func _build_movement_controls() -> void:
	var safe := _safe_insets()
	var control_scale := clampf(float(_settings().get("control_size", 1.0)), .85, 1.35)
	var control_size := 86.0 * control_scale
	var left := HBoxContainer.new()
	left.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	left.offset_left = 30 + safe.x
	left.offset_top = -control_size - 42 - safe.w
	left.offset_bottom = -24 - safe.w
	left.add_theme_constant_override("separation", 14)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(left)
	_control(left, "left", "move_left", "A / ←", control_size)
	_control(left, "right", "move_right", "D / →", control_size)
	var right := HBoxContainer.new()
	right.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	right.offset_left = -(control_size * 2 + 44) - safe.z
	right.offset_right = -30 - safe.z
	right.offset_top = -control_size - 42 - safe.w
	right.offset_bottom = -24 - safe.w
	right.add_theme_constant_override("separation", 14)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(right)
	_control(right, "brake", "brake", "Brake / S", control_size)
	_control(right, "jump", "jump", "Jump / Space", control_size)
	var help := _label("E / Tab  draw     P / Esc  pause     R  restart", 13, Color(.20, .25, .33, .90))
	help.add_theme_stylebox_override("normal", _caption_style())
	help.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	help.offset_left = -220
	help.offset_right = 220
	help.offset_top = -45 - safe.w
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(help)

func _control(parent: Node, glyph: String, event_name: String, caption: String, button_size: float) -> void:
	var stack := _vbox(parent, 5)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var button := _button("", func() -> void: pass)
	button.custom_minimum_size = Vector2(button_size, button_size)
	button.modulate.a = clampf(float(_settings().get("control_opacity", .85)), .25, 1)
	button.add_theme_stylebox_override("normal", _style(Color(.999, .992, .972, .96), Color(.45, .59, .55, .42), 26))
	button.button_down.connect(func() -> void: _hold(event_name, true))
	button.button_up.connect(func() -> void: _hold(event_name, false))
	stack.add_child(button)
	var icon := InkGlyph.new()
	icon.kind = glyph
	icon.tint = ACCENT
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 20
	icon.offset_top = 20
	icon.offset_right = -20
	icon.offset_bottom = -20
	button.add_child(icon)
	var label := _label(caption, 12, TEXT)
	label.add_theme_stylebox_override("normal", _caption_style())
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(label)
	_register_touch(button, event_name, true)

func _caption_style() -> StyleBoxFlat:
	var style := _meter_style(Color(.999, .992, .972, .92))
	style.set_corner_radius_all(8)
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	return style

func _build_drawing_toolbar() -> void:
	var safe := _safe_insets()
	var bottom := VBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 26 + safe.x
	bottom.offset_right = -26 - safe.z
	bottom.offset_top = -171 - safe.w
	bottom.offset_bottom = -22 - safe.w
	bottom.add_theme_constant_override("separation", 10)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bottom)
	var tools := _hbox(bottom, 12)
	tools.alignment = BoxContainer.ALIGNMENT_CENTER
	tools.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for ink: String in INKS:
		var selected: String = ink
		var button := _button("%s  %s" % [ink.capitalize(), INK_COSTS[ink]], func() -> void: _emit("ink", selected))
		button.disabled = not ink in _level.get("allowed_inks",INKS)
		button.custom_minimum_size = Vector2(162, 70)
		button.add_theme_color_override("font_color", INK_TEXT[ink])
		button.add_theme_stylebox_override("normal", _style(INK_COLORS[ink].lightened(.75), INK_TEXT[ink].lightened(.65), 20))
		button.tooltip_text = {"solid": "Stable bridges and ramps", "bounce": "Spring away from the surface", "boost": "Accelerate along the arrow", "ice": "Keep your momentum", "fragile": "A short-lived path"}[ink]
		tools.add_child(button)
		_register_touch(button, "ink", false, selected)
		_ink_buttons[ink] = button
		var glyph := InkGlyph.new()
		glyph.kind = ink
		glyph.tint = INK_TEXT[ink]
		glyph.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		glyph.position = Vector2(8, 4)
		glyph.size = Vector2(28, 20)
		button.add_child(glyph)
	var actions := _hbox(bottom, 12)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reverse_button = _button("Boost direction  →", func() -> void: _emit("reverse"), false, true)
	actions.add_child(_reverse_button)
	_register_touch(_reverse_button, "reverse", false)
	for item: Array in [["Undo", "undo"], ["Clear paths", "clear"], ["Cancel stroke", "cancel_stroke"]]:
		var event_name: String = item[1]
		var button := _button(item[0], func() -> void:
			if event_name == "clear":
				_confirm("Clear all drawn paths?", "All surviving drawings will be removed and their remaining refundable ink returned.", func() -> void: _emit("clear"))
			else:
				_emit(event_name)
		, false, true)
		actions.add_child(button)
		# Clear's confirmation is invoked through the same button signal for touch.
		_register_touch(button, "_button", false, button)

func update_hud(stats: Dictionary) -> void:
	_stats = stats
	var mode := bool(stats.get("draw_mode", false))
	if _screen == "gameplay" and mode != _draw_mode:
		_draw_mode = mode
		_build_hud()
	if _screen != "gameplay":
		return
	var ink: String = str(stats.get("selected_ink", "solid"))
	if is_instance_valid(_ink_meter):
		_ink_meter.max_value = maxf(1, float(stats.get("max_ink", 100)))
		_ink_target = float(stats.get("ink", 100))
		if ink != _last_hud_ink:
			_ink_meter.add_theme_stylebox_override("fill", _meter_style(INK_COLORS.get(ink, MINT)))
		_ink_meter.modulate = Color(1, .7, .7) if float(stats.get("ink", 100)) < 10 else Color.WHITE
	if is_instance_valid(_ink_value):
		_ink_value.visible = bool(_settings().get("numeric_ink", true))
		_ink_value.text = "%d / %d" % [ceili(float(stats.get("ink", 100))), int(stats.get("max_ink", 100))]
	if is_instance_valid(_selected_label):
		_selected_label.text = ink.to_upper() + " INK" + ("  ·  paused" if _draw_mode else "")
		_selected_label.add_theme_color_override("font_color", INK_TEXT.get(ink, TEXT))
	if is_instance_valid(_time_label):
		_time_label.text = "%s   ·   %d falls" % ["Zen practice" if stats.get("difficulty", _settings().get("difficulty", "normal")) == "zen" else "%.1fs" % float(stats.get("elapsed", 0)), int(stats.get("deaths", 0))]
	if is_instance_valid(_reverse_button):
		_reverse_button.text = "Boost direction  ←" if bool(stats.get("reverse", false)) else "Boost direction  →"
	if ink != _last_hud_ink:
		for key: String in _ink_buttons:
			var button: Button = _ink_buttons[key]
			button.add_theme_stylebox_override("normal", _style(INK_COLORS[key].lightened(.35) if key == ink else INK_COLORS[key].lightened(.78), INK_TEXT[key] if key == ink else INK_TEXT[key].lightened(.65), 20))
	_last_hud_ink = ink

func _register_touch(button: Button, event_name: String, held: bool, value: Variant = null) -> void:
	button.focus_mode = Control.FOCUS_NONE
	_touch_buttons.append({"button": button, "action": event_name, "held": held, "value": value})
	_blocking.append(button)

func get_blocking_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for control: Control in _blocking:
		if is_instance_valid(control) and control.is_visible_in_tree():
			rects.append(control.get_global_rect())
	return rects

func is_gameplay_visible() -> bool:
	return _screen == "gameplay"

func _input(event: InputEvent) -> void:
	if _screen != "gameplay" or _dialog_open:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			for item: Dictionary in _touch_buttons:
				var button: Button = item.button
				if is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled and button.get_global_rect().has_point(event.position):
					_touch_owners[event.index] = item
					button.modulate = Color(.91, .96, .93)
					if bool(item.held):
						_hold(item.action, true)
					else:
						if item.action == "_button":
							button.pressed.emit()
						else:
							_emit(item.action, item.value)
					if bool(_settings().get("haptics", false)):
						Input.vibrate_handheld(12)
					get_viewport().set_input_as_handled()
					return
			for rect in get_blocking_rects():
				if rect.has_point(event.position):
					_touch_owners[event.index] = {}
					get_viewport().set_input_as_handled()
					return
		elif _touch_owners.has(event.index):
			var item: Dictionary = _touch_owners[event.index]
			if not item.is_empty():
				if bool(item.get("held", false)):
					_hold(str(item.action), false)
				var button: Button = item.button
				if is_instance_valid(button):
					button.modulate = Color(1, 1, 1, float(_settings().get("control_opacity", .85)) if bool(item.held) else 1)
			_touch_owners.erase(event.index)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and _touch_owners.has(event.index):
		get_viewport().set_input_as_handled()

func _hold(event_name: String, pressed: bool) -> void:
	var previous := int(_held_counts.get(event_name, 0))
	var count := maxi(0, previous + (1 if pressed else -1))
	_held_counts[event_name] = count
	if (previous > 0) != (count > 0):
		_emit(event_name, count > 0)

func release_controls() -> void:
	# Emitting an action can synchronously rebuild this HUD. Empty ownership
	# before callbacks so a nested release cannot emit the same controls again.
	var held := _held_counts.duplicate()
	_held_counts.clear()
	_touch_owners.clear()
	for event_name: String in held:
		if int(held[event_name]) > 0:
			_emit(event_name, false)

func show_message(message: String) -> void:
	if is_instance_valid(_toast):
		_toast.queue_free()
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast = _label(message, 18, TEXT)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_toast.offset_left = -400
	_toast.offset_right = 400
	_toast.offset_top = -55
	_toast.offset_bottom = 55
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.add_theme_stylebox_override("normal", _style(Color(.999, .992, .972, .99), MINT, 18))
	_root.add_child(_toast)
	_toast_tween = create_tween()
	_toast_tween.tween_interval(5.0)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, .3)
	_toast_tween.tween_callback(_toast.queue_free)

func _stop_toast() -> void:
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = null

func _exit_tree() -> void:
	_stop_toast()

func _transition() -> void:
	if bool(_settings().get("reduced_motion", false)):
		return
	_root.modulate.a = .0
	var tween := create_tween()
	tween.tween_property(_root, "modulate:a", 1.0, .18)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		release_controls()
