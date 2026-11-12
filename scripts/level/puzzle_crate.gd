class_name PuzzleCrate
extends RigidBody2D
var dimensions := Vector2(36,36)
var start := Vector2.ZERO
var tint := Color("f2bc72")
var drive := Vector2.ZERO
var drive_until_x := -INF
var waiting_for_chute := false
var reset_pending := false
var reset_target := Vector2.ZERO
var initial_waiting := false

func configure(data: Dictionary) -> void:
	position = Vector2(data.position[0],data.position[1])
	start = position
	drive = Vector2(data.get("drive",[0,0])[0],data.get("drive",[0,0])[1])
	drive_until_x = float(data.get("drive_until_x",-INF))
	waiting_for_chute = bool(data.get("release_on_ink_below",false))
	initial_waiting = waiting_for_chute
	freeze = waiting_for_chute
	dimensions = Vector2(data.get("size",[36,36])[0],data.get("size",[36,36])[1])
	mass = float(data.get("mass",2.0))
	set_meta("puzzle_object", "crate")
	set_meta("object_id", str(data.get("id","crate")))
	tint=Color("87d7e3") if str(data.get("id",""))=="far" else Color("f2bc72")
	collision_layer = 4
	collision_mask = 1 | 2 | 4 | 8
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = float(data.get("friction",0.5))
	var shape := RectangleShape2D.new()
	shape.size = dimensions
	var collider := CollisionShape2D.new()
	collider.shape = shape
	add_child(collider)

func _physics_process(_delta: float) -> void:
	if reset_pending: return
	if waiting_for_chute:
		var ray := PhysicsRayQueryParameters2D.create(global_position+Vector2(0,dimensions.y*.6),global_position+Vector2(0,200),4,[get_rid()])
		var hit := get_world_2d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty() and hit.collider is InkStroke:
			waiting_for_chute=false; freeze=false; queue_redraw()
	if position.x < drive_until_x: apply_central_force(drive)

func reset_at(at: Vector2) -> void:
	reset_target=at; reset_pending=true; freeze=false

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if reset_pending:
		state.transform=Transform2D(0,reset_target)
		state.linear_velocity=Vector2.ZERO; state.angular_velocity=0; reset_pending=false
		if waiting_for_chute: set_deferred("freeze",true)

func restore() -> void:
	# Explicit checkpoint reset, never ordinary motion.
	waiting_for_chute=initial_waiting
	reset_at(start)
	reset_physics_interpolation()

func _draw() -> void:
	if waiting_for_chute:
		draw_line(Vector2(0,-dimensions.y*.5),Vector2(0,-60),Color("B29A89"),2.5,true)
		draw_line(Vector2(-16,-62),Vector2(16,-62),Color("FFCAA6"),7,true)
		draw_circle(Vector2(-16,-62),3.5,Color("FFCAA6"))
		draw_circle(Vector2(16,-62),3.5,Color("FFCAA6"))
	var r := Rect2(-dimensions*.5,dimensions)
	var body_color := Color("B7DFFF") if tint.b > tint.r else Color("FFCAA6")
	var outline_color := Color("7892A7") if tint.b > tint.r else Color("B58F79")
	var style := StyleBoxFlat.new()
	style.bg_color = body_color
	style.border_color = outline_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.shadow_color = Color("344054",.1)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0,2)
	draw_style_box(style,r)
	draw_line(r.position+Vector2(5,5),r.end-Vector2(5,5),Color(outline_color,.66),3,true)
	draw_line(Vector2(r.end.x-5,r.position.y+5),Vector2(r.position.x+5,r.end.y-5),Color(outline_color,.66),3,true)
	for corner in [r.position+Vector2(5,5),Vector2(r.end.x-5,r.position.y+5),r.end-Vector2(5,5),Vector2(r.position.x+5,r.end.y-5)]:
		draw_circle(corner,1.3,Color("FFF9F0",.9))
	draw_circle(Vector2.ZERO,9.5,Color(outline_color,.45))
	draw_circle(Vector2(0,-.5),8.3,Color("FFF9F0"))
	draw_string(ThemeDB.fallback_font,Vector2(-5,4),str(get_meta("object_id","C")).substr(0,1).to_upper(),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("344054"))
