# enemy_ranged.gd
# Keeps its distance and fires 3 bullets in a burst at the player.

class_name EnemyRanged
extends Enemy

const BULLET_SCENE : String = "res://shared/Enemies/enemy_bullet.tscn"

@export var attack_damage   : int   = 1
@export var attack_cooldown : float = 2.5
@export var attack_range    : float = 350.0
@export var preferred_dist  : float = 220.0

const BURST_SIZE  : int   = 3
const BURST_DELAY : float = 0.18

var _attack_timer : float = 0.0
var _burst_count  : int   = 0
var _burst_timer  : float = 0.0

var _bullet_scene : PackedScene


func _on_ready() -> void:
	_bullet_scene = load(BULLET_SCENE)
	sprite.modulate = Color(0.1, 0.5, 1.0)


func _tick_chase(delta: float) -> void:
	if not is_instance_valid(_player_ref):
		_enter_state(State.IDLE)
		return
	var to_player := _player_ref.global_position - global_position
	if to_player.length() <= attack_range:
		_enter_state(State.ATTACK)
		return
	velocity = velocity.move_toward(to_player.normalized() * chase_speed, 800 * delta)


func _on_enter_attack() -> void:
	_attack_timer = 0.0
	_burst_count = 0
	_burst_timer = 0.0


func _tick_attack(delta: float) -> void:
	if not is_instance_valid(_player_ref):
		_enter_state(State.IDLE)
		return

	var to_player := _player_ref.global_position - global_position
	var dist := to_player.length()

	if dist > attack_range * 1.3:
		_enter_state(State.CHASE)
		return

	# Back away if player gets too close
	if dist < preferred_dist:
		velocity = velocity.move_toward(-to_player.normalized() * chase_speed * 0.6, 600 * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 600 * delta)

	# Mid-burst: fire next bullet
	if _burst_count > 0:
		_burst_timer -= delta
		if _burst_timer <= 0.0:
			_fire_bullet()
			_burst_count -= 1
			_burst_timer = BURST_DELAY
		return

	# Start next burst
	_attack_timer -= delta
	if _attack_timer <= 0.0:
		_attack_timer = attack_cooldown
		_burst_count = BURST_SIZE - 1
		_burst_timer = BURST_DELAY
		_fire_bullet()


func _fire_bullet() -> void:
	if not is_instance_valid(_player_ref) or _bullet_scene == null:
		return
	var b : Node2D = _bullet_scene.instantiate()
	get_tree().current_scene.add_child(b)
	b.global_position = global_position
	b.direction = (_player_ref.global_position - global_position).normalized()
	b.damage = attack_damage
