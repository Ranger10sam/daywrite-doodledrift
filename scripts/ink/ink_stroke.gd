class_name InkStroke
extends RigidBody2D
## Unsupported strokes fall. A bridge is anchored only when BOTH ends touch terrain.
signal shattered(stroke: InkStroke)
var points := PackedVector2Array()
var ink_type: String = "solid"
var reversed: bool = false
var ledger_id: int = 0
var paid_cost: float = 0.0
var width: float = 12.0
var break_remaining: float = -1.0
var break_delay: float = 1.5
var pulse: float = 0.0
var removed: bool = false

func configure(polyline: PackedVector2Array, type: String, reverse: bool = false) -> void:
	var center := Vector2.ZERO
	for point in polyline: center += point
	center /= maxi(1, polyline.size())
	position = center
	points = PackedVector2Array()
	for point in polyline: points.append(point - center)
	mass = clampf(StrokeGeometry.length_of(points) * 0.015, 1.5, 15.0)
	linear_damp = 0.35
	angular_damp = 1.2
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	ink_type = type
	reversed = reverse
	width = PhysicsConfig.number("stroke_width", 12.0)
	var data := InkCatalog.get_ink(type)
	break_delay = float(data.break_delay)
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = float(data.friction)
	physics_material_override.bounce = 0.0
	collision_layer = 4
	collision_mask = 1 | 2 | 4 | 8
	for i in range(1, points.size()):
		var a := points[i - 1]
		var b := points[i]
		if a.distance_to(b) < 1.0:
			continue
		var shape := CapsuleShape2D.new()
		shape.radius = width * 0.5
		shape.height = a.distance_to(b) + width
		var collider := CollisionShape2D.new()
		collider.shape = shape
		collider.position = (a + b) * 0.5
		collider.rotation = (b - a).angle() + PI * 0.5
		add_child(collider)
	queue_redraw()

func _ready() -> void:
	var owner_world := get_parent()
	if owner_world.has_method("has_terrain_anchor"):
		freeze = owner_world.has_terrain_anchor(to_global(points[0])) and owner_world.has_terrain_anchor(to_global(points[-1]))
		if freeze: queue_redraw()

func world_points() -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points: result.append(to_global(point))
	return result

func get_surface_data(contact: Vector2 = Vector2.ZERO) -> Dictionary:
	contact = to_local(contact)
	var closest := INF
	var direction := Vector2.RIGHT
	for i in range(1, points.size()):
		var nearest := Geometry2D.get_closest_point_to_segment(contact, points[i - 1], points[i])
		var distance := contact.distance_squared_to(nearest)
		if distance < closest:
			closest = distance
			direction = (points[i] - points[i - 1]).normalized()
	if reversed:
		direction = -direction
	var data := InkCatalog.get_ink(ink_type)
	data["direction"] = direction.rotated(global_rotation)
	return data

func touch() -> void:
	if removed:
		return
	pulse = 1.0
	if ink_type == "fragile" and break_remaining < 0.0:
		break_remaining = break_delay

func _physics_process(delta: float) -> void:
	if freeze and get_parent().has_method("has_terrain_anchor"):
		if not get_parent().has_terrain_anchor(to_global(points[0])) or not get_parent().has_terrain_anchor(to_global(points[-1])):
			freeze = false
			queue_redraw()
	if not freeze:
		linear_velocity = linear_velocity.limit_length(900.0)
		if position.y > 1200.0 and not removed:
			removed = true
			set_deferred("collision_layer", 0)
			set_deferred("collision_mask", 0)
			hide()
	if pulse > 0.0:
		pulse = maxf(0.0, pulse - delta * 3.0)
		queue_redraw()
	if break_remaining >= 0.0 and not removed:
		break_remaining -= delta
		queue_redraw()
		if break_remaining <= 0.0:
			removed = true
			set_deferred("collision_layer", 0)
			set_deferred("collision_mask", 0)
			AudioManager.play_sfx("fragile")
			shattered.emit(self)
			# Remain a tiny invisible ledger entry until clear/undo, no collision ghost.
			hide()

func _draw() -> void:
	if points.size() < 2 or removed:
		return
	var color := InkCatalog.color(ink_type)
	draw_set_transform(Vector2(0,2))
	draw_polyline(points, Color("344054", .09), width + 4, true)
	draw_set_transform(Vector2.ZERO)
	draw_polyline(points, Color(color, .07 + pulse*.04), width + 9 + pulse*3, true)
	draw_polyline(points, color.darkened(.19), width + 1.5, true)
	# The core width and rounded endpoints still match the existing capsules.
	draw_polyline(points, color, width, true)
	draw_set_transform(Vector2(0,-1.5))
	draw_polyline(points, Color("FFF9F0", .38), width*.24, true)
	draw_set_transform(Vector2.ZERO)
	for endpoint in [points[0], points[-1]]:
		draw_circle(endpoint, width * 0.5, color)
		if freeze:
			draw_circle(endpoint+Vector2(0,1),8,Color("344054",.16))
			draw_circle(endpoint,7,Color("809A99"))
			draw_circle(endpoint,4.6,Color("FFF9F0"))
			draw_circle(endpoint,1.6,color.darkened(.15))
	var distance := 0.0
	for i in range(1, points.size()):
		var a := points[i - 1]
		var b := points[i]
		var tangent := (b - a).normalized()
		var length := a.distance_to(b)
		var mark := 20.0 - fmod(distance, 32.0)
		while mark < length:
			var at := a + tangent * mark
			var normal := tangent.orthogonal()
			match ink_type:
				"solid":
					draw_line(at-tangent*3-normal*1.8,at+tangent*3-normal*1.8,Color("526976",.65),1.1,true)
					draw_line(at-tangent*3+normal*1.8,at+tangent*3+normal*1.8,Color("526976",.65),1.1,true)
				"boost":
					var forward := tangent * (-1.0 if reversed else 1.0)
					draw_polyline(PackedVector2Array([at - forward * 4 + normal * 3.2, at + forward * 3, at - forward * 4 - normal * 3.2]), Color("A27454"), 1.8, true)
				"ice":
					draw_line(at-normal*3.4,at+normal*3.4,Color("547F9A"),1.2,true)
					draw_line(at-tangent*3.4,at+tangent*3.4,Color("547F9A"),1.2,true)
					draw_line(at-normal*2.2-tangent*2.2,at+normal*2.2+tangent*2.2,Color("547F9A",.65),1,true)
				"bounce":
					draw_polyline(PackedVector2Array([at-tangent*4,at-tangent*2-normal*2.5,at+normal*2.5,at+tangent*2-normal*2.5,at+tangent*4]),Color("7C69A0"),1.3,true)
				"fragile":
					draw_line(at-normal*3-tangent*2.2,at+normal*3+tangent*2.2,Color("A6687D"),1.5,true)
			mark += 32.0
		distance += length
	if break_remaining >= 0.0:
		var amount := 1.0 - break_remaining / break_delay
		for i in range(1, points.size()):
			if fmod(float(i), 3.0) <= amount * 3.0:
				var mid := points[i].lerp(points[i - 1], 0.5)
				draw_polyline(PackedVector2Array([mid + Vector2(-5,-5),mid + Vector2(1,0),mid + Vector2(-2,5)]), Color("9B5E77"), 1.8, true)
