# enemy.gd
# Base class for all enemy types. Handles detection, chasing, stun, and death.
# Subclasses override _tick_attack() and _on_enter_attack() for their attack behavior.

class_name Enemy
extends CharacterBody2D

@export var ai_enabled      : bool  = true
@export var chase_speed     : float = 110.0
@export var max_health      : int   = 3
@export var stun_duration   : float = 0.25

signal died
signal player_damaged(amount: int)

enum State { IDLE, ALERT, CHASE, ATTACK, STUNNED }
var _state        : State  = State.IDLE
var _state_timer  : float  = 0.0
var _health       : int
var _player_ref   : Node2D = null
var _hit_sound    : AudioStreamPlayer

@onready var detection_zone  : Area2D           = $DetectionZone
@onready var hit_zone        : Area2D           = $HitZone
@onready var bullet_hit_zone : Area2D           = $BulletHitZone
@onready var sprite          : CanvasItem        = $Sprite
@onready var alert_label     : Label            = $AlertLabel


func _setup_sprite() -> void:
	if not sprite is AnimatedSprite2D:
		return
	var anim := sprite as AnimatedSprite2D
	var tex : Texture2D = preload("res://assets/enemies/fish.png")
	var frames := SpriteFrames.new()
	frames.add_animation("swim")
	frames.set_animation_loop("swim", true)
	frames.set_animation_speed("swim", 8.0)
	for i in 4:
		var atlas := AtlasTexture.new()
		atlas.atlas  = tex
		atlas.region = Rect2(i * 32, 0, 32, 32)
		frames.add_frame("swim", atlas)
	anim.sprite_frames = frames
	anim.play("swim")


func _ready() -> void:
	_health = max_health
	_hit_sound = AudioStreamPlayer.new()
	_hit_sound.stream = load("res://assets/sounds/hit.mp3")
	add_child(_hit_sound)
	_setup_sprite()
	detection_zone.body_entered.connect(_on_detection_body_entered)
	detection_zone.body_exited.connect(_on_detection_body_exited)
	bullet_hit_zone.area_entered.connect(_on_bullet_hit)
	alert_label.hide()
	_on_ready()


func _on_ready() -> void:
	pass


func _physics_process(delta: float) -> void:
	if not ai_enabled:
		return
	match _state:
		State.IDLE:    _tick_idle(delta)
		State.ALERT:   _tick_alert(delta)
		State.CHASE:   _tick_chase(delta)
		State.ATTACK:  _tick_attack(delta)
		State.STUNNED: _tick_stunned(delta)

	if velocity.x != 0 and sprite is AnimatedSprite2D:
		(sprite as AnimatedSprite2D).flip_h = velocity.x < 0

	move_and_slide()


func _tick_idle(_delta: float) -> void:
	velocity = Vector2.ZERO


func _tick_alert(delta: float) -> void:
	velocity = Vector2.ZERO
	_state_timer -= delta
	if _state_timer <= 0.0:
		alert_label.hide()
		_enter_state(State.CHASE)


func _tick_chase(delta: float) -> void:
	if not is_instance_valid(_player_ref):
		_enter_state(State.IDLE)
		return
	var to_player := _player_ref.global_position - global_position
	velocity = velocity.move_toward(to_player.normalized() * chase_speed, 800 * delta)


func _tick_attack(_delta: float) -> void:
	pass


func _tick_stunned(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, 1200 * delta)
	_state_timer -= delta
	if _state_timer <= 0.0:
		_enter_state(State.CHASE if is_instance_valid(_player_ref) else State.IDLE)


func _enter_state(new_state: State) -> void:
	_state = new_state
	match new_state:
		State.IDLE:
			_player_ref = null
			alert_label.hide()
			velocity = Vector2.ZERO
		State.ALERT:
			_state_timer = 0.55
			alert_label.show()
		State.CHASE:
			alert_label.hide()
		State.ATTACK:
			_on_enter_attack()
		State.STUNNED:
			_state_timer = stun_duration


func _on_enter_attack() -> void:
	pass


func _on_detection_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if _state == State.IDLE:
		_player_ref = body
		_enter_state(State.ALERT)


func _on_detection_body_exited(body: Node2D) -> void:
	if body == _player_ref and _state != State.IDLE:
		_enter_state(State.IDLE)


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
	_hit_react()
	_enter_state(State.STUNNED)


func _spawn_death_vfx() -> void:
	var anim := AnimatedSprite2D.new()
	var tex : Texture2D = load("res://assets/vfx/enemy-death.png")
	var frames := SpriteFrames.new()
	frames.add_animation("death")
	frames.set_animation_loop("death", false)
	frames.set_animation_speed("death", 12.0)
	for i in 6:
		var atlas := AtlasTexture.new()
		atlas.atlas  = tex
		atlas.region = Rect2(i * 52, 0, 52, 53)
		frames.add_frame("death", atlas)
	anim.sprite_frames = frames
	anim.global_position = global_position
	anim.animation_finished.connect(anim.queue_free)
	get_parent().add_child(anim)
	anim.play("death")


func _hit_react() -> void:
	var orig_mod := modulate
	modulate = Color(1.5, 1.5, 1.5)
	create_tween().tween_property(self, "modulate", orig_mod, 0.2)

	if sprite is Node2D:
		var s := sprite as Node2D
		var orig := s.position
		var shake := create_tween()
		shake.tween_property(s, "position", orig + Vector2(5, 0), 0.04)
		shake.tween_property(s, "position", orig + Vector2(-5, 0), 0.04)
		shake.tween_property(s, "position", orig, 0.04)
