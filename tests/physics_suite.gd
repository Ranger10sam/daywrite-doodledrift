extends SceneTree
## Real fixed-step Godot Physics 2D regression tests, using production scripts.
## Run with --headless --fixed-fps 60 --script res://tests/physics_suite.gd
var checks: int = 0
var failures: Array[String] = []
var fixture: Node2D
var ball: Variant
var ball_script: Script
var stroke_script: Script

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("FAIL: " + label)

func ticks(count: int) -> void:
	for i in range(count):
		await physics_frame

func fresh() -> void:
	if is_instance_valid(fixture):
		fixture.queue_free()
		await process_frame
		await physics_frame
	fixture = Node2D.new()
	root.add_child(fixture)
	ball = null

func ground(left: float = 0.0, right: float = 2500.0, top: float = 560.0) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 2
	body.physics_material_override = PhysicsMaterial.new()
	body.physics_material_override.friction = 0.6
	var shape := RectangleShape2D.new()
	shape.size = Vector2(right - left, 50.0)
	var collider := CollisionShape2D.new()
	collider.shape = shape
	collider.position = Vector2((left + right) * 0.5, top + 25.0)
	body.add_child(collider)
	fixture.add_child(body)
	return body

func stroke(ink: String, a: Vector2 = Vector2(0, 560), b: Vector2 = Vector2(2500, 560), reverse: bool = false) -> Variant:
	var surface: Variant = stroke_script.new()
	surface.configure(PackedVector2Array([a, b]), ink, reverse)
	fixture.add_child(surface)
	# These isolate contact effects on a fixed test surface. Free-fall and
	# support anchoring are exercised separately by revision_suite.gd.
	surface.freeze = true
	if ink == "fragile": surface.break_delay = 1.5
	return surface

func spawn(at: Vector2, velocity: Vector2 = Vector2.ZERO) -> Variant:
	var body: Variant = ball_script.new()
	body.position = at
	body.linear_velocity = velocity
	fixture.add_child(body)
	ball = body
	return body

func run() -> void:
	# Autoload identifiers are registered after the custom SceneTree is initialized.
	ball_script = load("res://scripts/player/ball.gd")
	stroke_script = load("res://scripts/ink/ink_stroke.gd")
	await movement_tests()
	await configuration_tests()
	await forgiving_jump_tests()
	await high_speed_tests()
	await bounce_tests()
	await boost_tests()
	await ice_tests()
	await fragile_and_pause_tests()
	await fresh()
	fixture.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: %d actual Godot fixed-step physics regression checks" % checks)
		quit(0)
	else:
		print("FAIL: %d of %d physics checks failed" % [failures.size(), checks])
		for failure in failures:
			print("  " + failure)
		quit(1)

func movement_tests() -> void:
	await fresh()
	ground()
	spawn(Vector2(200, 540))
	await ticks(30)
	check(ball.grounded, "ball settles grounded on ordinary terrain")
	check(absf(ball.position.y - 542.0) < 3.0, "ball rests above floor without penetration")
	var origin: float = ball.position.x
	ball.axis = 1.0
	await ticks(45)
	check(ball.position.x - origin > 150.0 and ball.linear_velocity.x > 200.0, "right accelerates using fixed-step momentum")
	check(ball.angular_velocity > 2.0, "movement produces rolling angular velocity")
	var initial_speed: float = ball.linear_velocity.x
	ball.axis = 0.0
	ball.braking = true
	await ticks(1)
	check(ball.linear_velocity.x > 10.0, "brake does not instantaneously halt motion")
	await ticks(30)
	check(absf(ball.linear_velocity.x) < initial_speed * 0.2, "grounded brake reduces momentum gradually")
	ball.braking = false
	ball.axis = -1.0
	await ticks(35)
	check(ball.linear_velocity.x < -200.0, "left reverses movement")
	ball.axis = 0.0
	ball.braking = true
	await ticks(30)
	ball.braking = false
	ball.request_jump()
	await ticks(3)
	check(ball.linear_velocity.y < -300.0 and not ball.grounded, "grounded jump produces controlled upward impulse")
	var before_air_jump: float = ball.linear_velocity.y
	ball.request_jump()
	await ticks(2)
	check(ball.linear_velocity.y > before_air_jump - 10.0, "airborne input cannot trigger a second jump")
	var x_before_air: float = ball.position.x
	ball.axis = 1.0
	await ticks(10)
	check(ball.position.x > x_before_air, "air control retains horizontal authority")
	ball.axis = 0.0
	var fall_before: float = ball.linear_velocity.y
	ball.braking = true
	await ticks(3)
	check(ball.linear_velocity.y > fall_before + 60.0, "air brake adds controlled fast-fall acceleration")
	ball.braking = false
	await ticks(80)
	check(ball.grounded, "ball lands reliably after jump")

