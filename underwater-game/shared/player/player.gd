extends CharacterBody2D

# ── Movement ──────────────────────────────────────────────────────────────────
const SWIM_SPEED   : float = 200.0
const ACCELERATION : float = 340.0
# Water drag coefficients (exponential decay): velocity *= exp(-coeff * delta)
const WATER_RESIST : float = 1.0    # resistance applied while actively swimming
const SWIM_DRAG    : float = 3.2    # stronger drag when coasting (no input)

# ── Submarine driving ─────────────────────────────────────────────────────────
const SUB_SPEED    : float = 140.0  # heavier, slower
const SUB_ACCEL    : float = 105.0  # sluggish build-up
# Exponential drag for submarine (drifts much longer than free-swimming)
const SUB_RESIST   : float = 0.18   # light resistance while thrusting
const SUB_DRAG     : float = 1.1    # coasting drag — vessel drifts noticeably

var submarine_mode : bool = false

# ── Weapon ────────────────────────────────────────────────────────────────────
const DEFAULT_WEAPON : WeaponData = preload("res://shared/weapons/pistol.tres")

var current_weapon : WeaponData = null
var _ammo          : Dictionary = {}   # weapon_id → current ammo (int)

## Emitted whenever the equipped weapon or ammo count changes.
signal ammo_changed(weapon_name: String, current: int, maximum: int)

# ── Internal ──────────────────────────────────────────────────────────────────
@onready var cone_light        : PointLight2D    = $ConeLight
@onready var _sprite           : AnimatedSprite2D = $Sprite
@onready var _interaction_prompt : Label          = $InteractionPromptLayer/PromptLabel

var _fire_timer : float = 0.0


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	Inventory.item_added.connect(func(item, qty):
		print("Picked up: ", item.display_name, " x", qty)
	)
	equip_weapon(DEFAULT_WEAPON)
	_setup_sprite()
	_setup_interaction_prompt()


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
			input_dir = input_dir.normalized()
			velocity = velocity.move_toward(input_dir * SWIM_SPEED, ACCELERATION * delta)
			velocity *= exp(-WATER_RESIST * delta) # water resistance while swimming
		else:
			velocity *= exp(-SWIM_DRAG * delta)    # glide to a stop, not a snap
		velocity = velocity.limit_length(SWIM_SPEED)

	move_and_slide()

	# Aim the cone light at the mouse cursor every frame.
	# Offset the origin a few pixels toward the mouse so it always
	# appears to emit from the same point regardless of cursor direction.
	var to_mouse := get_global_mouse_position() - global_position
	if to_mouse.length() > 1.0:
		var dir := to_mouse.normalized()
		cone_light.rotation = to_mouse.angle()
		cone_light.position = dir * 5.0

	# Drive sprite animation and facing (only in free-swim)
	if not submarine_mode:
		var is_moving := velocity.length() > 8.0
		var target_anim := "swim" if is_moving else "idle"
		if _sprite.animation != "hurt" and _sprite.animation != target_anim:
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

	# Count down fire cooldown
	if _fire_timer > 0.0:
		_fire_timer -= delta


# ── Input (shooting) ──────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed:
		_fire()


# ── Weapon logic ──────────────────────────────────────────────────────────────

## Equip a weapon. First-time equip gives a full ammo pool; switching back
## to a previously held weapon restores its last ammo count.
func equip_weapon(weapon: WeaponData) -> void:
	current_weapon = weapon
	if not _ammo.has(weapon.id):
		_ammo[weapon.id] = weapon.max_ammo
	emit_signal("ammo_changed", weapon.display_name, _ammo[weapon.id], weapon.max_ammo)


func _fire() -> void:
	# Block fire during active dialogue or while piloting the submarine
	if DialogueManager.is_active or submarine_mode or current_weapon == null:
		return
	if _ammo.get(current_weapon.id, 0) <= 0:
		# TODO: play a "dry fire" / click sound
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

	_ammo[current_weapon.id] -= 1
	_fire_timer = current_weapon.fire_cooldown
	emit_signal("ammo_changed", current_weapon.display_name,
			_ammo[current_weapon.id], current_weapon.max_ammo)


## Call this from an ammo-pickup interactable to refill the current weapon's ammo.
func add_ammo(amount: int) -> void:
	if current_weapon == null:
		return
	var id := current_weapon.id
	_ammo[id] = mini(_ammo.get(id, 0) + amount, current_weapon.max_ammo)
	emit_signal("ammo_changed", current_weapon.display_name, _ammo[id], current_weapon.max_ammo)


## Called by an enemy when the player is killed.
## Plays a brief ORCA death line then reloads the level.
func die() -> void:
	set_physics_process(false)
	set_process_unhandled_input(false)
	DialogueManager.start_dialogue({
		"speaker": "ORCA",
		"lines": ["Pilot down. Reinitialising from last checkpoint."],
	})
	DialogueManager.dialogue_ended.connect(
		func(): get_tree().reload_current_scene(), CONNECT_ONE_SHOT
	)


func _process(_delta: float) -> void:
	pass
