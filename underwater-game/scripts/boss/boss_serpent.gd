# boss_serpent.gd
# Level 3 boss — the Serpent.
#
# Multi-segment snake entity. The head is a CharacterBody2D; six body segments
# (sprites 2–7) are Node2D children whose positions are driven by a
# position-history trail recorded from the head every physics frame.
#
# ── Phase overview ────────────────────────────────────────────────────────────
#   Phase 1  Boss starts invulnerable. Player activates both ArenaEnergyBeams
#            in level_3 → level calls make_vulnerable() → boss takes damage.
#            At 50% HP the PHASE_TRANSITION state fires.
#
#   Transition  Boss returns to arena_center, glows blue, becomes invulnerable.
#               Emits phase_2_started → level_3 resets the beams.
#
#   Phase 2  Player must activate both beams again. Now the ranged attack fires
#            a ring of homing bullets that lock onto the player then travel
#            straight (dodgeable by moving after the lock).
#
# Signal contract required by level_3.gd:
#   signal died            — emitted the moment health hits zero (before queue_free)
#   signal phase_2_started — emitted when transition completes; level resets beams

class_name BossSerpent
extends CharacterBody2D

signal died
signal player_damaged(amount: int)
signal phase_2_started
signal window_consumed   ## Fired when the 30-HP damage cap is hit; beams must reset
signal health_changed(current: int, maximum: int)
signal vulnerability_changed(is_vulnerable: bool)
signal became_visible
signal became_hidden

# ── Exports ───────────────────────────────────────────────────────────────────
@export var ai_enabled    : bool  = true
@export var max_health    : int   = 100
@export var chase_speed   : float = 165.0
@export var stun_duration : float = 0.15
@export var attack_damage : int   = 1
@export var head_hit_dmg  : int   = 1
@export var body_hit_dmg  : int   = 2

## World-space centre of the boss arena. Set in the inspector to the middle of
## the room. The boss retreats here during PHASE_TRANSITION.
@export var arena_center  : Vector2 = Vector2.ZERO
## Radius from arena_center at which summoned minions spawn.
@export var arena_radius  : float   = 500.0

# ── Snake body ────────────────────────────────────────────────────────────────
const NUM_SEGMENTS    : int   = 6
const SEGMENT_SPACING : float = 40.0
const SAMPLE_DIST     : float = 2.0
const MAX_HISTORY     : int   = 200

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
const SLITHER_FREQ           : float = 2.2
const SLITHER_AMPLITUDE      : float = 0.18

# Per-vulnerability-window damage cap
const VULN_DAMAGE_CAP : int = 30

# Phase 2 homing ring
const HOMING_COUNT         : int   = 8     # bullets spawned in a circle
const HOMING_PREPARE_DUR   : float = 1.2   # wind-up before ring fires
const HOMING_LOCK_DURATION : float = 0.9   # seconds each bullet tracks before going straight
const HOMING_SPAWN_RADIUS  : float = 55.0  # radius of the spawn circle around head

# Phase transition
const PHASE_TRANS_MOVE_SPEED  : float = 220.0
const PHASE_TRANS_ARRIVE_DIST : float = 18.0
const PHASE_TRANS_GLOW_DUR    : float = 2.2

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
	PHASE_TRANSITION,
	HOMING_SHOOT_PREPARE,
	HOMING_SHOOTING,
	RESHIELD_MOVE,
}
var _state       : State = State.IDLE
var _state_timer : float = 0.0
var _health      : int

# ── Phase / invulnerability ───────────────────────────────────────────────────
var _is_invulnerable   : bool  = true   # cleared by make_vulnerable()
var _is_phase_2        : bool  = false
var _phase_2_triggered : bool  = false  # guard against double-trigger
var _summon_triggered  : bool  = false  # guard against double-summon
var _invuln_pulse_t    : float = 0.0

# Phase transition sub-stage: 0 = moving to centre, 1 = glowing at centre
var _trans_stage : int = 0

# ── Runtime state ─────────────────────────────────────────────────────────────
var _player_ref   : Node2D     = null
var _bullet_scene  : PackedScene
var _homing_scene  : PackedScene
var _minion_scene  : PackedScene
var _ever_aggro   : bool = false

var _vuln_damage_in_window : int   = 0
var _attack_timer          : float = 2.5
var _shoot_count          : int   = 0
var _shoot_timer          : float = 0.0
var _slither_timer        : float = 0.0
var _periodic_shoot_timer : float = 5.0

