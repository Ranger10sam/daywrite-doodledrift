class_name LevelWorld
extends Node2D
signal reached_finish
signal checkpoint_reached(at: Vector2)
signal pickup_collected(units: float)
signal player_failed
var definition: Dictionary = {}
var player: QuestBall
var terrain: Array[TerrainBody] = []
var ferries: Array[MovingPlatform] = []
var checkpoints: Array[Vector2] = []
var collected: Dictionary = {}
var active_checkpoint: int = -1
var finish := Vector2.ZERO
var clock: float = 0.0
var drawing: bool = false
var debug: bool = false
var complete: bool = false
var death_lock: bool = false
var reduced_motion: bool = false
var difficulty: String = "normal"
var accent := Color("93dfb3")
var ground_color := Color("264f48")
var trail_points: Array[Vector2] = []
var trail_timer: float = 0.0
var trajectory_hint: bool = false
var gates: Array[Dictionary] = []
var crates: Array[PuzzleCrate] = []
var presentation_draw_usec: int = 0
var _flower_batches_ready: bool = false
var _flower_textures: Array[Texture2D] = []

func configure(data: Dictionary, mode: String) -> void:
	definition = data
	difficulty = mode
	finish = vec(data.finish)
	var biomes: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/biomes/biomes.json"))
	var biome: Dictionary = biomes[int(data.biome)]
	accent = Color(str(biome.accent))
	ground_color = Color(str(biome.terrain))
	# Physical side walls stop the player and loose drawings before camera limits.
	for x in [-24.0, float(data.width) + 24.0]:
		var wall := StaticBody2D.new()
		wall.collision_layer = 1
		wall.collision_mask = 2 | 4
		var shape := RectangleShape2D.new()
		shape.size = Vector2(48, float(data.height) + 2000)
		var collision := CollisionShape2D.new()
		collision.shape = shape
		collision.position = Vector2(x, float(data.height) * 0.5 - 500)
		wall.add_child(collision)
		add_child(wall)
	for item in data.terrain:
		var body := TerrainBody.new()
		body.configure(item, ground_color, accent)
		add_child(body)
		terrain.append(body)
	for item in data.get("gates", []):
		var at := vec(item.gate)
		var gate := TerrainBody.new()
		gate.configure({"points": [[at.x-14,at.y-190],[at.x+14,at.y-190],[at.x+14,at.y],[at.x-14,at.y]], "role":"gate"}, Color("dfa77e"), Color("fff1d3"))
		add_child(gate)
		terrain.append(gate)
		gates.append({"body":gate,"plate":vec(item.plate),"latched":false,"crate_only":bool(item.get("crate_only",false)),"object_id":str(item.get("object_id","")),"latch":bool(item.get("latch",true))})
		# A level cradle keeps a dropped weight on the plate even on icy slopes.
		var cradle := StaticBody2D.new()
		cradle.collision_layer = 1
		cradle.collision_mask = 2 | 4
		var plate_at := vec(item.plate)
		var cradle_shapes := [Rect2(plate_at+Vector2(-42,-3),Vector2(84,8)),Rect2(plate_at+Vector2(-44,-23),Vector2(7,23)),Rect2(plate_at+Vector2(37,-23),Vector2(7,23))]
		if bool(item.get("crate_only",false)):
			# Parcels enter from the left on a flush floor; the far stop parks
			# them on the sensor. A front lip would make delivery impossible.
			cradle_shapes=[Rect2(plate_at+Vector2(-42,0),Vector2(84,8)),Rect2(plate_at+Vector2(37,-28),Vector2(7,28))]
		for geometry in cradle_shapes:
			var collider := CollisionShape2D.new()
			var shape := RectangleShape2D.new()
			shape.size = geometry.size
			collider.shape = shape
			collider.position = geometry.get_center()
			cradle.add_child(collider)
		add_child(cradle)
	for item in data.get("crates", []):
		var crate := PuzzleCrate.new()
		crate.configure(item)
		add_child(crate)
		crates.append(crate)
	for item in data.get("platforms", []):
		var ferry := MovingPlatform.new()
		ferry.configure(item, accent)
		add_child(ferry)
		ferries.append(ferry)
	if mode != "expert":
		for point in data.get("checkpoints", []):
			checkpoints.append(vec(point))
	if mode == "easy" or mode == "zen":
		for point in data.get("easy_checkpoints", []):
			checkpoints.append(vec(point))
		checkpoints.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	_build_flower_batches()
	queue_redraw()

