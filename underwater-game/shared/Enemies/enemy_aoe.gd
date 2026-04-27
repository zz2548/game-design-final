# enemy_aoe.gd
# Slow enemy. When the player is in range it charges up (flashing blue),
# then releases a shockwave that damages everything inside ShockZone.

class_name EnemyAoe
extends Enemy

@export var attack_damage    : int   = 2
@export var attack_cooldown  : float = 4.0
@export var charge_duration  : float = 2.0
@export var trigger_range    : float = 200.0

var _attack_timer : float = 0.0
var _charge_timer : float = 0.0
var _is_charging  : bool  = false
var _charge_tween : Tween = null

@onready var shock_zone : Area2D = $ShockZone


func _on_ready() -> void:
	chase_speed = 80.0
	var anim := sprite as AnimatedSprite2D
	var tex : Texture2D = load("res://assets/enemies/fish-dart.png")
	var frames := SpriteFrames.new()
	frames.add_animation("swim")
	frames.set_animation_loop("swim", true)
	frames.set_animation_speed("swim", 8.0)
	for i in 4:
		var atlas := AtlasTexture.new()
		atlas.atlas  = tex
		atlas.region = Rect2(i * 39, 0, 39, 20)
		frames.add_frame("swim", atlas)
	anim.sprite_frames = frames
	anim.play("swim")


func _tick_chase(delta: float) -> void:
	if not is_instance_valid(_player_ref):
		_enter_state(State.IDLE)
		return
	var to_player := _player_ref.global_position - global_position
	if to_player.length() <= trigger_range:
		_enter_state(State.ATTACK)
		return
	velocity = velocity.move_toward(to_player.normalized() * chase_speed, 400 * delta)


func _on_enter_attack() -> void:
	velocity = Vector2.ZERO
	_attack_timer = attack_cooldown
	_start_charge()


func _tick_attack(delta: float) -> void:
	velocity = Vector2.ZERO

	if _is_charging:
		_charge_timer -= delta
		if _charge_timer <= 0.0:
			_is_charging = false
			_release_shock()
		return

	_attack_timer -= delta
	if _attack_timer <= 0.0:
		if not is_instance_valid(_player_ref):
			_enter_state(State.IDLE)
			return
		var dist := (_player_ref.global_position - global_position).length()
		if dist <= trigger_range * 1.4:
			_attack_timer = attack_cooldown
			_start_charge()
		else:
			_enter_state(State.CHASE)


func _start_charge() -> void:
	_is_charging = true
	_charge_timer = charge_duration
	if _charge_tween:
		_charge_tween.kill()
	_charge_tween = create_tween().set_loops(int(charge_duration / 0.3))
	_charge_tween.tween_property(sprite, "modulate", Color(0.2, 0.8, 1.0), 0.15)
	_charge_tween.tween_property(sprite, "modulate", Color(0.3, 0.0, 0.9), 0.15)


func _release_shock() -> void:
	if _charge_tween:
		_charge_tween.kill()

	sprite.modulate = Color(1, 1, 1)
	var flash := create_tween()
	flash.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.4)

	_spawn_explosion()

	for body in shock_zone.get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(attack_damage)
			emit_signal("player_damaged", attack_damage)


func _spawn_explosion() -> void:
	var anim := AnimatedSprite2D.new()
	var tex : Texture2D = load("res://assets/vfx/explosion.png")
	var frames := SpriteFrames.new()
	frames.add_animation("explode")
	frames.set_animation_loop("explode", false)
	frames.set_animation_speed("explode", 18.0)
	for i in 11:
		var atlas := AtlasTexture.new()
		atlas.atlas  = tex
		atlas.region = Rect2(i * 60, 0, 60, 82)
		frames.add_frame("explode", atlas)
	anim.sprite_frames = frames
	anim.scale = Vector2(2.5, 2.5)
	anim.global_position = global_position
	anim.animation_finished.connect(anim.queue_free)
	get_parent().add_child(anim)
	anim.play("explode")
