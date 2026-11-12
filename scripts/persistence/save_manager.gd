extends Node
## Local progress is ordinary JSON; portable backups use password-derived encryption
## and authentication. No entitlement is ever loaded from a progress save.
signal changed
signal save_error(message: String)

const SCHEMA_VERSION: int = 1
const SAVE_PATH: String = "user://progress.json"
const PREVIOUS_PATH: String = "user://progress.previous.json"
const MAX_SAVE_BYTES: int = 1048576
const MAX_BACKUP_BYTES: int = 2097152
const BACKUP_ITERATIONS: int = 100000
const BACKUP_MAGIC: String = "MOMENTUM-QUEST-BACKUP-1"

var data: Dictionary = {}
var recovery_message: String = ""
var storage_path: String = SAVE_PATH
var previous_path: String = PREVIOUS_PATH

func _ready() -> void:
	reload_save()

func defaults() -> Dictionary:
	return {
		"version": SCHEMA_VERSION,
		"settings": {
			"difficulty": "normal", "master": 0.8, "music": 0.3, "ambience": 0.35, "sfx": 0.8,
			"mute": false, "reduced_motion": false, "hints": true, "face": true, "haptics": false,
			"control_opacity": 0.8, "control_size": 1.0, "ui_scale": 1.0,
			"numeric_ink": true, "trajectory_hint": false
		},
		"levels": {}, "last_level": 1, "tutorials": {}, "cosmetic": "pearl"
	}

func reload_save() -> void:
	recovery_message = ""
	var primary: Dictionary = _read_valid_save(storage_path)
	if not primary.is_empty():
		data = primary
	elif FileAccess.file_exists(storage_path):
		var previous: Dictionary = _read_valid_save(previous_path)
		if not previous.is_empty():
			data = previous
			recovery_message = "Recovered the previous valid save."
		else:
			data = defaults()
			recovery_message = "Progress could not be read. Started safely with default progress; the original file remains on disk."
	else:
		data = defaults()
	changed.emit()

func save_game() -> bool:
	var checked: Dictionary = validate_save(data)
	if checked.is_empty():
		save_error.emit("Progress was not saved because validation failed.")
		return false
	var old: Dictionary = _read_valid_save(storage_path)
	if not old.is_empty():
		if not _atomic_write(previous_path, JSON.stringify(old)):
			save_error.emit("Could not preserve the previous save.")
			return false
	if not _atomic_write(storage_path, JSON.stringify(checked)):
		save_error.emit("Could not write progress. Check available storage.")
		return false
	data = checked
	changed.emit()
	return true

func set_settings(settings: Dictionary) -> void:
	var updated: Dictionary = data.get("settings", defaults().settings).duplicate(true)
	for key: Variant in settings:
		if updated.has(key):
			updated[key] = settings[key]
	var candidate: Dictionary = data.duplicate(true)
	candidate.settings = updated
	var checked: Dictionary = validate_save(candidate)
	if not checked.is_empty():
		data = checked
		save_game()

func is_unlocked(level_id: int) -> bool:
	if level_id < 1 or level_id > 50:
		return false
	if level_id == 1:
		return true
	return bool(data.get("levels", {}).get(str(level_id - 1), {}).get("explorer", false))

func complete_level(level_id: int, result: Dictionary) -> void:
	if level_id < 1 or level_id > 50:
		return
	data.last_level = level_id
	if bool(result.get("zen", false)) or str(result.get("difficulty", data.settings.difficulty)) == "zen":
		save_game()
		return
	var elapsed: float = maxf(0.0, float(result.get("elapsed", result.get("time", 0.0))))
	var ink_used: float = maxf(0.0, float(result.get("net_ink", result.get("ink", 0.0))))
	var deaths: int = maxi(0, int(result.get("deaths", 0)))
	var budget: float = maxf(0.0, float(result.get("budget", 60.0)))
	var record: Dictionary = data.levels.get(str(level_id), {})
	data.levels[str(level_id)] = {
		"explorer": true,
		"engineer": bool(record.get("engineer", false)) or ink_used <= budget,
		"master": bool(record.get("master", false)) or deaths == 0,
		"best_time": minf(float(record.get("best_time", INF)), elapsed),
		"best_ink": minf(float(record.get("best_ink", INF)), ink_used),
		"best_deaths": mini(int(record.get("best_deaths", 2147483647)), deaths)
	}
	if level_id < 50:
		data.last_level = level_id + 1
	save_game()