# ── Line-of-sight tracking ────────────────────────────────────────────────────
var _player_in_range : bool  = false  # player is inside the detection zone
var _los_check_timer : float = 0.0    # polls LOS while player is in range but unseen

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
	_health        = max_health
	_bullet_scene  = load("res://shared/Enemies/enemy_bullet.tscn")
	_homing_scene  = load("res://scripts/boss/homing_bullet.tscn")
	_minion_scene  = load("res://shared/Enemies/enemy_ranged.tscn")
	_prev_sampled  = global_position
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
	_apply_invuln_tint()

	# Screen-presence notifier so the HUD can show/hide with the boss
	var notifier := VisibleOnScreenNotifier2D.new()
	notifier.rect = Rect2(-220, -220, 440, 440)
	add_child(notifier)
	notifier.screen_entered.connect(func(): became_visible.emit())
	notifier.screen_exited.connect(func(): became_hidden.emit())

	emit_signal("health_changed", _health, max_health)
	emit_signal("vulnerability_changed", _is_invulnerable)


# ── Public API ────────────────────────────────────────────────────────────────

## Called by level_3.gd when both ArenaEnergyBeams are simultaneously primed.
func make_vulnerable() -> void:
	if not _is_invulnerable:
		return
	_is_invulnerable = false
	_vuln_damage_in_window = 0
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.4)
	emit_signal("vulnerability_changed", false)


# ── Sprite setup ──────────────────────────────────────────────────────────────

func _setup_head_sprite() -> void:
	var tex : Texture2D = load("res://assets/enemies/boss/1.png")
	var frames := SpriteFrames.new()

	frames.add_animation("idle")
	frames.set_animation_loop("idle", true)
	frames.set_animation_speed("idle", 4.0)
	var a0 := AtlasTexture.new()
	a0.atlas  = tex
	a0.region = Rect2(0, 0, 96, 96)
	frames.add_frame("idle", a0)

	frames.add_animation("mouth")
	frames.set_animation_loop("mouth", false)
	frames.set_animation_speed("mouth", 10.0)
	for f in range(1, 4):
		var a := AtlasTexture.new()
		a.atlas  = tex
		a.region = Rect2(f * 96, 0, 96, 96)
		frames.add_frame("mouth", a)

	_head_sprite.sprite_frames = frames
	_head_sprite.z_index = 1
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

		var bhz    := Area2D.new()
		bhz.collision_layer = 0
		bhz.collision_mask  = 4
		var cs     := CollisionShape2D.new()
		var circle := CircleShape2D.new()
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

	_tick_invuln_pulse(delta)
	_tick_periodic_shoot(delta)
	_tick_los_check(delta)

	match _state:
		State.IDLE:                 _tick_idle(delta)
		State.ALERT:                _tick_alert(delta)
		State.CHASE:                _tick_chase(delta)
		State.MELEE_WIND_UP:        _tick_melee_wind_up(delta)
		State.MELEE_CHARGE:         _tick_melee_charge(delta)
		State.BACKING_OFF:          _tick_backing_off(delta)
		State.SHOOT_PREPARE:        _tick_shoot_prepare(delta)
		State.SHOOTING:             _tick_shooting(delta)
		State.STUNNED:              _tick_stunned(delta)
		State.PHASE_TRANSITION:     _tick_phase_transition(delta)
		State.HOMING_SHOOT_PREPARE: _tick_homing_shoot_prepare(delta)
		State.HOMING_SHOOTING:      _tick_homing_shooting(delta)
		State.RESHIELD_MOVE:        _tick_reshield_move(delta)

	move_and_slide()
	_update_history()
	_update_body_positions()
	_update_head_rotation()


# ── Invulnerability visual ────────────────────────────────────────────────────

func _apply_invuln_tint() -> void:
	modulate = Color(0.45, 0.75, 1.4)


func _tick_invuln_pulse(delta: float) -> void:
	if not _is_invulnerable or _state == State.PHASE_TRANSITION:
		return
	_invuln_pulse_t += delta
	var p := 0.12 * sin(_invuln_pulse_t * 4.5)
	modulate = Color(0.45 + p, 0.75 + p, 1.4 + p * 0.5)


