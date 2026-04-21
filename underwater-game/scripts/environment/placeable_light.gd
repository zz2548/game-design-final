# placeable_light.gd
# Reusable world-space point light. Instance PlaceableLight.tscn into any
# level and tune the exports in the Inspector — no code needed.
class_name PlaceableLight
extends Node2D

## Base colour of the emitted light.
@export var light_color: Color = Color(0.75, 0.90, 1.0, 1.0):
	set(v):
		light_color = v
		if _light: _light.color = v

## Peak brightness (PointLight2D energy).
@export var energy: float = 1.5:
	set(v):
		energy = v
		if _light: _light.energy = v

## Effective radius — drives PointLight2D.texture_scale.
@export var radius: float = 3.0:
	set(v):
		radius = v
		if _light: _light.texture_scale = v

## Cast shadows from occluders in the scene.
@export var shadows: bool = false:
	set(v):
		shadows = v
		if _light: _light.shadow_enabled = v

## Add a subtle organic flicker.
@export var flicker: bool = false
## Oscillation speed of the flicker.
@export var flicker_speed: float = 2.5
## Maximum energy swing during flicker (± this value).
@export var flicker_amount: float = 0.30

@onready var _light: PointLight2D = $Light


func _ready() -> void:
	_light.color          = light_color
	_light.energy         = energy
	_light.texture_scale  = radius
	_light.shadow_enabled = shadows


func _process(_delta: float) -> void:
	if not flicker:
		return
	# Two overlapping sines produce an organic, non-repeating flutter.
	var t     := Time.get_ticks_msec() * 0.001
	var noise := sin(t * flicker_speed * 4.1) * 0.6 + sin(t * flicker_speed * 1.7) * 0.4
	_light.energy = maxf(0.0, energy + noise * flicker_amount)
