class_name DrawingController
extends Node2D
signal feedback(message: String)
signal changed
var reservoir := InkReservoir.new()
var strokes: Array[InkStroke] = []
var selected_ink: String = "solid"
var reverse: bool = false
var draw_mode: bool = false
var current := PackedVector2Array()
var stroke_id: int = -1
var finger: int = -2
var level_world: Node2D
var player: RigidBody2D
var maximum_segments: int = 512
var maximum_strokes: int = 32
var maximum_points: int = 128
var maximum_length: float = 6000.0
var last_warning: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	maximum_segments = int(PhysicsConfig.number("max_segments", 512))
	maximum_strokes = int(PhysicsConfig.number("max_strokes", 32))
	maximum_points = int(PhysicsConfig.number("max_points", 128))
	maximum_length = PhysicsConfig.number("max_total_length", 6000.0)

func start_mode() -> void:
	draw_mode = true
	finger = -2
	last_warning = ""
	queue_redraw()

func end_mode() -> void:
	finish_stroke()
	draw_mode = false
	finger = -2
	queue_redraw()

func screen_to_world(screen: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * screen

func _unhandled_input(event: InputEvent) -> void:
	if not draw_mode:
		return
	if event is InputEventScreenTouch:
		if event.pressed and finger == -2:
			finger = event.index
			begin_stroke(screen_to_world(event.position))
		elif event.index == finger and not event.pressed:
			finish_stroke()
			finger = -2
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == finger:
		accept_to(screen_to_world(event.position))
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and finger == -2:
			finger = -1
			begin_stroke(screen_to_world(event.position))
		elif not event.pressed and finger == -1:
			finish_stroke()
			finger = -2
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and finger == -1:
		accept_to(screen_to_world(event.position))
		get_viewport().set_input_as_handled()

func segment_count() -> int:
	var count := 0
	for stroke in strokes:
		if is_instance_valid(stroke) and not stroke.removed:
			count += stroke.points.size() - 1
	return count

func begin_stroke(point: Vector2) -> bool:
	if is_instance_valid(level_world) and not selected_ink in level_world.definition.get("allowed_inks",InkCatalog.IDS):
		warn("This puzzle's ink supply: " + ", ".join(level_world.definition.get("allowed_inks",InkCatalog.IDS)))
		return false
	if not current.is_empty():
		finish_stroke()
	if strokes.size() >= maximum_strokes or segment_count() >= maximum_segments:
		warn("Drawing limit reached. Undo or clear a structure.")
		return false
	if not valid_segment(point, point):
		warn("Draw inside the dotted build area, clear of the ball and obstacles.")
		return false
	if reservoir.amount < 0.2:
		warn("Ink is empty. Resume to refill.")
		return false
	current.append(point)
	stroke_id = reservoir.begin_stroke()
	changed.emit()
	queue_redraw()
	return true

func accept_to(destination: Vector2) -> void:
	if current.is_empty():
		return
	var start := current[-1]
	var distance := start.distance_to(destination)
	if distance < 4.0:
		return
	# Resample every <=10 world pixels, so fast drags cannot cross obstacles or evade cost.
	var steps := int(ceilf(distance / 10.0))
	var existing_length := StrokeGeometry.length_of(current)
	for stroke in strokes:
		if is_instance_valid(stroke) and not stroke.removed:
			existing_length += StrokeGeometry.length_of(stroke.points)
	for i in range(1, steps + 1):
		# A polyline has one fewer segment than points; accept the final legal
		# segment at the exact active collision budget, then reject the next one.
		if current.size() >= maximum_points or segment_count() + current.size() - 1 >= maximum_segments:
			warn("Stroke limit reached. Start another line.")
			finish_stroke()
			return
		var target := start.lerp(destination, float(i) / steps)
		var previous := current[-1]
		if existing_length + previous.distance_to(target) > maximum_length:
			warn("Total drawing length reached. Remove a structure to continue.")
			finish_stroke()
			return
		if StrokeGeometry.crosses_self(current, target) or not valid_segment(previous, target):
			warn("That segment crosses a protected area.")
			# Finish at the last valid point; never jump across invalid geometry on next drag.
			finish_stroke()
			return
		var unit_cost := PhysicsConfig.number("base_ink_cost", 0.06) * float(InkCatalog.get_ink(selected_ink).cost)
		var requested := previous.distance_to(target) * unit_cost
		if requested > reservoir.amount:
			target = previous.lerp(target, reservoir.amount / requested)
			requested = reservoir.amount
		if previous.distance_to(target) > 0.1:
			reservoir.spend(stroke_id, requested)
			AudioManager.play_sfx("draw",0.5)
			existing_length += previous.distance_to(target)
			current.append(target)
		if reservoir.amount < 0.001:
			warn("Ink is empty. Resume to refill.")
			finish_stroke()
			return
	changed.emit()
	queue_redraw()

func valid_segment(a: Vector2, b: Vector2) -> bool:
	if not is_instance_valid(level_world) or not is_instance_valid(player):
		return false
	var margin := PhysicsConfig.number("stroke_width", 12.0) * 0.5
	if StrokeGeometry.circle_near_segment(player.global_position, 18.0 + margin + 3.0, a, b):
		return false
	return level_world.can_build_segment(a, b, margin)

func finish_stroke() -> void:
	if current.size() >= 2 and StrokeGeometry.length_of(current) >= 8.0:
		# RDP bounds geometry error to 1.5px; radius stays identical visually and physically.
		var simplified := StrokeGeometry.simplify(current, 1.5)
		var safe := true
		for i in range(1, simplified.size()):
			if not valid_segment(simplified[i - 1], simplified[i]):
				safe = false
				break
		if not safe:
			simplified = current.duplicate()
		var stroke := InkStroke.new()
		stroke.configure(simplified, selected_ink, reverse)
		stroke.ledger_id = stroke_id
		stroke.shattered.connect(_on_shattered)
		# Strokes inherit a pausable world even while their controller processes UI during pause.
		stroke.process_mode = Node.PROCESS_MODE_PAUSABLE
		level_world.add_child(stroke)
		strokes.append(stroke)
		AudioManager.play_sfx("draw")
	elif stroke_id >= 0:
		reservoir.refund(stroke_id)
	current.clear()
	stroke_id = -1
	changed.emit()
	queue_redraw()

func cancel_stroke() -> void:
	if stroke_id >= 0:
		reservoir.refund(stroke_id)
	current.clear()
	stroke_id = -1
	finger = -2
	changed.emit()
	queue_redraw()

func undo() -> void:
	cancel_stroke()
	if strokes.is_empty():
		return
	var stroke: InkStroke = strokes.pop_back()
	if is_instance_valid(stroke):
		# Destroyed fragile structures were used and do not earn a refund.
		if not stroke.removed:
			reservoir.refund(stroke.ledger_id)
		stroke.collision_layer = 0
		stroke.queue_free()
	changed.emit()

func clear_drawings(refund: bool = true) -> void:
	cancel_stroke()
	for stroke in strokes:
		if is_instance_valid(stroke):
			if refund and not stroke.removed:
				reservoir.refund(stroke.ledger_id)
			stroke.collision_layer = 0
			stroke.queue_free()
	strokes.clear()
	changed.emit()

func snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for stroke in strokes:
		if is_instance_valid(stroke) and not stroke.removed:
			result.append({"points": stroke.world_points(), "ink": stroke.ink_type, "reverse": stroke.reversed})
	return result

func _on_shattered(stroke: InkStroke) -> void:
	if level_world.has_method("burst_at") and not stroke.points.is_empty():
		level_world.burst_at(stroke.to_global(stroke.points[stroke.points.size() / 2]), InkCatalog.color("fragile"), 16)

func warn(message: String) -> void:
	if last_warning != message:
		last_warning = message
		feedback.emit(message)

func _draw() -> void:
	if current.size() >= 2:
		var color := InkCatalog.color(selected_ink)
		draw_polyline(current, Color(color, 0.12), 22.0, true)
		draw_polyline(current, color, 12.0, true)
		draw_circle(current[0], 6.0, color)
		draw_circle(current[-1], 6.0, color)
