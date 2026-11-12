class_name QuestBall
extends RigidBody2D
signal failed
signal landed(speed: float)
var axis: float = 0.0
var braking: bool = false
var grounded: bool = false
var ground_normal := Vector2.UP
var jump_buffer: float = 0.0
var coyote: float = 0.0
var coyote_duration: float = 0.12
var buffer_duration: float = 0.14
var grounded_time: float = 0.0
var bounce_cooldown: float = 0.0
var effect_flash: float = 0.0
var effect_color := Color("a6f5cc")
var impact: float = 0.0
var previous_vertical: float = 0.0
var wind := Vector2.ZERO
var respawn_target := Vector2.ZERO
var respawn_pending: bool = false
var facial_expression: bool = true
var reduced_motion: bool = false
var last_contact_normals: Array[Vector2] = []
var visual: Node2D
var trail: Array[Vector2] = []
var trail_clock: float = 0.0

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 4 | 8
	mass = 1.0
	gravity_scale = PhysicsConfig.number("gravity", 1100.0) / maxf(1.0, float(ProjectSettings.get_setting("physics/2d/default_gravity", 1100.0)))
	linear_damp = 0.04
	angular_damp = 0.1
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	contact_monitor = true
	max_contacts_reported = 12
	can_sleep = false
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.65
	physics_material_override.bounce = 0.04
	var shape := CircleShape2D.new()
	shape.radius = PhysicsConfig.number("radius", 18.0)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	visual = Node2D.new()
	visual.set_script(preload("res://scripts/player/ball_visual.gd"))
	add_child(visual)

func request_jump() -> void:
	jump_buffer = buffer_duration

func clear_controls() -> void:
	axis = 0.0
	braking = false
	jump_buffer = 0.0

func respawn(at: Vector2) -> void:
	set_meta("victory",false)
	respawn_target = at
	respawn_pending = true
	clear_controls()
	trail.clear()
	impact = 0.8
	reset_physics_interpolation()

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	var dt := state.step
	if respawn_pending:
		state.transform = Transform2D(0.0, respawn_target)
		state.linear_velocity = Vector2.ZERO
		state.angular_velocity = 0.0
		respawn_pending = false
		coyote = 0.0
		grounded = false
		return
	jump_buffer = maxf(0.0, jump_buffer - dt)
	coyote = maxf(0.0, coyote - dt)
	bounce_cooldown = maxf(0.0, bounce_cooldown - dt)
	var origin := state.transform.origin
	var query := PhysicsRayQueryParameters2D.create(origin, origin + Vector2(0, 25), 1 | 4 | 8, [get_rid()])
	var hit := state.get_space_state().intersect_ray(query)
	var was_grounded := grounded
	grounded = not hit.is_empty() and Vector2(hit.normal).y < -0.45 and state.linear_velocity.y >= -85.0
	var surface := "solid"
	if grounded:
		ground_normal = hit.normal
		coyote = coyote_duration
		grounded_time += dt
		var collider: Object = hit.collider
		if collider.has_method("get_surface_data"):
			surface = str(collider.get_surface_data(hit.position).id)
		if not was_grounded and previous_vertical > 180.0:
			impact = minf(1.0, previous_vertical / 650.0)
			landed.emit(previous_vertical)
			AudioManager.play_sfx("land")
	else:
		grounded_time = 0.0
	var velocity := state.linear_velocity
	var acceleration := PhysicsConfig.number("ground_accel", 1600.0) if grounded else PhysicsConfig.number("air_accel", 620.0)
	if surface == "ice":
		acceleration *= 0.28
	if absf(axis) > 0.01:
		var speed_limit := PhysicsConfig.number("max_speed", 500.0)
		if absf(velocity.x) < speed_limit or signf(axis) != signf(velocity.x):
			velocity.x += axis * acceleration * dt
		state.angular_velocity = move_toward(state.angular_velocity, velocity.x / 18.0, 40.0 * dt)
	if braking:
		if grounded:
			var grip := 0.17 if surface == "ice" else 1.0
			velocity.x = move_toward(velocity.x, 0.0, PhysicsConfig.number("brake_strength", 1900.0) * grip * dt)
			state.angular_velocity = move_toward(state.angular_velocity, 0.0, 50.0 * grip * dt)
		else:
			velocity.y += 900.0 * dt
	velocity += wind * dt
	if jump_buffer > 0.0 and coyote > 0.0:
		velocity.y = -PhysicsConfig.number("jump_speed", 470.0)
		jump_buffer = 0.0
		coyote = 0.0
		grounded = false
		impact = -0.5
		AudioManager.play_sfx("jump")
	last_contact_normals.clear()
	var boost_applied := false
	for i in range(state.get_contact_count()):
		var other: Object = state.get_contact_collider_object(i)
		if other == null or not other.has_method("get_surface_data"):
			continue
		# Godot's "local" here identifies this body, not a local-space vector:
		# the API already returns a world-space contact point. Transforming it
		# again rotates/translates the point and corrupts sloped/wall launches.
		var point := state.get_contact_local_position(i)
		var data: Dictionary = other.get_surface_data(point)
		var normal := state.get_contact_local_normal(i).normalized()
		# The contact location gives a stable outward normal for a circular collider.
		var radial := (origin - point).normalized()
		if radial.length_squared() > 0.5:
			normal = radial
		last_contact_normals.append(normal)
		if other.has_method("touch"):
			other.touch()
		match str(data.id):
			"bounce":
				if bounce_cooldown <= 0.0:
					# Springs follow the drawn surface, including its rounded lip;
					# a tiny endcap should not reverse an otherwise flat launch.
					var tangent: Vector2 = data.get("direction",Vector2.RIGHT)
					var spring_normal := Vector2(tangent.y,-tangent.x).normalized()
					if spring_normal.dot(normal) < 0: spring_normal = -spring_normal
					normal = spring_normal
					var launch := minf(float(data.get("bounce_speed", 650.0)), PhysicsConfig.number("max_launch", 760.0))
					velocity += normal * maxf(0.0, launch - velocity.dot(normal))
					bounce_cooldown = PhysicsConfig.number("bounce_cooldown_seconds", 0.22)
					coyote = 0.0
					grounded = false
					effect_color = InkCatalog.color("bounce")
					effect_flash = 1.0
					impact = 0.9
					AudioManager.play_sfx("bounce")
			"boost":
				if not boost_applied:
					velocity += Vector2(data.get("direction", Vector2.RIGHT)) * float(data.get("boost_force", 1800.0)) * dt
					boost_applied = true
					effect_color = InkCatalog.color("boost")
					if effect_flash < 0.2:
						AudioManager.play_sfx("boost")
					effect_flash = 0.6
	# Global cap also bounds stacked wind/boost/bounce interactions.
	var max_launch := PhysicsConfig.number("max_launch", 760.0)
	velocity.x = clampf(velocity.x, -max_launch, max_launch)
	velocity.y = clampf(velocity.y, -max_launch, PhysicsConfig.number("max_fall", 900.0))
	if velocity.length() > 1100.0:
		velocity = velocity.limit_length(1100.0)
	state.linear_velocity = velocity
	previous_vertical = velocity.y

func _process(delta: float) -> void:
	impact = move_toward(impact, 0.0, delta * 4.0)
	effect_flash = move_toward(effect_flash, 0.0, delta * 2.0)
	if is_instance_valid(visual):
		visual.rotation = -rotation
		visual.scale = Vector2(1.0 + impact * 0.17, 1.0 - impact * 0.17) if not reduced_motion else Vector2.ONE
		visual.queue_redraw()
