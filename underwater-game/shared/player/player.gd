extends CharacterBody2D

# ── Movement ──────────────────────────────────────────────────────────────────
const SWIM_SPEED   : float = 200.0
const ACCELERATION : float = 480.0
# Water drag coefficients (exponential decay): velocity *= exp(-coeff * delta)
const SWIM_DRAG    : float = 3.8    # drag when coasting (no input)

# ── Submarine driving ─────────────────────────────────────────────────────────
const SUB_SPEED    : float = 140.0  # heavier, slower
const SUB_ACCEL    : float = 105.0  # sluggish build-up
# Exponential drag for submarine (drifts much longer than free-swimming)
const SUB_RESIST   : float = 0.18   # light resistance while thrusting
const SUB_DRAG     : float = 1.1    # coasting drag — vessel drifts noticeably

var submarine_mode : bool = false
var _swim_dir      : Vector2 = Vector2.ZERO  # smoothed input direction for curved turns
var _sub_sprite    : AnimatedSprite2D = null  # set by level when boarding

# ── Health ────────────────────────────────────────────────────────────────────
const MAX_HEALTH : int = 5
var health       : int = MAX_HEALTH

signal health_changed(current: int, maximum: int)

# ── Oxygen ────────────────────────────────────────────────────────────────────
const MAX_OXYGEN        : float = 90.0  # seconds of air at a full tank
const OXYGEN_DRAIN_RATE : float = 1.0   # units drained per second while free-swimming
const OXYGEN_WARN_LOW   : float = 22.5  # 25% — first ORCA warning
const OXYGEN_WARN_CRIT  : float = 9.0   # 10% — critical ORCA warning

var oxygen : float = MAX_OXYGEN

## Emitted whenever the oxygen level changes (also fires once on _ready).
signal oxygen_changed(current: float, maximum: float)
## Emitted when poison state changes (true = currently being poisoned).
signal poison_changed(is_poisoned: bool)

var _poison_sources: int = 0

var _oxygen_warned_low  : bool = false
var _oxygen_warned_crit : bool = false

# ── Battery / Flashlight ──────────────────────────────────────────────────────
const MAX_BATTERY        : float = 120.0  # seconds at full charge
const BATTERY_DRAIN_RATE : float = 1.0    # units per second while light is on
const BATTERY_WARN_LOW   : float = 30.0   # 25 % — first ORCA warning
const BATTERY_WARN_CRIT  : float = 12.0   # 10 % — critical ORCA warning

var battery       : float = MAX_BATTERY
var _light_on     : bool  = true
var _flicker_timer: float = 0.0

## Emitted whenever the battery level changes (also fires once on _ready).
signal battery_changed(current: float, maximum: float)

var _battery_warned_low  : bool = false
var _battery_warned_crit : bool = false

# ── Weapon ────────────────────────────────────────────────────────────────────
const DEFAULT_WEAPON : WeaponData = preload("res://shared/weapons/pistol.tres")

## Set false in levels where the player should start unarmed.
@export var start_armed : bool = true

var current_weapon : WeaponData = null
var _weapons       : Array      = []   # ordered list of collected WeaponData

## Emitted whenever the equipped weapon changes.
signal weapon_changed(weapon_name: String)

# ── Internal ──────────────────────────────────────────────────────────────────
@onready var _camera           : Camera2D         = $Camera2D
@onready var cone_light        : PointLight2D    = $ConeLight
@onready var muzzle_flash      : PointLight2D    = $MuzzleFlash
@onready var _sprite           : AnimatedSprite2D = $Sprite
@onready var _swim_trail       : CPUParticles2D   = $SwimTrail
@onready var _sub_trail        : CPUParticles2D   = $SubTrail
@onready var _interaction_prompt : Label          = $InteractionPromptLayer/PromptLabel

var _fire_timer        : float  = 0.0
var _hurt_timer        : float  = 0.0   # counts down while hurt animation plays
var _pre_dialogue_pos  : Vector2

