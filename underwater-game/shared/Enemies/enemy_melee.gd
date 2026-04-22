# enemy_melee.gd
# Chases the player and deals damage on contact.

class_name EnemyMelee
extends Enemy

@export var attack_damage   : int   = 1
@export var attack_cooldown : float = 0.8

var _attack_timer : float = 0.0


func _on_ready() -> void:
	hit_zone.body_entered.connect(_on_hit_zone_body_entered)
	hit_zone.body_exited.connect(_on_hit_zone_body_exited)


func _on_enter_attack() -> void:
	_attack_timer = 0.0


func _tick_attack(delta: float) -> void:
	if is_instance_valid(_player_ref):
		var to_player := _player_ref.global_position - global_position
		velocity = velocity.move_toward(to_player.normalized() * (chase_speed * 0.4), 600 * delta)

	_attack_timer -= delta
	if _attack_timer <= 0.0:
		_attack_timer = attack_cooldown
		if is_instance_valid(_player_ref) and _player_ref.has_method("take_damage"):
			_player_ref.take_damage(attack_damage)
			emit_signal("player_damaged", attack_damage)


func _on_hit_zone_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_ref = body
	if _state != State.ATTACK:
		_enter_state(State.ATTACK)


func _on_hit_zone_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") and _state == State.ATTACK:
		_enter_state(State.CHASE)
