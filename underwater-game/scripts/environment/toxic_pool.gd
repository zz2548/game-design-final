class_name ToxicPool
extends Area2D

## Oxygen drained per second (player's normal rate is 1.0 unit/s).
@export var oxygen_drain: float = 6.0
@export var radius: float = 40.0

var _light: PointLight2D
var _bubbles: CPUParticles2D
var _inside: Array = []
var _t: float = 0.0


func _ready() -> void:
	_build_visuals()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _build_visuals() -> void:
	# Filled pool drawn via _draw — always visible regardless of lighting
	# Light for glow effect
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	grad.colors = PackedColorArray([Color(0.1, 1.0, 0.2, 1.0), Color(0.05, 0.5, 0.1, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 128
	tex.height = 128
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	_light = PointLight2D.new()
	_light.texture = tex
	_light.texture_scale = 3.5
	_light.energy = 1.2
	_light.color = Color(0.1, 1.0, 0.2)
	add_child(_light)

	# Rising toxic bubbles
	_bubbles = CPUParticles2D.new()
	_bubbles.amount = 16
	_bubbles.lifetime = 1.5
	_bubbles.explosiveness = 0.0
	_bubbles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_bubbles.emission_sphere_radius = radius * 0.7
	_bubbles.gravity = Vector2(0.0, -40.0)
	_bubbles.initial_velocity_min = 10.0
	_bubbles.initial_velocity_max = 30.0
	_bubbles.color = Color(0.2, 1.0, 0.3, 0.7)
	_bubbles.emitting = true
	add_child(_bubbles)


func _draw() -> void:
	var pulse := 0.18 + sin(_t * 2.0) * 0.05
	draw_circle(Vector2.ZERO, radius, Color(0.05, 0.8, 0.15, pulse))


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

	for body in _inside:
		body.oxygen = maxf(0.0, body.oxygen - oxygen_drain * delta)

	# Pulse light energy
	_light.energy = 1.0 + sin(_t * 2.0) * 0.4


func _on_body_entered(body: Node) -> void:
	if body.has_method("refill_oxygen"):
		_inside.append(body)
		body.add_poison()


func _on_body_exited(body: Node) -> void:
	if _inside.has(body):
		_inside.erase(body)
		body.remove_poison()