func _tick_periodic_shoot(delta: float) -> void:
	_periodic_shoot_timer -= delta
	if _periodic_shoot_timer > 0.0:
		return
	const INTERRUPTIBLE := [State.IDLE, State.ALERT, State.CHASE, State.BACKING_OFF, State.STUNNED]
	if _state not in INTERRUPTIBLE or not _ever_aggro or not is_instance_valid(_player_ref):
		_periodic_shoot_timer = 0.5  # retry soon
		return
	_periodic_shoot_timer = 5.0
	_enter_state(State.HOMING_SHOOT_PREPARE if _is_phase_2 else State.SHOOT_PREPARE)


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
	if not is_instance_valid(_player_ref):
		_player_ref = get_tree().get_first_node_in_group("player") as Node2D
		if _player_ref == null:
			return

	_slither_timer += delta

	var to_player := _player_ref.global_position - global_position
	var dist      := to_player.length()

	if dist > 0.1:
		var desired  := to_player / dist
		var steered  := _get_steered_dir(desired)
		var perp     := Vector2(-steered.y, steered.x)
		var wiggle   := sin(_slither_timer * SLITHER_FREQ * TAU) * SLITHER_AMPLITUDE
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
		_enter_state(State.HOMING_SHOOT_PREPARE if _is_phase_2 else State.SHOOT_PREPARE)


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

	_head_sprite.play("idle")
	_enter_state(State.CHASE)


func _tick_stunned(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, 1600.0 * delta)
	_state_timer -= delta
	if _state_timer <= 0.0:
		_enter_state(State.CHASE if is_instance_valid(_player_ref) else State.IDLE)


func _tick_phase_transition(delta: float) -> void:
	if _trans_stage == 0:
		# Move toward arena centre
		var to_centre := arena_center - global_position
		if to_centre.length() > PHASE_TRANS_ARRIVE_DIST:
			velocity = velocity.move_toward(
					to_centre.normalized() * PHASE_TRANS_MOVE_SPEED, 1800.0 * delta)
		else:
			velocity           = Vector2.ZERO
			global_position    = arena_center
			_trans_stage       = 1
			_state_timer       = PHASE_TRANS_GLOW_DUR
			_start_glow_tween()
	else:
		# Glow at centre
		velocity = Vector2.ZERO
		_state_timer -= delta
		if _state_timer <= 0.0:
			_finish_phase_transition()


func _tick_homing_shoot_prepare(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, 1400.0 * delta)
	_state_timer -= delta
	if _state_timer <= 0.0:
		_enter_state(State.HOMING_SHOOTING)


