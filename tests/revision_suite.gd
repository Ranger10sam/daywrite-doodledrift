extends SceneTree
var checks := 0
var failures := 0
var world: Variant
var ball: Variant

func _initialize() -> void: call_deferred("run")
func ticks(n: int) -> void:
	for i in range(n): await physics_frame
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
	print("PASS " if ok else "FAIL ",label)
func run() -> void:
	var world_script: Script = load("res://scripts/level/level_world.gd")
	var ball_script: Script = load("res://scripts/player/ball.gd")
	var ink_script: Script = load("res://scripts/ink/ink_stroke.gd")
	world=world_script.new()
	world.configure({"id":1,"biome":0,"width":1200,"height":900,"start":[100,540],"finish":[1100,522],"terrain":[{"points":[[0,560],[1200,560],[1200,900],[0,900]]}],"hazards":[],"build_regions":[[10,100,1180,690]],"gates":[{"plate":[700,560],"gate":[900,560]}]},"normal")
	root.add_child(world)
	ball=ball_script.new(); ball.position=Vector2(100,540); world.add_child(ball); world.player=ball
	var loose: Variant=ink_script.new()
	loose.configure(PackedVector2Array([Vector2(300,250),Vector2(420,250)]),"solid")
	world.add_child(loose)
	await ticks(45)
	check(loose.position.y>400,"unsupported ink falls under gravity")
	await ticks(70)
	check(loose.position.y<565 and loose.position.y>530,"loose ink lands on terrain rather than falling through")
	var fixed: Variant=ink_script.new()
	fixed.configure(PackedVector2Array([Vector2(480,552),Vector2(620,552)]),"solid")
	world.add_child(fixed)
	await ticks(40)
	check(fixed.freeze and absf(fixed.position.y-552)<1,"both supported endpoints anchor the bridge")
	ball.axis=-1; await ticks(180)
	check(ball.position.x>=17,"physical left boundary contains player")
	world.complete=true; ball.respawn(Vector2(1100,540)); await ticks(3); ball.axis=1; await ticks(120)
	check(ball.position.x<=1183,"physical right boundary contains player")
	ball.respawn(Vector2(100,540)); await ticks(3)
	world.complete=false; world.gates[0].latched=false; await ticks(10)
	check(not world.gates[0].body.removed,"unweighted pressure plate leaves gate closed")
	var weight: Variant=ink_script.new()
	weight.configure(PackedVector2Array([Vector2(670,350),Vector2(730,350)]),"solid")
	world.add_child(weight); await ticks(100)
	check(world.gates[0].body.removed,"dropped physical weight opens pressure-plate gate")
	world.queue_free(); await process_frame
	var levels: Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/levels/campaign.json"))
	var blocked := 0
	for data in levels:
		world=world_script.new(); world.configure(data,"normal"); root.add_child(world)
		ball=ball_script.new(); ball.position=Vector2(data.start[0],data.start[1]); world.add_child(ball); world.player=ball
		for i in range(850):
			ball.axis=1
			if ball.grounded: ball.request_jump()
			await physics_frame
			if world.complete or world.death_lock: break
		if not world.complete: blocked+=1
		world.queue_free(); await process_frame
	check(blocked==50,"all 50 levels reject right-plus-repeated-jump bypass")
	print("REVISION: ",checks," checks; ",failures," failures")
	quit(0 if failures==0 else 1)
