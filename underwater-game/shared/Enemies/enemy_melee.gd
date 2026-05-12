# enemy_melee.gd
# Chases the player and deals damage on contact.

class_name EnemyMelee
extends Enemy

@export var attack_damage   : int   = 1
@export var attack_cooldown : float = 0.8

const CHARGE_DURATION : float = 0.35

var _attack_timer : float = 0.0
var _charge_timer : float = 0.0
var _charging     : bool  = false


func _on_ready() -> void:
	hit_zone.body_entered.connect(_on_hit_zone_body_entered)
	hit_zone.body_exited.connect(_on_hit_zone_body_exited)


func _on_enter_attack() -> void:
	_attack_timer = 0.0
	_charging = false


func _tick_attack(delta: float) -> void:
	if is_instance_valid(_player_ref):
		var to_player := _player_ref.global_position - global_position
		velocity = velocity.move_toward(to_player.normalized() * (chase_speed * 0.4), 600 * delta)

	if _charging:
		_charge_timer -= delta
		var t: float = 1.0 - (_charge_timer / CHARGE_DURATION)
		modulate = Color(1.0 + t * 0.6, 1.0 - t * 0.5, 1.0 - t * 0.5)
		if _charge_timer <= 0.0:
			_charging = false
			modulate = Color(1.0, 1.0, 1.0)
			_do_strike()
		return

	_attack_timer -= delta
	if _attack_timer <= 0.0:
		_attack_timer = attack_cooldown
		_charging = true
		_charge_timer = CHARGE_DURATION


func _do_strike() -> void:
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


func _on_bullet_hit(_area: Area2D) -> void:
	_hit_sound.play()
	_health -= 1
	if _health <= 0:
		_spawn_death_vfx()
		var snd := AudioStreamPlayer.new()
		snd.stream = load("res://assets/sounds/mobdeath.mp3")
		snd.finished.connect(snd.queue_free)
		get_parent().add_child(snd)
		snd.play()
		emit_signal("died")
		queue_free()
		return
	if _player_ref == null:
		_player_ref = get_tree().get_first_node_in_group("player") as Node2D
	_melee_hit_react()
	# No STUNNED — keeps chasing


func _melee_hit_react() -> void:
	var orig_mod := modulate
	modulate = Color(2.0, 0.3, 0.3)
	create_tween().tween_property(self, "modulate", orig_mod, 0.3)

	var orig_scale := scale
	var sq := create_tween()
	sq.tween_property(self, "scale", orig_scale * 0.75, 0.05)
	sq.tween_property(self, "scale", orig_scale * 1.2,  0.05)
	sq.tween_property(self, "scale", orig_scale,        0.08)

	if sprite is Node2D:
		var s    := sprite as Node2D
		var orig := s.position
		var shk  := create_tween()
		for _i in 4:
			shk.tween_property(s, "position",
				orig + Vector2(randf_range(-9.0, 9.0), randf_range(-6.0, 6.0)), 0.035)
		shk.tween_property(s, "position", orig, 0.04)

	var particles := CPUParticles2D.new()
	particles.global_position       = global_position
	particles.one_shot              = true
	particles.explosiveness         = 1.0
	particles.amount                = 10
	particles.lifetime              = 1.0
	particles.initial_velocity_min  = 25.0
	particles.initial_velocity_max  = 60.0
	particles.spread                = 180.0
	particles.gravity               = Vector2.ZERO
	particles.scale_amount_min      = 2.0
	particles.scale_amount_max      = 5.0
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.25, 0.08, 1.0))
	grad.set_color(1, Color(1.0, 0.25, 0.08, 0.0))
	particles.color_ramp            = grad
	get_parent().add_child(particles)
	particles.emitting = true
	get_tree().create_timer(1.3).timeout.connect(particles.queue_free)
