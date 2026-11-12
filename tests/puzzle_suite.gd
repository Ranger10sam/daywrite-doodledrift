extends SceneTree
var failures := 0
var checks := 0
var levels: Array
var world: Variant
var ball: Variant
var drawing: Variant
func _initialize() -> void: call_deferred("run")
func ticks(n: int) -> void:
	for i in range(n): await physics_frame
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1
	print("PASS " if ok else "FAIL ",label)
func setup(id: int) -> void:
	if is_instance_valid(world): world.queue_free()
	if is_instance_valid(drawing): drawing.queue_free()
	await process_frame
	world=load("res://scripts/level/level_world.gd").new(); world.configure(levels[id-1],"normal"); root.add_child(world)
	ball=load("res://scripts/player/ball.gd").new(); ball.position=Vector2(levels[id-1].start[0],levels[id-1].start[1]); world.add_child(ball); world.player=ball
	drawing=load("res://scripts/ink/drawing_controller.gd").new(); drawing.player=ball; drawing.level_world=world; root.add_child(drawing)
	drawing.reservoir.configure(100,5)
func place(ink: String, a: Vector2,b: Vector2) -> bool:
	drawing.selected_ink=ink
	if not drawing.begin_stroke(a): return false
	drawing.accept_to(b); drawing.finish_stroke()
	return not drawing.strokes.is_empty()
func drive(frames: int) -> bool:
	var minimum := 9999.0
	var apex := Vector2.ZERO
	for i in range(frames):
		ball.axis=1
		await physics_frame
		if ball.position.y<minimum: minimum=ball.position.y; apex=ball.position
		if world.complete or world.death_lock: break
	print("drive final ",ball.position," apex ",apex)
	return world.complete
func run() -> void:
	levels=JSON.parse_string(FileAccess.get_file_as_string("res://data/levels/campaign.json"))
	await setup(1); place("solid",Vector2(500,612),Vector2(610,612))
	check(not await drive(500),"Solid pad cannot reach the elevated spring garden")
	await setup(1); check(place("bounce",Vector2(500,612),Vector2(610,612)),"Bounce launch pad accepted by real drawing validator")
	check(await drive(500),"Bounce pad reaches actual elevated goal")
	await setup(2); place("solid",Vector2(350,612),Vector2(1450,612))
	check(not await drive(700),"Solid cannot overcome headwind")
	await setup(2); place("boost",Vector2(350,612),Vector2(1450,612))
	check(await drive(700),"forward Boost reaches actual goal against headwind")
	await setup(3)
	check(not place("solid",Vector2(410,550),Vector2(1000,490)),"moving-island channel rejects a generic bridge")
	var initial: Vector2=world.ferries[0].position; await ticks(90)
	check(world.ferries[0].position.distance_to(initial)>60,"floating island really moves under fixed-step physics")
	await setup(4)
	ball.respawn(Vector2(1030,575)); await ticks(30)
	check(not world.gates[0].body.removed,"ball cannot substitute for the crate key")
	ball.respawn(Vector2(140,575)); await ticks(3)
	world.crates[0].reset_at(Vector2(1030,575)); await ticks(40)
	print("crate key ",world.crates[0].position)
	check(world.gates[0].body.removed,"correct physical crate opens its matching gate")
	await setup(4)
	for i in range(1100):
		ball.axis=1
		if ball.grounded and ball.position.x>960 and ball.linear_velocity.x<80: ball.request_jump()
		await physics_frame
		if world.complete or world.death_lock: break
	print("delivery final ball ",ball.position," crate ",world.crates[0].position," gate ",world.gates[0].body.removed)
	check(world.complete,"push the parcel, hop over it and finish Special Delivery using actual controls")
	await setup(5)
	check(not place("solid",Vector2(480,572),Vector2(840,572)),"Fragile tutorial rejects ink outside its visible supply")
	check(place("fragile",Vector2(480,572),Vector2(840,572)),"Fragile bridge fits the low roof and legal build zone")
	check(await drive(500),"Fragile bridge completes low-roof puzzle before collapsing")
	await setup(6); place("ice",Vector2(558,342),Vector2(1100,590)); await ticks(600)
	print("Ice crate ",world.crates[0].position, " stroke ",drawing.strokes.size())
	check(world.crates[0].position.x>1000,"cargo slides down Ice chute to receiving area")
	check(world.gates[0].body.removed,"Ice cargo activates actual receiving switch")
	check(await drive(700),"Ice cargo unlocks a reachable player route through the final goal")
	await setup(6); place("solid",Vector2(558,342),Vector2(1100,590)); await ticks(600)
	check(world.crates[0].position.x<1000,"grippy Solid chute does not substitute for Ice")
	await setup(7)
	place("solid",Vector2(648,330),Vector2(800,590))
	place("solid",Vector2(948,330),Vector2(1100,590))
	await ticks(600)
	print("parcel routing ",world.crates[0].position," / ",world.crates[1].position," strokes ",drawing.strokes.size()," ",drawing.last_warning)
	check(world.gates[0].body.removed and world.gates[1].body.removed,"two actual chutes deliver both labelled parcels to their own switches")
	check(await drive(800),"both parcel doors lead to the actual goal")
	var starts_safe := 0
	for id in range(1,51):
		await setup(id); await ticks(20)
		if not world.death_lock and is_instance_valid(ball) and ball.position.y<float(world.definition.height): starts_safe+=1
	check(starts_safe==50,"all 50 revised puzzle sessions load with safe starts")
	if is_instance_valid(drawing): drawing.queue_free()
	if is_instance_valid(world): world.queue_free()
	await process_frame
	print("PUZZLES: ",checks," checks, ",failures," failures")
	quit(0 if failures==0 else 1)
