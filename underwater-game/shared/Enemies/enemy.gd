# enemy.gd
# A hostile deep-sea creature that guards a position.
# Idles in place until the player enters detection range.
# If submarine is not fixed — warns the player via dialogue.
# If submarine is fixed — chases and attacks.

class_name Enemy
extends CharacterBody2D

# ── Stats ─────────────────────────────────────────────────────────────────────
@export var ai_enabled      : bool  = true
@export var chase_speed     : float = 220.0
@export var attack_damage   : int   = 1
@export var attack_cooldown : float = 0.8
@export var max_health      : int   = 3
@export var stun_duration   : float = 0.25

# ── Signals ───────────────────────────────────────────────────────────────────
signal died
signal player_damaged(amount: int)

# ── State ─────────────────────────────────────────────────────────────────────
enum State { IDLE, ALERT, CHASE, ATTACK, STUNNED }
var _state        : State  = State.IDLE
var _state_timer  : float  = 0.0
var _health       : int
var _attack_timer : float  = 0.0
var _player_ref   : Node2D = null

# ── Children ──────────────────────────────────────────────────────────────────
@onready var detection_zone  : Area2D   = $DetectionZone
@onready var hit_zone        : Area2D   = $HitZone
@onready var bullet_hit_zone : Area2D   = $BulletHitZone
@onready var sprite          : AnimatedSprite2D = $Sprite
@onready var alert_label     : Label    = $AlertLabel


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _setup_sprite() -> void:
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
	sprite.sprite_frames = frames
	sprite.play("swim")


func _ready() -> void:
	_health = max_health
	_setup_sprite()

	detection_zone.body_entered.connect(_on_detection_body_entered)
	detection_zone.body_exited.connect(_on_detection_body_exited)

	hit_zone.body_entered.connect(_on_hit_zone_body_entered)
	hit_zone.body_exited.connect(_on_hit_zone_body_exited)

	bullet_hit_zone.area_entered.connect(_on_bullet_hit)

	alert_label.hide()


func _physics_process(delta: float) -> void:
	if not ai_enabled:
		return
	match _state:
		State.IDLE:    _tick_idle(delta)
		State.ALERT:   _tick_alert(delta)
		State.CHASE:   _tick_chase(delta)
		State.ATTACK:  _tick_attack(delta)
		State.STUNNED: _tick_stunned(delta)

	if velocity.x != 0:
		sprite.flip_h = velocity.x < 0

	move_and_slide()


# ── State ticks ───────────────────────────────────────────────────────────────

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


func _tick_attack(delta: float) -> void:
	if is_instance_valid(_player_ref):
		var to_player := _player_ref.global_position - global_position
		velocity = velocity.move_toward(to_player.normalized() * (chase_speed * 0.4), 600 * delta)

	_attack_timer -= delta
	if _attack_timer <= 0.0:
		_attack_timer = attack_cooldown
		emit_signal("player_damaged", attack_damage)
		if is_instance_valid(_player_ref) and _player_ref.has_method("take_damage"):
			_player_ref.take_damage(attack_damage)


func _tick_stunned(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, 1200 * delta)
	_state_timer -= delta
	if _state_timer <= 0.0:
		_enter_state(State.CHASE if is_instance_valid(_player_ref) else State.IDLE)


# ── State transitions ─────────────────────────────────────────────────────────

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
			_attack_timer = 0.0
		State.STUNNED:
			_state_timer = stun_duration


# ── Callbacks ─────────────────────────────────────────────────────────────────

func _on_detection_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if not ai_enabled:
		if not GameState.submarine_fixed and not DialogueManager.is_active:
			# After the warning dialogue closes, give the player a velocity
			# kick away from this enemy instead of teleporting — avoids
			# clipping into walls.
			var push_from := global_position
			DialogueManager.dialogue_ended.connect(func():
				if is_instance_valid(body):
					body.velocity = (body.global_position - push_from).normalized() * 500.0
			, CONNECT_ONE_SHOT)
			DialogueManager.start_dialogue({
				"speaker": "ORCA",
				"lines": [
					"Creature detected. Threat classification: unknown biological.",
					"Tethys-7 is not operational. Do not engage.",
				],
			})
		return
	if not GameState.submarine_fixed:
		if not DialogueManager.is_active:
			DialogueManager.start_dialogue({
				"speaker": "ORCA",
				"lines": [
					"Creature detected. Threat classification: unknown biological.",
					"Tethys-7 is not operational. Do not engage.",
				],
			})
	if _state == State.IDLE:
		_player_ref = body
		_enter_state(State.ALERT)


func _on_detection_body_exited(body: Node2D) -> void:
	if body == _player_ref and _state != State.IDLE:
		_enter_state(State.IDLE)


func _on_hit_zone_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_ref = body
	if not GameState.submarine_fixed:
		# Tethys-7 not operational — one-hit kill
		body.die()
		return
	if _state != State.ATTACK:
		_enter_state(State.ATTACK)


func _on_hit_zone_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") and _state == State.ATTACK:
		_enter_state(State.CHASE)


func _on_bullet_hit(_area: Area2D) -> void:
	_health -= 1
	if _health <= 0:
		emit_signal("died")
		queue_free()
		return
	_enter_state(State.STUNNED)
