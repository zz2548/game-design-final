# homing_bullet.gd
# Phase 2 serpent projectile.
#
# LOCKING phase  — hovers in place, rotates toward the player over lock_duration.
# TRAVELING phase — fires in the locked direction at travel_speed. Dodgeable
#                   because the direction is frozen at lock time.

extends Area2D

const TRAVEL_SPEED : float = 300.0
const MAX_RANGE    : float = 1100.0

var lock_duration : float = 0.9
var damage        : int   = 1

var _player_ref        : Node2D  = null
var _lock_timer        : float   = 0.0
var _direction         : Vector2 = Vector2.DOWN
var _traveling         : bool    = false
var _distance_traveled : float   = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_player_ref = get_tree().get_first_node_in_group("player")
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _traveling:
		global_position += _direction * TRAVEL_SPEED * delta
		_distance_traveled += TRAVEL_SPEED * delta
		if _distance_traveled >= MAX_RANGE:
			queue_free()
		return

	# Locking — track player direction each frame
	_lock_timer += delta
	if is_instance_valid(_player_ref):
		_direction = (_player_ref.global_position - global_position).normalized()
	rotation = _direction.angle() + PI / 2.0

	if _lock_timer >= lock_duration:
		_traveling = true

	queue_redraw()


func _draw() -> void:
	if _traveling:
		# Cyan/white bullet
		draw_circle(Vector2.ZERO, 7.0, Color(0.0, 0.9, 1.0, 0.25))
		draw_circle(Vector2.ZERO, 4.5, Color(0.2, 1.0, 0.9, 1.0))
		draw_circle(Vector2.ZERO, 2.0, Color(1.0, 1.0, 1.0, 1.0))
	else:
		# Locking — colour shifts red→orange as lock completes
		var t     := clampf(_lock_timer / lock_duration, 0.0, 1.0)
		var col   := Color(0.6 + t * 0.4, 0.8 - t * 0.5, 1.0 - t, 1.0)
		var pulse := 0.6 + sin(_lock_timer * TAU * 3.0) * 0.2
		draw_circle(Vector2.ZERO, 8.0 * pulse, Color(col.r, col.g, col.b, 0.2))
		draw_circle(Vector2.ZERO, 5.0 * pulse, col)
		# Forward arrow (local -Y = forward because rotation offset +PI/2)
		draw_line(Vector2.ZERO, Vector2(0, -12.0 * pulse), Color(1.0, 0.6, 0.1, 0.85), 2.0)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()
