class_name KeyPickup
extends PickupItem

var _t: float = 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var bob := sin(_t * 3.0) * 2.0
	var c := Color(1.0, 0.85, 0.1)
	# Ring
	draw_arc(Vector2(0, -6 + bob), 5.0, 0.0, TAU, 20, c, 2.5)
	# Shaft
	draw_line(Vector2(0, -1 + bob), Vector2(0, 9 + bob), c, 2.5)
	# Teeth
	draw_line(Vector2(0, 2 + bob), Vector2(4, 2 + bob), c, 2.0)
	draw_line(Vector2(0, 5 + bob), Vector2(4, 5 + bob), c, 2.0)