func mark_tutorial(tutorial_id: String) -> void:
	if tutorial_id.length() > 80:
		return
	data.tutorials[tutorial_id] = true
	save_game()

func restore_previous() -> String:
	var previous: Dictionary = _read_valid_save(previous_path)
	if previous.is_empty():
		return "No valid previous save is available."
	# Read both before saving: the old primary becomes the next previous save.
	var prior_data: Dictionary = data.duplicate(true)
	data = previous
	if not save_game():
		data = prior_data
		return "Could not restore the previous save."
	return ""

func validate_save(candidate: Variant) -> Dictionary:
	if not candidate is Dictionary:
		return {}
	var source: Dictionary = candidate
	var version: Variant = source.get("version", -1)
	if not _is_number(version) or float(version) != float(SCHEMA_VERSION):
		return {}
	if not source.get("settings") is Dictionary or not source.get("levels") is Dictionary or not source.get("tutorials") is Dictionary:
		return {}
	var clean: Dictionary = defaults()
	var settings: Dictionary = source.settings
	var difficulty: String = str(settings.get("difficulty", "normal"))
	if difficulty not in ["easy", "normal", "expert", "zen"]:
		return {}
	clean.settings.difficulty = difficulty
	for key: String in ["master", "music", "ambience", "sfx", "control_opacity", "control_size", "ui_scale"]:
		var value: Variant = settings.get(key, clean.settings[key])
		if not (value is float or value is int) or not is_finite(float(value)):
			return {}
		var minimum: float = 0.0
		var maximum: float = 1.0
		if key == "control_opacity":
			minimum = 0.25
		elif key == "control_size":
			minimum = 0.75
			maximum = 1.4
		elif key == "ui_scale":
			minimum = 0.8
			maximum = 1.3
		clean.settings[key] = clampf(float(value), minimum, maximum)
	for key: String in ["mute", "reduced_motion", "hints", "face", "haptics", "numeric_ink", "trajectory_hint"]:
		var value: Variant = settings.get(key, clean.settings[key])
		if not value is bool:
			return {}
		clean.settings[key] = value
	if source.levels.size() > 50 or source.tutorials.size() > 200:
		return {}
	for key: Variant in source.levels:
		if not str(key).is_valid_int() or int(key) < 1 or int(key) > 50:
			return {}
		var record: Variant = source.levels[key]
		if not record is Dictionary:
			return {}
		var record_clean: Dictionary = {}
		for objective: String in ["explorer", "engineer", "master"]:
			if not record.get(objective, false) is bool:
				return {}
			record_clean[objective] = record.get(objective, false)
		for stat: String in ["best_time", "best_ink", "best_deaths"]:
			var value: Variant = record.get(stat, 0.0)
			if not (value is int or value is float) or not is_finite(float(value)) or float(value) < 0.0 or float(value) > 100000000.0:
				return {}
			record_clean[stat] = value
		clean.levels[str(int(key))] = record_clean
	for key: Variant in source.tutorials:
		if str(key).length() > 80 or not source.tutorials[key] is bool:
			return {}
		clean.tutorials[str(key)] = source.tutorials[key]
	var last_level: Variant = source.get("last_level", 1)
	if not _is_number(last_level):
		return {}
	clean.last_level = clampi(int(last_level), 1, 50)
	clean.cosmetic = str(source.get("cosmetic", "pearl")).left(32)
	return clean