func forgiving_jump_tests() -> void:
	await fresh()
	ground(0, 420)
	spawn(Vector2(370, 540))
	await ticks(25)
	ball.linear_velocity = Vector2(350, 0)
	var left_ground: bool = false
	for i in range(30):
		await ticks(1)
		if not ball.grounded:
			left_ground = true
			break
	check(left_ground, "coyote fixture leaves the ledge")
	ball.request_jump()
	await ticks(2)
	check(ball.linear_velocity.y < -300.0, "jump within coyote window works after leaving ledge")
	await fresh()
	ground(0, 420)
	spawn(Vector2(370, 540))
	await ticks(25)
	ball.linear_velocity = Vector2(350, 0)
	for i in range(30):
		await ticks(1)
		if not ball.grounded:
			break
	await ticks(12)
	ball.request_jump()
	await ticks(2)
	check(ball.linear_velocity.y >= 0.0, "expired coyote window prevents unsupported jump")
	await fresh()
	ground()
	spawn(Vector2(200, 430))
	var buffered: bool = false
	for i in range(60):
		await ticks(1)
		if ball.position.y > 510.0 and ball.linear_velocity.y > 100.0:
			ball.request_jump()
			buffered = true
			break
	check(buffered, "buffer fixture requests jump just before landing")
	var launched: bool = false
	for i in range(12):
		await ticks(1)
		if ball.linear_velocity.y < -300.0:
			launched = true
			break
	check(launched, "buffered jump activates on impending ground contact")

func high_speed_tests() -> void:
	await fresh()
	ground()
	spawn(Vector2(200, 370), Vector2(0, 900))
	await ticks(30)
	check(ball.position.y < 545.0 and ball.grounded, "shape CCD prevents downward tunneling at supported maximum fall speed")
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	var shape := RectangleShape2D.new()
	shape.size = Vector2(12, 500)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(686, 400)
	wall.add_child(collision)
	fixture.add_child(wall)
	ball.linear_velocity = Vector2(760, 0)
	await ticks(50)
	check(ball.position.x <= 664.0, "shape CCD prevents sideways tunneling through thin wall")
	ball.respawn(Vector2(250, 540))
	await ticks(3)
	check(ball.position.distance_to(Vector2(250, 540)) < 8.0, "respawn restores checkpoint position through integrate_forces")
	check(ball.linear_velocity.length() < 80.0, "respawn clears unsafe velocity")

func bounce_tests() -> void:
	await fresh()
	stroke("bounce")
	spawn(Vector2(300, 480))
	var minimum_y_velocity: float = 0.0
	var maximum_speed: float = 0.0
	for i in range(100):
		await ticks(1)
		minimum_y_velocity = minf(minimum_y_velocity, ball.linear_velocity.y)
		maximum_speed = maxf(maximum_speed, ball.linear_velocity.length())
	check(minimum_y_velocity < -500.0, "Bounce launches upward from horizontal surface normal")
	check(minimum_y_velocity >= -761.0 and maximum_speed <= 1101.0, "repeated Bounce contacts stay inside global energy cap")
	await fresh()
	stroke("bounce", Vector2(600, 100), Vector2(600, 750))
	spawn(Vector2(520, 420), Vector2(400, 0))
	ball.gravity_scale = 0.0
	var minimum_x_velocity: float = 0.0
	for i in range(35):
		await ticks(1)
		minimum_x_velocity = minf(minimum_x_velocity, ball.linear_velocity.x)
	check(minimum_x_velocity < -500.0, "Bounce uses leftward normal on a vertical wall")
	check(absf(ball.linear_velocity.y) < 50.0, "vertical-wall Bounce does not inject an arbitrary upward impulse")

