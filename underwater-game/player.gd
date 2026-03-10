extends CharacterBody2D

const SWIM_SPEED = 300.0
const ACCELERATION = 800.0
const FRICTION = 400.0
const BUOYANCY = 30.0  # gentle upward drift when idle

func _physics_process(delta: float) -> void:
	var direction := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	)

	if direction.length() > 0:
		# Normalize so diagonal isn't faster
		direction = direction.normalized()
		velocity = velocity.move_toward(direction * SWIM_SPEED, ACCELERATION * delta)
	else:
		# Friction slows you down, buoyancy floats you up
		velocity = velocity.move_toward(Vector2(0, -BUOYANCY), FRICTION * delta)

	move_and_slide()
