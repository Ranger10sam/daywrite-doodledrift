extends Node
## Original, offline DoodleDrift sound. Four persistent decks and eight effect
## voices are allocated once; rapid biome changes queue only the latest request.
const SAMPLE_RATE: int = 22050
const POOL_SIZE: int = 8
const CROSSFADE_SECONDS: float = 0.9
const BIOMES: Array[String] = ["valley", "peaks", "desert", "caverns", "volcano"]
const EFFECT_ALIASES: Dictionary = {
	"button": "click", "ink_drawing": "draw", "drawing": "draw",
	"ink_selection": "select", "landing": "land", "fragile": "break",
	"fragile_break": "break", "failure": "fail", "completion": "complete",
	"achievement_unlock": "achievement", "regeneration": "regen", "roll": "rolling"
}
const EFFECT_INTERVALS: Dictionary = {
	"draw": 95, "rolling": 180, "regen": 1450, "land": 90,
	"bounce": 110, "boost": 150, "break": 100, "checkpoint": 220,
	"complete": 400, "achievement": 350, "jump": 80, "click": 45, "select": 60
}

var effects: Dictionary = {}
var ambience: Dictionary = {}
var music: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
# Public alias retained for existing callers. Suspend both layers using the API.
var music_player: AudioStreamPlayer
var music_decks: Array[AudioStreamPlayer] = []
var ambience_decks: Array[AudioStreamPlayer] = []
var next_voice: int = 0
var playback_enabled: bool = DisplayServer.get_name() != "headless"
var _sfx_last_played: Dictionary = {}
var _suspended: bool = false
var _active_deck: int = 0
var _incoming_deck: int = 1
var _current_biome: int = -1
var _target_biome: int = -1
var _pending_biome: int = -1
var _transitioning: bool = false
var _fade_elapsed: float = 0.0
var _shutdown_prepared: bool = false
var _shutdown_started: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus_name: String in ["Music", "Ambience", "SFX"]:
		_ensure_bus(bus_name)
	for index: int in range(2):
		music_decks.append(_new_player("Music", "MusicDeck%d" % index))
		ambience_decks.append(_new_player("Ambience", "AmbienceDeck%d" % index))
	music_player = music_decks[0]
	for index: int in range(POOL_SIZE):
		voices.append(_new_player("SFX", "EffectVoice%d" % index))
	_build_effects()
	SaveManager.changed.connect(apply_settings)
	apply_settings()
	set_biome(0)

func _new_player(bus_name: String, player_name: String) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.name = player_name
	player.bus = bus_name
	add_child(player)
	return player

func _process(delta: float) -> void:
	# A resume frame cannot jump an entire transition after a long suspension.
	_advance_crossfade(minf(maxf(delta, 0.0), 0.1))

func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var index: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, "Master")

func apply_settings(settings: Dictionary = {}) -> void:
	if settings.is_empty():
		settings = SaveManager.data.get("settings", {})
	AudioServer.set_bus_mute(0, bool(settings.get("mute", false)))
	AudioServer.set_bus_volume_db(0, _volume_db(float(settings.get("master", 0.8))))
	for layer: String in ["Music", "Ambience", "SFX"]:
		var key: String = layer.to_lower()
		var fallback: float = {"music": 0.3, "ambience": 0.35, "sfx": 0.8}[key]
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(layer), _volume_db(float(settings.get(key, fallback))))

func _volume_db(volume: float) -> float:
	return -80.0 if volume <= 0.0001 else linear_to_db(clampf(volume, 0.0, 1.0))

func set_biome(index: int) -> void:
	if _shutdown_started:
		return
	var selected: int = clampi(index, 0, BIOMES.size() - 1)
	if _transitioning:
		# Finish the existing fade without stealing an audible deck. A hundred
		# requests allocate no new players and retain only the last choice.
		_pending_biome = -1 if selected == _target_biome else selected
		return
	if selected == _current_biome:
		return
	_begin_crossfade(selected)

