# enemy_bullet.gd
# Projectile fired by EnemyRanged. Damages the player on contact, expires after MAX_RANGE.

extends Area2D

const SPEED     : float = 380.0
const MAX_RANGE : float = 900.0

var direction : Vector2 = Vector2.RIGHT
var damage    : int     = 1

var _distance_traveled : float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _draw() -> void:
	draw_circle(Vector2.ZERO, 5.5, Color(1.0, 0.35, 0.0, 0.35))
	draw_circle(Vector2.ZERO, 3.5, Color(1.0, 0.65, 0.1, 1.0))
	draw_circle(Vector2.ZERO, 1.8, Color(1.0, 0.95, 0.7, 1.0))


func _physics_process(delta: float) -> void:
	position += direction * SPEED * delta
	_distance_traveled += SPEED * delta
	if _distance_traveled >= MAX_RANGE:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()
