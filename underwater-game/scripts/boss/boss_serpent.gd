# boss_serpent.gd
# Level 3 boss — the Serpent.
#
# Multi-segment snake entity. The head is a CharacterBody2D; six body segments
# (sprites 2–7) are Node2D children whose positions are driven by a
# position-history trail recorded from the head every physics frame.
#
# Signal contract required by level_3.gd:
#   signal died  — emitted the moment health hits zero (before queue_free)

class_name BossSerpent
extends CharacterBody2D

signal died
signal player_damaged(amount: int)

# ── Exports ───────────────────────────────────────────────────────────────────
@export var ai_enabled    : bool  = true
@export var max_health    : int   = 30
@export var chase_speed   : float = 165.0
@export var stun_duration : float = 0.15
@export var attack_damage : int   = 1
@export var head_hit_dmg  : int   = 1   # bullet hits head  → 1 HP lost
@export var body_hit_dmg  : int   = 2   # bullet hits body  → 2 HP lost

# ── Snake body ────────────────────────────────────────────────────────────────
const NUM_SEGMENTS    : int   = 6      # sprites 2–7
const SEGMENT_SPACING : float = 40.0   # pixels between adjacent segment centres
const SAMPLE_DIST     : float = 2.0    # record a history point every N pixels moved
const MAX_HISTORY     : int   = 200    # SEGMENT_SPACING * NUM_SEGMENTS / SAMPLE_DIST = 120; 200 gives margin

# ── Attack tuning ─────────────────────────────────────────────────────────────
const MELEE_TRIGGER_DIST     : float = 90.0
const CHARGE_SPEED           : float = 310.0
const WIND_UP_DURATION       : float = 0.30
const CHARGE_DURATION        : float = 0.60
const BACK_OFF_DURATION      : float = 0.75
const BACK_OFF_SPEED         : float = 110.0
const SHOOT_RANGE            : float = 300.0
const SHOOT_PREPARE_DURATION : float = 1.0
const SHOOT_BURST_SIZE       : int   = 3
const SHOOT_BURST_DELAY      : float = 0.25
const SLITHER_FREQ           : float = 2.2   # Hz
const SLITHER_AMPLITUDE      : float = 0.18  # perpendicular speed multiplier

# ── State machine ─────────────────────────────────────────────────────────────
enum State {
	IDLE,
	ALERT,
	CHASE,
	MELEE_WIND_UP,
	MELEE_CHARGE,
	BACKING_OFF,
	SHOOT_PREPARE,
	SHOOTING,
	STUNNED,
}
var _state       : State = State.IDLE
var _state_timer : float = 0.0
var _health      : int

# ── Runtime state ─────────────────────────────────────────────────────────────
var _player_ref   : Node2D     = null
var _bullet_scene : PackedScene
var _ever_aggro   : bool = false  # once true, never returns to IDLE due to range

var _attack_timer  : float = 2.5
var _shoot_count   : int   = 0
var _shoot_timer   : float = 0.0
var _slither_timer : float = 0.0

# ── Wall navigation ───────────────────────────────────────────────────────────
var _stuck_timer : float   = 0.0
var _stuck_boost : Vector2 = Vector2.ZERO

# ── Snake body data ───────────────────────────────────────────────────────────
var _position_history : Array[Vector2] = []
var _segments         : Array[Node2D]  = []
var _prev_sampled     : Vector2        = Vector2.ZERO
var _sample_accum     : float          = 0.0

# ── Node references ───────────────────────────────────────────────────────────
@onready var _head_sprite    : AnimatedSprite2D  = $HeadSprite
@onready var _alert_label    : Label             = $AlertLabel
@onready var _detection_zone : Area2D            = $DetectionZone
@onready var _hit_zone       : Area2D            = $HitZone
@onready var _head_bhz       : Area2D            = $BulletHitZone
@onready var _hit_sound      : AudioStreamPlayer = $HitSound
@onready var _fire_sound     : AudioStreamPlayer = $FireSound


# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_health       = max_health
	_bullet_scene = load("res://shared/Enemies/enemy_bullet.tscn")
	_prev_sampled = global_position
	_position_history.append(global_position)

	_hit_sound.stream  = load("res://assets/sounds/hit.mp3")
	_fire_sound.stream = load("res://assets/sounds/fire.mp3")

	_setup_head_sprite()
	_setup_body_segments()

	_detection_zone.body_entered.connect(_on_detection_body_entered)
	_detection_zone.body_exited.connect(_on_detection_body_exited)
	_hit_zone.body_entered.connect(_on_hit_zone_body_entered)
	_head_bhz.area_entered.connect(_on_head_bullet_hit)

	_alert_label.hide()


# ── Sprite setup ──────────────────────────────────────────────────────────────

func _setup_head_sprite() -> void:
	var tex : Texture2D = load("res://assets/enemies/boss/1.png")
	var frames := SpriteFrames.new()

	# "idle" — frame 0 (mouth closed). Used for all non-attack states.
	frames.add_animation("idle")
	frames.set_animation_loop("idle", true)
	frames.set_animation_speed("idle", 4.0)
	var a0 := AtlasTexture.new()
	a0.atlas  = tex
	a0.region = Rect2(0, 0, 96, 96)
	frames.add_frame("idle", a0)

	# "mouth" — frames 1–3 (mouth opening/open). Played before melee and ranged attacks.
	frames.add_animation("mouth")
	frames.set_animation_loop("mouth", false)
	frames.set_animation_speed("mouth", 10.0)
	for f in range(1, 4):
		var a := AtlasTexture.new()
		a.atlas  = tex
		a.region = Rect2(f * 96, 0, 96, 96)
		frames.add_frame("mouth", a)

	_head_sprite.sprite_frames = frames
	_head_sprite.z_index = 1  # render on top of body segments
	_head_sprite.play("idle")
	_head_sprite.animation_finished.connect(_on_head_anim_finished)


func _setup_body_segments() -> void:
	for i in NUM_SEGMENTS:
		var seg := Node2D.new()
		seg.name    = "Segment%d" % (i + 2)
		seg.z_index = 0

		var spr := Sprite2D.new()
		spr.texture = load("res://assets/enemies/boss/%d.png" % (i + 2))
		seg.add_child(spr)

		# Each segment can be hit by player bullets.
		# Layer 0 so zones don't detect each other when stacked at spawn.
		var bhz    := Area2D.new()
		bhz.collision_layer = 0
		bhz.collision_mask  = 4
		var cs     := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		# Segments taper toward the tail — slightly shrink the hit radius
		circle.radius = maxf(14.0, 22.0 - float(i) * 1.4)
		cs.shape = circle
		bhz.add_child(cs)
		bhz.area_entered.connect(_on_body_bullet_hit.bind(i))
		seg.add_child(bhz)

		add_child(seg)
		_segments.append(seg)


# ── Physics loop ──────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if not ai_enabled:
		return

	match _state:
		State.IDLE:          _tick_idle(delta)
		State.ALERT:         _tick_alert(delta)
		State.CHASE:         _tick_chase(delta)
		State.MELEE_WIND_UP: _tick_melee_wind_up(delta)
		State.MELEE_CHARGE:  _tick_melee_charge(delta)
		State.BACKING_OFF:   _tick_backing_off(delta)
		State.SHOOT_PREPARE: _tick_shoot_prepare(delta)
		State.SHOOTING:      _tick_shooting(delta)
		State.STUNNED:       _tick_stunned(delta)

	move_and_slide()
	_update_history()
	_update_body_positions()
	_update_head_rotation()


# ── State ticks ───────────────────────────────────────────────────────────────

func _tick_idle(_delta: float) -> void:
	velocity = Vector2.ZERO


func _tick_alert(delta: float) -> void:
	velocity = Vector2.ZERO
	_state_timer -= delta
	if _state_timer <= 0.0:
		_alert_label.hide()
		_enter_state(State.CHASE)