func _begin_crossfade(selected: int) -> void:
	if not music.has(selected):
		music[selected] = _load_loop(selected, "music")
		ambience[selected] = _load_loop(selected, "ambience")
	if music[selected] == null or ambience[selected] == null:
		push_warning("A DoodleDrift soundscape could not be loaded: " + BIOMES[selected])
		return
	_target_biome = selected
	_incoming_deck = 1 - _active_deck
	_fade_elapsed = 0.0
	_transitioning = true
	music_decks[_incoming_deck].stream = music[selected]
	ambience_decks[_incoming_deck].stream = ambience[selected]
	_set_deck_gain(_incoming_deck, 0.0)
	music_player = music_decks[_incoming_deck]
	for player: AudioStreamPlayer in [music_decks[_incoming_deck], ambience_decks[_incoming_deck]]:
		if playback_enabled:
			player.play()
		player.stream_paused = _suspended

func _load_loop(index: int, layer: String) -> AudioStreamWAV:
	var path: String = "res://audio/generated/%s_%s.wav" % [BIOMES[index], layer]
	var stream: AudioStreamWAV = load(path) as AudioStreamWAV
	if stream != null:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
	return stream

func _advance_crossfade(delta: float) -> void:
	if not _transitioning or _suspended:
		return
	_fade_elapsed = minf(CROSSFADE_SECONDS, _fade_elapsed + maxf(delta, 0.0))
	var ratio: float = _fade_elapsed / CROSSFADE_SECONDS
	var eased: float = ratio * ratio * (3.0 - 2.0 * ratio)
	# Equal-power gains preserve energy through the middle of a transition.
	_set_deck_gain(_active_deck, cos(eased * PI * 0.5))
	_set_deck_gain(_incoming_deck, sin(eased * PI * 0.5))
	if ratio < 1.0:
		return
	for player: AudioStreamPlayer in [music_decks[_active_deck], ambience_decks[_active_deck]]:
		player.stop()
		player.stream = null
	_active_deck = _incoming_deck
	_current_biome = _target_biome
	_transitioning = false
	_set_deck_gain(_active_deck, 1.0)
	if _pending_biome >= 0:
		var requested: int = _pending_biome
		_pending_biome = -1
		if requested != _current_biome:
			_begin_crossfade(requested)

func _set_deck_gain(index: int, gain: float) -> void:
	music_decks[index].volume_db = _volume_db(gain)
	ambience_decks[index].volume_db = _volume_db(gain)

func suspend_audio() -> void:
	if _suspended:
		return
	_suspended = true
	for player: AudioStreamPlayer in music_decks + ambience_decks:
		player.stream_paused = true
	for voice: AudioStreamPlayer in voices:
		voice.stop()
		voice.stream = null

func resume_audio() -> void:
	if not _suspended or _shutdown_started:
		return
	_suspended = false
	for player: AudioStreamPlayer in music_decks + ambience_decks:
		player.stream_paused = false

func suspend() -> void:
	suspend_audio()

func resume() -> void:
	resume_audio()

func prepare_shutdown() -> void:
	if _shutdown_prepared:
		return
	if _shutdown_started:
		while not _shutdown_prepared and is_inside_tree():
			await get_tree().process_frame
		return
	_shutdown_started = true
	_suspended = true
	_transitioning = false
	_pending_biome = -1
	_release_streams()
	# Stop requests retire on the audio callback, including in a browser. Await
	# frames against a bounded wall-clock deadline without freezing the game/UI.
	var retire_deadline: int = Time.get_ticks_msec() + 150
	while Time.get_ticks_msec() < retire_deadline and is_inside_tree():
		await get_tree().process_frame
	_shutdown_prepared = true

func play_sfx(effect: String, intensity: float = 1.0) -> bool:
	var key: String = str(EFFECT_ALIASES.get(effect, effect))
	if _suspended or intensity <= 0.0 or not effects.has(key) or voices.is_empty():
		return false
	var now: int = Time.get_ticks_msec()
	if now - int(_sfx_last_played.get(key, -100000)) < int(EFFECT_INTERVALS.get(key, 40)):
		return false
	var chosen: int = -1
	for offset: int in range(POOL_SIZE):
		var candidate: int = (next_voice + offset) % POOL_SIZE
		if not voices[candidate].playing:
			chosen = candidate
			break
	if chosen < 0:
		# Continuous quiet textures never steal a jump, bounce, or other cue.
		if key in ["rolling", "draw", "regen"]:
			return false
		chosen = next_voice
	_sfx_last_played[key] = now
	next_voice = (chosen + 1) % POOL_SIZE
	var voice: AudioStreamPlayer = voices[chosen]
	voice.stream = effects[key]
	var strength: float = clampf(intensity, 0.0, 1.0)
	if key == "rolling":
		voice.volume_db = _volume_db(0.2 + strength * 0.65)
		voice.pitch_scale = 0.8 + strength * 0.4
	elif key == "regen":
		voice.volume_db = _volume_db(0.2 + strength * 0.3)
		voice.pitch_scale = 1.0
	else:
		voice.volume_db = _volume_db(strength)
		voice.pitch_scale = 1.0
	if playback_enabled:
		voice.play()
	return true

