class_name InkCatalog
extends RefCounted

const IDS: Array[String] = ["solid", "bounce", "boost", "ice", "fragile"]
const COLORS: Dictionary = {"solid": Color("AFC3CB"), "bounce": Color("C5AFF1"), "boost": Color("FFCAA6"), "ice": Color("B7DFFF"), "fragile": Color("F5B3C5")}
const COSTS: Dictionary = {"solid": 1.0, "bounce": 2.5, "boost": 2.0, "ice": 1.5, "fragile": 0.5}
static var config: Dictionary = {}

static func get_ink(id: String) -> Dictionary:
	if config.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/inks/inks.json"))
		if parsed is Dictionary:
			config = parsed.get("inks", parsed)
		elif parsed is Array:
			for item in parsed:
				config[str(item.get("id", ""))] = item
	var entry: Dictionary = config.get(id, {})
	return {"id": id, "cost": float(entry.get("cost", entry.get("cost_multiplier", COSTS.get(id, 1.0)))), "friction": float(entry.get("friction", 0.6)), "bounce_speed": float(entry.get("bounce_speed", 650.0)), "boost_force": float(entry.get("boost_force", 1800.0)), "break_delay": float(entry.get("break_delay", 1.5))}

static func color(id: String) -> Color:
	return COLORS.get(id, Color.WHITE)
