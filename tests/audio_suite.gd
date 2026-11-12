extends SceneTree
## Headless state/PCM verification; this does not claim listening or device QA.
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var manager: Variant = load("res://scripts/managers/audio_manager.gd").new()
	# Headless Godot uses its dummy audio driver. Start real AudioStreamPlayer
	# playback state so pause assertions cover active decks, without claiming sound.
	manager.playback_enabled = true
	root.add_child(manager)
	manager.set_process(false)
	await process_frame
	check(manager.get_child_count() == 12, "exactly four soundscape decks and eight effect voices")
	check(manager.effects.size() == 14, "all required effects plus rolling and regeneration")
	for bus_name: String in ["Music", "Ambience", "SFX"]:
		var index: int = AudioServer.get_bus_index(bus_name)
		check(index >= 0 and AudioServer.get_bus_send(index) == "Master", bus_name + " is independently routed to Master")
	manager._advance_crossfade(1.0)
	check(manager.audio_snapshot().current_biome == 0 and manager.audio_snapshot().assigned_decks == 2, "initial biome settles with one music and one ambience layer")
	manager.set_biome(1)
	manager._advance_crossfade(0.45)
	check(manager.audio_snapshot().assigned_decks == 4, "a transition uses at most two decks per layer")
	var outgoing: float = db_to_linear(manager.music_decks[manager._active_deck].volume_db)
	var incoming: float = db_to_linear(manager.music_decks[manager._incoming_deck].volume_db)
	check(absf(outgoing * outgoing + incoming * incoming - 1.0) < 0.0001, "equal-power transition has no energy hole")
	check(absf(outgoing - incoming) < 0.0001, "transition midpoint is balanced")
	var fade_before: float = manager.audio_snapshot().fade_elapsed
	manager.suspend_audio()
	manager._advance_crossfade(4.0)
	check(manager.audio_snapshot().suspended and is_equal_approx(manager.audio_snapshot().fade_elapsed, fade_before), "backgrounding freezes transition progress")
	for player: AudioStreamPlayer in manager.music_decks + manager.ambience_decks:
		check(player.stream_paused, "backgrounding pauses every soundscape deck")
	check(not manager.play_sfx("jump"), "backgrounding suppresses transient effects")
	manager.set_biome(2)
	manager.resume_audio()
	manager._advance_crossfade(0.46)
	check(manager.audio_snapshot().target_biome == 2, "latest queued biome starts after a smooth current fade")
	manager._advance_crossfade(1.0)
	check(manager.audio_snapshot().current_biome == 2 and manager.audio_snapshot().assigned_decks == 2, "outgoing layers are stopped and cleared")
	for index: int in range(100):
		manager.set_biome(index % 5)
	manager._advance_crossfade(1.0)
	manager._advance_crossfade(1.0)
	check(manager.audio_snapshot().current_biome == 4, "rapid changes retain the latest requested biome")
	check(manager.get_child_count() == 12 and manager.audio_snapshot().assigned_decks == 2, "repeated changes allocate no additional players or lingering tracks")
	for index: int in range(5):
		manager.set_biome(index)
		manager._advance_crossfade(1.0)
		for layer: Dictionary in [manager.music, manager.ambience]:
			var stream: AudioStreamWAV = layer[index]
			check(stream != null and stream.stereo and stream.mix_rate == 22050, "biome %d uses locally bundled stereo PCM" % index)
			check(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and stream.loop_begin == 0 and stream.loop_end == roundi(stream.get_length() * stream.mix_rate), "biome %d loop spans its complete seamless buffer" % index)
	check(manager.music.size() == 5 and manager.ambience.size() == 5, "cache is bounded to five music and five ambience streams")
	manager.apply_settings({"master": 0.8, "music": 0.0, "ambience": 0.65, "sfx": 0.25, "mute": false})
	check(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")) <= -79.0, "music can be silenced independently")
	check(absf(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Ambience"))) - 0.65) < 0.001, "ambience retains independent gain")
	check(absf(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX"))) - 0.25) < 0.001, "effects retain independent gain")
	manager.apply_settings({"mute": true})
	check(AudioServer.is_bus_mute(0), "master mute covers every sound layer")
	manager.apply_settings()
	for key: String in ["draw", "rolling", "regen"]:
		check(manager.play_sfx(key, 0.5), key + " cue accepts a first request")
		check(not manager.play_sfx(key, 0.5), key + " cue throttles repeated frame-rate calls")
	check(not manager.play_sfx("not-an-effect") and not manager.play_sfx("jump", 0.0), "unknown and silent cues do not consume voices")
	for index: int in range(1000):
		manager.play_sfx("rolling", 0.8)
	check(manager.voices.size() == 8 and manager.get_child_count() == 12, "effect calls cannot grow the voice pool")
	paused = true
	await manager.prepare_shutdown()
	check(manager.audio_snapshot().assigned_decks == 0 and manager.music.is_empty() and manager.ambience.is_empty(), "cooperative shutdown releases both soundscape layers while the tree is paused")
	check(not manager.play_sfx("jump"), "cooperative shutdown cannot start new effects")
	manager.set_biome(2)
	manager.resume_audio()
	check(manager.audio_snapshot().assigned_decks == 0 and manager.audio_snapshot().suspended, "late focus/biome callbacks cannot restart shutdown audio")
	paused = false
	manager.free()
	print("Audio: %d checks, %d failures; state, routing, cached loops, bounded fades, suspend/resume and cue throttles. No audibility claim." % [checks, failures])
	quit(0 if failures == 0 else 1)

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