var _fire_sound  : AudioStreamPlayer
var _death_sound : AudioStreamPlayer
var _hurt_overlay : ColorRect
var _desat_rect   : ColorRect = null


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_fire_sound = AudioStreamPlayer.new()
	_fire_sound.stream = load("res://assets/sounds/fire.mp3")
	add_child(_fire_sound)

	_death_sound = AudioStreamPlayer.new()
	_death_sound.stream = load("res://assets/sounds/death.mp3")
	add_child(_death_sound)

	var desat_cl := CanvasLayer.new()
	desat_cl.layer = 88
	_desat_rect = ColorRect.new()
	_desat_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_desat_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var _shader := Shader.new()
	_shader.code = "shader_type canvas_item;\nuniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;\nuniform float desaturation : hint_range(0.0, 1.0) = 0.0;\nvoid fragment() {\n\tvec4 col = textureLod(SCREEN_TEXTURE, SCREEN_UV, 0.0);\n\tfloat gray = dot(col.rgb, vec3(0.299, 0.587, 0.114));\n\tCOLOR = vec4(mix(col.rgb, vec3(gray), desaturation), col.a);\n}"
	var _mat := ShaderMaterial.new()
	_mat.shader = _shader
	_desat_rect.material = _mat
	desat_cl.add_child(_desat_rect)
	add_child(desat_cl)

	var cl := CanvasLayer.new()
	cl.layer = 90
	_hurt_overlay = ColorRect.new()
	_hurt_overlay.color = Color(1.0, 0.0, 0.0, 0.0)
	_hurt_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hurt_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(_hurt_overlay)
	add_child(cl)

	Inventory.item_added.connect(func(item, qty):
		print("Picked up: ", item.display_name, " x", qty)
	)
	if start_armed:
		equip_weapon(DEFAULT_WEAPON)
	emit_signal("health_changed", health, MAX_HEALTH)
	emit_signal("oxygen_changed", oxygen, MAX_OXYGEN)
	emit_signal("battery_changed", battery, MAX_BATTERY)
	if current_weapon != null:
		emit_signal("weapon_changed", current_weapon.display_name)
	_setup_sprite()
	_setup_particle_trails()
	_setup_interaction_prompt()
	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)


func _on_dialogue_started() -> void:
	_pre_dialogue_pos = global_position
	velocity = Vector2.ZERO
	set_physics_process(false)
	set_process_unhandled_input(false)


func _on_dialogue_ended() -> void:
	global_position = _pre_dialogue_pos
	set_physics_process(true)
	set_process_unhandled_input(true)


func _setup_sprite() -> void:
	var frames := SpriteFrames.new()

	var idle_tex : Texture2D = preload("res://assets/player/player-idle.png")
	var swim_tex : Texture2D = preload("res://assets/player/player-swiming.png")
	var hurt_tex : Texture2D = preload("res://assets/player/player-hurt.png")

	_build_anim(frames, "idle", idle_tex, 6,  8.0, true)
	_build_anim(frames, "swim", swim_tex, 7, 10.0, true)
	_build_anim(frames, "hurt", hurt_tex, 5, 12.0, false)

	_sprite.sprite_frames = frames
	_sprite.play("idle")


func _setup_particle_trails() -> void:
	# No texture is defined in the scene, so particles render as invisible 1×1 squares.
	# Build an 8×8 soft-circle texture at runtime so the bubbles are actually visible.
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	for y in 8:
		for x in 8:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(4.0, 4.0))
			var a := clampf(1.0 - d / 4.0, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a * a))
	var tex := ImageTexture.create_from_image(img)
	_swim_trail.texture = tex
	_sub_trail.texture  = tex


func _setup_interaction_prompt() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Consolas", "Courier New", "monospace"])
	_interaction_prompt.add_theme_font_override("font", font)
	_interaction_prompt.add_theme_font_size_override("font_size", 14)
	_interaction_prompt.add_theme_color_override("font_color", Color(0.28, 0.82, 1.0, 1.0))

	var isys := $InteractionSystem as InteractionSystem
	isys.interactable_focused.connect(_on_interactable_focused)
	isys.interactable_unfocused.connect(_on_interactable_unfocused)

	DialogueManager.dialogue_started.connect(func(): _interaction_prompt.hide())
	DialogueManager.dialogue_ended.connect(func():
		if $InteractionSystem.get_current_interactable() != null:
			_interaction_prompt.show()
	)


func _on_interactable_focused(interactable: Interactable) -> void:
	_interaction_prompt.text = "[%s]  %s" % [interactable.interaction_key, interactable.interaction_label]
	if not DialogueManager.is_active:
		_interaction_prompt.show()


