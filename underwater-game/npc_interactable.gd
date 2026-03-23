# npc_interactable.gd
# Example: an NPC or note/log that triggers dialogue when E is pressed.
# Extend Interactable and call DialogueManager.start_dialogue()

class_name NpcInteractable
extends Interactable

# Define dialogue directly in the Inspector via exported vars,
# or load a JSON/resource file for larger projects.
@export var speaker_name: String = "Unknown"
@export_multiline var dialogue_lines: Array[String] = []
@export var portrait: Texture2D = null

func _ready() -> void:
	interaction_label = "Talk to %s" % speaker_name


func _on_interact(player: Node) -> void:
	if dialogue_lines.is_empty():
		return

	var dialogue := {
		"speaker": speaker_name,
		"lines": dialogue_lines,
		"portrait": portrait,
	}
	DialogueManager.start_dialogue(dialogue)
