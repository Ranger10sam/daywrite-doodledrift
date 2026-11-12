extends Control
## An inexpensive menu illustration. It owns no physics or input; all movement
## is confined to this decorative canvas and respects reduced motion.

var reduced_motion := false
var show_face := true
var _time := 0.0
var _paper_style: StyleBoxFlat

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paper_style = _pill(Color(1, .995, .978, .64), 28)
	resized.connect(queue_redraw)

func _process(delta: float) -> void:
	if not reduced_motion:
		_time += minf(delta, .1)
		queue_redraw()

func _draw() -> void:
	var width := maxf(200.0, size.x)
	var height := maxf(140.0, size.y)
	var floor_y := height * .75
	var ball_x: float = width * .24 + (sin(_time * .45) * 9 if not reduced_motion else 0)
	var ball_y: float = floor_y - 42 + (sin(_time * .9) * 1.5 if not reduced_motion else 0)
	var center := Vector2(ball_x, ball_y)
	# A pale paper patch keeps the little path legible over the landscape.
	if _paper_style != null:
		draw_style_box(_paper_style, Rect2(8, floor_y - 12, minf(width - 20, 465), 52))
	draw_line(Vector2(30, floor_y + 2), Vector2(width * .48, floor_y + 2), Color("A8DFC8"), 12, true)
	draw_circle(Vector2(30, floor_y + 2), 6, Color("A8DFC8"))
	var path := PackedVector2Array()
	for index in range(25):
		var t := float(index) / 24.0
		path.append(Vector2(lerpf(width * .48, width * .84, t), floor_y + 2 - sin(t * PI) * 30))
	draw_polyline(path, Color(.60, .49, .78, .12), 17, true)
	draw_polyline(path, Color("C5AFF1"), 9, true)
	draw_circle(path[-1], 4.5, Color("C5AFF1"))
	# Hand-drawn sparkle and tiny grass make the scene feel quietly alive.
	for point in [Vector2(width * .51, floor_y - 70), Vector2(width * .81, floor_y - 64)]:
		draw_line(point - Vector2(0, 6), point + Vector2(0, 6), Color("8DA8B8"), 2, true)
		draw_line(point - Vector2(5, 0), point + Vector2(5, 0), Color("8DA8B8"), 2, true)
	draw_line(Vector2(width * .39, floor_y + 3), Vector2(width * .39 - 5, floor_y - 5), Color("74A88F"), 2, true)
	draw_line(Vector2(width * .39, floor_y + 3), Vector2(width * .39 + 3, floor_y - 8), Color("74A88F"), 2, true)
	draw_set_transform(Vector2(ball_x, floor_y + 7), 0, Vector2(1, .19))
	draw_circle(Vector2.ZERO, 44, Color(.35, .42, .40, .12))
	draw_set_transform(Vector2.ZERO)
	draw_circle(center + Vector2(0, 3), 44, Color(.72, .55, .43, .09))
	for index in range(14, 0, -1):
		var t := float(index) / 14.0
		var shade := Color("FFE7BA").lerp(Color("F3AE8B"), t * .65)
		draw_circle(center + Vector2(-6, -8) * (1 - t), 42 * t, shade)
	draw_arc(center, 42, PI * .13, PI * 1.75, 50, Color(.77, .48, .34, .28), 1.7, true)
	draw_set_transform(center - Vector2(13, 17), -.5, Vector2(1, .65))
	draw_circle(Vector2.ZERO, 11, Color(1, 1, .98, .68))
	draw_set_transform(Vector2.ZERO)
	if show_face:
		var eyes := Color("6A5149")
		var blink := not reduced_motion and fmod(_time, 6.5) > 6.34
		for offset in [-10.0, 10.0]:
			if blink:
				draw_line(center + Vector2(offset - 2.5, 2), center + Vector2(offset + 2.5, 2), eyes, 2, true)
			else:
				draw_circle(center + Vector2(offset, 1), 2.6, eyes)
		draw_arc(center + Vector2(0, 5), 9, .2, PI - .2, 20, eyes, 1.7, true)
		draw_circle(center + Vector2(-20, 9), 4.5, Color(.94, .54, .56, .22))
		draw_circle(center + Vector2(20, 9), 4.5, Color(.94, .54, .56, .22))

func _pill(color: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	return box
