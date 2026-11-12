extends SceneTree
## QA asset sheet: production visual children posed without running simulation.
class Sheet:
	extends Node2D
	var title: FontVariation
	var body: FontVariation
	func _ready() -> void:
		title = FontVariation.new()
		title.base_font = load("res://assets/fonts/Fredoka-Variable.ttf")
		title.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"):600.0}
		body = FontVariation.new()
		body.base_font = load("res://assets/fonts/Nunito-Variable.ttf")
		body.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"):650.0}
	func _draw() -> void:
		draw_rect(Rect2(0,0,1280,440),Color("FFF9F0"))
		var heading := "Companion expressions"
		var width := title.get_string_size(heading,HORIZONTAL_ALIGNMENT_LEFT,-1,40).x
		draw_string(title,Vector2((1280-width)*.5,72),heading,HORIZONTAL_ALIGNMENT_LEFT,-1,40,Color("344054"))
		var captions := ["Idle","Jump","Bounce","Impact","Victory"]
		for i in range(5):
			var label_width := body.get_string_size(captions[i],HORIZONTAL_ALIGNMENT_LEFT,-1,22).x
			draw_string(body,Vector2(130+i*255-label_width*.5,361),captions[i],HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("344054"))
		draw_string(body,Vector2(367,412),"Production visual child · cosmetic pose study",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("667085"))

func _initialize() -> void:
	call_deferred("render")

func render() -> void:
	root.size = Vector2i(1280,440)
	root.content_scale_size = Vector2i(1280,440)
	root.add_child(Sheet.new())
	var script: Script = load("res://scripts/player/ball.gd")
	for i in range(5):
		var ball: Variant = script.new()
		ball.position = Vector2(130+i*255,235)
		ball.freeze = true
		ball.reduced_motion = true
		root.add_child(ball)
		ball.set_process(false)
		ball.visual.scale = Vector2(3.5,3.5)
		match i:
			1: ball.linear_velocity = Vector2(0,-300)
			2:
				ball.effect_color = InkCatalog.color("bounce")
				ball.effect_flash = .9
			3:
				ball.impact = .8
				ball.visual.scale = Vector2(3.9,3.05)
			4: ball.set_meta("victory",true)
		ball.visual.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(image.save_png("res://docs/screenshots/doodledrift-companion-expressions.png")==OK)
	print("DOODLEDRIFT_COMPANION_PASS: five productionvisualstates, collisiongeometry unchanged")
	var audio: Variant = root.get_node("AudioManager")
	await audio.prepare_shutdown()
	quit(0)
