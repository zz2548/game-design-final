# submarine_interactable.gd
# Attach to the submarine Area2D in level_1.
#
# First interact → tells the player what parts are missing.
# All 3 parts in inventory → consumes them, repairs, then transitions to next level
# after the repair dialogue closes.

class_name SubmarineInteractable
extends Interactable

## Emitted after the repair dialogue closes and the player confirms departure.
## The level scene listens to this to start the driving sequence.
signal boarded(player: Node)

const PARTS : Dictionary = {
	"engine_component":  "drive coupling",
	"hull_plating":      "pressure seal",
	"navigation_module": "nav core",
}

var _repaired : bool = false
var _boarding_player : Node = null


func _ready() -> void:
	interaction_label = "Inspect Tethys-7"


func _on_interact(player: Node) -> void:
	_boarding_player = player
	if _repaired:
		# Already repaired — confirm boarding, then hand off to level
		DialogueManager.start_dialogue({
			"speaker": "ORCA",
			"lines": ["Systems nominal. Take the helm."],
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
			"speaker": "ORCA",
			"lines": [
				"Tethys-7 systems check: critical failures detected.",
				"Missing components: " + ", ".join(missing) + ".",
				"Departure is not possible in current state.",
			],
		})


func _repair() -> void:
	for part_id : String in PARTS:
		Inventory.remove_item(part_id, 1)
	_repaired = true
	interaction_label = "Board Tethys-7"
	DialogueManager.start_dialogue({
		"speaker": "ORCA",
		"lines": [
			"Drive coupling installed.",
			"Pressure seal nominal.",
			"Nav core online.",
			"Tethys-7 is operational.",
		],
	})


func _depart() -> void:
	monitoring = false   # prevent further interactions
	emit_signal("boarded", _boarding_player)
