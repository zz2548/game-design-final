class_name ArenaEnergyBeam
extends Interactable

## Emitted when the player activates this beam.
## level_3.gd checks if both beams are primed to unlock the boss.
signal beam_primed

var _primed       : bool  = false
var _pulse_timer  : float = 0.0


func _ready() -> void:
	interaction_label = "Activate"


func _process(delta: float) -> void:
	_pulse_timer += delta
	queue_redraw()


func _draw() -> void:
	var t := _pulse_timer
	if _primed:
		var a := 0.7 + sin(t * 6.0) * 0.3
		# Outer glow
		draw_circle(Vector2.ZERO, 22.0, Color(0.2, 1.0, 1.0, a * 0.25))
		draw_circle(Vector2.ZERO, 14.0, Color(0.3, 1.0, 1.0, a * 0.6))
		draw_circle(Vector2.ZERO,  6.0, Color(1.0, 1.0, 1.0, 1.0))
		# Vertical beam pillar
		draw_line(Vector2(0, -70), Vector2(0, 70), Color(0.4, 1.0, 1.0, a * 0.7), 5.0)
		draw_line(Vector2(0, -70), Vector2(0, 70), Color(1.0, 1.0, 1.0, a * 0.3), 2.0)
	else:
		var a := 0.25 + sin(t * 2.0) * 0.1
		draw_circle(Vector2.ZERO, 16.0, Color(0.2, 0.5, 0.8, a * 0.3))
		draw_circle(Vector2.ZERO,  9.0, Color(0.3, 0.6, 0.9, a * 0.7))
		draw_circle(Vector2.ZERO,  4.0, Color(0.6, 0.85, 1.0, 0.8))
		draw_line(Vector2(0, -45), Vector2(0, 45), Color(0.3, 0.65, 0.9, a * 0.5), 3.0)


func _on_interact(_player: Node) -> void:
	if _primed:
		return
	_primed = true
	emit_signal("beam_primed")


## Called by level_3.gd when the phase 2 transition begins, so the beams can
## be re-activated for the second vulnerability window.
func reset() -> void:
	_primed = false


func is_primed() -> bool:
	return _primed
