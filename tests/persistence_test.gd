extends SceneTree
## Run: godot --headless --path . --script tests/persistence_test.gd
## Uses only dedicated files under res://tests/, preserving the player's save.
var failures: int = 0
var checks: int = 0
const PREFIX: String = "res://tests/.persistence_test"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var manager: Variant = load("res://scripts/persistence/save_manager.gd").new()
	manager.storage_path = PREFIX + ".json"
	manager.previous_path = PREFIX + ".previous.json"
	_cleanup()
	root.add_child(manager)
	await process_frame
	_expect(manager.data.version == 1, "default save schema")
	_expect(manager.is_unlocked(1) and not manager.is_unlocked(2), "initial progression")
	_expect(manager.save_game(), "atomic initial write")
	manager.complete_level(1, {"elapsed": 30.0, "net_ink": 45.0, "deaths": 2, "budget": 40.0})
	_expect(manager.is_unlocked(2), "completion unlocks following level")
	_expect(not manager.data.levels["1"].engineer and not manager.data.levels["1"].master, "objectives are independent")
	manager.complete_level(1, {"elapsed": 35.0, "net_ink": 20.0, "deaths": 0, "budget": 40.0})
	_expect(manager.data.levels["1"].engineer and manager.data.levels["1"].master, "mastery accumulates across runs")
	_expect(is_equal_approx(float(manager.data.levels["1"].best_time), 30.0), "best time preserved")
	manager.complete_level(2, {"elapsed": 1.0, "net_ink": 0.0, "deaths": 0, "difficulty": "zen"})
	_expect(not manager.data.levels.has("2"), "Zen awards no competitive records")
	manager.set_settings({"master": 0.42, "control_opacity": 4.0, "haptics": true})
	_expect(is_equal_approx(float(manager.data.settings.master), 0.42) and float(manager.data.settings.control_opacity) == 1.0, "settings validate and clamp")
	_expect(manager.data.settings.haptics, "optional haptics preference persists")
	manager.reload_save()
	_expect(manager.data.levels["1"].master, "save/load round trip")
	var invalid: Dictionary = manager.data.duplicate(true)
	invalid.version = 999
	_expect(manager.validate_save(invalid).is_empty(), "future save schema rejected")
	invalid.version = []
	_expect(manager.validate_save(invalid).is_empty(), "malformed version rejected safely")
	invalid = manager.data.duplicate(true)
	invalid.settings.master = "invalid"
	_expect(manager.validate_save(invalid).is_empty(), "malformed settings rejected")
	invalid = manager.data.duplicate(true)
	invalid.last_level = {}
	_expect(manager.validate_save(invalid).is_empty(), "malformed level index rejected safely")
	_write(manager.storage_path, "{not valid json")
	manager.reload_save()
	_expect(manager.data.levels.has("1") and not manager.recovery_message.is_empty(), "corrupt primary recovers previous valid save")
	_expect(manager.restore_previous().is_empty(), "restore previous save")
	var derived: PackedByteArray = manager._pbkdf2("password".to_utf8_buffer(), "salt".to_utf8_buffer(), 1)
	_expect(derived.hex_encode() == "120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b4dbf3a2f3dad3377264bb7b8e8330d4efc7451418617dabef683735361cdc18c", "PBKDF2-SHA256 independent known vector")
	_expect(not manager.export_backup(PREFIX + ".mqbackup", "short").is_empty(), "weak export password rejected")
	var started: int = Time.get_ticks_msec()
	_expect(manager.export_backup(PREFIX + ".mqbackup", "a-long-test-password").is_empty(), "authenticated encrypted backup export")
	var export_ms: int = Time.get_ticks_msec() - started
	var before: String = JSON.stringify(manager.data)
	_expect(not manager.import_backup(PREFIX + ".mqbackup", "a-long-test-password", false).is_empty(), "import requires explicit overwrite confirmation")
	_expect(not manager.import_backup(PREFIX + ".mqbackup", "wrong password", true).is_empty() and JSON.stringify(manager.data) == before, "wrong password preserves progress")
	_expect(manager.import_backup(PREFIX + ".mqbackup", "a-long-test-password", true).is_empty(), "encrypted backup round trip")
	var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PREFIX + ".mqbackup"))
	var ciphertext: PackedByteArray = Marshalls.base64_to_raw(envelope.ciphertext)
	ciphertext[0] = ciphertext[0] ^ 1
	envelope.ciphertext = Marshalls.raw_to_base64(ciphertext)
	_write(PREFIX + ".tampered.mqbackup", JSON.stringify(envelope))
	before = JSON.stringify(manager.data)
	_expect(not manager.import_backup(PREFIX + ".tampered.mqbackup", "a-long-test-password", true).is_empty() and JSON.stringify(manager.data) == before, "ciphertext tampering is authenticated before decryption")
	var old_save: Dictionary = manager.data.duplicate(true)
	old_save.settings.erase("ambience")
	old_save.settings.music = 0.23
	var old_records: Dictionary = old_save.levels.duplicate(true)
	_write(manager.storage_path, JSON.stringify(old_save))
	manager.reload_save()
	_expect(is_equal_approx(float(manager.data.settings.ambience), 0.35), "old schema-1 save gains default ambience without a version bump")
	_expect(manager.data.levels == old_records and is_equal_approx(float(manager.data.settings.music), 0.23), "old progress and music preference survive migration")
	_expect(manager.import_backup("res://tests/fixtures/legacy_progress_v1.encrypted.json", "fixture-only-passphrase", true).is_empty(), "independent pre-rebrand encrypted backup imports")
	_expect(is_equal_approx(float(manager.data.levels["1"].best_time), 18.25) and manager.data.levels["1"].master and manager.data.last_level == 2, "legacy backup retains records, mastery, and progression")
	_expect(is_equal_approx(float(manager.data.settings.ambience), 0.35) and is_equal_approx(float(manager.data.settings.music), 0.23) and is_equal_approx(float(manager.data.settings.master), 0.66), "legacy backup adds ambience while retaining previous audio settings")
	_expect(manager.data.tutorials.get("draw", false) and manager.data.cosmetic == "pearl", "legacy tutorials and cosmetic survive")
	manager.set_settings({"ambience": 0.61})
	manager.reload_save()
	_expect(is_equal_approx(float(manager.data.settings.ambience), 0.61), "independent ambience preference persists")
	_expect(manager.BACKUP_MAGIC == "MOMENTUM-QUEST-BACKUP-1" and manager.SAVE_PATH == "user://progress.json", "backup format and progress filename remain backward compatible")
	print("Persistence: %d checks, %d failures; export KDF+encryption %d ms on this host." % [checks, failures, export_ms])
	manager.free()
	_cleanup()
	quit(0 if failures == 0 else 1)

func _expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)

func _write(path: String, contents: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(contents)
		file.close()

func _cleanup() -> void:
	for suffix: String in [".json", ".json.tmp", ".previous.json", ".previous.json.tmp", ".mqbackup", ".mqbackup.tmp", ".tampered.mqbackup"]:
		var path: String = ProjectSettings.globalize_path(PREFIX + suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
