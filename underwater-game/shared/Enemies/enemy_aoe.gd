# enemy_aoe.gd
# Stationary mine. When the player gets close it arms (flashes red), then explodes.

class_name EnemyAoe
extends Enemy

@export var attack_damage   : int   = 2
@export var charge_duration : float = 2.0
@export var trigger_range   : float = 80.0

var _triggered    : bool  = false
var _charge_timer : float = 0.0
var _charge_tween : Tween = null

@onready var shock_zone : Area2D = $ShockZone


func _on_ready() -> void:
	var anim := sprite as AnimatedSprite2D
	var frames := SpriteFrames.new()

	var tex_idle : Texture2D = load("res://assets/enemies/mine.png")
	frames.add_animation("idle")
	frames.set_animation_loop("idle", false)
	var a_idle := AtlasTexture.new()
	a_idle.atlas = tex_idle
	a_idle.region = Rect2(0, 0, 45, 45)
	frames.add_frame("idle", a_idle)

	var tex_armed : Texture2D = load("res://assets/enemies/mine-big.png")
	frames.add_animation("armed")
	frames.set_animation_loop("armed", false)
	var a_armed := AtlasTexture.new()
	a_armed.atlas = tex_armed
	a_armed.region = Rect2(0, 0, 69, 69)
	frames.add_frame("armed", a_armed)

	anim.sprite_frames = frames
	anim.play("idle")

	var bob := create_tween().set_loops()
	bob.tween_property(sprite, "position", Vector2(0, -5), 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(sprite, "position", Vector2(0, 5), 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _physics_process(delta: float) -> void:
	if not ai_enabled:
		return
	velocity = Vector2.ZERO
	move_and_slide()

	if _triggered:
		_charge_timer -= delta
		if _charge_timer <= 0.0:
			_explode()
		return

	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	if (player.global_position - global_position).length() <= trigger_range:
		_trigger()


func _on_bullet_hit(_area: Area2D) -> void:
	_hit_sound.play()
	_health -= 1
	if _health <= 0:
		_explode()
		return
	_hit_react()


func _trigger() -> void:
	_triggered = true
	_charge_timer = charge_duration
	(sprite as AnimatedSprite2D).play("armed")
	if _charge_tween:
		_charge_tween.kill()
	_charge_tween = create_tween().set_loops(int(charge_duration / 0.25))
	_charge_tween.tween_property(sprite, "modulate", Color(1.8, 0.3, 0.3), 0.125)
	_charge_tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0), 0.125)


func _explode() -> void:
	if _charge_tween:
		_charge_tween.kill()

	for body in shock_zone.get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(attack_damage)
			emit_signal("player_damaged", attack_damage)

	_spawn_explosion()

	var snd := AudioStreamPlayer.new()
	snd.stream = load("res://assets/sounds/mobdeath.mp3")
	snd.finished.connect(snd.queue_free)
	get_parent().add_child(snd)
	snd.play()

	queue_free()


func _spawn_explosion() -> void:
	var anim := AnimatedSprite2D.new()
	var tex : Texture2D = load("res://assets/vfx/explosion-big.png")
	var frames := SpriteFrames.new()
	frames.add_animation("explode")
	frames.set_animation_loop("explode", false)
	frames.set_animation_speed("explode", 18.0)
	for i in 11:
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(i * 78, 0, 78, 87)
		frames.add_frame("explode", atlas)
	anim.sprite_frames = frames
	anim.global_position = global_position
	anim.animation_finished.connect(anim.queue_free)
	get_parent().add_child(anim)
	anim.play("explode")
