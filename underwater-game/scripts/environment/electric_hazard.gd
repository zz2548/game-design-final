class_name ElectricHazard
extends Area2D

@export var damage: int = 1
@export var interval_min: float = 2.0
@export var interval_max: float = 4.5

var _light: PointLight2D
var _sparks: CPUParticles2D
var _timer: float = 0.0
var _next_zap: float = 0.0
var _zap_timer: float = 0.0
var _charge_timer: float = 0.0
var _charging: bool = false

const ZAP_DURATION := 0.75
const CHARGE_DURATION := 0.8


func _ready() -> void:
	_next_zap = randf_range(interval_min, interval_max)
	_build_light()
	_build_sparks()
	body_entered.connect(_on_body_entered)


func _build_light() -> void:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	grad.colors = PackedColorArray([Color(0.5, 0.75, 1.0, 1.0), Color(0.3, 0.5, 1.0, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 128
	tex.height = 128
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	_light = PointLight2D.new()
	_light.texture = tex
	_light.texture_scale = 1.2
	_light.energy = 0.35
	_light.color = Color(0.4, 0.65, 1.0)
	add_child(_light)


func _build_sparks() -> void:
	_sparks = CPUParticles2D.new()
	_sparks.amount = 18
	_sparks.lifetime = 0.22
	_sparks.explosiveness = 0.85
	_sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_sparks.emission_sphere_radius = 4.0
	_sparks.gravity = Vector2.ZERO
	_sparks.initial_velocity_min = 60.0
	_sparks.initial_velocity_max = 120.0
	_sparks.color = Color(0.5, 0.8, 1.0)
	_sparks.emitting = false
	add_child(_sparks)


func _process(delta: float) -> void:
	if _zap_timer > 0.0:
		_zap_timer -= delta
		if _zap_timer <= 0.0:
			_sparks.emitting = false
			_light.energy = 0.35
		return

	if _charging:
		_charge_timer -= delta
		# Pulse the light during charge-up so the player notices
		var pulse: float = 0.35 + 1.2 * abs(sin(_charge_timer * PI / CHARGE_DURATION * 3.0))
		_light.energy = pulse
		if _charge_timer <= 0.0:
			_charging = false
			_trigger_zap()
		return

	_timer += delta
	if _timer >= _next_zap:
		_timer = 0.0
		_next_zap = randf_range(interval_min, interval_max)
		_start_charge()


func _start_charge() -> void:
	_charging = true
	_charge_timer = CHARGE_DURATION


func _trigger_zap() -> void:
	_zap_timer = ZAP_DURATION
	_sparks.emitting = true
	_light.energy = 3.5
	for body in get_overlapping_bodies():
		if body.has_method("refill_oxygen"):
			body.take_damage(damage)


func _on_body_entered(body: Node) -> void:
	if _zap_timer > 0.0 and body.has_method("refill_oxygen"):
		body.take_damage(damage)
