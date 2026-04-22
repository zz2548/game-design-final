# enemy.gd
# Base class for all enemy types. Handles detection, chasing, stun, and death.
# Subclasses override _tick_attack() and _on_enter_attack() for their attack behavior.

class_name Enemy
extends CharacterBody2D

@export var ai_enabled      : bool  = true
@export var chase_speed     : float = 220.0
@export var max_health      : int   = 3
@export var stun_duration   : float = 0.25

signal died
signal player_damaged(amount: int)

enum State { IDLE, ALERT, CHASE, ATTACK, STUNNED }
var _state        : State  = State.IDLE
var _state_timer  : float  = 0.0
var _health       : int
var _player_ref   : Node2D = null

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
	_health -= 1
	if _health <= 0:
		emit_signal("died")
		queue_free()
		return
	_enter_state(State.STUNNED)