func audio_snapshot() -> Dictionary:
	var assigned: int = 0
	for player: AudioStreamPlayer in music_decks + ambience_decks:
		if player.stream != null:
			assigned += 1
	return {"current_biome": _current_biome, "target_biome": _target_biome,
		"pending_biome": _pending_biome, "transitioning": _transitioning,
		"fade_elapsed": _fade_elapsed, "suspended": _suspended,
		"deck_count": music_decks.size() + ambience_decks.size(),
		"assigned_decks": assigned, "effect_voices": voices.size(),
		"music_cache": music.size(), "ambience_cache": ambience.size()}

func _build_effects() -> void:
	var definitions: Dictionary = {
		"click": [520.0, 690.0, 0.065, 0.14], "draw": [950.0, 780.0, 0.085, 0.045],
		"select": [440.0, 880.0, 0.13, 0.13], "jump": [260.0, 640.0, 0.18, 0.18],
		"land": [180.0, 100.0, 0.12, 0.17], "bounce": [210.0, 820.0, 0.24, 0.19],
		"boost": [300.0, 1250.0, 0.29, 0.14], "break": [360.0, 70.0, 0.25, 0.13],
		"checkpoint": [440.0, 880.0, 0.42, 0.16], "fail": [340.0, 90.0, 0.34, 0.15],
		"complete": [523.25, 1046.5, 0.75, 0.18], "achievement": [659.25, 1318.5, 0.55, 0.15],
		"rolling": [105.0, 135.0, 0.13, 0.055], "regen": [659.25, 783.99, 0.25, 0.085]
	}
	for key: String in definitions:
		var values: Array = definitions[key]
		effects[key] = _synthesize(float(values[0]), float(values[1]), float(values[2]), float(values[3]), key)

func _synthesize(start_hz: float, end_hz: float, duration: float, gain: float, kind: String) -> AudioStreamWAV:
	var count: int = int(duration * SAMPLE_RATE)
	var samples: PackedByteArray = PackedByteArray()
	samples.resize(count * 2)
	var phase: float = 0.0
	var noise: float = 0.0
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = 7331
	for index: int in range(count):
		var fraction: float = float(index) / float(count - 1)
		var frequency: float = lerpf(start_hz, end_hz, fraction)
		if kind in ["checkpoint", "complete", "achievement"]:
			frequency = start_hz * [1.0, 1.25, 1.5, 2.0][mini(3, int(fraction * 4.0))]
		phase += TAU * frequency / float(SAMPLE_RATE)
		var envelope: float = minf(1.0, fraction * 45.0) * pow(1.0 - fraction, 1.8)
		var value: float = sin(phase) * 0.85 + sin(phase * 2.0) * 0.15
		if kind == "break":
			value = value * 0.4 + random.randf_range(-0.6, 0.6)
		elif kind in ["draw", "rolling"]:
			noise = lerpf(noise, random.randf_range(-1.0, 1.0), 0.35 if kind == "draw" else 0.09)
			value = noise * 0.8 + value * 0.2
		elif kind == "regen":
			value = sin(phase) * 0.9 + sin(phase * 1.5) * 0.1
		samples.encode_s16(index * 2, clampi(int(value * envelope * gain * 32767.0), -32768, 32767))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = samples
	return stream

func _exit_tree() -> void:
	if is_instance_valid(SaveManager) and SaveManager.changed.is_connected(apply_settings):
		SaveManager.changed.disconnect(apply_settings)
	_release_streams()
	# Native AudioServer stop requests retire on the mix callback. A direct tree
	# quit supplies no subsequent frames; allow that callback to finish only at
	# shutdown, never during gameplay. Web uses the asynchronous prepare API.
	if playback_enabled and not _shutdown_prepared and not OS.has_feature("web"):
		OS.delay_msec(120)

func _release_streams() -> void:
	for player: AudioStreamPlayer in music_decks + ambience_decks + voices:
		player.stop()
		player.stream = null
	effects.clear()
	music.clear()
	ambience.clear()
