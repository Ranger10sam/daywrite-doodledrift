class_name BiomeBackground
extends Node2D
## Paper-cut scenery. Presentation only: camera samples affect distant parallax,
## never world geometry or collision transforms.

const PALETTES := [
	[Color("E8F5EE"), Color("FFF9F0"), Color("DDECDD"), Color("CBE1D1"), Color("B9D3C1"), Color("FFE0B7")],
	[Color("E1EFF9"), Color("FFF9F0"), Color("DDEAF2"), Color("C6DDE9"), Color("B2CDDE"), Color("FFF0CF")],
	[Color("F8E9DA"), Color("FFF9F0"), Color("F0DDC6"), Color("E6CEB5"), Color("D8BFA6"), Color("FFE2B7")],
	[Color("EEE6F8"), Color("FAF2F3"), Color("E2D5EF"), Color("D4C4E5"), Color("C3B0D5"), Color("FFF0D8")],
	[Color("F5E0E6"), Color("FFEEDF"), Color("E6CDD8"), Color("D8BCCB"), Color("C5A9BB"), Color("FFD2B0")]
]

var _biome := 0
var _camera := Vector2.ZERO
var _time := 0.0
var _reduced := false
var _motions: Array[Vector3] = []
var presentation_draw_usec: int = 0
var _cloud_texture: Texture2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var rng := RandomNumberGenerator.new()
	rng.seed = 612871
	for index in range(28):
		_motions.append(Vector3(rng.randf(), rng.randf(), rng.randf_range(.3, 1)))
	_build_cloud_texture()
	get_viewport().size_changed.connect(queue_redraw)
	queue_redraw()

func set_biome(index: int) -> void:
	_biome = clampi(index, 0, 4)
	queue_redraw()

func set_camera(camera_pos: Vector2) -> void:
	if not _camera.is_equal_approx(camera_pos):
		_camera = camera_pos
		queue_redraw()

func set_reduced_motion(enabled: bool) -> void:
	_reduced = enabled
	queue_redraw()

func _process(delta: float) -> void:
	if not _reduced:
		_time += minf(delta, .1)
		queue_redraw()

func _parallax(factor: float) -> float:
	return 0.0 if _reduced else _camera.x * factor

func _draw() -> void:
	var draw_started := Time.get_ticks_usec()
	var size := get_viewport_rect().size
	if size.x < 1.0 or size.y < 1.0:
		return
	var palette: Array = PALETTES[_biome]
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]), PackedColorArray([palette[0], palette[0], palette[1], palette[1]]))
	var sun := Vector2(size.x * .78 - fposmod(_parallax(.012), size.x * .12), size.y * .21)
	var sunlight: Color = palette[5]
	draw_circle(sun, 71, Color(sunlight, .16))
	draw_circle(sun, 55, Color(sunlight, .24))
	draw_circle(sun, 36, sunlight)
	draw_arc(sun + Vector2(-3, -3), 28, PI * 1.12, PI * 1.69, 24, Color("FFF9F0", .65), 2, true)
	for i in range(6):
		var drift := 0.0 if _reduced else _time * (3.0 + fmod(i * 7.0, 3.0))
		var x := fposmod(i * 257.0 + 40.0 - _parallax(.026) + drift, size.x + 250.0) - 100.0
		var y := size.y * (.13 + fmod(i * .073, .21))
		_cloud(Vector2(x, y), .72 + fmod(i * .19, .4))
	if _biome in [1, 2, 4]:
		_mountains(size, palette)
	for layer_index in range(3):
		_hills(size, layer_index, palette[2 + layer_index])
	match _biome:
		0: _meadow(size)
		2: _desert_plants(size)
		3: _crystals(size)
		4: _warm_stones(size)
	_ambient(size)
	draw_polygon(PackedVector2Array([Vector2(0, size.y * .40), Vector2(size.x, size.y * .40), Vector2(size.x, size.y * .58), Vector2(0, size.y * .58)]), PackedColorArray([Color(palette[1], .0), Color(palette[1], .0), Color(palette[1], .13), Color(palette[1], .13)]))
	presentation_draw_usec = Time.get_ticks_usec() - draw_started

func _cloud(at: Vector2, factor: float) -> void:
	if _cloud_texture != null:
		draw_texture_rect(_cloud_texture, Rect2(at + Vector2(-65,-42)*factor,Vector2(130,80)*factor),false)
		return
	var shade := Color("CCD6DE", .10)
	var cream := Color("FFFEF8", .80)
	for i in range(4):
		var p := at + Vector2((i - 1.5) * 25.0, -sin(float(i) / 3.0 * PI) * 13.0) * factor
		var radius := (21.0 + sin(float(i) / 3.0 * PI) * 5.0) * factor
		draw_circle(p + Vector2(0, 3) * factor, radius, shade)
		draw_circle(p, radius, cream)

