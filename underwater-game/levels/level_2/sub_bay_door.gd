extends AnimatableBody2D

var _override_callback : Callable

func close() -> void:
	# Door is already in its closed position by default.
	# Add a tween here later for the closing animation.
	pass

func open() -> void:
	# Move the door out of the way — shift it down by its own height.
	var tween := create_tween()
	tween.tween_property(self, "position", position + Vector2(0, 160), 1.2)

func enable_player_override(callback: Callable) -> void:
	_override_callback = callback
	# TODO: show an interaction prompt here — for now the player
	# can trigger it by pressing E near the door once this is called.

func _on_interact(_player: Node) -> void:
	if _override_callback.is_valid():
		_override_callback.call()
