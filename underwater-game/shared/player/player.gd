extends CharacterBody2D

# ── Movement ──────────────────────────────────────────────────────────────────
const SWIM_SPEED   : float = 300.0
const ACCELERATION : float = 800.0
const FRICTION     : float = 600.0
const BUOYANCY     : float = 60.0   # passive upward drift when not moving

# ── Submarine driving ─────────────────────────────────────────────────────────
const SUB_SPEED    : float = 180.0  # slower, heavier feel
const SUB_ACCEL    : float = 300.0
const SUB_FRICTION : float = 150.0  # drifts longer than swimming

var submarine_mode : bool = false

# ── Weapon ────────────────────────────────────────────────────────────────────
const BULLET_SCENE  : PackedScene = preload("res://scripts/weapons/bullet.tscn")
const BULLET_OFFSET : float = 12.0  # px ahead of centre to spawn bullet
const FIRE_COOLDOWN : float = 0.20  # seconds between shots

# ── Ammo ──────────────────────────────────────────────────────────────────────
const MAX_AMMO : int = 30
var current_ammo : int = MAX_AMMO

## Emitted whenever ammo changes so a HUD Label can update.
signal ammo_changed(current: int, maximum: int)

# ── Internal ──────────────────────────────────────────────────────────────────
@onready var cone_light  : PointLight2D = $ConeLight
@onready var _body_rect  : ColorRect    = $ColorRect

var _fire_timer : float = 0.0


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	Inventory.item_added.connect(func(item, qty):
		print("Picked up: ", item.display_name, " x", qty)
	)


# ── Submarine mode ────────────────────────────────────────────────────────────

## Called by the level once the player boards the submarine.
func enter_submarine_mode() -> void:
	submarine_mode = true
	_body_rect.hide()
	$InteractionZone.monitoring = false   # no interactions while piloting


# ── Physics (movement) ────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	var input_dir := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)

	if submarine_mode:
		# Heavier, no buoyancy — feels like piloting a vessel
		if input_dir.length() > 0.0:
			velocity = velocity.move_toward(
				input_dir.normalized() * SUB_SPEED, SUB_ACCEL * delta
			)
		else:
			velocity.x = move_toward(velocity.x, 0.0, SUB_FRICTION * delta)
			velocity.y = move_toward(velocity.y, 0.0, SUB_FRICTION * delta)
		velocity = velocity.limit_length(SUB_SPEED)
	else:
		if input_dir.length() > 0.0:
			input_dir = input_dir.normalized()
			velocity = velocity.move_toward(input_dir * SWIM_SPEED, ACCELERATION * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
			velocity.y = move_toward(velocity.y, 0.0, FRICTION * delta)
			velocity.y -= BUOYANCY * delta  # passive upward drift
		velocity = velocity.limit_length(SWIM_SPEED)

	move_and_slide()

	# Aim the cone light at the mouse cursor every frame
	var to_mouse := get_global_mouse_position() - global_position
	if to_mouse.length() > 1.0:
		cone_light.rotation = to_mouse.angle()

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

func _fire() -> void:
	# Block fire during active dialogue or while piloting the submarine
	if DialogueManager.is_active or submarine_mode:
		return
	if current_ammo <= 0:
		# TODO: play a "dry fire" / click sound
		return
	if _fire_timer > 0.0:
		return

	var aim_dir := (get_global_mouse_position() - global_position).normalized()

	var bullet : CharacterBody2D = BULLET_SCENE.instantiate()
	bullet.global_position = global_position + aim_dir * BULLET_OFFSET
	bullet.rotation       = aim_dir.angle()   # so the 5×2 rect faces the right way
	bullet.direction      = aim_dir
	get_parent().add_child(bullet)

	current_ammo -= 1
	_fire_timer   = FIRE_COOLDOWN
	emit_signal("ammo_changed", current_ammo, MAX_AMMO)


## Call this from an ammo-pickup interactable to refill ammo.
func add_ammo(amount: int) -> void:
	current_ammo = mini(current_ammo + amount, MAX_AMMO)
	emit_signal("ammo_changed", current_ammo, MAX_AMMO)


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