func _build_cloud_texture() -> void:
	# Cache the same eight translucent puffs once. Drawing a moving cloud now
	# submits a single quad rather than rebuilding/tessellating eight circles.
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="130" height="80" viewBox="-65 -42 130 80">'
	for i in range(4):
		var x := (float(i)-1.5)*25.0
		var y := -sin(float(i)/3.0*PI)*13.0
		var radius := 21.0+sin(float(i)/3.0*PI)*5.0
		svg += '<circle cx="%.5f" cy="%.5f" r="%.5f" fill="#CCD6DE" opacity=".1"/>' % [x,y+3.0,radius]
		svg += '<circle cx="%.5f" cy="%.5f" r="%.5f" fill="#FFFEF8" opacity=".8"/>' % [x,y,radius]
	svg += '</svg>'
	var image := Image.new()
	if image.load_svg_from_string(svg,2.0) == OK:
		_cloud_texture = ImageTexture.create_from_image(image)

func _hills(size: Vector2, layer_index: int, color: Color) -> void:
	var points := PackedVector2Array([Vector2(-10, size.y + 10)])
	var ridge := PackedVector2Array()
	var fraction := float(layer_index)
	var camera_x := _parallax(.020 + fraction * .024)
	var camera_y := 0.0 if _reduced else _camera.y * (.008 + fraction * .009)
	var base_y := size.y * (.57 + fraction * .12) - camera_y
	for index in range(43):
		var x := float(index) / 42.0 * (size.x + 20) - 10
		var world_x := x + camera_x
		var y := base_y + sin(world_x * (.0037 + fraction * .0007) + fraction * 2.2) * (29 + fraction * 12) + sin(world_x * .0085 + fraction * 4.6) * 8
		var point := Vector2(x, y)
		points.append(point)
		ridge.append(point)
	points.append(size + Vector2(10, 10))
	draw_colored_polygon(points, color)
	draw_polyline(ridge, Color("FFF9F0", .26), 2, true)

func _mountains(size: Vector2, palette: Array) -> void:
	var spacing := 260.0
	var offset := fposmod(_parallax(.020), spacing)
	for index in range(-1, ceili(size.x / spacing) + 2):
		var x := index * spacing - offset
		var peak := Vector2(x + 115, size.y * (.30 + sin(index * 1.9) * .045))
		var left := Vector2(x - 110, size.y * .69)
		var right := Vector2(x + 360, size.y * .69)
		var shoulder_left := peak.lerp(left, .18) + Vector2(0, -3)
		var shoulder_right := peak.lerp(right, .16) + Vector2(0, -2)
		draw_colored_polygon(PackedVector2Array([left, shoulder_left, peak + Vector2(-4, 0), peak + Vector2(6, 0), shoulder_right, right]), Color(palette[2]).lightened(.04))
		draw_colored_polygon(PackedVector2Array([peak + Vector2(6, 0), shoulder_right, right, peak + Vector2(72, size.y * .39)]), Color(palette[2]).darkened(.035))
		if _biome == 1:
			var snow_left := peak.lerp(left, .23)
			var snow_right := peak.lerp(right, .23)
			var height := left.y - peak.y
			draw_colored_polygon(PackedVector2Array([peak + Vector2(-4, 0), peak + Vector2(6, 0), snow_right, snow_right.lerp(snow_left, .36) - Vector2(0, height * .045), snow_right.lerp(snow_left, .65) - Vector2(0, height * .025), snow_left]), Color("FFFEFA", .85))
		elif _biome == 4:
			draw_arc(peak + Vector2(2, 8), 11, .06, PI - .06, 18, Color("F5B3C5", .75), 5, true)
			draw_polyline(PackedVector2Array([peak + Vector2(3, 18), peak + Vector2(16, 43), peak + Vector2(10, 64), peak + Vector2(25, 89)]), Color("FFC6AA", .56), 4, true)

