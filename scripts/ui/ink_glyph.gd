class_name InkGlyph
extends Control

var kind: String = "solid"
var tint: Color = Color("b8e8db")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.36
	match kind:
		"solid":
			draw_line(c + Vector2(-r, 0), c + Vector2(r, 0), tint, 4.0, true)
			draw_circle(c + Vector2(-r, 0), 2, tint)
			draw_circle(c + Vector2(r, 0), 2, tint)
		"bounce":
			var pts := PackedVector2Array([c + Vector2(-r, r * .5), c + Vector2(-r * .5, -r * .4), c + Vector2(0, r * .5), c + Vector2(r * .5, -r * .4), c + Vector2(r, r * .5)])
			draw_polyline(pts, tint, 3, true)
		"boost":
			for x in [-r * .4, r * .4]:
				draw_polyline(PackedVector2Array([c + Vector2(x - r * .4, -r * .6), c + Vector2(x + r * .2, 0), c + Vector2(x - r * .4, r * .6)]), tint, 3, true)
		"ice":
			for angle in [0.0, PI / 3.0, PI * 2.0 / 3.0]:
				var v := Vector2.from_angle(angle) * r
				draw_line(c - v, c + v, tint, 2.4, true)
		"fragile":
			draw_polyline(PackedVector2Array([c + Vector2(-r, r * .5), c + Vector2(-r * .2, 0), c + Vector2(-r * .4, -r * .5), c + Vector2(r * .3, -r * .1), c + Vector2(r, -r * .6)]), tint, 3, true)
		"left", "right":
			var direction := -1.0 if kind == "left" else 1.0
			draw_polyline(PackedVector2Array([c + Vector2(-r * .3 * direction, -r * .6), c + Vector2(r * .4 * direction, 0), c + Vector2(-r * .3 * direction, r * .6)]), tint, 4, true)
		"jump":
			draw_polyline(PackedVector2Array([c + Vector2(-r * .65, r * .1), c + Vector2(0, -r * .55), c + Vector2(r * .65, r * .1)]), tint, 4, true)
			draw_line(c + Vector2(0, -r * .45), c + Vector2(0, r * .65), tint, 4, true)
		"brake":
			draw_line(c + Vector2(-r * .35, -r * .55), c + Vector2(-r * .35, r * .55), tint, 4, true)
			draw_line(c + Vector2(r * .35, -r * .55), c + Vector2(r * .35, r * .55), tint, 4, true)
		"pause":
			draw_line(c + Vector2(-r * .35, -r * .55), c + Vector2(-r * .35, r * .55), tint, 3, true)
			draw_line(c + Vector2(r * .35, -r * .55), c + Vector2(r * .35, r * .55), tint, 3, true)
		"quest":
			draw_arc(c, r, -PI * .85, PI * .7, 48, tint, 5, true)
			draw_line(c + Vector2(r * .36, r * .34), c + Vector2(r * .9, r * .85), tint, 5, true)
			draw_circle(c + Vector2(-r * .2, -r * .13), r * .14, tint)