static func vec(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))

func has_terrain_anchor(point: Vector2) -> bool:
	for body in terrain:
		if body.removed: continue
		for i in range(body.polygon.size()):
			if point.distance_to(Geometry2D.get_closest_point_to_segment(point, body.polygon[i], body.polygon[(i + 1) % body.polygon.size()])) <= 22.0:
				return true
	return false

static func rect(value: Array) -> Rect2:
	return Rect2(float(value[0]), float(value[1]), float(value[2]), float(value[3]))

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player) or complete:
		return
	clock += delta
	var at := player.global_position
	for gate in gates:
		var query := PhysicsShapeQueryParameters2D.new()
		var shape := CircleShape2D.new()
		shape.radius = 18
		query.shape = shape
		query.collision_mask = 2 | 4
		query.transform = Transform2D(0, gate.plate + Vector2(0,-8))
		var contacts := get_world_2d().direct_space_state.intersect_shape(query, 16)
		var pressed := false
		for contact in contacts:
			var object: Object = contact.collider
			if not gate.crate_only or (object.get_meta("puzzle_object","")=="crate" and (gate.object_id.is_empty() or object.get_meta("object_id","")==gate.object_id)):
				pressed = true
		if gate.latch and at.x > gate.body.polygon[0].x + 35: gate.latched = true
		var opened: bool = pressed or bool(gate.latched)
		gate.body.set_deferred("collision_layer", 0 if opened else 1)
		gate.body.visible = not opened
		gate.body.removed = opened
	player.wind = Vector2.ZERO
	for zone in definition.get("winds", []):
		if rect(zone.rect).has_point(at):
			player.wind += vec(zone.force)
	if not death_lock:
		var failed_now := at.y > float(definition.height) + 90.0 or at.x < -80.0 or at.x > float(definition.width) + 80.0
		for hazard in definition.get("hazards", []):
			var bounds := rect(hazard.rect)
			# Easy/Zen shrink hazard pressure without changing player physics.
			var modifier := float(PhysicsConfig.difficulty(difficulty).hazard)
			if modifier < 1.0:
				bounds = bounds.grow_individual(-bounds.size.x * (1.0 - modifier) * 0.25, -8.0, -bounds.size.x * (1.0 - modifier) * 0.25, 0.0)
			if bounds.grow(12.0).has_point(at):
				failed_now = true
		# A moving body pinning the ball against terrain is a lethal crush.
		if player.get_colliding_bodies().size() >= 2:
			for ferry in ferries:
				if ferry.motion_velocity.length() > 30.0 and player.get_colliding_bodies().has(ferry) and player.linear_velocity.length() < 8.0:
					if absf(ferry.motion_velocity.y) > 20.0 and at.distance_to(ferry.position) < 35.0:
						failed_now = true
		if failed_now:
			death_lock = true
			player_failed.emit()
			return
	for i in range(checkpoints.size()):
		if i > active_checkpoint and at.distance_to(checkpoints[i]) < 50.0:
			active_checkpoint = i
			checkpoint_reached.emit(checkpoints[i])
			burst_at(checkpoints[i], accent, 18)
			AudioManager.play_sfx("checkpoint")
	for i in range(definition.get("pickups", []).size()):
		if not collected.has(i) and at.distance_to(vec(definition.pickups[i])) < 35.0:
			collected[i] = true
			pickup_collected.emit(25.0)
			burst_at(at, Color("7de1ef"), 12)
	if absf(at.x - finish.x) < 37.0 and absf(at.y - finish.y) < 62.0:
		complete = true
		reached_finish.emit()
	trail_timer += delta
	if trail_timer > 0.04:
		trail_timer = 0.0
		if player.linear_velocity.length() > 240.0 and not reduced_motion:
			trail_points.push_front(at)
		if trail_points.size() > 12:
			trail_points.pop_back()
		elif player.linear_velocity.length() < 200.0 and not trail_points.is_empty():
			trail_points.pop_back()
	queue_redraw()

