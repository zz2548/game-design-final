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


func _physics_process(delta: float) -> void:
	position += direction * SPEED * delta
	_distance_traveled += SPEED * delta
	if _distance_traveled >= MAX_RANGE:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()