func _tick_homing_shooting(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
	_state_timer -= delta
	if _state_timer <= 0.0:
		_head_sprite.play("idle")
		_enter_state(State.CHASE)


func _tick_reshield_move(delta: float) -> void:
	var to_centre := arena_center - global_position
	if to_centre.length() > PHASE_TRANS_ARRIVE_DIST:
		velocity = velocity.move_toward(
				to_centre.normalized() * PHASE_TRANS_MOVE_SPEED, 1800.0 * delta)
	else:
		velocity           = Vector2.ZERO
		global_position    = arena_center
		_enter_state(State.CHASE)


# ── Phase transition helpers ──────────────────────────────────────────────────

func _start_glow_tween() -> void:
	var tw := create_tween().set_loops()
	tw.tween_property(self, "modulate", Color(0.5, 0.85, 2.0), 0.4)
	tw.tween_property(self, "modulate", Color(0.2, 0.55, 1.5), 0.4)


func _finish_phase_transition() -> void:
	_apply_invuln_tint()
	_is_phase_2    = true
	_attack_timer  = randf_range(1.5, 3.0)
	emit_signal("phase_2_started")
	_enter_state(State.CHASE)


# ── State transitions ─────────────────────────────────────────────────────────

func _enter_state(new_state: State) -> void:
	_state = new_state
	match new_state:
		State.IDLE:
			# Keep _player_ref if the player is still inside the detection zone
			# so the LOS poller can still see them.
			if not _player_in_range:
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

		State.BACKING_OFF:
			_state_timer = BACK_OFF_DURATION
			_head_sprite.play("idle")

		State.SHOOT_PREPARE:
			_state_timer = SHOOT_PREPARE_DURATION
			_head_sprite.play("mouth")

		State.SHOOTING:
			_shoot_count = SHOOT_BURST_SIZE - 1
			_shoot_timer = SHOOT_BURST_DELAY
			_fire_bullet()

		State.STUNNED:
			_state_timer = stun_duration
			_head_sprite.play("idle")

		State.PHASE_TRANSITION:
			_trans_stage     = 0
			_is_invulnerable = true
			_apply_invuln_tint()
			emit_signal("vulnerability_changed", true)

		State.HOMING_SHOOT_PREPARE:
			_state_timer = HOMING_PREPARE_DUR
			_head_sprite.play("mouth")

		State.HOMING_SHOOTING:
			# Linger long enough for bullets to complete their lock and travel
			_state_timer = HOMING_LOCK_DURATION + 0.5
			_spawn_homing_ring()

		State.RESHIELD_MOVE:
			_head_sprite.play("idle")


# ── Line-of-sight ─────────────────────────────────────────────────────────────

## Returns true if there is a clear straight line from the boss to the player
## with no wall (collision layer 1) in between.
func _has_los_to_player() -> bool:
	if not is_instance_valid(_player_ref):
		return false
	var space := get_world_2d().direct_space_state
	var q     := PhysicsRayQueryParameters2D.create(
			global_position, _player_ref.global_position, 1)  # layer 1 = walls
	q.exclude = [get_rid()]
	return space.intersect_ray(q).is_empty()


## Polls LOS while the player is in detection range but the boss hasn't
## aggroed yet (e.g. player entered zone from behind a wall).
func _tick_los_check(delta: float) -> void:
	if _ever_aggro or not _player_in_range or _state != State.IDLE:
		return
	_los_check_timer -= delta
	if _los_check_timer > 0.0:
		return
	_los_check_timer = 0.25
	if _has_los_to_player():
		_ever_aggro = true
		_enter_state(State.ALERT)


# ── Detection / hit callbacks ─────────────────────────────────────────────────

func _on_detection_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_ref      = body
	_player_in_range = true
	if _ever_aggro:
		# Already knows the player — resume chase if currently idle
		if _state == State.IDLE:
			_enter_state(State.ALERT)
	elif _has_los_to_player():
		# First sighting — only aggro if there's a clear line of sight
		_ever_aggro = true
		_enter_state(State.ALERT)
	# else: player is in range but blocked by a wall; _tick_los_check will poll


func _on_detection_body_exited(body: Node2D) -> void:
	if body != _player_ref:
		return
	_player_in_range = false
	if not _ever_aggro:
		_player_ref = null
		# Already in IDLE — nothing else to do


func _on_hit_zone_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player") or _state != State.MELEE_CHARGE:
		return
	if body.has_method("take_damage"):
		body.take_damage(attack_damage)
		emit_signal("player_damaged", attack_damage)


func _on_head_bullet_hit(area: Area2D) -> void:
	var bullet := area.get_parent()
	if not is_instance_valid(bullet):
		return
	if _is_invulnerable:
		bullet.queue_free()
		_flash_shield()
		return
	_take_damage(head_hit_dmg)
	bullet.queue_free()


func _on_body_bullet_hit(area: Area2D, _seg_index: int) -> void:
	var bullet := area.get_parent()
	if not is_instance_valid(bullet):
		return
	if _is_invulnerable:
		bullet.queue_free()
		_flash_shield()
		return
	_take_damage(body_hit_dmg)
	bullet.queue_free()


func _on_head_anim_finished() -> void:
	if _state not in [
		State.MELEE_WIND_UP, State.MELEE_CHARGE,
		State.SHOOT_PREPARE, State.SHOOTING,
		State.HOMING_SHOOT_PREPARE, State.HOMING_SHOOTING,
	]:
		_head_sprite.play("idle")


# ── Damage / death ────────────────────────────────────────────────────────────

func _flash_shield() -> void:
	var orig := modulate
	modulate = Color(1.8, 1.8, 2.2)
	create_tween().tween_property(self, "modulate", orig, 0.15)


func _take_damage(amount: int) -> void:
	_hit_sound.play()
	_health -= amount
	_vuln_damage_in_window += amount
	emit_signal("health_changed", maxi(_health, 0), max_health)

	# Phase 2 trigger at 70 HP — clamp so transition always fires exactly here
	if not _phase_2_triggered and _health <= 70:
		_phase_2_triggered = true
		_health = 70
		_enter_state(State.PHASE_TRANSITION)
		return

	# Summon allies at 40 HP
	if not _summon_triggered and _health <= 40:
		_summon_triggered = true
		_spawn_minions(5)

	if _health <= 0:
		_die()
		return

	# Re-shield once the 30-HP window is consumed; clamp excess damage
	if _vuln_damage_in_window >= VULN_DAMAGE_CAP:
		var excess := _vuln_damage_in_window - VULN_DAMAGE_CAP
		_health               += excess
		_vuln_damage_in_window = VULN_DAMAGE_CAP
		emit_signal("health_changed", maxi(_health, 0), max_health)
		_is_invulnerable = true
		_apply_invuln_tint()
		emit_signal("window_consumed")
		emit_signal("vulnerability_changed", true)
		_enter_state(State.RESHIELD_MOVE)
		return

	var orig := modulate
	modulate = Color(1.6, 1.6, 1.6)
	create_tween().tween_property(self, "modulate", orig, 0.2)

	if _state not in [State.STUNNED, State.MELEE_CHARGE, State.PHASE_TRANSITION, State.RESHIELD_MOVE]:
		_enter_state(State.STUNNED)

	if _player_ref == null:
		_player_ref = get_tree().get_first_node_in_group("player") as Node2D


func _die() -> void:
	var bbi := get_node_or_null("BossBodyInteractable")
	if is_instance_valid(bbi):
		bbi.reparent(get_parent(), true)

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


# ── Projectiles ───────────────────────────────────────────────────────────────

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


func _spawn_homing_ring() -> void:
	if _homing_scene == null:
		return
	_fire_sound.play()
	for i in HOMING_COUNT:
		var angle  := (TAU / HOMING_COUNT) * i
		var offset := Vector2(cos(angle), sin(angle)) * HOMING_SPAWN_RADIUS
		var b      := _homing_scene.instantiate()
		get_tree().current_scene.add_child(b)
		b.global_position = global_position + offset
		b.lock_duration   = HOMING_LOCK_DURATION
		b.damage          = 1


func _spawn_minions(count: int) -> void:
	if _minion_scene == null:
		return
	var scene_root   := get_tree().current_scene
	var player       := get_tree().get_first_node_in_group("player") as Node2D
	var origin       := arena_center if arena_center != Vector2.ZERO else global_position
	var angle_step   := TAU / count
	var angle_offset := randf() * TAU
	for i in count:
		var angle := angle_offset + angle_step * i
		var m     := _minion_scene.instantiate()
		scene_root.add_child(m)
		m.global_position = origin + Vector2(cos(angle), sin(angle)) * arena_radius
		# Force-aggro so minions attack immediately without waiting for detection
		if is_instance_valid(player):
			m.set("_player_ref", player)
			m.call("_enter_state", Enemy.State.CHASE)


# ── Wall navigation ───────────────────────────────────────────────────────────

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
	var d := global_position.distance_to(_prev_sampled)
	_sample_accum  += d
	_prev_sampled   = global_position
	while _sample_accum >= SAMPLE_DIST:
		_sample_accum -= SAMPLE_DIST
		_position_history.push_front(global_position)
		if _position_history.size() > MAX_HISTORY:
			_position_history.pop_back()


func _update_body_positions() -> void:
	var hist_len := _position_history.size()
	if hist_len == 0:
		return

	var world_pos : Array[Vector2] = []
	world_pos.resize(_segments.size() + 1)
	world_pos[0] = global_position

	for seg_i in _segments.size():
		var target_dist := SEGMENT_SPACING * float(seg_i + 1)
		var float_idx   := (target_dist - _sample_accum) / SAMPLE_DIST
		var base        := int(float_idx)
		var t           := float_idx - float(base)

		var p0 := _position_history[base]     if base     < hist_len else _position_history[0]
		var p1 := _position_history[base + 1] if base + 1 < hist_len else p0
		world_pos[seg_i + 1] = p0.lerp(p1, t)

	for seg_i in _segments.size():
		_segments[seg_i].global_position = world_pos[seg_i + 1]
		var ahead := world_pos[seg_i]
		var here  := world_pos[seg_i + 1]
		if here.distance_squared_to(ahead) > 0.01:
			_segments[seg_i].rotation = (ahead - here).angle() - PI / 2.0


func _update_head_rotation() -> void:
	if velocity.length_squared() <= 4.0:
		return
	var angle := velocity.angle()
	if cos(angle) >= 0.0:
		_head_sprite.flip_v = false
		_head_sprite.rotation = angle - PI / 2.0
	else:
		_head_sprite.flip_v = true
		_head_sprite.rotation = angle + PI / 2.0
