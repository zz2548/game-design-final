extends CharacterBody2D

const SWIM_SPEED = 300.0
const ACCELERATION = 800.0
const FRICTION = 600.0
const BUOYANCY = 60.0  # upward force when idle (not a velocity target)

func _physics_process(delta: float) -> void:
	var direction := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	)

	if direction.length() > 0:
		direction = direction.normalized()
		velocity = velocity.move_toward(direction * SWIM_SPEED, ACCELERATION * delta)
	else:
		# Friction brings you to a stop first, then buoyancy lifts you gently
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		velocity.y = move_toward(velocity.y, 0.0, FRICTION * delta)
		velocity.y -= BUOYANCY * delta  # apply as a force, not a velocity target

	velocity = velocity.limit_length(SWIM_SPEED)  # cap diagonal/buoyancy overshoot
	move_and_slide()

func _ready() -> void:
	Inventory.item_added.connect(func(item, qty):
		print("Picked up: ", item.display_name, " x", qty)
	)

func _process(_delta: float) -> void:
	# print("Nearby: ", $InteractionSystem.get_current_interactable())
	pass