func _is_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func _read_valid_save(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_SAVE_BYTES:
		return {}
	var parser: JSON = JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {}
	return validate_save(parser.data)

func _atomic_write(path: String, text: String) -> bool:
	var temporary: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.flush()
	var status: Error = file.get_error()
	file.close()
	if status != OK:
		return false
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path)) == OK

func export_backup(path: String, password: String) -> String:
	if password.length() < 10:
		return "Choose a password with at least 10 characters. It cannot be recovered if forgotten."
	var clean: Dictionary = validate_save(data)
	if clean.is_empty():
		return "Progress validation failed."
	var crypto: Crypto = Crypto.new()
	var salt: PackedByteArray = crypto.generate_random_bytes(16)
	var iv: PackedByteArray = crypto.generate_random_bytes(16)
	var keys: PackedByteArray = _pbkdf2(password.to_utf8_buffer(), salt, BACKUP_ITERATIONS)
	var plaintext: PackedByteArray = JSON.stringify(clean).to_utf8_buffer()
	var padding: int = 16 - plaintext.size() % 16
	for index: int in range(padding):
		plaintext.append(padding)
	var aes: AESContext = AESContext.new()
	if aes.start(AESContext.MODE_CBC_ENCRYPT, keys.slice(0, 32), iv) != OK:
		return "Encryption could not be initialized."
	var ciphertext: PackedByteArray = aes.update(plaintext)
	aes.finish()
	if ciphertext.is_empty():
		return "Encryption failed."
	var mac: PackedByteArray = crypto.hmac_digest(HashingContext.HASH_SHA256, keys.slice(32, 64), _authenticated_bytes(salt, iv, ciphertext))
	var envelope: Dictionary = {
		"format": BACKUP_MAGIC, "version": 1, "iterations": BACKUP_ITERATIONS,
		"kdf": "PBKDF2-HMAC-SHA256", "cipher": "AES-256-CBC-HMAC-SHA256",
		"salt": Marshalls.raw_to_base64(salt), "iv": Marshalls.raw_to_base64(iv),
		"ciphertext": Marshalls.raw_to_base64(ciphertext), "mac": Marshalls.raw_to_base64(mac)
	}
	if not _write_portable_backup(path, JSON.stringify(envelope)):
		return "Could not write the backup file."
	return ""

func _write_portable_backup(path: String, contents: String) -> bool:
	if not path.begins_with("content://"):
		return _atomic_write(path, contents)
	# Android SAF grants access to this document URI, not a sibling temporary
	# document. Local progress remains atomic; portable document writes may be
	# interrupted, in which case authenticated import rejects the partial file.
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(contents)
	file.flush()
	var status: Error = file.get_error()
	file.close()
	return status == OK

