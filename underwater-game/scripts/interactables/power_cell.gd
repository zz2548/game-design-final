# power_cell.gd
# Auto-collect flashlight battery pickup.
# The player swims through it to pick it up — no button press required.
#
# Place PowerCell.tscn in a level, adjust charge_amount in the Inspector.

class_name PowerCell
extends Area2D

## Battery units restored on pickup (max battery is 120).
@export var charge_amount : float = 40.0

var _collected : bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Bob up and down gently
	var tween := create_tween().set_loops()
	tween.tween_property(self, "position:y", position.y - 4.0, 0.8).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "position:y", position.y,       0.8).set_trans(Tween.TRANS_SINE)


func _on_body_entered(body: Node) -> void:
	if _collected:
		return
	if not body.is_in_group("player"):
		return
	if not body.has_method("add_battery"):
		return

	_collected = true
	body.add_battery(charge_amount)

	# Flash white then fade out before freeing
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.tween_callback(queue_free)
