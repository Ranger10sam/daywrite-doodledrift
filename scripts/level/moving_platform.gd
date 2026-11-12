class_name MovingPlatform
extends AnimatableBody2D
var origin := Vector2.ZERO
var destination := Vector2.ZERO
var dimensions := Vector2(120, 20)
var period: float = 4.0
var clock: float = 0.0
var accent := Color("f5c284")
var previous_pos := Vector2.ZERO
var motion_velocity := Vector2.ZERO
var island: bool = false

func configure(data: Dictionary, tint: Color) -> void:
	origin = Vector2(data.from[0], data.from[1])
	destination = Vector2(data.to[0], data.to[1])
	dimensions = Vector2(data.size[0], data.size[1])
	period = maxf(1.0, float(data.period))
	accent = tint
	island = bool(data.get("island",false))
	position = origin
	previous_pos = position
	collision_layer = 8
	collision_mask = 2 | 4
	sync_to_physics = true
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.9
	var shape := RectangleShape2D.new()
	shape.size = dimensions
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)

func reset() -> void:
	clock = 0.0
	position = origin
	previous_pos = position
	reset_physics_interpolation()

func _physics_process(delta: float) -> void:
	clock += delta
	var phase := 0.5 - 0.5 * cos(clock * TAU / period)
	position = origin.lerp(destination, phase)
	motion_velocity = (position - previous_pos) / delta
	previous_pos = position

func get_surface_data(_point: Vector2 = Vector2.ZERO) -> Dictionary:
	return InkCatalog.get_ink("solid")

func _draw() -> void:
	draw_style_box(_style(), Rect2(-dimensions * 0.5, dimensions))
	if island:
		var half := dimensions.x*.5
		draw_colored_polygon(PackedVector2Array([Vector2(-half,0),Vector2(half,0),Vector2(half*.65,32),Vector2(-half*.45,44)]),Color("D0BCA7"))
		draw_polyline(PackedVector2Array([Vector2(-half*.4,11),Vector2(half*.22,16),Vector2(half*.42,12)]),Color("FFF9F0",.25),2,true)
		draw_line(Vector2(-half,-dimensions.y*.5),Vector2(half,-dimensions.y*.5),Color("A8DFC8"),6,true)
	draw_line(Vector2(-dimensions.x * .5 + 8, -dimensions.y * .5 + 2), Vector2(dimensions.x * .5 - 8, -dimensions.y * .5 + 2), Color("FFF9F0",.85), 1.5, true)
	for side in [-1.0,1.0]:
		draw_circle(Vector2(side*(dimensions.x*.5-12),1),2,Color("344054",.28))
	draw_line(Vector2(-8,2),Vector2(8,2),Color(accent.darkened(.25),.4),2,true)

func _style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("FFF9F0").lerp(accent,.34)
	style.set_corner_radius_all(8)
	style.border_color = Color("344054",.24)
	style.set_border_width_all(1)
	style.shadow_color = Color("344054",.09)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0,3)
	return style
