class_name StrokeGeometry
extends RefCounted
## Iterative Ramer–Douglas–Peucker; world-space points map to capsule segments.
static func simplify(points: PackedVector2Array, epsilon: float = 2.0) -> PackedVector2Array:
	if points.size() < 3:
		return points.duplicate()
	var keep: Dictionary = {0: true, points.size() - 1: true}
	var stack: Array[Vector2i] = [Vector2i(0, points.size() - 1)]
	while not stack.is_empty():
		var ends: Vector2i = stack.pop_back()
		var maximum := epsilon
		var chosen := -1
		for i in range(ends.x + 1, ends.y):
			var nearest := Geometry2D.get_closest_point_to_segment(points[i], points[ends.x], points[ends.y])
			var distance := points[i].distance_to(nearest)
			if distance > maximum:
				maximum = distance
				chosen = i
		if chosen >= 0:
			keep[chosen] = true
			stack.append(Vector2i(ends.x, chosen))
			stack.append(Vector2i(chosen, ends.y))
	var result := PackedVector2Array()
	for i in range(points.size()):
		if keep.has(i):
			result.append(points[i])
	return result

static func length_of(points: PackedVector2Array) -> float:
	var result := 0.0
	for i in range(1, points.size()):
		result += points[i - 1].distance_to(points[i])
	return result

static func crosses_self(points: PackedVector2Array, end: Vector2) -> bool:
	if points.size() >= 2:
		var previous := points[-1] - points[-2]
		var next := end - points[-1]
		if previous.dot(next) < 0.0 and absf(previous.normalized().cross(next.normalized())) < 0.05:
			return true
	if points.size() < 3:
		return false
	for i in range(points.size() - 2):
		if Geometry2D.segment_intersects_segment(points[i], points[i + 1], points[-1], end) != null:
			return true
		# Godot returns null for collinear overlap. Reject a return along old geometry too.
		if end.distance_to(Geometry2D.get_closest_point_to_segment(end, points[i], points[i + 1])) < 0.5:
			return true
	return false

static func circle_near_segment(center: Vector2, radius: float, a: Vector2, b: Vector2) -> bool:
	return center.distance_to(Geometry2D.get_closest_point_to_segment(center, a, b)) < radius
