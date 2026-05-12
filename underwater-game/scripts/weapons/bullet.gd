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
var _hit               : bool  = false

@onready var _bullet_area : Area2D = $BulletArea


func _ready() -> void:
	_bullet_area.collision_mask = 4  # detect BulletHitZone (enemy layer 4)
	_bullet_area.area_entered.connect(_on_hit_enemy)


func _on_hit_enemy(area: Area2D) -> void:
	if _hit:
		return
	if area.name != "BulletHitZone":
		return
	_hit = true
	queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 3.0, Color(0.3, 0.7, 1.0))


func _physics_process(delta: float) -> void:
	if _hit:
		return
	var collision := move_and_collide(direction * SPEED * delta)
	_distance_traveled += SPEED * delta

	if collision != null or _distance_traveled >= MAX_RANGE:
		queue_free()
