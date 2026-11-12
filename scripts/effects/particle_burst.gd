class_name ParticleBurst
extends Node2D
var particles: Array[Dictionary] = []
var duration: float = 0.7
var age: float = 0.0
var tint := Color.WHITE

func _init() -> void:
	# Celebration can finish while the completed world's physics remains paused.
	process_mode = Node.PROCESS_MODE_ALWAYS

func configure(at: Vector2, color: Color, count: int = 12) -> void:
	position = at
	tint = color
	for i in range(mini(count, 32)):
		var angle := float(i) * 2.399963
		particles.append({"p": Vector2.ZERO, "v": Vector2.from_angle(angle) * (45.0 + fmod(i * 37.0, 140.0)), "r": 2.0 + fmod(i * 7.0, 3.0)})

func _process(delta: float) -> void:
	age += delta
	if age >= duration:
		queue_free()
		return
	for particle in particles:
		particle.v += Vector2(0, 190.0) * delta
		particle.p += particle.v * delta
	queue_redraw()

func _draw() -> void:
	for particle in particles:
		draw_circle(particle.p, float(particle.r) * (1.0 - age / duration), Color(tint, 1.0 - age / duration))
