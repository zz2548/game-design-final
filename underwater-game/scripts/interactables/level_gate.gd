class_name LevelGate
extends Interactable

signal gate_opened

const KEY_ID := "level2_key"


func _ready() -> void:
	interaction_label = "Gate (Locked)"
	scale = Vector2(0.5, 0.5)


func _on_interact(player: Node) -> void:
	if Inventory.has_item(KEY_ID, 1):
		Inventory.remove_item(KEY_ID, 1)
		interaction_label = "Gate (Open)"
		queue_redraw()
		emit_signal("gate_opened")
	else:
		DialogueManager.start_dialogue({
			"speaker": "ORCA",
			"lines": ["Gate is locked.", "An access key is required."],
		})