func _tick_chase(delta: float) -> void:
	# Re-acquire player from scene tree if reference went stale
	if not is_instance_valid(_player_ref):
		_player_ref = get_tree().get_first_node_in_group("player") as Node2D
		if _player_ref == null:
			return

	_slither_timer += delta

	var to_player := _player_ref.global_position - global_position
	var dist      := to_player.length()

	if dist > 0.1:
		var desired := to_player / dist
		var steered := _get_steered_dir(desired)
		var perp    := Vector2(-steered.y, steered.x)
		var wiggle  := sin(_slither_timer * SLITHER_FREQ * TAU) * SLITHER_AMPLITUDE
		var move_dir := (steered + perp * wiggle + _stuck_boost).normalized()
		velocity = velocity.move_toward(move_dir * chase_speed, 900.0 * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)

	_tick_stuck(delta)

	if dist < MELEE_TRIGGER_DIST:
		_enter_state(State.MELEE_WIND_UP)
		return

	_attack_timer -= delta
	if _attack_timer <= 0.0 and dist <= SHOOT_RANGE:
		_attack_timer = randf_range(3.5, 6.0)
		_enter_state(State.SHOOT_PREPARE)


func _tick_melee_wind_up(delta: float) -> void:
	if is_instance_valid(_player_ref):
		var dir := (_player_ref.global_position - global_position).normalized()
		velocity = velocity.move_toward(dir * chase_speed * 0.35, 700.0 * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 700.0 * delta)
	_state_timer -= delta
	if _state_timer <= 0.0:
		_enter_state(State.MELEE_CHARGE)


func _tick_melee_charge(delta: float) -> void:
	if is_instance_valid(_player_ref):
		var dir := (_player_ref.global_position - global_position).normalized()
		velocity = velocity.move_toward(dir * CHARGE_SPEED, 2200.0 * delta)
	_state_timer -= delta
	if _state_timer <= 0.0:
		_enter_state(State.BACKING_OFF)


