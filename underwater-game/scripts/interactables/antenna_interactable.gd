# antenna_interactable.gd
# Attach to the antenna array Area2D in level_2.
#
# First interact  → plays ORCA repair dialogue, emits repaired signal.
# Second interact → confirms active status.

class_name AntennaInteractable
extends Interactable

signal repaired

var _fixed : bool = false


func _ready() -> void:
	interaction_label = "Inspect Antenna Array"


func _on_interact(_player: Node) -> void:
	if _fixed:
		DialogueManager.start_dialogue({
			"speaker": "ORCA",
			"lines": ["Antenna array is active. Signal broadcast nominal."],
		})
		return

	_fixed = true
	interaction_label = "Antenna Array [ACTIVE]"
	DialogueManager.start_dialogue({
		"speaker": "ORCA",
		"lines": [
			"Hardwiring bypass to antenna relay.",
			"Carrier signal locked.",
			"Broadcast initiated.",
			"If anyone is listening — we are here.",
		],
	})
	DialogueManager.dialogue_ended.connect(
		func(): emit_signal("repaired"), CONNECT_ONE_SHOT
	)
