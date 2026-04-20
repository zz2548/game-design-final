# submarine_interactable.gd
# Attach to the submarine Area2D in level_1.
#
# Before repair: opens the shared multi-slot drag task UI.
# After repair:  confirms boarding and emits boarded.
class_name SubmarineInteractable
extends Interactable

signal boarded(player: Node)

var _boarding_player: Node = null


func _ready() -> void:
	add_to_group("submarine_interactable")
	interaction_label = "Inspect Tethys-7"


func get_prompt_text() -> String:
	var label := "Board Tethys-7" if GameState.submarine_fixed else "Repair Tethys-7"
	return "[%s] %s" % [interaction_key, label]


func _on_interact(player: Node) -> void:
	_boarding_player = player

	if not GameState.submarine_fixed:
		var slots := get_tree().get_nodes_in_group("component_slot")
		get_tree().root.add_child(TaskUI.create_for_slots(slots))
		return

	DialogueManager.start_dialogue({
		"speaker": "ORCA",
		"lines": ["Systems nominal. Take the helm."],
	})
	DialogueManager.dialogue_ended.connect(_depart, CONNECT_ONE_SHOT)


func _depart() -> void:
	monitoring = false
	emit_signal("boarded", _boarding_player)
