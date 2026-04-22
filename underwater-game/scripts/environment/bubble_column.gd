class_name BubbleColumn
extends Area2D

## Downward push applied to the player per second while inside.
@export var push_force: float = 1000.0

var _bubbles: CPUParticles2D


func _ready() -> void:
	_build_bubbles()


func _build_bubbles() -> void:
	_bubbles = CPUParticles2D.new()
	_bubbles.amount = 60
	_bubbles.lifetime = 4.0
	_bubbles.explosiveness = 0.0
	_bubbles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_bubbles.emission_rect_extents = Vector2(40.0, 2.0)
	_bubbles.gravity = Vector2(0.0, 90.0)
	_bubbles.initial_velocity_min = 40.0
	_bubbles.initial_velocity_max = 80.0
	_bubbles.spread = 10.0
	_bubbles.direction = Vector2(0.0, 1.0)
	_bubbles.color = Color(0.7, 0.92, 1.0, 0.55)
	_bubbles.emitting = true
	add_child(_bubbles)


func _physics_process(delta: float) -> void:
	for body in get_overlapping_bodies():
		if body.has_method("refill_oxygen"):
			body.velocity.y += push_force * delta
