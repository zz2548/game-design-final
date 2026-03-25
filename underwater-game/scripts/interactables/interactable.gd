# interactable.gd
# BASE CLASS for all interactable objects in the world.
# Extend this script and override _on_interact() for custom behavior.
#
# Setup:
#   1. Create an Area3D node (or Area2D for 2D)
#   2. Add a CollisionShape3D child
#   3. Attach this script (or a script that extends it)
#
# Example child scripts: PickupItem, NoteObject, NpcInteractable, Door

class_name Interactable
extends Area2D

@export var interaction_label: String = "Examine"   # Shown in the UI prompt
@export var interaction_key: String = "E"            # Display only — actual key set in InteractionSystem

var is_in_range: bool = false

# ─── Override in child classes ───────────────────────────────────────────────

func _on_interact(player: Node) -> void:
	"""Called when the player presses E on this object. Override me."""
	pass


func get_prompt_text() -> String:
	"""Override to return a dynamic label (e.g., door open/close state)."""
	return "[%s] %s" % [interaction_key, interaction_label]
