extends CharacterBody2D

const SWIM_SPEED = 300.0
const ACCELERATION = 800.0
const FRICTION = 600.0
const BUOYANCY = 60.0  # upward force when idle (not a velocity target)
@onready var cone_light: PointLight2D = $ConeLight

var _last_direction := Vector2.RIGHT

func _physics_process(delta: float) -> void:
	var direction := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	)

	if direction.length() > 0:
		direction = direction.normalized()
		_last_direction = direction
		velocity = velocity.move_toward(direction * SWIM_SPEED, ACCELERATION * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		velocity.y = move_toward(velocity.y, 0.0, FRICTION * delta)
		velocity.y -= BUOYANCY * delta

	velocity = velocity.limit_length(SWIM_SPEED)
	move_and_slide()

	# Rotate cone light to face movement direction
	cone_light.rotation = _last_direction.angle()

func _ready() -> void:
	Inventory.item_added.connect(func(item, qty):
		print("Picked up: ", item.display_name, " x", qty)
	)

func _process(_delta: float) -> void:
	# print("Nearby: ", $InteractionSystem.get_current_interactable())
	pass
