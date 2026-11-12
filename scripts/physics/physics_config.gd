class_name PhysicsConfig
extends RefCounted
## All simulation values share pixel/second units, fixed at 60 Hz.
static var values: Dictionary = {}

static func load_config() -> void:
	if values.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/configuration/physics.json"))
		if parsed is Dictionary:
			values = parsed

static func number(key: String, fallback: float) -> float:
	load_config()
	return float(values.get(key, fallback))

static func difficulty(name: String) -> Dictionary:
	load_config()
	var entry: Dictionary = values.get("difficulties", {}).get(name, {})
	var forgiveness := float(entry.get("forgiveness_multiplier", 1.0))
	return {
		"capacity": number("ink_capacity", 100.0) * float(entry.get("capacity_multiplier", 1.0)),
		"regen": number("ink_regen", 5.0) * float(entry.get("regen_multiplier", 1.0)),
		"coyote": number("coyote_seconds", 0.12) * forgiveness,
		"buffer": number("jump_buffer_seconds", 0.14) * forgiveness,
		"hazard": float(entry.get("hazard_scale", 1.0)),
		"budget": float(entry.get("mastery_budget_multiplier", 1.35 if name == "easy" else (0.8 if name == "expert" else 1.0)))
	}