func reset_checkpoint() -> void:
	for crate in crates: crate.restore()
	for gate in gates: gate.latched = false
	death_lock = false
	collected.clear()
	trail_points.clear()
	for body in terrain:
		body.restore()
	for ferry in ferries:
		ferry.reset()
	queue_redraw()

func burst_at(at: Vector2, tint: Color, count: int = 12) -> void:
	if reduced_motion or get_child_count() > 150:
		return
	var burst := ParticleBurst.new()
	burst.configure(at, tint, count)
	add_child(burst)

func can_build_segment(a: Vector2, b: Vector2, margin: float) -> bool:
	var inside := false
	for area in definition.get("build_regions", []):
		var region := rect(area).grow(-margin)
		if region.has_point(a) and region.has_point(b):
			inside = true
			break
	if not inside or StrokeGeometry.circle_near_segment(finish, 38.0 + margin, a, b):
		return false
	for area in definition.get("no_build_regions", []):
		var forbidden := rect(area).grow(margin)
		for point in [a,b,(a+b)*.5]:
			if forbidden.has_point(point): return false
	for body in terrain:
		if body.removed:
			continue
		var polygon := body.polygon
		for point in [a, (a + b) * 0.5, b]:
			if Geometry2D.is_point_in_polygon(point, polygon):
				return false
		for i in range(polygon.size()):
			var c := polygon[i]
			var d := polygon[(i + 1) % polygon.size()]
			if Geometry2D.segment_intersects_segment(a, b, c, d) != null:
				return false
			# Capsule clearance except exact tangential contact at a terrain lip.
			for point in [a, b, (a + b) * 0.5]:
				if point.distance_to(Geometry2D.get_closest_point_to_segment(point, c, d)) < margin - 0.15:
					return false
	for ferry in ferries:
		var platform_rect := Rect2(ferry.position - ferry.dimensions * 0.5, ferry.dimensions).grow(margin)
		for point in [a, (a + b) * 0.5, b]:
			if platform_rect.has_point(point):
				return false
	return true

