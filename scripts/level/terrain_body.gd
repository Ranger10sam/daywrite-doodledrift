class_name TerrainBody
extends StaticBody2D
var polygon := PackedVector2Array()
var surface: String = "solid"
var color := Color("264f48")
var accent := Color("93dfb3")
var role: String = "ground"
var break_remaining: float = -1.0
var break_delay: float = 1.5
var initial_position := Vector2.ZERO
var removed: bool = false

func configure(data: Dictionary, base_color: Color, edge_color: Color) -> void:
	for p in data.points:
		polygon.append(Vector2(float(p[0]), float(p[1])))
	surface = str(data.get("surface", "solid"))
	role = str(data.get("role", "ground"))
	break_delay = float(data.get("break_delay", 1.5))
	color = base_color
	accent = edge_color
	collision_layer = 1
	collision_mask = 2 | 4
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.015 if surface == "ice" else 0.65
	var collision := CollisionPolygon2D.new()
	collision.polygon = polygon
	add_child(collision)
	queue_redraw()

func get_surface_data(_contact: Vector2 = Vector2.ZERO) -> Dictionary:
	return InkCatalog.get_ink(surface)

func touch() -> void:
	if surface == "fragile" and break_remaining < 0.0 and not removed:
		break_remaining = break_delay

func restore() -> void:
	removed = false
	break_remaining = -1.0
	collision_layer = 1
	show()
	queue_redraw()

func _physics_process(delta: float) -> void:
	if break_remaining >= 0.0 and not removed:
		break_remaining -= delta
		queue_redraw()
		if break_remaining <= 0.0:
			removed = true
			set_deferred("collision_layer", 0)
			hide()
			AudioManager.play_sfx("fragile")

func _draw() -> void:
	if polygon.size() < 3:
		return
	var lowest := polygon[0].y
	var highest := polygon[0].y
	for point in polygon:
		lowest = maxf(lowest, point.y)
		highest = minf(highest, point.y)
	var shades := PackedColorArray()
	for point in polygon:
		var depth := clampf((point.y - highest) / maxf(30.0, lowest - highest), 0.0, 1.0)
		shades.append(color.lightened(.10).lerp(color.darkened(.085), depth))
	draw_polygon(polygon, shades)
	var outline := polygon.duplicate()
	outline.append(polygon[0])
	draw_polyline(outline, Color("344054", .14), 1.5, true)
	var top := polygon.slice(0, maxi(2, polygon.size() - 2))
	if role == "ceiling":
		top = polygon.slice(polygon.size() - 2)
	var edge := InkCatalog.color(surface) if surface != "solid" else accent
	draw_polyline(top, Color("344054", .16), 7.0, true)
	draw_polyline(top, edge, 5.0, true)
	draw_polyline(top, Color("FFF9F0", .76), 1.5, true)
	# Sparse printed strata give the terrain a warm illustrated-paper texture.
	for i in range(1, top.size()):
		var a := top[i - 1]
		var b := top[i]
		var count := int(a.distance_to(b) / 86.0)
		for j in range(count):
			var at := a.lerp(b, (float(j) + .35) / maxf(1.0, count)) + Vector2(0, 30 + fmod(j * 17.0, 34.0))
			if Geometry2D.is_point_in_polygon(at, polygon):
				draw_line(at, at + Vector2(13, -1), Color("FFF9F0", .16), 2.0, true)
				draw_circle(at + Vector2(22, 11), 1.2, Color("344054", .08))
	if surface == "fragile" and break_remaining >= 0.0:
		for p in top:
			draw_polyline(PackedVector2Array([p, p + Vector2(10, 16), p + Vector2(5, 29)]), Color("A5677B"), 2.0, true)