func _on_interactable_unfocused() -> void:
	_interaction_prompt.hide()


func _build_anim(frames: SpriteFrames, anim: String, sheet: Texture2D,
		count: int, fps: float, loop: bool) -> void:
	frames.add_animation(anim)
	frames.set_animation_loop(anim, loop)
	frames.set_animation_speed(anim, fps)
	for i in count:
		var atlas := AtlasTexture.new()
		atlas.atlas  = sheet
		atlas.region = Rect2(i * 80, 0, 80, 80)
		frames.add_frame(anim, atlas)


# ── Submarine mode ────────────────────────────────────────────────────────────

## Called by the level once the player boards the submarine.
func enter_submarine_mode() -> void:
	submarine_mode = true
	oxygen = MAX_OXYGEN
	emit_signal("oxygen_changed", oxygen, MAX_OXYGEN)
	_sprite.hide()
	$InteractionZone.monitoring = false   # no interactions while piloting


# ── Physics (movement) ────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	var input_dir := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)

	if submarine_mode:
		# Heavy vessel: slow thrust build-up, long glide after engines cut
		if input_dir.length() > 0.0:
			velocity = velocity.move_toward(
				input_dir.normalized() * SUB_SPEED, SUB_ACCEL * delta
			)
			velocity *= exp(-SUB_RESIST * delta)  # water pushes back while thrusting
		else:
			velocity *= exp(-SUB_DRAG * delta)    # smooth exponential coast-to-stop
		velocity = velocity.limit_length(SUB_SPEED)
	else:
		if input_dir.length() > 0.0:
			# Blend toward the new input direction so sharp pivots curve naturally
			_swim_dir = _swim_dir.lerp(input_dir.normalized(), 12.0 * delta)
			velocity = velocity.move_toward(_swim_dir * SWIM_SPEED, ACCELERATION * delta)
		else:
			_swim_dir = Vector2.ZERO
			velocity *= exp(-SWIM_DRAG * delta)    # glide to a stop, not a snap
		velocity = velocity.limit_length(SWIM_SPEED)

	move_and_slide()
	_update_trails()

	# Rotate the submarine sprite to face the direction of travel.
	if submarine_mode and _sub_sprite != null:
		var is_moving := velocity.length() > 8.0
		if is_moving:
			var angle := velocity.angle()
			if cos(angle) >= 0.0:
				_sub_sprite.flip_h = false
				_sub_sprite.rotation = angle
			else:
				_sub_sprite.flip_h = true
				var mirrored := (PI - angle) if angle > 0.0 else (-PI - angle)
				_sub_sprite.rotation = -mirrored
		else:
			_sub_sprite.rotation = 0.0
			_sub_sprite.flip_h = false

	# Aim the cone light at the mouse cursor with a slight lag.
	var to_mouse := get_global_mouse_position() - global_position
	if to_mouse.length() > 1.0:
		cone_light.rotation = lerp_angle(cone_light.rotation, to_mouse.angle(), 7.0 * delta)
		cone_light.position = Vector2.from_angle(cone_light.rotation) * 5.0

	# Drive sprite animation and facing (only in free-swim)
	if not submarine_mode:
		var is_moving := velocity.length() > 8.0
		var target_anim := "swim" if is_moving else "idle"
		if _hurt_timer > 0.0:
			_hurt_timer -= delta   # let hurt animation finish before switching
		elif _sprite.animation != target_anim:
			_sprite.play(target_anim)
		# Rotate sprite to match velocity direction.
		# When moving leftward we flip_h and mirror the angle so the sprite
		# never appears upside-down.
		if is_moving:
			var angle := velocity.angle()
			if cos(angle) >= 0.0:
				# Rightward half: rotate directly.
				_sprite.flip_h = false
				_sprite.rotation = angle
			else:
				# Leftward half: flip, then negate the mirrored angle.
				# flip_h reverses the visual rotation direction, so without the
				# negation up-left and down-left appear swapped.
				_sprite.flip_h = true
				var mirrored := (PI - angle) if angle > 0.0 else (-PI - angle)
				_sprite.rotation = -mirrored
		else:
			_sprite.rotation = 0.0
			_sprite.flip_h = false

	# Drain oxygen while free-swimming (sub is pressurised; dialogue pauses drain)
	if not submarine_mode:
		oxygen = maxf(0.0, oxygen - OXYGEN_DRAIN_RATE * delta)
		emit_signal("oxygen_changed", oxygen, MAX_OXYGEN)
		_check_oxygen_warnings()
		if oxygen <= 0.0:
			_die_oxygen()
			return

	# Drain flashlight battery while free-swimming with light on
	# (submarine has its own power supply)
	if not submarine_mode and _light_on:
		battery = maxf(0.0, battery - BATTERY_DRAIN_RATE * delta)
		emit_signal("battery_changed", battery, MAX_BATTERY)
		_check_battery_warnings()
		_update_cone_light(delta)
		if battery <= 0.0:
			_light_on = false
			cone_light.visible = false

	# Count down fire cooldown and auto-fire while LMB is held
	if _fire_timer > 0.0:
		_fire_timer -= delta
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_fire()