func _draw() -> void:
	var draw_started := Time.get_ticks_usec()
	# Cheerful foreground details follow actual bank contours; never obscure gaps.
	if not _flower_batches_ready:
		_draw_flowers_direct()
	for gate in gates:
		var p: Vector2 = gate.plate
		for side in ([40] if gate.crate_only else [-40,40]): draw_circle(p+Vector2(side,-17),5,Color("d2934c"))
		draw_style_box(_region_style(Color("ffc866")),Rect2(p-Vector2(30,7),Vector2(60,9)))
		draw_arc(p+Vector2(0,-21),9,0,TAU,24,Color("fff2c0"),2,true)
		if gate.crate_only:
			draw_rect(Rect2(p+Vector2(-7,-28),Vector2(14,14)),Color("a96c43"),false,2)
			draw_string(ThemeDB.fallback_font,p+Vector2(-5,-32),str(gate.object_id).substr(0,1).to_upper(),HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("74523f"))
	for zone in definition.get("winds", []):
		var bounds := rect(zone.rect)
		draw_style_box(_region_style(Color(accent, 0.025)), bounds)
		var direction := signf(float(zone.force[0]))
		for i in range(12):
			var x := bounds.position.x + fposmod(i * 97.0 + clock * 50.0 * direction, bounds.size.x)
			var y := bounds.position.y + fposmod(i * 67.0, bounds.size.y)
			draw_line(Vector2(x, y), Vector2(x + direction * 25.0, y), Color(accent, 0.22), 1.3, true)
	for hazard in definition.get("hazards", []):
		var bounds := rect(hazard.rect)
		if str(hazard.type) == "spikes":
			var water := Color("83bad1") if int(definition.biome) < 3 else Color("ac91cb")
			draw_rect(bounds,water)
			draw_line(bounds.position,bounds.position+Vector2(bounds.size.x,0),Color("52738d"),3,true)
			for i in range(int(bounds.size.x/30)):
				var p := bounds.position+Vector2(i*30, sin(clock*2+i)*3)
				draw_line(p,p+Vector2(22,0),Color("dbfbf4"),2,true)
		else:
			draw_rect(bounds, Color("e89a89"))
			draw_rect(Rect2(bounds.position, Vector2(bounds.size.x, 6.0)), Color("c66f6c"))
			for i in range(int(bounds.size.x / 50.0)):
				var p := bounds.position + Vector2(i * 50.0 + 10.0, 15.0 + sin(clock + i) * 3.0)
				draw_line(p, p + Vector2(23, 0), Color("ffe3ba"), 2.0, true)
	for i in range(trail_points.size()):
		draw_circle(trail_points[i], 5.0 * (1.0 - float(i) / 12.0), Color(player.effect_color if is_instance_valid(player) else accent, 0.3 * (1.0 - float(i) / 12.0)))
	for i in range(checkpoints.size()):
		var p := checkpoints[i] + Vector2(0, 15)
		var tint := accent if i <= active_checkpoint else Color("8aabb0")
		draw_line(p, p + Vector2(0, -65), tint, 2.5, true)
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -65), p + Vector2(28, -54), p + Vector2(0, -43)]), Color(tint, 0.8))
		if i == active_checkpoint:
			draw_arc(p + Vector2(0, -4), 28, 0, TAU, 32, Color(accent, 0.2), 2, true)
	for i in range(definition.get("pickups", []).size()):
		if not collected.has(i):
			var p := vec(definition.pickups[i]) + Vector2(0, sin(clock * 2 + i) * 3.0 if not reduced_motion else 0.0)
			draw_circle(p, 19.0, Color("7de1ef", 0.08))
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -12), p + Vector2(9, 0), p + Vector2(0, 12), p + Vector2(-9, 0)]), Color("a8f2ef"))
	# The goal is a luminous open ring, visually distinct from all ink shapes.
	draw_circle(finish, 48.0, Color(accent, 0.035))
	draw_circle(finish,32,Color("fff9f0"))
	draw_arc(finish,34,-PI*.48,PI*1.48,64,Color("596479"),5,true)
	draw_arc(finish, 33.0, -PI * 0.48, PI * 1.48, 64, Color(accent, 0.2), 11.0, true)
	draw_arc(finish, 33.0, -PI * 0.48, PI * 1.48, 64, accent, 3.0, true)
	draw_polyline(PackedVector2Array([finish + Vector2(-8, -6), finish + Vector2(1, 0), finish + Vector2(-8, 6)]), Color("344054"), 2.5, true)
	if drawing:
		for area in definition.get("no_build_regions",[]):
			var forbidden := rect(area)
			draw_rect(forbidden,Color("7486ad",.06))
			_dotted_rect(forbidden,Color("91516A",.85))
			for corner in [forbidden.position,Vector2(forbidden.end.x,forbidden.position.y),forbidden.end,Vector2(forbidden.position.x,forbidden.end.y)]:
				draw_line(corner-Vector2(4,4),corner+Vector2(4,4),Color("91516A"),2,true)
				draw_line(corner+Vector2(-4,4),corner+Vector2(4,-4),Color("91516A"),2,true)
		for body in terrain:
			if body.role == "ground":
				for anchor in [body.polygon[0],body.polygon[body.polygon.size()-3]]:
					draw_circle(anchor+Vector2(0,-8),12,Color("ffe7a1",.3))
					draw_circle(anchor+Vector2(0,-8),7,Color("fff1b3"),false,2,true)
		for area in definition.get("build_regions", []):
			var r := rect(area)
			draw_rect(r, Color(accent, 0.025))
			_dotted_rect(r, Color("3F7564", 0.85))
	if trajectory_hint and drawing and is_instance_valid(player):
		# A visual estimate of a jump arc, no hidden assistance to the simulation.
		var velocity := Vector2(player.linear_velocity.x, -PhysicsConfig.number("jump_speed", 470.0))
		for i in range(1, 25):
			var t := float(i) * 0.04
			var point := player.position + velocity * t + Vector2(0, PhysicsConfig.number("gravity", 1100.0) * t * t * 0.5)
			draw_circle(point, 2.0, Color(accent, 0.5 * (1.0 - t)))
	if debug and OS.is_debug_build() and is_instance_valid(player):
		draw_line(player.position, player.position + player.linear_velocity * 0.25, Color.YELLOW, 2.0)
		for normal in player.last_contact_normals:
			draw_line(player.position, player.position + normal * 65.0, Color.MAGENTA, 2.0)
		for region in definition.get("build_regions", []):
			draw_rect(rect(region), Color.CYAN, false, 1.0)
	presentation_draw_usec = Time.get_ticks_usec() - draw_started

