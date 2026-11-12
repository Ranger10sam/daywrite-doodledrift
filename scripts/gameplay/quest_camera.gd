class_name QuestCamera
extends Camera2D
var target: QuestBall
var bounds := Vector2(1800, 900)
var reduced_motion: bool = false

func _init() -> void:
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS

func _ready() -> void:
	position_smoothing_enabled = false
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	zoom = Vector2(0.82, 0.82)
	limit_left = 0
	limit_top = 0
	limit_right = int(bounds.x)
	limit_bottom = int(bounds.y)
	if is_instance_valid(target):
		position = _clamped_target(target.position)
	reset_physics_interpolation()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	var look := clampf(target.linear_velocity.x * 0.25, -105.0, 105.0) if not reduced_motion else 0.0
	var desired := _clamped_target(target.position + Vector2(look, -65))
	position.x = lerpf(position.x, desired.x, 1.0 - exp(-delta * 5.0))
	position.y = lerpf(position.y, desired.y, 1.0 - exp(-delta * 2.4))

func _clamped_target(at: Vector2) -> Vector2:
	var half := get_viewport_rect().size / (zoom * 2.0)
	return Vector2(clampf(at.x, minf(half.x, bounds.x * 0.5), maxf(bounds.x - half.x, bounds.x * 0.5)), clampf(at.y, minf(half.y, bounds.y * 0.5), maxf(bounds.y - half.y, bounds.y * 0.5)))

func snap() -> void:
	if is_instance_valid(target):
		position = _clamped_target(target.respawn_target + Vector2(0, -65))
	reset_physics_interpolation()