# ── Input (shooting) ──────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_light"):
		if battery > 0.0:
			_light_on = not _light_on
			cone_light.visible = _light_on
	if event.is_action_pressed("swap_weapon") and _weapons.size() > 1:
		var idx := (_weapons.find(current_weapon) + 1) % _weapons.size()
		equip_weapon(_weapons[idx])


# ── Weapon logic ──────────────────────────────────────────────────────────────

func equip_weapon(weapon: WeaponData) -> void:
	current_weapon = weapon
	if not _weapons.has(weapon):
		_weapons.append(weapon)
	emit_signal("weapon_changed", weapon.display_name)


func _fire() -> void:
	# Block fire during active dialogue or while piloting the submarine
	if DialogueManager.is_active or submarine_mode or current_weapon == null:
		return
	if _fire_timer > 0.0:
		return

	var aim_dir    := (get_global_mouse_position() - global_position).normalized()
	var base_angle := aim_dir.angle()
	var count      := current_weapon.bullet_count
	# For count=1, step=0 so start=base_angle and only one bullet fires dead-centre
	var step       : float = deg_to_rad(current_weapon.spread_angle) / max(count - 1, 1)
	var start      := base_angle - step * (count - 1) / 2.0

	for i in count:
		var angle  := start + step * i
		var dir    := Vector2.from_angle(angle)
		var bullet := current_weapon.bullet_scene.instantiate()
		bullet.global_position = global_position + dir * current_weapon.bullet_offset
		bullet.rotation        = angle
		bullet.direction       = dir
		get_parent().add_child(bullet)

	_fire_sound.play()
	_shake_camera()

	muzzle_flash.position = aim_dir * current_weapon.bullet_offset
	muzzle_flash.energy   = 4.0
	var _mf := create_tween()
	_mf.tween_property(muzzle_flash, "energy", 0.0, 0.1)

	_fire_timer = current_weapon.fire_cooldown


func _shake_camera(magnitude: float = 2.5, steps: int = 3) -> void:
	var tween := create_tween()
	for i in steps:
		tween.tween_property(_camera, "offset", Vector2(randf_range(-magnitude, magnitude), randf_range(-magnitude, magnitude)), 0.025)
	tween.tween_property(_camera, "offset", Vector2.ZERO, 0.04)


func add_poison() -> void:
	_poison_sources += 1
	if _poison_sources == 1:
		emit_signal("poison_changed", true)


func remove_poison() -> void:
	_poison_sources = maxi(0, _poison_sources - 1)
	if _poison_sources == 0:
		emit_signal("poison_changed", false)


## Refill oxygen by `amount` units (capped at MAX_OXYGEN).
## Call this from oxygen-station interactables.
func refill_oxygen(amount: float) -> void:
	oxygen = minf(MAX_OXYGEN, oxygen + amount)
	_oxygen_warned_low  = false
	_oxygen_warned_crit = false
	emit_signal("oxygen_changed", oxygen, MAX_OXYGEN)


func _check_oxygen_warnings() -> void:
	if DialogueManager.is_active:
		return
	if not _oxygen_warned_low and oxygen <= OXYGEN_WARN_LOW:
		_oxygen_warned_low = true
		DialogueManager.start_dialogue({
			"speaker": "ORCA",
			"lines": ["Oxygen at twenty-five percent.", "Locate a refill station."],
		})
	elif not _oxygen_warned_crit and oxygen <= OXYGEN_WARN_CRIT:
		_oxygen_warned_crit = true
		DialogueManager.start_dialogue({
			"speaker": "ORCA",
			"lines": ["Oxygen critical."],
		})