func import_backup(path: String, password: String, confirmed: bool = false) -> String:
	if not confirmed:
		return "Confirm before replacing existing progress."
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return "The backup file could not be opened."
	if file.get_length() > MAX_BACKUP_BYTES:
		return "The backup file is too large."
	var parser: JSON = JSON.new()
	var parse_error: Error = parser.parse(file.get_as_text())
	file.close()
	if parse_error != OK:
		return "This is not a valid DoodleDrift backup. Legacy Momentum Quest backups are supported."
	var parsed: Variant = parser.data
	if not parsed is Dictionary:
		return "This is not a DoodleDrift backup. Legacy Momentum Quest backups are supported."
	var envelope: Dictionary = parsed
	if str(envelope.get("format", "")) != BACKUP_MAGIC or not _is_number(envelope.get("version")) or float(envelope.version) != 1.0:
		return "Unsupported backup format or version."
	if str(envelope.get("kdf", "")) != "PBKDF2-HMAC-SHA256" or str(envelope.get("cipher", "")) != "AES-256-CBC-HMAC-SHA256" or not _is_number(envelope.get("iterations")) or float(envelope.iterations) != float(BACKUP_ITERATIONS):
		return "Unsupported backup cryptography settings."
	for key: String in ["salt", "iv", "ciphertext", "mac"]:
		if not envelope.get(key) is String:
			return "The backup is malformed."
	var salt: PackedByteArray = Marshalls.base64_to_raw(envelope.salt)
	var iv: PackedByteArray = Marshalls.base64_to_raw(envelope.iv)
	var ciphertext: PackedByteArray = Marshalls.base64_to_raw(envelope.ciphertext)
	var stored_mac: PackedByteArray = Marshalls.base64_to_raw(envelope.mac)
	if salt.size() != 16 or iv.size() != 16 or stored_mac.size() != 32 or ciphertext.is_empty() or ciphertext.size() % 16 != 0 or ciphertext.size() > MAX_SAVE_BYTES + 16:
		return "The backup is malformed."
	var keys: PackedByteArray = _pbkdf2(password.to_utf8_buffer(), salt, BACKUP_ITERATIONS)
	var crypto: Crypto = Crypto.new()
	var expected_mac: PackedByteArray = crypto.hmac_digest(HashingContext.HASH_SHA256, keys.slice(32, 64), _authenticated_bytes(salt, iv, ciphertext))
	if not crypto.constant_time_compare(expected_mac, stored_mac):
		return "Wrong password or damaged backup. Existing progress was preserved."
	var aes: AESContext = AESContext.new()
	if aes.start(AESContext.MODE_CBC_DECRYPT, keys.slice(0, 32), iv) != OK:
		return "Decryption could not be initialized."
	var plaintext: PackedByteArray = aes.update(ciphertext)
	aes.finish()
	if plaintext.is_empty():
		return "The backup is damaged."
	var padding: int = plaintext[plaintext.size() - 1]
	if padding < 1 or padding > 16 or padding > plaintext.size():
		return "The backup is damaged."
	for index: int in range(plaintext.size() - padding, plaintext.size()):
		if plaintext[index] != padding:
			return "The backup is damaged."
	plaintext.resize(plaintext.size() - padding)
	var plaintext_parser: JSON = JSON.new()
	if plaintext_parser.parse(plaintext.get_string_from_utf8()) != OK:
		return "The backup contains invalid progress data."
	var clean: Dictionary = validate_save(plaintext_parser.data)
	if clean.is_empty():
		return "Unsupported or invalid progress schema."
	var old_data: Dictionary = data.duplicate(true)
	data = clean
	if not save_game():
		data = old_data
		return "Could not save imported progress."
	return ""

func _authenticated_bytes(salt: PackedByteArray, iv: PackedByteArray, ciphertext: PackedByteArray) -> PackedByteArray:
	var bytes: PackedByteArray = (BACKUP_MAGIC + ":PBKDF2-HMAC-SHA256:AES-256-CBC-HMAC-SHA256:" + str(BACKUP_ITERATIONS)).to_utf8_buffer()
	bytes.append_array(salt)
	bytes.append_array(iv)
	bytes.append_array(ciphertext)
	return bytes

func _pbkdf2(password: PackedByteArray, salt: PackedByteArray, iterations: int) -> PackedByteArray:
	var crypto: Crypto = Crypto.new()
	var output: PackedByteArray = PackedByteArray()
	# Two SHA-256 blocks provide independent 256-bit encryption and MAC keys.
	for block: int in range(1, 3):
		var block_salt: PackedByteArray = salt.duplicate()
		block_salt.append_array(PackedByteArray([0, 0, 0, block]))
		var u: PackedByteArray = crypto.hmac_digest(HashingContext.HASH_SHA256, password, block_salt)
		var accumulator: PackedByteArray = u.duplicate()
		for iteration: int in range(1, iterations):
			u = crypto.hmac_digest(HashingContext.HASH_SHA256, password, u)
			for index: int in range(32):
				accumulator[index] = accumulator[index] ^ u[index]
		output.append_array(accumulator)
	return output
