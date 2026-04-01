# bullet.gd
# Fired by the player. Travels in a straight line until it hits a wall or
# exceeds MAX_RANGE, then frees itself.
#
# Collision layers:
#   layer  3 (value 4) — bullets live here so enemies can detect hits via Area2D
#   mask   1 (value 1) — detects walls / TileMapLayer physics bodies

extends CharacterBody2D

const SPEED     : float = 900.0
const MAX_RANGE : float = 1200.0

## Set by the player immediately after instantiation.
var direction : Vector2 = Vector2.RIGHT

var _distance_traveled : float = 0.0


func _physics_process(delta: float) -> void:
	var collision := move_and_collide(direction * SPEED * delta)
	_distance_traveled += SPEED * delta

	if collision != null or _distance_traveled >= MAX_RANGE:
		queue_free()