func boost_tests() -> void:
	await fresh()
	for i in range(3):
		stroke("boost", Vector2(0, 560), Vector2(6000, 560))
	spawn(Vector2(200, 536))
	var maximum: float = 0.0
	for i in range(120):
		await ticks(1)
		maximum = maxf(maximum, absf(ball.linear_velocity.x))
	check(ball.linear_velocity.x > 350.0, "Boost accelerates in indicated forward direction")
	check(maximum <= 761.0, "overlapping Boost surfaces cannot exceed launch cap")
	await fresh()
	stroke("boost", Vector2(-4000, 560), Vector2(2500, 560), true)
	spawn(Vector2(500, 536))
	await ticks(55)
	check(ball.linear_velocity.x < -250.0, "reversed Boost accelerates in opposite direction")
	await fresh()
	stroke("boost", Vector2(0, 650), Vector2(2000, 250))
	spawn(Vector2(200, 586))
	await ticks(60)
	check(ball.position.x > 400.0 and ball.position.y < 565.0, "sloped Boost follows rising tangent")
	await fresh()
	stroke("boost", Vector2(600, -1200), Vector2(600, 1600), true)
	spawn(Vector2(575, 500), Vector2(140, 0))
	ball.gravity_scale = 0.0
	ball.axis = 1.0
	await ticks(45)
	check(ball.linear_velocity.y < -250.0, "vertical reversed Boost follows upward tangent while pressing wall")

func coast_speed(kind: String, braking: bool, frames: int) -> float:
	await fresh()
	stroke(kind, Vector2(-1000, 560), Vector2(6000, 560))
	spawn(Vector2(200, 536), Vector2(400, 0))
	ball.braking = braking
	await ticks(frames)
	return absf(ball.linear_velocity.x)

func ice_tests() -> void:
	var solid_speed: float = await coast_speed("solid", false, 60)
	var ice_speed: float = await coast_speed("ice", false, 60)
	check(ice_speed > solid_speed + 25.0, "Ice friction preserves more momentum than Solid from equal nonrolling launch")
	check(ice_speed > 250.0, "Ice retains useful speed without velocity teleportation")
	var solid_brake: float = await coast_speed("solid", true, 20)
	var ice_brake: float = await coast_speed("ice", true, 20)
	check(ice_brake > solid_brake + 100.0, "braking is weaker on Ice than Solid")

func fragile_and_pause_tests() -> void:
	await fresh()
	var fragile: Variant = stroke("fragile")
	spawn(Vector2(200, 536))
	await ticks(15)
	check(fragile.break_remaining > 0.0, "first contact activates Fragile countdown")
	for i in range(6):
		fragile.touch()
		await ticks(10)
	check(not fragile.removed, "Fragile supports player before configured delay")
	await ticks(40)
	check(fragile.removed and fragile.collision_layer == 0 and fragile.collision_mask == 0, "Fragile safely disables collision after delay")
	check(ball.position.y > 570.0, "no ghost collision remains after Fragile shatters")
	await fresh()
	ground()
	fragile = stroke("fragile", Vector2(1000, 450), Vector2(1400, 450))
	fragile.touch()
	spawn(Vector2(200, 540))
	ball.axis = 1.0
	await ticks(20)
	var saved_position: Vector2 = ball.position
	var saved_velocity: Vector2 = ball.linear_velocity
	var saved_break: float = fragile.break_remaining
	paused = true
	for i in range(20):
		await process_frame
	check(ball.position.distance_to(saved_position) < .001 and ball.linear_velocity.distance_to(saved_velocity) < .001, "paused gameplay preserves physics transform and velocity")
	check(absf(fragile.break_remaining - saved_break) < .001, "Fragile countdown uses simulation time and pauses")
	paused = false
	await ticks(10)
	check(ball.position.x > saved_position.x + 10.0, "physics resumes after pause")

func configuration_tests() -> void:
	await fresh()
	var original_gravity := PhysicsConfig.number("gravity", 1100.0)
	PhysicsConfig.values["gravity"] = 550.0
	spawn(Vector2(200, 100))
	check(absf(ball.gravity_scale - 0.5) < 0.001, "central gravity configuration reaches the rigid body")
	await ticks(30)
	check(ball.linear_velocity.y > 240.0 and ball.linear_velocity.y < 300.0, "configured gravity changes actual fixed-step fall acceleration")
	PhysicsConfig.values["gravity"] = original_gravity
