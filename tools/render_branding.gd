extends SceneTree
## Renders the actual bundled Fredoka/Nunito fonts into the native boot PNG.
## No SVG text support, installed system fonts or third-party artwork is needed.

class SplashCanvas:
	extends Node2D
	var title_font: FontVariation
	var body_font: FontVariation
	func _ready() -> void:
		title_font = FontVariation.new()
		title_font.base_font = load("res://assets/fonts/Fredoka-Variable.ttf")
		title_font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 600.0}
		body_font = FontVariation.new()
		body_font.base_font = load("res://assets/fonts/Nunito-Variable.ttf")
		body_font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 600.0}
		queue_redraw()
	func _curve(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> PackedVector2Array:
		var result := PackedVector2Array()
		for i in range(21):
			var t := float(i)/20.0
			var s := 1.0-t
			result.append(s*s*s*a+3*s*s*t*b+3*s*t*t*c+t*t*t*d)
		return result
	func _draw() -> void:
		draw_rect(Rect2(0,0,960,540),Color("FFF9F0"))
		draw_circle(Vector2(182,111),110,Color("A8DFC8",.12))
		draw_circle(Vector2(805,422),145,Color("C5AFF1",.10))
		var curves: Array[PackedVector2Array] = [
			_curve(Vector2(315,258),Vector2(350,262),Vector2(376,251),Vector2(405,231)),
			_curve(Vector2(405,231),Vector2(442,212),Vector2(456,220),Vector2(480,233)),
			_curve(Vector2(480,233),Vector2(511,251),Vector2(523,259),Vector2(548,245)),
			_curve(Vector2(548,245),Vector2(589,220),Vector2(589,220),Vector2(613,220)),
			_curve(Vector2(613,220),Vector2(622,219),Vector2(629,215),Vector2(637,213))]
		var colors := [Color("A8DFC8"),Color("C5AFF1"),Color("FFCAA6"),Color("B7DFFF"),Color("F5B3C5")]
		for i in range(curves.size()):
			draw_set_transform(Vector2(0,3))
			draw_polyline(curves[i],Color("344054",.06),16,true)
			draw_set_transform(Vector2.ZERO)
			draw_polyline(curves[i],colors[i],11,true)
			draw_circle(curves[i][0],5.5,colors[i])
			draw_circle(curves[i][-1],5.5,colors[i])
		var at := Vector2(480,164)
		draw_circle(at+Vector2(0,1),47.5,Color("D8B095"))
		for radius in range(47,0,-1):
			var light := 1.0-float(radius)/47.0
			draw_circle(at+Vector2(-8,-11)*light,float(radius),Color("FFCAA6").lerp(Color("FFF9F0"),light*.76))
		draw_arc(at+Vector2(-1,-1),41,PI*1.1,PI*1.68,28,Color("FFF9F0",.8),3,true)
		draw_circle(at+Vector2(-11,0),3.5,Color("344054"))
		draw_circle(at+Vector2(12,0),3.5,Color("344054"))
		draw_circle(at+Vector2(-22,12),4.8,Color("F5B3C5",.65))
		draw_circle(at+Vector2(23,12),4.8,Color("F5B3C5",.65))
		draw_arc(at+Vector2(.5,9),8,.12,PI-.12,18,Color("344054"),2.7,true)
		for point in [Vector2(372,149),Vector2(590,170)]:
			draw_line(point-Vector2(4,0),point+Vector2(4,0),Color("C5AFF1"),2,true)
			draw_line(point-Vector2(0,4),point+Vector2(0,4),Color("C5AFF1"),2,true)
		var title := "DoodleDrift"
		var subtitle := "A little adventure by Daywrite"
		var title_width := title_font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,86).x
		var body_width := body_font.get_string_size(subtitle,HORIZONTAL_ALIGNMENT_LEFT,-1,24).x
		draw_string(title_font,Vector2((960-title_width)*.5,372),title,HORIZONTAL_ALIGNMENT_LEFT,-1,86,Color("344054"))
		draw_string(body_font,Vector2((960-body_width)*.5,424),subtitle,HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("657080"))

func _initialize() -> void:
	call_deferred("render")

func render() -> void:
	root.size = Vector2i(960,540)
	root.content_scale_size = Vector2i(960,540)
	root.add_child(SplashCanvas.new())
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(image.get_width()==960 and image.get_height()==540)
	assert(image.save_png("res://assets/splash.png")==OK)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/screenshots"))
	assert(image.save_png("res://docs/screenshots/doodledrift-splash.png")==OK)
	var icon: Texture2D = load("res://assets/icon.svg")
	assert(icon.get_image().save_png("res://docs/screenshots/doodledrift-icon.png")==OK)
	print("DOODLEDRIFT_SPLASH_PASS: native960x540 Fredoka600/Nunito600 with exact brand/subtitle")
	var audio: Variant = root.get_node("AudioManager")
	await audio.prepare_shutdown()
	quit(0)