func _die_oxygen() -> void:
	_death_sound.play()
	set_physics_process(false)
	set_process_unhandled_input(false)
	GameState.death_return_scene = get_tree().current_scene.scene_file_path
	get_tree().change_scene_to_file("res://cutscene/death_screen.tscn")


## Called by an enemy hit. Reduces health and triggers hurt animation.
func take_damage(amount: int) -> void:
	if _hurt_timer > 0.0:
		return   # already in hit-stun, iframes active
	_sprite.play("hurt")
	_hurt_timer = 5.0 / 12.0  # hurt sheet: 5 frames @ 12 fps ≈ 0.42 s
	health = maxi(0, health - amount)
	emit_signal("health_changed", health, MAX_HEALTH)
	_update_health_desat()
	_hurt_flash()
	if health <= 0:
		die()


func _hurt_flash() -> void:
	_shake_camera(5.0, 5)
	_hurt_overlay.color.a = 0.45
	var tween := create_tween()
	tween.tween_property(_hurt_overlay, "color:a", 0.0, 0.35)


func _update_health_desat() -> void:
	if _desat_rect == null:
		return
	var desat: float
	if health <= 1:
		desat = 0.85
	elif health == 2:
		desat = 0.5
	else:
		desat = 0.0
	(_desat_rect.material as ShaderMaterial).set_shader_parameter("desaturation", desat)


## Called by an enemy when the player is killed.
func die() -> void:
	_death_sound.play()
	set_physics_process(false)
	set_process_unhandled_input(false)
	GameState.death_return_scene = get_tree().current_scene.scene_file_path
	get_tree().change_scene_to_file("res://cutscene/death_screen.tscn")


func _update_trails() -> void:
	var moving := velocity.length() > 8.0
	if submarine_mode:
		_swim_trail.emitting = false
		_sub_trail.emitting  = moving
		if moving:
			_sub_trail.rotation = velocity.angle() + PI
	else:
		_sub_trail.emitting  = false
		_swim_trail.emitting = moving
		if moving:
			_swim_trail.rotation = velocity.angle() + PI


## Recharge the flashlight battery by `amount` units (capped at MAX_BATTERY).
## Call this from PowerCell pickups.
func add_battery(amount: float) -> void:
	battery = minf(MAX_BATTERY, battery + amount)
	_battery_warned_low  = false
	_battery_warned_crit = false
	# Auto-switch light back on if it died
	if battery > 0.0 and not _light_on:
		_light_on = true
	emit_signal("battery_changed", battery, MAX_BATTERY)
	_update_cone_light(0.0)


func _update_cone_light(delta: float) -> void:
	var ratio := battery / MAX_BATTERY
	if ratio <= 0.0:
		cone_light.visible = false
		return
	if ratio < 0.1:
		# Flicker — random visibility and energy jitter near death
		_flicker_timer -= delta
		if _flicker_timer <= 0.0:
			_flicker_timer = randf_range(0.04, 0.22)
			cone_light.visible = randf() > 0.35
			cone_light.energy  = lerpf(0.15, 0.5, ratio / 0.1) * randf_range(0.6, 1.3)
	else:
		cone_light.visible = _light_on
		# Full brightness above 50 %; dims linearly down to 35 % at 10 % battery
		cone_light.energy = lerpf(0.35, 1.0, clampf(ratio / 0.5, 0.0, 1.0))


func _check_battery_warnings() -> void:
	if DialogueManager.is_active:
		return
	if not _battery_warned_low and battery <= BATTERY_WARN_LOW:
		_battery_warned_low = true
		DialogueManager.start_dialogue({
			"speaker": "ORCA",
			"lines": ["Torch battery at twenty-five percent.", "Find a power cell."],
		})
	elif not _battery_warned_crit and battery <= BATTERY_WARN_CRIT:
		_battery_warned_crit = true
		DialogueManager.start_dialogue({
			"speaker": "ORCA",
			"lines": ["Torch battery critical."],
		})


func _process(_delta: float) -> void:
	pass
