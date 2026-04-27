class_name BubbleColumn
extends Area2D

## Downward push applied to the player per second while inside.
@export var push_force: float = 1000.0

var _bubbles: CPUParticles2D


func _ready() -> void:
	_build_bubbles()


func _build_bubbles() -> void:
	_bubbles = CPUParticles2D.new()
	_bubbles.amount = 120
	_bubbles.lifetime = 4.0
	_bubbles.explosiveness = 0.0
	_bubbles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_bubbles.emission_rect_extents = Vector2(40.0, 2.0)
	_bubbles.gravity = Vector2(0.0, 90.0)
	_bubbles.initial_velocity_min = 40.0
	_bubbles.initial_velocity_max = 80.0
	_bubbles.spread = 10.0
	_bubbles.direction = Vector2(0.0, 1.0)
	_bubbles.scale_amount_min = 0.8
	_bubbles.scale_amount_max = 2.2
	_bubbles.color = Color(0.82, 0.96, 1.0, 0.75)
	_bubbles.texture = _make_bubble_texture()
	_bubbles.emitting = true
	add_child(_bubbles)


func _make_bubble_texture() -> ImageTexture:
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	for y in 12:
		for x in 12:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(6.0, 6.0))
			var a := clampf(1.0 - d / 6.0, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a * a))
	return ImageTexture.create_from_image(img)


func _physics_process(delta: float) -> void:
	for body in get_overlapping_bodies():
		if body.has_method("refill_oxygen"):
			body.velocity.y += push_force * delta