func _tick_backing_off(delta: float) -> void:
	if is_instance_valid(_player_ref):
		var away := (global_position - _player_ref.global_position).normalized()
		velocity = velocity.move_toward(away * BACK_OFF_SPEED, 600.0 * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
	_state_timer -= delta
	if _state_timer <= 0.0:
		_enter_state(State.CHASE)


func _tick_shoot_prepare(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, 1400.0 * delta)
	_state_timer -= delta
	if _state_timer <= 0.0:
		_enter_state(State.SHOOTING)


func _tick_shooting(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)

	if _shoot_count > 0:
		_shoot_timer -= delta
		if _shoot_timer <= 0.0:
			_fire_bullet()
			_shoot_count -= 1
			_shoot_timer = SHOOT_BURST_DELAY
		return

	# All shots fired — resume chasing
	_head_sprite.play("idle")
	_enter_state(State.CHASE)


func _tick_stunned(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, 1600.0 * delta)
	_state_timer -= delta
	if _state_timer <= 0.0:
		_enter_state(State.CHASE if is_instance_valid(_player_ref) else State.IDLE)


# ── State transitions ─────────────────────────────────────────────────────────

func _enter_state(new_state: State) -> void:
	_state = new_state
	match new_state:
		State.IDLE:
			_player_ref = null
			_alert_label.hide()
			velocity = Vector2.ZERO
			_head_sprite.play("idle")

		State.ALERT:
			_state_timer = 0.55
			_alert_label.show()

		State.CHASE:
			_alert_label.hide()
			_head_sprite.play("idle")

		State.MELEE_WIND_UP:
			_state_timer = WIND_UP_DURATION
			_head_sprite.play("mouth")

		State.MELEE_CHARGE:
			_state_timer = CHARGE_DURATION
			# Keep mouth open (hold last frame of "mouth" animation)

		State.BACKING_OFF:
			_state_timer = BACK_OFF_DURATION
			_head_sprite.play("idle")

		State.SHOOT_PREPARE:
			_state_timer = SHOOT_PREPARE_DURATION
			_head_sprite.play("mouth")

		State.SHOOTING:
			_shoot_count = SHOOT_BURST_SIZE - 1
			_shoot_timer = SHOOT_BURST_DELAY
			_fire_bullet()  # First shot immediately

		State.STUNNED:
			_state_timer = stun_duration
			_head_sprite.play("idle")


# ── Detection / hit callbacks ─────────────────────────────────────────────────

func _on_detection_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_ref = body
	_ever_aggro  = true
	if _state == State.IDLE:
		_enter_state(State.ALERT)


func _on_detection_body_exited(body: Node2D) -> void:
	# Once the serpent has spotted the player it never loses track.
	if body == _player_ref and not _ever_aggro:
		_enter_state(State.IDLE)


func _on_hit_zone_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player") or _state != State.MELEE_CHARGE:
		return
	if body.has_method("take_damage"):
		body.take_damage(attack_damage)
		emit_signal("player_damaged", attack_damage)


func _on_head_bullet_hit(_area: Area2D) -> void:
	_take_damage(head_hit_dmg)


# Called by each body-segment BulletHitZone; _seg_index unused for now but
# available for future per-segment behaviour.
func _on_body_bullet_hit(_area: Area2D, _seg_index: int) -> void:
	_take_damage(body_hit_dmg)


func _on_head_anim_finished() -> void:
	# "mouth" animation holds its last frame — only auto-return to idle when
	# the boss is not in a state that needs the open mouth.
	if _state not in [
		State.MELEE_WIND_UP, State.MELEE_CHARGE,
		State.SHOOT_PREPARE, State.SHOOTING
	]:
		_head_sprite.play("idle")


# ── Damage / death ────────────────────────────────────────────────────────────

func _take_damage(amount: int) -> void:
	_hit_sound.play()
	_health -= amount
	if _health <= 0:
		_die()
		return

	var orig := modulate
	modulate = Color(1.6, 1.6, 1.6)
	create_tween().tween_property(self, "modulate", orig, 0.2)

	# Stun interrupts most states, but not an active charge
	if _state not in [State.STUNNED, State.MELEE_CHARGE]:
		_enter_state(State.STUNNED)

	if _player_ref == null:
		_player_ref = get_tree().get_first_node_in_group("player") as Node2D


func _die() -> void:
	# Detach BossBodyInteractable before freeing the boss so the level script
	# can enable it for the post-boss story sequence.
	var bbi := get_node_or_null("BossBodyInteractable")
	if is_instance_valid(bbi):
		bbi.reparent(get_parent(), true)  # keep_global_transform = true

	_spawn_death_vfx()

	var snd := AudioStreamPlayer.new()
	snd.stream = load("res://assets/sounds/mobdeath.mp3")
	snd.finished.connect(snd.queue_free)
	get_parent().add_child(snd)
	snd.play()

	emit_signal("died")
	queue_free()


func _spawn_death_vfx() -> void:
	var anim   := AnimatedSprite2D.new()
	var tex    : Texture2D = load("res://assets/vfx/enemy-death.png")
	var frames := SpriteFrames.new()
	frames.add_animation("death")
	frames.set_animation_loop("death", false)
	frames.set_animation_speed("death", 12.0)
	for i in 6:
		var atlas := AtlasTexture.new()
		atlas.atlas  = tex
		atlas.region = Rect2(i * 52, 0, 52, 53)
		frames.add_frame("death", atlas)
	anim.sprite_frames    = frames
	anim.global_position  = global_position
	anim.animation_finished.connect(anim.queue_free)
	get_parent().add_child(anim)
	anim.play("death")


# ── Projectile ────────────────────────────────────────────────────────────────

func _fire_bullet() -> void:
	if _bullet_scene == null or not is_instance_valid(_player_ref):
		return
	var b := _bullet_scene.instantiate()
	get_tree().current_scene.add_child(b)
	b.global_position = global_position
	b.direction       = (_player_ref.global_position - global_position).normalized()
	b.damage          = 1
	_fire_sound.play()
	var orig := modulate
	modulate = Color(1.5, 1.3, 0.5)
	create_tween().tween_property(self, "modulate", orig, 0.12)


# ── Wall navigation ───────────────────────────────────────────────────────────

# Cast 5 rays (0°, ±35°, ±70° from desired direction) and pick the one with
# the best clearance, penalising directions far from the goal.
func _get_steered_dir(desired: Vector2) -> Vector2:
	var space := get_world_2d().direct_space_state
	var rid   := get_rid()
	var probe := 88.0

	var best_dir   := desired
	var best_score := -INF

	for deg in [0, -35, 35, -70, 70]:
		var d := desired.rotated(deg_to_rad(float(deg)))
		var q := PhysicsRayQueryParameters2D.create(
				global_position, global_position + d * probe, 1)
		q.exclude = [rid]
		var hit       := space.intersect_ray(q)
		var clearance := probe if hit.is_empty() \
				else global_position.distance_to(hit["position"])
		var score := clearance - absf(float(deg)) * 0.45
		if score > best_score:
			best_score = score
			best_dir   = d

	return best_dir


# When the serpent is barely moving despite trying to chase, build up a random
# sideways boost so it can slide out of corners.
func _tick_stuck(delta: float) -> void:
	if velocity.length() < chase_speed * 0.22:
		_stuck_timer += delta
		if _stuck_timer > 0.45:
			_stuck_timer = 0.0
			var angle := randf_range(-PI * 0.55, PI * 0.55)
			_stuck_boost = Vector2(cos(angle), sin(angle)) * 0.6
	else:
		_stuck_timer = maxf(_stuck_timer - delta * 2.0, 0.0)
		_stuck_boost  = _stuck_boost.move_toward(Vector2.ZERO, delta * 2.5)


# ── Snake body ────────────────────────────────────────────────────────────────

func _update_history() -> void:
	# Record a sample every SAMPLE_DIST pixels moved, using an accumulator so
	# fast frames don't skip samples and slow frames don't record duplicates.
	var d := global_position.distance_to(_prev_sampled)
	_sample_accum  += d
	_prev_sampled   = global_position
	while _sample_accum >= SAMPLE_DIST:
		_sample_accum -= SAMPLE_DIST
		_position_history.push_front(global_position)
		if _position_history.size() > MAX_HISTORY:
			_position_history.pop_back()


func _update_body_positions() -> void:
	# push_front means index 0 = newest (head), index hist_len-1 = oldest.
	# When history is too short for a segment's index, fall back to index 0
	# (head position) so segments coil at the head rather than appearing at
	# the stale spawn position far across the map.
	var step     := int(SEGMENT_SPACING / SAMPLE_DIST)  # 20 samples per gap
	var hist_len := _position_history.size()
	if hist_len == 0:
		return

	for seg_i in _segments.size():
		var idx     := step * (seg_i + 1)
		var seg_pos := _position_history[idx] if idx < hist_len else _position_history[0]
		_segments[seg_i].global_position = seg_pos

		# Rotate so the segment faces toward the one ahead (toward head).
		# Sprite points down at rotation 0, so subtract PI/2 to align with direction.
		var ahead_idx := step * seg_i
		var ahead_pos := _position_history[ahead_idx] if ahead_idx < hist_len else _position_history[0]
		if seg_pos.distance_squared_to(ahead_pos) > 0.01:
			_segments[seg_i].rotation = (ahead_pos - seg_pos).angle() - PI / 2.0


func _update_head_rotation() -> void:
	if velocity.length_squared() <= 4.0:
		return
	var angle := velocity.angle()
	if cos(angle) >= 0.0:
		# Moving rightward: sprite faces down at rot=0, subtract PI/2 to face right.
		_head_sprite.flip_v = false
		_head_sprite.rotation = angle - PI / 2.0
	else:
		# Moving leftward: flip vertically so the head reads right-side-up,
		# then add PI/2 to align the flipped sprite with the velocity direction.
		_head_sprite.flip_v = true
		_head_sprite.rotation = angle + PI / 2.0