func _build_flower_batches() -> void:
	# Exact existing decoration positions/colors, grouped into two sprite batches.
	# No collision, gameplay node or terrain contour is replaced by this cache.
	var locations: Array[PackedVector2Array] = [PackedVector2Array(),PackedVector2Array()]
	for body in terrain:
		if body.role != "ground": continue
		var top := body.polygon.slice(0,body.polygon.size()-2)
		for i in range(1,top.size()):
			var a := top[i-1]
			var b := top[i]
			var count := int(a.distance_to(b)/65.0)
			for j in range(count):
				locations[j%2].append(a.lerp(b,(float(j)+.5)/maxf(1,count)))
	var quad := QuadMesh.new()
	quad.size = Vector2(20,28)
	for group in range(2):
		var petal_color := "#FFDFAD" if group == 0 else "#F5B3C5"
		var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="20" height="28" viewBox="-10 -26 20 28"><path d="M0 0V-15" stroke="#72A48B" stroke-width="2"/>'
		for petal in range(5):
			var at := Vector2(0,-17)+Vector2.from_angle(petal*TAU/5.0)*4
			svg += '<circle cx="%.5f" cy="%.5f" r="3.3" fill="%s"/>' % [at.x,at.y,petal_color]
		svg += '<circle cx="0" cy="-17" r="2.7" fill="#FFF7D1"/></svg>'
		var image := Image.new()
		if image.load_svg_from_string(svg,2.0) != OK:
			return
		var texture := ImageTexture.create_from_image(image)
		_flower_textures.append(texture)
		if locations[group].is_empty(): continue
		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_2D
		batch.mesh = quad
		batch.instance_count = locations[group].size()
		for i in range(locations[group].size()):
			# QuadMesh's 3D UV vertical convention is opposite CanvasItem images.
			batch.set_instance_transform_2d(i,Transform2D(Vector2.RIGHT,Vector2.UP,locations[group][i]+Vector2(0,-12)))
		var visual := MultiMeshInstance2D.new()
		visual.name = "FlowerBatch%d"%group
		visual.multimesh = batch
		visual.texture = texture
		add_child(visual)
		move_child(visual,0)
	_flower_batches_ready = true

func _draw_flowers_direct() -> void:
	# Fallback for a custom export without runtime SVG support.
	var view_start := get_canvas_transform().affine_inverse() * Vector2.ZERO
	var view_end := get_canvas_transform().affine_inverse() * get_viewport_rect().size
	for body in terrain:
		if body.role != "ground": continue
		var top := body.polygon.slice(0,body.polygon.size()-2)
		for i in range(1,top.size()):
			var a := top[i-1]
			var b := top[i]
			for j in range(int(a.distance_to(b)/65.0)):
				var p := a.lerp(b,(float(j)+.5)/maxf(1,int(a.distance_to(b)/65.0)))
				if p.x < view_start.x-100 or p.x > view_end.x+100: continue
				draw_line(p,p+Vector2(0,-15),Color("72a48b"),2,true)
				for petal in range(5):
					draw_circle(p+Vector2(0,-17)+Vector2.from_angle(petal*TAU/5)*4,3.3,Color("ffdfad") if j%2==0 else Color("f5b3c5"))
				draw_circle(p+Vector2(0,-17),2.7,Color("fff7d1"))

func _dotted_rect(r: Rect2, tint: Color) -> void:
	for y in [r.position.y, r.end.y]:
		var x := r.position.x
		while x < r.end.x:
			draw_line(Vector2(x, y), Vector2(minf(x + 7, r.end.x), y), tint, 2.0)
			x += 18.0
	for x in [r.position.x, r.end.x]:
		var y := r.position.y
		while y < r.end.y:
			draw_line(Vector2(x, y), Vector2(x, minf(y + 7, r.end.y)), tint, 2.0)
			y += 18.0

func _region_style(tint: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = tint
	style.set_corner_radius_all(12)
	return style
