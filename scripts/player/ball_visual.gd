extends Node2D
## All squash, highlights and expressions belong to this visual child. The
## parent's circular collision shape remains unchanged.

func _draw() -> void:
	var ball := get_parent() as QuestBall
	if ball == null:
		return
	var cream := Color("FFF9F0")
	var peach := Color("FFCAA6")
	var ink := Color("344054")
	var tint := peach.lerp(ball.effect_color, clampf(ball.effect_flash * .34, 0, .34))
	var victory := bool(ball.get_meta("victory", false))
	draw_circle(Vector2.ZERO, 28, Color(tint, .055))
	draw_circle(Vector2.ZERO, 23, Color(tint, .095))
	draw_set_transform(Vector2(1, 20), 0, Vector2(1.05, .18))
	draw_circle(Vector2.ZERO, 15, Color("8C7C77", .14))
	draw_set_transform(Vector2.ZERO)
	draw_circle(Vector2(0, .6), 18.5, Color("C49880"))
	for i in range(18, 0, -1):
		var light := 1.0 - float(i) / 18.0
		draw_circle(Vector2(-3.2, -4.5) * light, float(i), tint.lerp(cream, light * .76))
	draw_arc(Vector2(-.6, -.6), 15.7, PI * 1.10, PI * 1.68, 22, Color(cream, .84), 1.8, true)
	draw_set_transform(Vector2(-6.0, -9.5), -.5, Vector2(1.6, .7))
	draw_circle(Vector2.ZERO, 2.3, Color("FFFFFF", .53))
	draw_set_transform(Vector2.ZERO)
	# A little embroidered freckle rotates while the face stays upright.
	var seam := Vector2.from_angle(ball.rotation + .7) * 13.4
	draw_circle(seam, 1.6, Color("D3A38A", .65))
	if not ball.facial_expression:
		return
	var look := clampf(ball.linear_velocity.x / 330.0, -1.4, 1.4)
	var face := Vector2(look, .5)
	draw_circle(face + Vector2(-9, 4), 2.6, Color("F5B3C5", .64))
	draw_circle(face + Vector2(9, 4), 2.6, Color("F5B3C5", .64))
	var rising := ball.linear_velocity.y < -180.0
	var spring := ball.effect_flash > .2 and ball.effect_color.is_equal_approx(InkCatalog.color("bounce"))
	var blink := not ball.reduced_motion and fmod(float(Time.get_ticks_msec()) / 1000.0, 5.2) > 5.04
	if victory or spring:
		for x in [-5.1, 5.1]:
			draw_polyline(PackedVector2Array([face + Vector2(x - 2.2, -.1), face + Vector2(x, -2), face + Vector2(x + 2.2, -.1)]), ink, 1.6, true)
	elif blink or ball.impact > .58:
		draw_line(face + Vector2(-7, -.5), face + Vector2(-3, -.5), ink, 1.5, true)
		draw_line(face + Vector2(3, -.5), face + Vector2(7, -.5), ink, 1.5, true)
	else:
		for x in [-5, 5]:
			draw_set_transform(face + Vector2(x, -1), 0, Vector2(1, 1.25 if rising else 1.1))
			draw_circle(Vector2.ZERO, 1.7, ink)
			draw_circle(Vector2(-.4, -.5), .5, Color(cream, .9))
			draw_set_transform(Vector2.ZERO)
	if rising or victory or spring:
		draw_set_transform(face + Vector2(0, 5), 0, Vector2(1, 1.15 if victory else 1))
		draw_circle(Vector2.ZERO, 3.0 if victory else 2.6, ink)
		draw_arc(Vector2(0, .4), 1.9, .15, PI - .15, 10, Color("F5B3C5"), 1.2, true)
		draw_set_transform(Vector2.ZERO)
	else:
		draw_arc(face + Vector2(0, 2.6), 3.7, .15, PI - .15, 14, ink, 1.3, true)
	if victory:
		var twinkle := 1.0 if ball.reduced_motion else .86 + sin(float(Time.get_ticks_msec()) * .004) * .14
		for at in [Vector2(-24, -14), Vector2(23, -19), Vector2(24, 10)]:
			draw_line(at + Vector2(-2.5, 0), at + Vector2(2.5, 0), Color("C5AFF1", twinkle), 1.5, true)
			draw_line(at + Vector2(0, -2.5), at + Vector2(0, 2.5), Color("C5AFF1", twinkle), 1.5, true)