func _meadow(size: Vector2) -> void:
	var offset := fposmod(_parallax(.055), 220.0)
	for index in range(-1, ceili(size.x / 220.0) + 2):
		var x := index * 220.0 - offset
		var y := size.y * .84 + sin(x * .0034) * 22
		var factor := .65 + absf(sin(index * 11.1)) * .33
		var trunk := Color("93B7A1", .65)
		draw_line(Vector2(x, y + 17), Vector2(x, y - 28 * factor), trunk, 4, true)
		draw_circle(Vector2(x - 12 * factor, y - 28 * factor), 24 * factor, Color("A8CDB5", .8))
		draw_circle(Vector2(x + 12 * factor, y - 39 * factor), 29 * factor, Color("B2D8BF", .85))
		draw_circle(Vector2(x - 2 * factor, y - 52 * factor), 18 * factor, Color("C0E0C8", .7))
		var flower := Vector2(x + 61, y + 31)
		draw_line(flower, flower + Vector2(0, -12), Color("8EB79E", .7), 1.5, true)
		for petal in range(5):
			draw_circle(flower + Vector2(0, -15) + Vector2.from_angle(petal * TAU / 5.0) * 3.0, 2.8, Color("FFF9F0", .9))
		draw_circle(flower + Vector2(0, -15), 2.2, Color("E8C78F", .8))

func _desert_plants(size: Vector2) -> void:
	var offset := fposmod(_parallax(.048), 270.0)
	for index in range(-1, ceili(size.x / 270.0) + 2):
		var at := Vector2(index * 270.0 + 50 - offset, size.y * .88 + sin(index * 3.0) * 16)
		var color := Color("B3C8AC", .72)
		draw_line(at, at + Vector2(0, -33), color, 8, true)
		draw_circle(at + Vector2(0, -33), 4, color)
		draw_polyline(PackedVector2Array([at + Vector2(0, -12), at + Vector2(-14, -12), at + Vector2(-14, -23)]), color, 6, true)
		draw_circle(at + Vector2(-14, -23), 3, color)
		draw_polyline(PackedVector2Array([at + Vector2(0, -21), at + Vector2(12, -21), at + Vector2(12, -31)]), color, 5, true)
		draw_circle(at + Vector2(12, -31), 2.5, color)

func _crystals(size: Vector2) -> void:
	var offset := fposmod(_parallax(.045), 220.0)
	for index in range(-1, ceili(size.x / 220.0) + 2):
		var x := index * 220.0 + 20 - offset
		var y := size.y * .87 + sin(index * 2.1) * 22
		var height := 44.0 + absf(sin(index * 8.1)) * 44
		var crystal := PackedVector2Array([Vector2(x - 18, y), Vector2(x - 20, y - height * .65), Vector2(x - 4, y - height), Vector2(x + 14, y - height * .68), Vector2(x + 18, y)])
		draw_colored_polygon(crystal, Color("B49DCB", .65))
		draw_colored_polygon(PackedVector2Array([Vector2(x - 4, y - height), Vector2(x + 14, y - height * .68), Vector2(x + 18, y), Vector2(x + 1, y)]), Color("C5AFF1", .72))
		draw_line(Vector2(x - 5, y - height + 9), Vector2(x - 7, y - 12), Color("FFF9F0", .55), 2, true)
		draw_circle(Vector2(x + 33, y - 14), 2.2, Color("FFF9F0", .72))

func _warm_stones(size: Vector2) -> void:
	var offset := fposmod(_parallax(.048), 190.0)
	for index in range(-1, ceili(size.x / 190.0) + 2):
		var at := Vector2(index * 190.0 + 23 - offset, size.y * .91 + sin(index * 1.8) * 12)
		draw_set_transform(at, 0, Vector2(1.8, .65))
		draw_circle(Vector2.ZERO, 15 + fmod(index * 9.0, 7.0), Color("B79CB0", .55))
		draw_set_transform(Vector2.ZERO)

func _ambient(size: Vector2) -> void:
	for point in _motions:
		var speed := point.z
		var x := point.x * size.x
		var y := point.y * size.y
		if not _reduced:
			x = fposmod(x + _time * (5 if _biome != 2 else 22) * speed - _parallax(.014), size.x)
			y = fposmod(y + _time * (9 if _biome == 1 else -4) * speed, size.y)
		var opacity := .12 + speed * .13
		if _biome == 1:
			draw_circle(Vector2(x, y), 1 + speed * 1.5, Color("FFFEFA", opacity * 1.8))
		elif _biome == 2:
			draw_line(Vector2(x, y), Vector2(x + 8 + speed * 11, y - 1), Color("C7AD92", opacity * .65), 1, true)
		elif _biome == 4:
			draw_circle(Vector2(x, y), .8 + speed, Color("FFF0D8", opacity))
		else:
			draw_circle(Vector2(x, y), .7 + speed, Color("FFFDF6", opacity * 1.4))
