# submarine_interactable.gd
# Attach to the submarine Area2D in level_1.
#
# First interact → tells the player what parts are missing.
# All 3 parts in inventory → consumes them, repairs, then transitions to next level
# after the repair dialogue closes.

class_name SubmarineInteractable
extends Interactable

const PARTS : Dictionary = {
	"engine_component":  "Engine Component",
	"hull_plating":      "Hull Plating",
	"navigation_module": "Navigation Module",
}

var _repaired : bool = false


func _ready() -> void:
	interaction_label = "Inspect Submarine"


func _on_interact(_player: Node) -> void:
	if _repaired:
		# Already repaired — board and depart
		DialogueManager.start_dialogue({
			"speaker": "SUBMARINE",
			"lines": ["Engines online. Departing now."],
		})
		DialogueManager.dialogue_ended.connect(_depart, CONNECT_ONE_SHOT)
		return

	# Check which parts are still missing
	var missing : Array[String] = []
	for part_id : String in PARTS:
		if not Inventory.has_item(part_id):
			missing.append(PARTS[part_id])

	if missing.is_empty():
		_repair()
	else:
		DialogueManager.start_dialogue({
			"speaker": "SUBMARINE",
			"lines": [
				"WARNING: Critical systems offline.",
				"Missing: " + ", ".join(missing) + ".",
				"Find all components to restore functionality.",
			],
		})


func _repair() -> void:
	for part_id : String in PARTS:
		Inventory.remove_item(part_id, 1)
	_repaired = true
	interaction_label = "Board Submarine"
	DialogueManager.start_dialogue({
		"speaker": "SUBMARINE",
		"lines": [
			"All components installed.",
			"Hull integrity: RESTORED.",
			"Navigation: ONLINE.",
			"Submarine ready for departure.",
		],
	})


func _depart() -> void:
	SceneManager.next_level()
